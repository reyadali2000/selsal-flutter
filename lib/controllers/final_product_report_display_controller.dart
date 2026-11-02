import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/approval_status.dart';
import '../models/water_quality_models.dart';
import '../models/standards_models.dart';
import '../models/rejection_payload.dart';
import '../services/api/api.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../services/user_signature_service.dart';
import '../utils/final_product_report_pdf_generator.dart';

class FinalProductReportDisplayController extends GetxController {
  var isLoading = false.obs;

  late WaterQualityLog log;
  var currentLog = Rx<WaterQualityLog?>(null);

  var results = <WaterQualityResult>[].obs;
  var parameters = <int, TestParameter>{}.obs;
  var standards = <int, QualityStandard>{}.obs;

  var sensoryResults = <WaterQualityResult>[].obs;
  var physioChemicalResults = <WaterQualityResult>[].obs;
  var microbiologicalResults = <WaterQualityResult>[].obs;

  /// معايير الفحص الميكروبيولوجي (لإدخال النتائج في المرحلة الثانية)
  var microbiologicalStandards = <QualityStandard>[].obs;

  var shiftName = ''.obs;

  var inspectorSignatureBytes = Rx<Uint8List?>(null);
  var qmSignatureBytes = Rx<Uint8List?>(null);
  var gmSignatureBytes = Rx<Uint8List?>(null);
  var rejectedSignatureBytes = Rx<Uint8List?>(null);
  
  var microEntererSignatureBytes = Rx<Uint8List?>(null);
  var microQmSignatureBytes = Rx<Uint8List?>(null);
  var microGmSignatureBytes = Rx<Uint8List?>(null);

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is WaterQualityLog) {
      log = Get.arguments as WaterQualityLog;
      currentLog.value = log;
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    isLoading.value = true;
    final dbHelper = DatabaseHelper.instance;
    final effectiveLog = currentLog.value ?? log;

    // 1) إعادة تحميل التقرير ونتائجه من الـ API (المصدر الأساسي) إن أمكن
    if (Get.isRegistered<WaterQualityApiService>()) {
      try {
        final apiLog = await WaterQualityApiService.to.getLogById(log.id!);
        if (apiLog != null) {
          final logData = apiLog['log'] is Map
              ? Map<String, dynamic>.from(apiLog['log'])
              : (apiLog['Log'] is Map
                  ? Map<String, dynamic>.from(apiLog['Log'])
                  : apiLog);
          currentLog.value = WaterQualityLog.fromMap(logData);
          final resultsList = apiLog['results'] ?? apiLog['Results'] ?? logData['results'];
          if (resultsList is List) {
            results.value = (resultsList as List)
                .map((r) => WaterQualityResult.fromMap(Map<String, dynamic>.from(r)))
                .toList();
          }
        }
      } catch (e) {
        debugPrint('API final product getLogById error: $e');
      }
    }

    // مسار احتياطي: تحميل النتائج من قاعدة البيانات المحلية
    if (results.isEmpty) {
      results.value = await dbHelper.getWaterQualityResultsByLogId(log.id!);
    }

    // 2) بارامترات الفحص (الأسماء والوحدات)
    if (Get.isRegistered<MasterDataApiService>()) {
      try {
        final apiParams = await MasterDataApiService.to.getTestParameters();
        if (apiParams.isNotEmpty) {
          for (var pMap in apiParams) {
            final p = TestParameter.fromMap(pMap);
            if (p.id != null) parameters[p.id!] = p;
          }
        }
      } catch (e) {
        debugPrint('API final product params error: $e');
      }
    }
    if (parameters.isEmpty) {
      final allParams = await dbHelper.getTestParameters();
      for (var p in allParams) {
        parameters[p.id!] = p;
      }
    }

    // 3) المواصفات القياسية للمرجعية
    if (Get.isRegistered<MasterDataApiService>()) {
      try {
        final apiStds = await MasterDataApiService.to.getQualityStandards(waterType: 'Final Product');
        if (apiStds.isNotEmpty) {
          for (var sMap in apiStds) {
            final std = QualityStandard.fromMap(sMap);
            standards[std.parameterId] = std;
          }
        }
      } catch (e) {
        debugPrint('API final product standards error: $e');
      }
    }
    if (standards.isEmpty) {
      final allStandards = await dbHelper.getQualityStandards(null, 'Final Product');
      for (var std in allStandards) {
        standards[std.parameterId] = std;
      }
    }

    // Group results by category
    sensoryResults.clear();
    physioChemicalResults.clear();
    microbiologicalResults.clear();
    microbiologicalStandards.clear();

    for (var res in results) {
      final param = parameters[res.parameterId];
      if (param != null) {
        if (param.category == 'Sensory') {
          sensoryResults.add(res);
        } else if (param.category == 'Physical' ||
            param.category == 'Chemical' ||
            param.category == 'Physiochemical') {
          physioChemicalResults.add(res);
        } else if (param.category == 'Microbiological') {
          microbiologicalResults.add(res);
        }
      }
    }

    // فصل المعايير الميكروبيولوجية لاستخدامها في إدخال نتائج المرحلة الثانية
    for (var std in standards.values) {
      final param = parameters[std.parameterId];
      if (param != null && param.category == 'Microbiological') {
        microbiologicalStandards.add(std);
      }
    }

    // 4) اسم الوردية
    if (Get.isRegistered<MasterDataApiService>()) {
      try {
        final apiShifts = await MasterDataApiService.to.getShifts(branchId: effectiveLog.branchId);
        final shift = apiShifts.firstWhereOrNull((s) => s['id'] == effectiveLog.shiftId);
        if (shift != null) {
          shiftName.value = shift['name'] ?? 'غير معروف';
        }
      } catch (e) {
        debugPrint('API final product shifts error: $e');
      }
    }
    if (shiftName.value.isEmpty) {
      final allShifts = await dbHelper.getShifts();
      final shift = allShifts.firstWhereOrNull((s) => s.id == effectiveLog.shiftId);
      if (shift != null) {
        shiftName.value = shift.name;
      } else {
        shiftName.value = 'غير معروف';
      }
    }

    await _loadSignatures();

    isLoading.value = false;
  }

  Future<void> _loadSignatures() async {
    try {
      final sigService = UserSignatureService.instance;
      final curLog = currentLog.value ?? log;
      final inspName = curLog.sampleTaker?.isNotEmpty == true ? curLog.sampleTaker! : 'صلاح الجابري';
      inspectorSignatureBytes.value = await sigService.getSignatureBytesForUser(
        userName: inspName,
        userPosition: 'منفذ الفحص / أخصائي جودة',
      );

      final isClosed = curLog.approvalStatus == 'Closed';
      final qm = curLog.qmApprovedBy;
      final gm = curLog.gmApprovedBy ?? (isClosed ? curLog.gmDecisionBy : null);

      if (qm != null && qm.isNotEmpty) {
        qmSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userName: qm,
          userPosition: 'مدير الجودة',
        );
      } else {
        qmSignatureBytes.value = null;
      }

      if (gm != null && gm.isNotEmpty) {
        gmSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userName: gm,
          userPosition: 'مدير المصنع',
        );
      } else {
        gmSignatureBytes.value = null;
      }

      // تحميل توقيع الجهة التي رفضت التقرير (لعرضه بلون أحمر)
      final rejStatus = curLog.approvalStatus;
      if (ApprovalStatus.isRejectedStatus(rejStatus)) {
        final rejector = ApprovalStatus.rejectorName(
          rejectedBy: curLog.rejectedBy,
          gmDecisionBy: curLog.gmDecisionBy,
          status: rejStatus,
        );
        if (rejector != null && rejector.isNotEmpty) {
          final isGmRejector = ApprovalStatus.rejectedByFactoryManager(
            rejectedBy: curLog.rejectedBy,
            gmDecisionBy: curLog.gmDecisionBy,
            status: rejStatus,
          );
          rejectedSignatureBytes.value = await sigService.getSignatureBytesForUser(
            userName: rejector,
            userPosition: isGmRejector ? 'مدير المصنع' : 'مدير الجودة',
          );
        } else {
          rejectedSignatureBytes.value = null;
        }
      } else {
        rejectedSignatureBytes.value = null;
      }

      final microEnterer = curLog.microEnteredBy;
      final microQm = curLog.microQmApprovedBy;
      final microGm = curLog.microGmApprovedBy;

      if (microEnterer != null && microEnterer.isNotEmpty) {
        microEntererSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userName: microEnterer,
          userPosition: 'منفذ الفحص / أخصائي جودة',
        );
      } else {
        microEntererSignatureBytes.value = null;
      }

      if (microQm != null && microQm.isNotEmpty) {
        microQmSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userName: microQm,
          userPosition: 'مدير الجودة',
        );
      } else {
        microQmSignatureBytes.value = null;
      }

      if (microGm != null && microGm.isNotEmpty) {
        microGmSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userName: microGm,
          userPosition: 'مدير المصنع',
        );
      } else {
        microGmSignatureBytes.value = null;
      }
    } catch (_) {}
  }

  Future<void> fetchFreshLog() async {
    if (log.id != null) {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          final apiLog = await WaterQualityApiService.to.getLogById(log.id!);
          if (apiLog != null) {
            final logData = apiLog['log'] is Map
                ? Map<String, dynamic>.from(apiLog['log'])
                : (apiLog['Log'] is Map
                    ? Map<String, dynamic>.from(apiLog['Log'])
                    : apiLog);
            final freshApi = WaterQualityLog.fromMap(logData);
            log = freshApi;
            currentLog.value = freshApi;
            await _loadSignatures();
            return;
          }
        } catch (e) {
          debugPrint('fetchFreshLog API error: $e');
        }
      }

      final freshLog = await DatabaseHelper.instance.getWaterQualityLogById(log.id!);
      if (freshLog != null) {
        log = freshLog;
        currentLog.value = freshLog;
        await _loadSignatures();
      }
    }
  }

  Future<void> approveByQualityManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveQM) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية اعتماد مدير الجودة في حسابك الحالي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية اعتماد هذا التقرير التابع لمصنع آخر',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    final curLog = currentLog.value ?? log;
    if (!ApprovalStatus.canTransition(curLog.approvalStatus, 'Pending_GM')) {
      Get.snackbar('تنبيه', 'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(curLog.approvalStatus)})',
          backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'حمود يسر';

    try {
      final qmFull = '$qmName (مدير الجودة)';
      final now = DateTime.now();

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_GM',
            approvedBy: qmFull,
          );
        } catch (e) {
          debugPrint('API final product QM updateStatus error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_GM',
        qmApprovedBy: qmFull,
        qmApprovedAt: now,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'تقرير فحص منتج نهائي بانتظار الاعتماد النهائي',
          body: 'قام مدير الجودة ($qmName) باعتماد فحص المنتج النهائي (${log.batchNumber}) وهو بانتظار اعتماد مدير المصنع.',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'FactoryManager',
          branchId: log.branchId,
        );
        NotificationService.to.sendNotification(
          title: 'تم اعتماد تقرير فحص المنتج النهائي من مدير الجودة ✓',
          body: 'قام مدير الجودة ($qmName) باعتماد فحص المنتج النهائي (${log.batchNumber}) وتم تحويله لمدير المصنع للاعتماد النهائي.',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد بنجاح',
        'تم اعتماد التقرير من قبل مدير الجودة وتحويله لمدير المصنع للاعتماد النهائي',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث حالة الاعتماد: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> approveByFactoryManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveGM) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية اعتماد مدير المصنع في حسابك الحالي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا يمكنك اعتماد هذا التقرير لأنه يتبع لمصنع آخر',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    final curCheck = currentLog.value ?? log;
    final expectedNext = curCheck.microResultsPending ? 'Awaiting_Micro_Results' : 'Approved';
    if (!ApprovalStatus.canTransition(curCheck.approvalStatus, expectedNext)) {
      Get.snackbar('تنبيه', 'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(curCheck.approvalStatus)})',
          backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'مدير المصنع';

    try {
      final curLog = currentLog.value ?? log;
      final gmFull = '$gmName (مدير المصنع)';
      final now = DateTime.now();
      final targetStatus = curLog.microResultsPending ? 'Awaiting_Micro_Results' : 'Approved';

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            targetStatus,
            approvedBy: gmFull,
          );
        } catch (e) {
          debugPrint('API final product GM updateStatus error: $e');
        }
      }

      // المرحلة الأولى: إذا كانت نتائج الميكروبيولوجي لم تُدخل بعد،
      // يُعتمد التقرير مبدئياً ويُترك مفتوحاً لإدخالها لاحقاً.
      if (curLog.microResultsPending) {
        await DatabaseHelper.instance.updateWaterQualityLogApproval(
          logId: log.id!,
          approvalStatus: 'Awaiting_Micro_Results',
          gmApprovedBy: gmFull,
          gmApprovedAt: now,
          stage1QmApprovedBy: curLog.qmApprovedBy,
          stage1QmApprovedAt: curLog.qmApprovedAt,
          stage1GmApprovedBy: gmFull,
          stage1GmApprovedAt: now,
        );

        await fetchFreshLog();

        if (Get.isRegistered<NotificationService>()) {
          NotificationService.to.sendNotification(
            title: 'اعتماد مبدئي لتقرير فحص المنتج النهائي',
            body: 'اعتمد مدير المصنع ($gmName) التقرير (${log.batchNumber}) مبدئياً. بانتظار إدخال نتائج الفحص الميكروبيولوجي للاعتماد النهائي.',
            reportId: log.id,
            reportCategory: 'Final Product',
            targetRole: 'QualitySpecialist',
            branchId: log.branchId,
          );
        }

        Get.snackbar(
          'تم الاعتماد المبدئي',
          'اعتُمد التقرير مبدئياً وبانتظار إدخال نتائج الفحص الميكروبيولوجي لاستكمال الاعتماد النهائي',
          backgroundColor: Colors.teal.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Approved',
        gmApprovedBy: gmFull,
        gmApprovedAt: now,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'تم الاعتماد النهائي لتقرير فحص المنتج النهائي',
          body: 'قام مدير المصنع ($gmName) بالاعتماد النهائي للتقرير (${log.batchNumber}).',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد النهائي',
        'تم اعتماد التقرير بشكل نهائي من قبل مدير المصنع وأصبح جاهزاً للطباعة والأرشفة',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث حالة الاعتماد: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// إدخال نتائج الفحص الميكروبيولوجي (المرحلة الثانية) بعد الاعتماد المبدئي أو إعادة السحب
  Future<void> submitMicrobiologicalResults(List<WaterQualityResult> microResults) async {
    final curLog = currentLog.value ?? log;
    final st = curLog.approvalStatus;
    final canEnterMicro = st == 'Awaiting_Micro_Results' ||
        st == 'Micro_Resample_Pending' ||
        st == 'Micro_Rejected' ||
        st == 'Micro_Corrective_In_Progress' ||
        (st == 'Closed' && curLog.microResultsPending);
    if (!canEnterMicro) {
      Get.snackbar('تنبيه', 'لا يمكن إدخال النتائج الميكروبيولوجية في الحالة الحالية للتقرير',
          backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return;
    }

    final session = UserSessionService.to;
    if (!session.canEditReports && !session.canCreateWaterReports && !session.isAdmin) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية إدخال نتائج الفحص الميكروبيولوجي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final enteredBy = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : (curLog.sampleTaker ?? 'أخصائي الجودة');

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.saveMicroResults(
            curLog.id!,
            microResults.map((r) => r.toMap()).toList(),
            enteredBy: enteredBy,
          );
          await WaterQualityApiService.to.updateStatus(
            curLog.id!,
            'Pending_Micro_QM',
            approvedBy: enteredBy,
          );
        } catch (e) {
          debugPrint('API final product saveMicroResults error: $e');
        }
      }

      await DatabaseHelper.instance.saveMicrobiologicalResults(curLog.id!, microResults);

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: curLog.id!,
        approvalStatus: 'Pending_Micro_QM',
        microResultsPending: false,
        microEnteredBy: enteredBy,
        microEnteredAt: DateTime.now(),
      );

      await _loadReportData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'نتائج الفحص الميكروبيولوجي بانتظار الاعتماد',
          body: 'أدخل $enteredBy نتائج الفحص الميكروبيولوجي للتقرير (${curLog.batchNumber}) وهو بانتظار اعتماد مدير الجودة.',
          reportId: curLog.id,
          reportCategory: 'Final Product',
          targetRole: 'QualityManager',
          branchId: curLog.branchId,
        );
      }

      Get.snackbar(
        'تم إدخال النتائج',
        'أُرسلت نتائج الفحص الميكروبيولوجي لمدير الجودة للاعتماد (المرحلة الثانية)',
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حفظ نتائج الفحص الميكروبيولوجي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// المرحلة الثانية: اعتماد مدير الجودة لنتائج الفحص الميكروبيولوجي
  Future<void> approveMicroByQualityManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveQM || !session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية اعتماد نتائج الفحص الميكروبيولوجي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'حمود يسر';

    try {
      final qmFull = '$qmName (مدير الجودة)';
      final now = DateTime.now();

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_Micro_GM',
            approvedBy: qmFull,
          );
        } catch (e) {
          debugPrint('API final product approveMicroByQualityManager error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_Micro_GM',
        microQmApprovedBy: qmFull,
        microQmApprovedAt: now,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'نتائج الفحص الميكروبيولوجي بانتظار الاعتماد النهائي',
          body: 'اعتمد مدير الجودة ($qmName) نتائج الفحص الميكروبيولوجي للتقرير (${log.batchNumber}) وبانتظار اعتماد مدير المصنع.',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'FactoryManager',
          branchId: log.branchId,
        );
        NotificationService.to.sendNotification(
          title: 'تم اعتماد نتائج الفحص الميكروبيولوجي من مدير الجودة ✓',
          body: 'اعتمد مدير الجودة ($qmName) نتائج الفحص الميكروبيولوجي للتقرير (${log.batchNumber}) وتم تحويلها للاعتماد النهائي.',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد بنجاح',
        'تم اعتماد نتائج الفحص الميكروبيولوجي من مدير الجودة وتحويلها لمدير المصنع للاعتماد النهائي',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث حالة الاعتماد: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// المرحلة الثانية: الاعتماد النهائي لمدير المصنع على نتائج الفحص الميكروبيولوجي
  Future<void> approveMicroByFactoryManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveGM || !session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية الاعتماد النهائي على نتائج الفحص الميكروبيولوجي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'مدير المصنع';

    try {
      final gmFull = '$gmName (مدير المصنع)';
      final now = DateTime.now();

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Approved',
            approvedBy: gmFull,
          );
        } catch (e) {
          debugPrint('API final product approveMicroByFactoryManager error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Approved',
        gmApprovedBy: gmFull,
        gmApprovedAt: now,
        microGmApprovedBy: gmFull,
        microGmApprovedAt: now,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'تم الاعتماد النهائي لنتائج الفحص الميكروبيولوجي',
          body: 'قام مدير المصنع ($gmName) بالاعتماد النهائي لنتائج الفحص الميكروبيولوجي للتقرير (${log.batchNumber}).',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد النهائي',
        'اكتملت جولتا الاعتماد وأصبح التقرير معتمداً نهائياً وجاهزاً للطباعة والأرشفة',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث حالة الاعتماد: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفض خاص بنتائج الفحص الميكروبيولوجي دون إلغاء الاعتماد الفيزيوكيميائي الأولي
  Future<void> rejectMicroReport({
    required String reason,
    required String actionType,
    String? correctiveAction,
    String? correctiveOwner,
    DateTime? dueDate,
    String? notes,
  }) async {
    if (reason.trim().isEmpty) {
      Get.snackbar('تنبيه', 'يرجى كتابة سبب رفض نتائج الفحص الميكروبيولوجي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final session = UserSessionService.to;
    if (!session.canRejectReports) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفض التقارير في حسابك الحالي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفض هذا التقرير التابع لمصنع آخر',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final rejectorName = '${session.currentUserName.value} (${session.roleTitle})';
    final isResample = actionType == 'resample';
    final newStatus = isResample
        ? ApprovalStatus.microResamplePending
        : ((correctiveAction != null && correctiveAction.isNotEmpty)
            ? ApprovalStatus.microCorrectiveInProgress
            : ApprovalStatus.microRejected);

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            newStatus,
            approvedBy: rejectorName,
            rejectionReason: reason,
            microRejectionReason: reason,
            microRejectedBy: rejectorName,
            microRejectionAction: actionType,
            correctiveAction: correctiveAction,
            correctiveOwner: correctiveOwner,
            correctiveDueDate: dueDate?.toIso8601String(),
          );
        } catch (e) {
          debugPrint('API final product rejectMicroReport error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: newStatus,
        microResultsPending: isResample ? true : false,
        microRejectionReason: reason,
        microRejectedBy: rejectorName,
        microRejectedAt: DateTime.now(),
        microRejectionAction: actionType,
        correctiveAction: correctiveAction,
        correctiveOwner: correctiveOwner,
        correctiveDueDate: dueDate,
        rejectionNotes: notes,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: isResample
              ? 'مطلوب إعادة سحب عينة ميكروبيولوجية'
              : 'تم رفض نتائج الفحص الميكروبيولوجي',
          body: isResample
              ? 'طلب $rejectorName إعادة سحب عينة ميكروبيولوجية جديدة للتشغيلة (${log.batchNumber}): $reason'
              : 'رفض $rejectorName نتائج الفحص الميكروبيولوجي للتشغيلة (${log.batchNumber}): $reason',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        isResample ? 'تم طلب إعادة سحب عينة' : 'تم رفض نتائج الفحص الميكروبيولوجي',
        isResample
            ? 'تم حفظ طلب إعادة السحب وإبقاء الفحص الفيزيوكيميائي الأولي معتمداً وسارياً.'
            : 'تم رفض نتائج الفحص الميكروبيولوجي مع الحفاظ على اعتماد الفحص الفيزيوكيميائي الأولي.',
        backgroundColor: isResample ? const Color(0xFF00838F) : Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض نتائج الميكروبيولوجي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> rejectReport(RejectionPayload payload) async {
    if (!payload.isValid) {
      Get.snackbar('تنبيه', 'يرجى كتابة سبب الرفض', backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final session = UserSessionService.to;
    if (!session.canRejectReports) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفض التقارير في حسابك الحالي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفض هذا التقرير التابع لمصنع آخر',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final rejectorName = '${session.currentUserName.value} (${session.roleTitle})';
    final newStatus = payload.hasCorrectiveAction ? 'Corrective_In_Progress' : 'Rejected';

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            newStatus,
            approvedBy: rejectorName,
            rejectionReason: payload.reason,
            rejectionCategory: payload.category,
            severityLevel: payload.severity,
            rejectionNotes: payload.notes,
            affectedProducts: payload.affectedProducts,
            immediateAction: payload.immediateAction,
            correctiveAction: payload.correctiveAction,
            correctiveOwner: payload.correctiveOwner,
            correctiveDueDate: payload.dueDate?.toIso8601String(),
          );
        } catch (e) {
          debugPrint('API final product rejectReport error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: newStatus,
        rejectionReason: payload.reason,
        rejectedBy: rejectorName,
        rejectionCategory: payload.category,
        severityLevel: payload.severity,
        rejectionNotes: payload.notes,
        affectedProducts: payload.affectedProducts,
        immediateAction: payload.immediateAction,
        correctiveAction: payload.correctiveAction,
        correctiveOwner: payload.correctiveOwner,
        correctiveDueDate: payload.dueDate,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'تم رفض تقرير فحص المنتج النهائي',
          body: 'تم رفض تقرير التشغيلة (${log.batchNumber}) بواسطة $rejectorName: ${payload.reason}'
              '${payload.hasCorrectiveAction ? "\nالإجراء التصحيحي: ${payload.correctiveAction}" : ""}',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );

        if (payload.hasCorrectiveAction) {
          NotificationService.to.sendNotification(
            title: 'إجراء تصحيحي جديد مطلوب تنفيذه',
            body: 'تم رفض تقرير المنتج النهائي (${log.batchNumber}) وتعيين إجراء تصحيحي: ${payload.correctiveAction}'
                ' — المسؤول: ${payload.correctiveOwner}، يرجى التنفيذ والتوثيق.',
            reportId: log.id,
            reportCategory: 'Final Product',
            targetRole: 'QualitySpecialist',
            branchId: log.branchId,
          );
        }
      }

      Get.snackbar(
        payload.hasCorrectiveAction ? 'تم الرفض وتعيين إجراء تصحيحي' : 'تم الرفض',
        payload.hasCorrectiveAction
            ? 'تم رفض التقرير مع تعيين إجراء تصحيحي للمسؤول المختص'
            : 'تم رفض التقرير وإعادته لأخصائي الجودة مع ملاحظات الرفض',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض التقرير: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير الجودة ورفعه لمدير المصنع
  Future<void> qmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM || !session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية مدير الجودة لاعتماد الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';
    final now = DateTime.now();

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_GM_Decision',
            approvedBy: qmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API final product qmApproveCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_GM_Decision',
        qmApprovedBy: qmName,
        qmApprovedAt: now,
        gmDecisionNotes: notes,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي معتمد من الجودة وبانتظار قرار مدير المصنع',
          body: 'اعتمد $qmFull الإجراء التصحيحي لتقرير المنتج النهائي (${log.batchNumber}) وتم رفعه لمدير المصنع للقرار النهائي.',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'FactoryManager',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم اعتماد مدير الجودة للإجراء التصحيحي',
        'تم رفع الإجراء التصحيحي إلى مدير المصنع لاتخاذ القرار النهائي',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفض الإجراء التصحيحي من قبل مدير الجودة وإعادته للمسؤول للتعديل
  Future<void> qmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM || !session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية مدير الجودة لرفض الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Corrective_In_Progress',
            approvedBy: qmFull,
            rejectionReason: notes,
            gmDecision: 'Rejected',
            gmDecisionBy: qmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API final product qmRejectCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Corrective_In_Progress',
        gmDecision: 'Rejected',
        gmDecisionBy: qmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'مدير الجودة يرفض الإجراء التصحيحي للتعديل',
          body: 'رفض $qmFull الإجراء التصحيحي لتقرير المنتج النهائي (${log.batchNumber}) وطلب تعديله: $notes',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تمت إعادة الإجراء التصحيحي للمسؤول',
        'تمت إعادة التقرير للمسؤول لتعديل وتوثيق إجراء تصحيحي مناسب',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير المصنع وإغلاق التقرير
  Future<void> gmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM || !session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية اعتماد الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';

    final curLog = currentLog.value ?? log;
    final bool hasPendingMicro = curLog.microResultsPending;
    final String targetStatus = hasPendingMicro ? 'Awaiting_Micro_Results' : 'Closed';
    final now = DateTime.now();

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            targetStatus,
            approvedBy: gmFull,
            gmDecision: 'Approved',
            gmDecisionBy: gmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API final product gmApproveCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: targetStatus,
        gmApprovedBy: gmName,
        gmApprovedAt: now,
        gmDecision: 'Approved',
        gmDecisionBy: gmFull,
        gmDecisionAt: now,
        gmDecisionNotes: notes,
        stage1GmApprovedBy: hasPendingMicro ? gmFull : null,
        stage1GmApprovedAt: hasPendingMicro ? now : null,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: hasPendingMicro
              ? 'اعتماد الإجراء التصحيحي — بانتظار نتائج الميكروبيولوجي'
              : 'اعتماد الإجراء التصحيحي وإغلاق التقرير',
          body: hasPendingMicro
              ? 'اعتمد $gmFull الإجراء التصحيحي للتقرير (${log.batchNumber}). التقرير الآن بانتظار إدخال نتائج الفحص الميكروبيولوجي للاعتماد النهائي.'
              : 'اعتمد $gmFull الإجراء التصحيحي لتقرير المنتج النهائي (${log.batchNumber}) وتم إغلاقه نهائياً.',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: hasPendingMicro ? 'QualitySpecialist' : 'All',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم اعتماد الإجراء التصحيحي',
        hasPendingMicro
            ? 'اعتُمد الإجراء التصحيحي بنجاح، والتقرير الآن بانتظار إدخال نتائج الفحص الميكروبيولوجي'
            : 'أُغلق التقرير نهائياً وأصبح الإجراء التصحيحي معتمداً رسمياً',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفض الإجراء التصحيحي قطعياً من قبل مدير المصنع وإغلاق التقرير بالرفض النهائي
  Future<void> gmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM || !session.canApproveBranchData(log.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفض الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Rejected_By_GM',
            approvedBy: gmFull,
            rejectionReason: notes,
            gmDecision: 'Rejected',
            gmDecisionBy: gmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API final product gmRejectCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Rejected_By_GM',
        gmDecision: 'Rejected',
        gmDecisionBy: gmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'رفض قطعي للإجراء التصحيحي وإغلاق التقرير',
          body: 'رفض $gmFull الإجراء التصحيحي لتقرير المنتج النهائي (${log.batchNumber}) وتم إغلاقه بالرفض النهائي. السبب: $notes',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'All',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم الرفض النهائي وإغلاق التقرير',
        'تم رفض الإجراء التصحيحي قطعياً وإغلاق التقرير بالرفض النهائي',
        backgroundColor: const Color(0xFF8B0000),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفع الإجراء التصحيحي المنفَّذ إلى مدير الجودة للمراجعة والاعتماد
  Future<void> submitCorrectiveAction([String? notes]) async {
    final session = UserSessionService.to;
    if (!session.canEditReports && !session.canCreateWaterReports && !session.canRejectReports && !session.isAdmin) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفع الإجراء التصحيحي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final submitterName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : session.roleTitle;
    final effectiveAction = (notes != null && notes.trim().isNotEmpty) ? notes.trim() : (log.correctiveAction ?? 'تم إنجاز الإجراء التصحيحي');

    try {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_QM_Decision',
            approvedBy: submitterName,
            correctiveAction: effectiveAction,
          );
        } catch (e) {
          debugPrint('API final product submitCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_QM_Decision',
        correctiveAction: effectiveAction,
      );

      await fetchFreshLog();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي بانتظار اعتماد مدير الجودة',
          body: 'قام $submitterName بتوثيق ورفع الإجراء التصحيحي لتقرير المنتج النهائي (${log.batchNumber}) وهو بانتظار مراجعتك واعتمادك.',
          reportId: log.id,
          reportCategory: 'Final Product',
          targetRole: 'QualityManager',
          branchId: log.branchId,
        );
      }

      Get.snackbar(
        'تم رفع الإجراء التصحيحي لمدير الجودة',
        'أصبح التقرير بانتظار مراجعة واعتماد مدير الجودة للإجراء التصحيحي',
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفع الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  void printReport() {
    final curLog = currentLog.value ?? log;
    FinalProductReportPdfGenerator.generateAndPrintReport(
      log: curLog,
      results: results,
      parameters: parameters,
      shiftName: shiftName.value,
      productName: curLog.productName ?? 'مياه شرب معبأة سلسال',
      inspectorSignatureBytes: inspectorSignatureBytes.value,
      qmSignatureBytes: qmSignatureBytes.value,
      gmSignatureBytes: gmSignatureBytes.value,
      microEntererSignatureBytes: microEntererSignatureBytes.value,
      microQmSignatureBytes: microQmSignatureBytes.value,
      microGmSignatureBytes: microGmSignatureBytes.value,
    );
  }
}
