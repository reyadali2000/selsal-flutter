import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/approval_status.dart';
import '../models/water_quality_models.dart';
import '../models/standards_models.dart';
import '../models/rejection_payload.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../services/user_signature_service.dart';
import '../services/api/api.dart';
import '../utils/raw_water_report_pdf_generator.dart';

class RawWaterReportDisplayController extends GetxController {
  var isLoading = false.obs;

  var currentLog = Rx<WaterQualityLog?>(null);
  
  var results = <WaterQualityResult>[].obs;
  var parameters = <int, TestParameter>{}.obs;
  var standards = <int, QualityStandard>{}.obs;

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

  WaterQualityLog get log => currentLog.value!;

  @override
  void onInit() {
    super.onInit();
    if (Get.arguments != null && Get.arguments is WaterQualityLog) {
      currentLog.value = Get.arguments as WaterQualityLog;
      _loadReportData();
    }
  }

  Future<void> _loadReportData() async {
    if (currentLog.value == null) return;
    isLoading.value = true;
    final dbHelper = DatabaseHelper.instance;

    // Reload latest log from API / DB in case status changed
    if (currentLog.value?.id != null) {
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          final apiLog = await WaterQualityApiService.to.getLogById(currentLog.value!.id!);
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
          debugPrint('API raw water getLogById error: $e');
        }
      }

      if (results.isEmpty) {
        final freshLog = await dbHelper.getWaterQualityLogById(currentLog.value!.id!);
        if (freshLog != null) {
          currentLog.value = freshLog;
        }
        results.value = await dbHelper.getWaterQualityResultsByLogId(log.id!);
      }
    }

    if (Get.isRegistered<MasterDataApiService>()) {
      try {
        final apiParams = await MasterDataApiService.to.getTestParameters();
        if (apiParams.isNotEmpty) {
          for (var pMap in apiParams) {
            final p = TestParameter.fromMap(pMap);
            if (p.id != null) parameters[p.id!] = p;
          }
        }
        final apiStds = await MasterDataApiService.to.getQualityStandards(waterType: 'Raw Water');
        if (apiStds.isNotEmpty) {
          for (var sMap in apiStds) {
            final std = QualityStandard.fromMap(sMap);
            standards[std.parameterId] = std;
          }
        }
        final apiShifts = await MasterDataApiService.to.getShifts(branchId: log.branchId);
        if (apiShifts.isNotEmpty) {
          final shift = apiShifts.firstWhereOrNull((s) => s['id'] == log.shiftId);
          if (shift != null) {
            shiftName.value = shift['name'] ?? 'غير معروف';
          }
        }
      } catch (e) {
        debugPrint('API raw water params/standards error: $e');
      }
    }

    if (parameters.isEmpty) {
      final allParams = await dbHelper.getTestParameters();
      for (var p in allParams) {
        parameters[p.id!] = p;
      }
    }

    if (standards.isEmpty) {
      final allStandards = await dbHelper.getQualityStandards(null, 'Raw Water');
      for (var std in allStandards) {
        standards[std.parameterId] = std;
      }
    }

    // فصل المعايير الميكروبيولوجية لاستخدامها في إدخال نتائج المرحلة الثانية
    microbiologicalStandards.clear();
    for (var std in standards.values) {
      final param = parameters[std.parameterId];
      if (param != null && param.category == 'Microbiological') {
        microbiologicalStandards.add(std);
      }
    }

    if (shiftName.value.isEmpty) {
      final allShifts = await dbHelper.getShifts();
      final shift = allShifts.firstWhereOrNull((s) => s.id == log.shiftId);
      if (shift != null) {
        shiftName.value = shift.name;
      } else {
        shiftName.value = 'غير معروف';
      }
    }

    // Load visual overlay signatures
    try {
      final sigService = UserSignatureService.instance;
      final inspName = log.sampleTaker?.isNotEmpty == true ? log.sampleTaker! : 'أخصائي الجودة';
      inspectorSignatureBytes.value = await sigService.getSignatureBytesForUser(
        userName: inspName,
        userPosition: 'منفذ الفحص / أخصائي جودة',
      );

      // في الاعتماد على مرحلتين، أسماء المرحلة الثانية (نتائج الميكروبيولوجي)
      // لها الأولوية إن وُجدت
      final isClosed = log.approvalStatus == 'Closed';
      final effectiveQm = log.qmApprovedBy;
      final effectiveGm = log.gmApprovedBy ?? (isClosed ? log.gmDecisionBy : null);

      if (effectiveQm != null && effectiveQm.isNotEmpty) {
        qmSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userName: effectiveQm,
          userPosition: 'مدير الجودة',
        );
      } else {
        qmSignatureBytes.value = null;
      }

      if (effectiveGm != null && effectiveGm.isNotEmpty) {
        gmSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userName: effectiveGm,
          userPosition: 'مدير المصنع',
        );
      } else {
        gmSignatureBytes.value = null;
      }

      // تحميل توقيع الجهة التي رفضت التقرير (لعرضه بلون أحمر)
      final rejStatus = log.approvalStatus;
      if (ApprovalStatus.isRejectedStatus(rejStatus)) {
        final rejector = ApprovalStatus.rejectorName(
          rejectedBy: log.rejectedBy,
          gmDecisionBy: log.gmDecisionBy,
          status: rejStatus,
        );
        if (rejector != null && rejector.isNotEmpty) {
          final isGmRejector = ApprovalStatus.rejectedByFactoryManager(
            rejectedBy: log.rejectedBy,
            gmDecisionBy: log.gmDecisionBy,
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

      final microEnterer = log.microEnteredBy;
      final microQm = log.microQmApprovedBy;
      final microGm = log.microGmApprovedBy;

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

    isLoading.value = false;
  }

  Future<void> approveByQualityManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveQM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مدير الجودة في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!ApprovalStatus.canTransition(log.approvalStatus, 'Pending_GM')) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(log.approvalStatus)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'حمود يسر (مدير الجودة)';
    final now = DateTime.now();

    try {
      isLoading.value = true;
      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_GM',
            approvedBy: qmName,
          );
        } catch (e) {
          debugPrint('API raw water QM updateStatus error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_GM',
        qmApprovedBy: qmName,
        qmApprovedAt: now,
      );

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تقرير مياه خام بانتظار اعتماد مدير المصنع',
          body: 'تم اعتماد التقرير رقم (${log.batchNumber}) من مدير الجودة ($qmName) وبانتظار اعتمادك النهائي.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'FactoryManager',
          branchId: log.branchId,
        );
        await NotificationService.to.sendNotification(
          title: 'تم اعتماد تقرير فحص المياه الخام من مدير الجودة ✓',
          body: 'اعتمد مدير الجودة ($qmName) تقرير المياه الخام رقم (${log.batchNumber}) وتم إرساله لمدير المصنع للاعتماد النهائي.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم الاعتماد بنجاح',
        'تم اعتماد التقرير من قِبل مدير الجودة وإرساله لمدير المصنع للاعتماد النهائي',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد التقرير: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approveByFactoryManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveGM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مدير المصنع في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    final expectedNext = log.microResultsPending ? 'Awaiting_Micro_Results' : 'Approved';
    if (!ApprovalStatus.canTransition(log.approvalStatus, expectedNext)) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(log.approvalStatus)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'خالد العمري (مدير المصنع)';
    final now = DateTime.now();

    try {
      isLoading.value = true;

      // المرحلة الأولى: إذا كانت نتائج الميكروبيولوجي لم تُدخل بعد،
      // يُعتمد التقرير مبدئياً ويُترك مفتوحاً لإدخالها لاحقاً.
      if (log.microResultsPending) {
        if (Get.isRegistered<WaterQualityApiService>()) {
          try {
            await WaterQualityApiService.to.updateStatus(
              log.id!,
              'Awaiting_Micro_Results',
              approvedBy: gmName,
            );
          } catch (e) {
            debugPrint('API raw water GM updateStatus error: $e');
          }
        }

        await DatabaseHelper.instance.updateWaterQualityLogApproval(
          logId: log.id!,
          approvalStatus: 'Awaiting_Micro_Results',
          gmApprovedBy: gmName,
          gmApprovedAt: now,
          stage1QmApprovedBy: log.qmApprovedBy,
          stage1QmApprovedAt: log.qmApprovedAt,
          stage1GmApprovedBy: gmName,
          stage1GmApprovedAt: now,
        );

        if (Get.isRegistered<NotificationService>()) {
          await NotificationService.to.sendNotification(
            title: 'اعتماد مبدئي لتقرير فحص المياه الخام',
            body: 'اعتمد مدير المصنع ($gmName) التقرير رقم (${log.batchNumber}) مبدئياً. بانتظار إدخال نتائج الفحص الميكروبيولوجي للاعتماد النهائي.',
            reportId: log.id,
            reportCategory: 'Raw Water',
            targetRole: 'QualitySpecialist',
            branchId: log.branchId,
          );
        }

        await _loadReportData();

        Get.snackbar(
          'تم الاعتماد المبدئي',
          'اعتُمد التقرير مبدئياً وبانتظار إدخال نتائج الفحص الميكروبيولوجي لاستكمال الاعتماد النهائي',
          backgroundColor: Colors.teal.shade700,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        );
        return;
      }

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Approved',
            approvedBy: gmName,
          );
        } catch (e) {
          debugPrint('API raw water GM approved error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Approved',
        gmApprovedBy: gmName,
        gmApprovedAt: now,
      );

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'اعتماد نهائي لتقرير فحص المياه الخام',
          body: 'تم الاعتماد النهائي لتقرير فحص المياه الخام رقم (${log.batchNumber}) بنجاح من مدير المصنع.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'All',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم الاعتماد النهائي',
        'تم اعتماد التقرير نهائياً وأصبح مقفلاً وجاهزاً للطباعة الرسمية',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل الاعتماد النهائي: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// إدخال نتائج الفحص الميكروبيولوجي (المرحلة الثانية) بعد الاعتماد المبدئي أو إعادة السحب
  Future<void> submitMicrobiologicalResults(List<WaterQualityResult> microResults) async {
    final st = log.approvalStatus;
    final canEnterMicro = st == 'Awaiting_Micro_Results' ||
        st == 'Micro_Resample_Pending' ||
        st == 'Micro_Rejected' ||
        st == 'Micro_Corrective_In_Progress' ||
        (st == 'Closed' && log.microResultsPending);
    if (!canEnterMicro) {
      Get.snackbar('تنبيه', 'لا يمكن إدخال النتائج الميكروبيولوجية في الحالة الحالية للتقرير',
          backgroundColor: Colors.orange.shade800, colorText: Colors.white);
      return;
    }

    final session = UserSessionService.to;
    if (!session.canEditReports && !session.canCreateWaterReports && !session.isAdmin) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية إدخال نتائج الفحص الميكروبيولوجي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final enteredBy = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : (log.sampleTaker ?? 'أخصائي الجودة');

    try {
      isLoading.value = true;

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.saveMicroResults(
            log.id!,
            microResults.map((r) => r.toMap()).toList(),
            enteredBy: enteredBy,
          );
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_Micro_QM',
            approvedBy: enteredBy,
          );
        } catch (e) {
          debugPrint('API raw water saveMicroResults error: $e');
        }
      }

      await DatabaseHelper.instance.saveMicrobiologicalResults(log.id!, microResults);

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_Micro_QM',
        microResultsPending: false,
        microEnteredBy: enteredBy,
        microEnteredAt: DateTime.now(),
      );

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'نتائج الفحص الميكروبيولوجي بانتظار الاعتماد',
          body: 'أدخل $enteredBy نتائج الفحص الميكروبيولوجي للتقرير رقم (${log.batchNumber}) وهو بانتظار اعتماد مدير الجودة.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'QualityManager',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم إدخال النتائج',
        'أُرسلت نتائج الفحص الميكروبيولوجي لمدير الجودة للاعتماد (المرحلة الثانية)',
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل حفظ نتائج الفحص الميكروبيولوجي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// المرحلة الثانية: اعتماد مدير الجودة لنتائج الفحص الميكروبيولوجي
  Future<void> approveMicroByQualityManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveQM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مدير الجودة في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'حمود يسر (مدير الجودة)';

    try {
      isLoading.value = true;

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_Micro_GM',
            approvedBy: qmName,
          );
        } catch (e) {
          debugPrint('API raw water micro QM error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_Micro_GM',
        microQmApprovedBy: qmName,
        microQmApprovedAt: DateTime.now(),
      );

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'نتائج الفحص الميكروبيولوجي بانتظار الاعتماد النهائي',
          body: 'اعتمد مدير الجودة ($qmName) نتائج الفحص الميكروبيولوجي للتقرير رقم (${log.batchNumber}) وبانتظار اعتمادك النهائي.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'FactoryManager',
          branchId: log.branchId,
        );
        await NotificationService.to.sendNotification(
          title: 'تم اعتماد نتائج الفحص الميكروبيولوجي من مدير الجودة ✓',
          body: 'اعتمد مدير الجودة ($qmName) نتائج الفحص الميكروبيولوجي للتقرير رقم (${log.batchNumber}) وتم إرسالها للاعتماد النهائي.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم الاعتماد بنجاح',
        'تم اعتماد نتائج الفحص الميكروبيولوجي من مدير الجودة وتحويلها لمدير المصنع للاعتماد النهائي',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد النتائج: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// المرحلة الثانية: الاعتماد النهائي لمدير المصنع على نتائج الفحص الميكروبيولوجي
  Future<void> approveMicroByFactoryManager() async {
    final session = UserSessionService.to;
    if (!session.canApproveGM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مدير المصنع في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'خالد العمري (مدير المصنع)';

    try {
      isLoading.value = true;

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Approved',
            approvedBy: gmName,
          );
        } catch (e) {
          debugPrint('API raw water micro GM error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Approved',
        gmApprovedBy: gmName,
        gmApprovedAt: DateTime.now(),
        microGmApprovedBy: gmName,
        microGmApprovedAt: DateTime.now(),
      );

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تم الاعتماد النهائي لنتائج الفحص الميكروبيولوجي',
          body: 'تم الاعتماد النهائي لنتائج الفحص الميكروبيولوجي للتقرير رقم (${log.batchNumber}) بنجاح من مدير المصنع.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'All',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم الاعتماد النهائي',
        'اكتملت جولتا الاعتماد وأصبح التقرير معتمداً نهائياً وجاهزاً للطباعة الرسمية',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل الاعتماد النهائي: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
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
          debugPrint('API raw water rejectMicroReport error: $e');
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

      await _loadReportData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: isResample
              ? 'مطلوب إعادة سحب عينة ميكروبيولوجية للمياه الخام'
              : 'تم رفض نتائج الفحص الميكروبيولوجي للمياه الخام',
          body: isResample
              ? 'طلب $rejectorName إعادة سحب عينة ميكروبيولوجية جديدة للبئر (${log.wellNumber ?? ""}): $reason'
              : 'رفض $rejectorName نتائج الفحص الميكروبيولوجي للبئر (${log.wellNumber ?? ""}): $reason',
          reportId: log.id,
          reportCategory: 'Raw Water',
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
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية رفض أو إعادة التقارير في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final rejectorName = session.currentUserName.value.isNotEmpty
          ? session.currentUserName.value
          : session.roleTitle;
      final rejectorRole = session.roleTitle;
      final rejectorFull = '$rejectorName ($rejectorRole)';

      // الحالة الجديدة: يعود لمنفذ الفحص للتنفيذ والتوثيق
      final newStatus = payload.hasCorrectiveAction
          ? 'Corrective_In_Progress'
          : 'Rejected';

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            newStatus,
            rejectionReason: payload.reason,
            rejectionCategory: payload.category,
            severityLevel: payload.severity,
            rejectionNotes: payload.notes,
            affectedProducts: payload.affectedProducts,
            immediateAction: payload.immediateAction,
            approvedBy: rejectorFull,
            correctiveAction: payload.correctiveAction,
            correctiveOwner: payload.correctiveOwner,
            correctiveDueDate: payload.dueDate?.toIso8601String(),
          );
        } catch (e) {
          debugPrint('API raw water reject updateStatus error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: newStatus,
        rejectionReason: payload.reason,
        rejectedBy: rejectorFull,
        rejectionCategory: payload.category,
        severityLevel: payload.severity,
        rejectionNotes: payload.notes,
        affectedProducts: payload.affectedProducts,
        immediateAction: payload.immediateAction,
        correctiveAction: payload.correctiveAction,
        correctiveOwner: payload.correctiveOwner,
        correctiveDueDate: payload.dueDate,
      );

      if (Get.isRegistered<NotificationService>()) {
        // إشعار أخصائي الجودة المسؤول
        await NotificationService.to.sendNotification(
          title: 'تم رفض تقرير فحص المياه الخام',
          body: 'قام $rejectorFull برفض التقرير رقم (${log.batchNumber}). السبب: ${payload.reason}'
              '${payload.hasCorrectiveAction ? "\nالإجراء التصحيحي: ${payload.correctiveAction}" : ""}',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );

        // إشعار مهندس الجودة لتنفيذ وتوثيق الإجراء التصحيحي
        if (payload.hasCorrectiveAction) {
          await NotificationService.to.sendNotification(
            title: 'إجراء تصحيحي جديد مطلوب تنفيذه',
            body: 'تم رفض تقرير المياه الخام (${log.batchNumber}) وتعيين إجراء تصحيحي: ${payload.correctiveAction}'
                ' — المسؤول: ${payload.correctiveOwner}، يرجى التنفيذ والتوثيق.',
            reportId: log.id,
            reportCategory: 'Raw Water',
            targetRole: 'QualitySpecialist',
            branchId: log.branchId,
          );
        }
      }

      await _loadReportData();

      Get.snackbar(
        payload.hasCorrectiveAction ? 'تم الرفض وتعيين إجراء تصحيحي' : 'تم رفض التقرير',
        payload.hasCorrectiveAction
            ? 'تمت إعادة التقرير مع توثيق سبب الرفض والإجراء التصحيحي'
            : 'تمت إعادة التقرير مع توثيق سبب الرفض',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض التقرير: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير الجودة ورفعه لمدير المصنع
  Future<void> qmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مدير الجودة في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اتخاذ قرار على تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final qmName = session.currentUserName.value.isNotEmpty
          ? session.currentUserName.value
          : 'مدير الجودة';
      final qmFull = '$qmName (مدير الجودة)';
      final now = DateTime.now();

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_GM_Decision',
            approvedBy: qmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API raw water qmApproveCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_GM_Decision',
        qmApprovedBy: qmName,
        qmApprovedAt: now,
        gmDecisionNotes: notes,
      );

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي معتمد من الجودة وبانتظار قرار مدير المصنع',
          body: 'اعتمد $qmFull الإجراء التصحيحي للتقرير رقم (${log.batchNumber}) وتم رفعه لمدير المصنع للقرار النهائي.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'FactoryManager',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم اعتماد مدير الجودة للإجراء التصحيحي',
        'تم رفع الإجراء التصحيحي إلى مدير المصنع لاتخاذ القرار النهائي',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// رفض الإجراء التصحيحي من قبل مدير الجودة وإعادته للمسؤول للتعديل
  Future<void> qmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية مدير الجودة في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اتخاذ قرار على تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final qmName = session.currentUserName.value.isNotEmpty
          ? session.currentUserName.value
          : 'مدير الجودة';
      final qmFull = '$qmName (مدير الجودة)';

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
          debugPrint('API raw water qmRejectCorrectiveAction error: $e');
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

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'مدير الجودة يرفض الإجراء التصحيحي للتعديل',
          body: 'رفض $qmFull الإجراء التصحيحي للتقرير رقم (${log.batchNumber}) وطلب تعديله: $notes',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'QualitySpecialist',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تمت إعادة الإجراء التصحيحي للمسؤول',
        'تمت إعادة التقرير للمسؤول لتعديل وتوثيق إجراء تصحيحي مناسب',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// رفض الإجراء التصحيحي المنفَّذ قطعياً من قبل مدير المصنع وإغلاق التقرير بالرفض النهائي
  Future<void> gmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مدير المصنع في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اتخاذ قرار على تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final gmName = session.currentUserName.value.isNotEmpty
          ? session.currentUserName.value
          : 'مدير المصنع';
      final gmFull = '$gmName (مدير المصنع)';

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
          debugPrint('API raw water gmRejectCorrectiveAction error: $e');
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

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'رفض قطعي للإجراء التصحيحي وإغلاق التقرير',
          body: 'رفض $gmFull الإجراء التصحيحي للتقرير رقم (${log.batchNumber}) وتم إغلاق التقرير بالرفض النهائي. السبب: $notes',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'All',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم الرفض النهائي وإغلاق التقرير',
        'تم رفض الإجراء التصحيحي قطعياً وإغلاق التقرير بالرفض النهائي',
        backgroundColor: const Color(0xFF8B0000),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير المصنع
  /// تؤدي إلى إغلاق التقرير نهائياً مع توثيق قرار الاعتماد
  Future<void> gmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مدير المصنع في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(log.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اتخاذ قرار على تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final gmName = session.currentUserName.value.isNotEmpty
          ? session.currentUserName.value
          : 'مدير المصنع';
      final gmFull = '$gmName (مدير المصنع)';

      final bool hasPendingMicro = log.microResultsPending;
      final String targetStatus = hasPendingMicro ? 'Awaiting_Micro_Results' : 'Closed';
      final now = DateTime.now();

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
          debugPrint('API raw water gmApproveCorrectiveAction error: $e');
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

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'اعتماد الإجراء التصحيحي وإغلاق التقرير',
          body: 'اعتمد $gmFull الإجراء التصحيحي للتقرير رقم (${log.batchNumber}) وتم إغلاقه نهائياً.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'All',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم اعتماد الإجراء التصحيحي',
        'أُغلق التقرير نهائياً وأصبح الإجراء التصحيحي معتمداً رسمياً',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  /// رفع الإجراء التصحيحي المنفَّذ إلى مدير الجودة للمراجعة والاعتماد
  Future<void> submitCorrectiveAction([String? notes]) async {
    final session = UserSessionService.to;
    if (!session.canEditReports && !session.canCreateWaterReports && !session.canRejectReports && !session.isAdmin) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية رفع الإجراء التصحيحي في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    try {
      isLoading.value = true;
      final submitterName = session.currentUserName.value.isNotEmpty
          ? session.currentUserName.value
          : session.roleTitle;

      final effectiveNotes = (notes != null && notes.trim().isNotEmpty) ? notes.trim() : (log.correctiveAction ?? 'تم إنجاز الإجراء التصحيحي');

      if (Get.isRegistered<WaterQualityApiService>()) {
        try {
          await WaterQualityApiService.to.updateStatus(
            log.id!,
            'Pending_QM_Decision',
            approvedBy: submitterName,
            correctiveAction: effectiveNotes,
          );
        } catch (e) {
          debugPrint('API raw water submitCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateWaterQualityLogApproval(
        logId: log.id!,
        approvalStatus: 'Pending_QM_Decision',
        correctiveAction: effectiveNotes,
      );

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي بانتظار اعتماد مدير الجودة',
          body: 'قام $submitterName بتوثيق ورفع الإجراء التصحيحي للتقرير رقم (${log.batchNumber}) وهو بانتظار مراجعتك واعتمادك.',
          reportId: log.id,
          reportCategory: 'Raw Water',
          targetRole: 'QualityManager',
          branchId: log.branchId,
        );
      }

      await _loadReportData();

      Get.snackbar(
        'تم رفع الإجراء التصحيحي لمدير الجودة',
        'أصبح التقرير بانتظار مراجعة واعتماد مدير الجودة للإجراء التصحيحي',
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفع الإجراء التصحيحي: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  void printReport() {
    RawWaterReportPdfGenerator.generateAndPrintReport(
      log: log,
      results: results,
      parameters: parameters,
      standards: standards,
      shiftName: shiftName.value,
      inspectorSignatureBytes: inspectorSignatureBytes.value,
      qmSignatureBytes: qmSignatureBytes.value,
      gmSignatureBytes: gmSignatureBytes.value,
      microEntererSignatureBytes: microEntererSignatureBytes.value,
      microQmSignatureBytes: microQmSignatureBytes.value,
      microGmSignatureBytes: microGmSignatureBytes.value,
    );
  }
  String getStandardString(int parameterId) {
    final std = standards[parameterId];
    if (std == null) return '';
    if (std.expectedText != null && std.expectedText!.isNotEmpty) {
      return std.expectedText!;
    }
    if (std.minValue != null && std.maxValue != null) {
      return '${std.minValue} - ${std.maxValue}';
    }
    if (std.maxValue != null) {
      return 'Max ${std.maxValue}';
    }
    if (std.minValue != null) {
      return 'Min ${std.minValue}';
    }
    return '';
  }
}
