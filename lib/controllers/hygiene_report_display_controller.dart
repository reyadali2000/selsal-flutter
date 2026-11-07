import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/approval_status.dart';
import '../models/hygiene_models.dart';
import '../models/rejection_payload.dart';
import '../services/api/hygiene_api_service.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../services/user_signature_service.dart';
import '../utils/hygiene_report_pdf_generator.dart';

class HygieneReportDisplayController extends GetxController {
  HygieneReportDisplayController(this.reportId);

  final int reportId;
  final isLoading = true.obs;
  final employees = <Employee>[].obs;
  final criteria = <ChecklistItem>[].obs;
  final complianceMatrix = <String, bool>{}.obs;
  final correctiveActions = <int, String>{}.obs;

  String reportDate = '';
  String reportTime = '';
  String supervisorName = '';

  final approvalStatus = 'Pending_QM'.obs;
  final qmApprovedBy = Rx<String?>(null);
  final qmApprovedAt = Rx<DateTime?>(null);
  final gmApprovedBy = Rx<String?>(null);
  final gmApprovedAt = Rx<DateTime?>(null);
  final rejectedBy = Rx<String?>(null);
  final rejectionReason = Rx<String?>(null);
  final branchId = Rx<int?>(null);

  // ─── حقول دورة الإجراء التصحيحي ───
  final rejectionCategory = Rx<String?>(null);
  final severityLevel = Rx<String?>(null);
  final rejectionNotes = Rx<String?>(null);
  final affectedProducts = Rx<String?>(null);
  final immediateAction = Rx<String?>(null);
  final correctiveAction = Rx<String?>(null);
  final correctiveOwner = Rx<String?>(null);
  final correctiveDueDate = Rx<DateTime?>(null);
  final gmDecision = Rx<String?>(null);
  final gmDecisionBy = Rx<String?>(null);
  final gmDecisionNotes = Rx<String?>(null);
  final rejectionCount = 0.obs;

  final inspectorSignatureBytes = Rx<Uint8List?>(null);
  final qmSignatureBytes = Rx<Uint8List?>(null);
  final gmSignatureBytes = Rx<Uint8List?>(null);
  final rejectedSignatureBytes = Rx<Uint8List?>(null);

  int get reportBranchId => branchId.value ?? 1;
  String get branchName => reportBranchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل';

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  Future<void> loadReport() async {
    isLoading.value = true;
    try {
      Map<String, dynamic>? apiData;
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          apiData = await HygieneApiService.to.getReportDetails(reportId);
        } catch (e) {
          debugPrint('API getReportDetails error: $e');
        }
      }

      final reportMap = apiData?['report'] ?? apiData?['Report'];
      if (apiData != null && reportMap != null) {
        final report = Map<String, dynamic>.from(reportMap as Map);
        final rawEmployeesList = (apiData['employees'] ?? apiData['Employees'] ?? apiData['logs'] ?? apiData['Logs']) as List?;
        final rawEmployees = rawEmployeesList?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        
        final rawDetailsList = (apiData['details'] ?? apiData['Details']) as List?;
        final rawDetails = rawDetailsList?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
        
        final rawCriteriaList = (apiData['criteria'] ?? apiData['Criteria']) as List?;
        final rawCriteria = rawCriteriaList?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];

        final dateStr = (report['created_at'] ?? report['createdAt'])?.toString();
        final createdAt = dateStr != null ? (DateTime.tryParse(dateStr) ?? DateTime.now()) : DateTime.now();
        reportDate = '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        reportTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
        supervisorName = (report['supervisor_name'] ?? report['supervisorName'])?.toString() ?? 'مفتش الجودة';

        branchId.value = report['branch_id'] ?? report['branchId'] ?? 1;
        approvalStatus.value = (report['approval_status'] ?? report['approvalStatus'])?.toString() ?? 'Pending_QM';
        qmApprovedBy.value = (report['qm_approved_by'] ?? report['qmApprovedBy'])?.toString();
        final qmAtStr = (report['qm_approved_at'] ?? report['qmApprovedAt'])?.toString();
        qmApprovedAt.value = qmAtStr != null ? DateTime.tryParse(qmAtStr) : null;
        gmApprovedBy.value = (report['gm_approved_by'] ?? report['gmApprovedBy'])?.toString();
        final gmAtStr = (report['gm_approved_at'] ?? report['gmApprovedAt'])?.toString();
        gmApprovedAt.value = gmAtStr != null ? DateTime.tryParse(gmAtStr) : null;
        rejectedBy.value = (report['rejected_by'] ?? report['rejectedBy'])?.toString();
        rejectionReason.value = (report['rejection_reason'] ?? report['rejectionReason'])?.toString();
        rejectionCategory.value = (report['rejection_category'] ?? report['rejectionCategory'])?.toString();
        severityLevel.value = (report['severity_level'] ?? report['severityLevel'])?.toString();
        rejectionNotes.value = (report['rejection_notes'] ?? report['rejectionNotes'])?.toString();
        affectedProducts.value = (report['affected_products'] ?? report['affectedProducts'])?.toString();
        immediateAction.value = (report['immediate_action'] ?? report['immediateAction'])?.toString();
        correctiveAction.value = (report['corrective_action'] ?? report['correctiveAction'])?.toString();
        correctiveOwner.value = (report['corrective_owner'] ?? report['correctiveOwner'])?.toString();
        final dueStr = (report['corrective_due_date'] ?? report['correctiveDueDate'])?.toString();
        correctiveDueDate.value = dueStr != null ? DateTime.tryParse(dueStr) : null;
        gmDecision.value = (report['gm_decision'] ?? report['gmDecision'])?.toString();
        gmDecisionBy.value = (report['gm_decision_by'] ?? report['gmDecisionBy'])?.toString();
        gmDecisionNotes.value = (report['gm_decision_notes'] ?? report['gmDecisionNotes'])?.toString();
        rejectionCount.value = (report['rejection_count'] ?? report['rejectionCount'] ?? 0) is int
            ? (report['rejection_count'] ?? report['rejectionCount'] ?? 0) as int
            : int.tryParse((report['rejection_count'] ?? report['rejectionCount'] ?? 0).toString()) ?? 0;

        employees.assignAll(rawEmployees.map((emp) => Employee(
          id: (emp['employee_id'] ?? emp['employeeId'] ?? emp['id'] ?? 0) as int,
          branchId: branchId.value ?? 1,
          fullName: (emp['full_name'] ?? emp['fullName'] ?? emp['employee_name'] ?? 'عامل').toString(),
          jobTitle: (emp['job_title'] ?? emp['jobTitle'] ?? 'عامل إنتاج').toString(),
          isActive: true,
        )));

        if (rawCriteria.isNotEmpty) {
          criteria.assignAll(rawCriteria.map((c) => ChecklistItem(
            id: (c['id'] ?? c['checklist_item_id'] ?? c['checklistItemId'] ?? 1) as int,
            checklistId: (c['checklist_id'] ?? c['checklistId'] ?? 1) as int,
            itemName: (c['item_name'] ?? c['itemName'] ?? c['itemText'] ?? '').toString(),
          )));
        } else {
          criteria.assignAll([
            ChecklistItem(id: 1, checklistId: 1, itemName: 'ارتداء ملابس العمل'),
            ChecklistItem(id: 2, checklistId: 1, itemName: 'الملابس نظيفة وفي صورة جيدة'),
            ChecklistItem(id: 3, checklistId: 1, itemName: 'تغطية الشعر والشارب'),
            ChecklistItem(id: 4, checklistId: 1, itemName: 'ارتداء حماية الحذاء'),
            ChecklistItem(id: 5, checklistId: 1, itemName: 'الاظافر مقصوصة ونظيفة'),
            ChecklistItem(id: 6, checklistId: 1, itemName: 'الصحة جيدة (لا أمراض)'),
            ChecklistItem(id: 7, checklistId: 1, itemName: 'لا يرتدي أي اكسسوارات'),
            ChecklistItem(id: 8, checklistId: 1, itemName: 'لا توجد رائحة كريهة'),
            ChecklistItem(id: 9, checklistId: 1, itemName: 'لا روائح عطرية شديدة'),
          ]);
        }

        complianceMatrix.clear();
        correctiveActions.clear();
        for (final detail in rawDetails) {
          final employeeId = (detail['employee_id'] ?? detail['employeeId'] ?? 0) as int;
          final criterionId = (detail['checklist_item_id'] ?? detail['checklistItemId'] ?? 0) as int;
          final isComp = detail['is_compliant'] == 1 || detail['is_compliant'] == true || detail['isCompliant'] == true || detail['isCompliant'] == 1;
          complianceMatrix['${employeeId}_$criterionId'] = isComp;
          final note = (detail['notes'] ?? detail['Notes'])?.toString();
          if (note != null && note.trim().isNotEmpty) correctiveActions[employeeId] = note;
        }
      } else {
        final saved = await DatabaseHelper.instance.getHygieneReportDetails(reportId);
        if (saved == null) {
          Get.snackbar('تنبيه', 'لم يتم العثور على التقرير المطلوب');
          return;
        }

        final report = saved['report'] as Map<String, Object?>;
        final savedEmployees = saved['employees'] as List<Map<String, Object?>>;
        final savedCriteria = saved['criteria'] as List<Map<String, Object?>>;
        final savedDetails = saved['details'] as List<Map<String, Object?>>;
        final createdAt = DateTime.parse(report['created_at'] as String);
        reportDate = '${createdAt.year.toString().padLeft(4, '0')}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
        reportTime = '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';
        supervisorName = report['supervisor_name'] as String? ?? 'مفتش الجودة';

        branchId.value = report['branch_id'] as int? ?? 1;
        approvalStatus.value = report['approval_status'] as String? ?? 'Pending_QM';
        qmApprovedBy.value = report['qm_approved_by'] as String?;
        qmApprovedAt.value = report['qm_approved_at'] != null ? DateTime.tryParse(report['qm_approved_at'] as String) : null;
        gmApprovedBy.value = report['gm_approved_by'] as String?;
        gmApprovedAt.value = report['gm_approved_at'] != null ? DateTime.tryParse(report['gm_approved_at'] as String) : null;
        rejectedBy.value = report['rejected_by'] as String?;
        rejectionReason.value = report['rejection_reason'] as String?;
        rejectionCategory.value = report['rejection_category'] as String?;
        severityLevel.value = report['severity_level'] as String?;
        rejectionNotes.value = report['rejection_notes'] as String?;
        affectedProducts.value = report['affected_products'] as String?;
        immediateAction.value = report['immediate_action'] as String?;
        correctiveAction.value = report['corrective_action'] as String?;
        correctiveOwner.value = report['corrective_owner'] as String?;
        correctiveDueDate.value = report['corrective_due_date'] != null
            ? DateTime.tryParse(report['corrective_due_date'] as String)
            : null;
        gmDecision.value = report['gm_decision'] as String?;
        gmDecisionBy.value = report['gm_decision_by'] as String?;
        gmDecisionNotes.value = report['gm_decision_notes'] as String?;
        rejectionCount.value = (report['rejection_count'] ?? 0) as int;

        employees.assignAll(savedEmployees.map((employee) => Employee(
              id: employee['employee_id'] as int,
              branchId: 1,
              fullName: employee['full_name'] as String,
              jobTitle: employee['job_title'] as String,
              isActive: true,
            )));
        if (savedCriteria.isNotEmpty) {
          criteria.assignAll(savedCriteria.map((criterion) => ChecklistItem(
                id: criterion['id'] as int,
                checklistId: criterion['checklist_id'] as int,
                itemName: criterion['item_name'] as String,
              )));
        } else {
          criteria.assignAll([
            ChecklistItem(id: 1, checklistId: 1, itemName: 'ارتداء ملابس العمل'),
            ChecklistItem(id: 2, checklistId: 1, itemName: 'الملابس نظيفة وفي صورة جيدة'),
            ChecklistItem(id: 3, checklistId: 1, itemName: 'تغطية الشعر والشارب'),
            ChecklistItem(id: 4, checklistId: 1, itemName: 'ارتداء حماية الحذاء'),
            ChecklistItem(id: 5, checklistId: 1, itemName: 'الاظافر مقصوصة ونظيفة'),
            ChecklistItem(id: 6, checklistId: 1, itemName: 'الصحة جيدة (لا أمراض)'),
            ChecklistItem(id: 7, checklistId: 1, itemName: 'لا يرتدي أي اكسسوارات'),
            ChecklistItem(id: 8, checklistId: 1, itemName: 'لا توجد رائحة كريهة'),
            ChecklistItem(id: 9, checklistId: 1, itemName: 'لا روائح عطرية شديدة'),
          ]);
        }

        complianceMatrix.clear();
        correctiveActions.clear();
        for (final detail in savedDetails) {
          final employeeId = detail['employee_id'] as int;
          final criterionId = detail['checklist_item_id'] as int;
          complianceMatrix['${employeeId}_$criterionId'] = (detail['is_compliant'] as int) == 1;
          final note = detail['notes'] as String?;
          if (note != null && note.trim().isNotEmpty) correctiveActions[employeeId] = note;
        }
      }

      // Load visual overlay signatures
      try {
        final sigService = UserSignatureService.instance;
        final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
        final sessionUser = session?.currentUser.value;
        final sessionUserId = (sessionUser != null && sessionUser.id != null && sessionUser.id! > 0)
            ? sessionUser.id
            : null;

        final isInspectorSession = sessionUserId != null &&
            (supervisorName == session?.formattedSignerName ||
                supervisorName == session?.currentUserName.value ||
                (sessionUser != null && sessionUser.fullName.isNotEmpty && supervisorName.contains(sessionUser.fullName)));

        inspectorSignatureBytes.value = await sigService.getSignatureBytesForUser(
          userId: isInspectorSession ? sessionUserId : null,
          userName: supervisorName.isNotEmpty ? supervisorName : 'مفتش الجودة',
          userPosition: 'مفتش الجودة / منفذ الفحص',
        );

        final isRejectorGm = ApprovalStatus.rejectedByFactoryManager(
          rejectedBy: rejectedBy.value,
          gmDecisionBy: gmDecisionBy.value,
          qmApprovedBy: qmApprovedBy.value,
          status: approvalStatus.value,
        );

        // مدير الجودة: إذا كان معتمداً سابقاً أو كان الرافض هو مدير الجودة حصراً
        final qmSigner = (qmApprovedBy.value != null && qmApprovedBy.value!.isNotEmpty)
            ? qmApprovedBy.value
            : (!isRejectorGm && (approvalStatus.value == 'Closed' ||
                    approvalStatus.value == 'Pending_GM_Decision' ||
                    approvalStatus.value == 'Rejected' ||
                    approvalStatus.value == 'Corrective_In_Progress')
                ? rejectedBy.value
                : null);

        if (qmSigner != null && qmSigner.isNotEmpty) {
          final isQmSession = sessionUserId != null &&
              (qmSigner == session?.formattedSignerName ||
                  qmSigner == session?.currentUserName.value ||
                  (sessionUser != null && sessionUser.fullName.isNotEmpty && qmSigner.contains(sessionUser.fullName)));
          qmSignatureBytes.value = await sigService.getSignatureBytesForUser(
            userId: isQmSession ? sessionUserId : null,
            userName: qmSigner,
            userPosition: 'مدير الجودة',
          );
        } else {
          qmSignatureBytes.value = null;
        }

        final gmApprover = gmApprovedBy.value ??
            ((approvalStatus.value == 'Closed' || approvalStatus.value == 'Approved')
                ? gmDecisionBy.value
                : null);
        if (gmApprover != null && gmApprover.isNotEmpty) {
          final isGmSession = sessionUserId != null &&
              (gmApprover == session?.formattedSignerName ||
                  gmApprover == session?.currentUserName.value ||
                  (sessionUser != null && sessionUser.fullName.isNotEmpty && gmApprover.contains(sessionUser.fullName)));
          gmSignatureBytes.value = await sigService.getSignatureBytesForUser(
            userId: isGmSession ? sessionUserId : null,
            userName: gmApprover,
            userPosition: 'مدير المصنع',
          );
        } else {
          gmSignatureBytes.value = null;
        }

        // تحميل توقيع الجهة التي رفضت التقرير (لعرضه بلون أحمر)
        final rejStatus = approvalStatus.value;
        if (ApprovalStatus.isRejectedStatus(rejStatus)) {
          final rejector = ApprovalStatus.rejectorName(
            rejectedBy: rejectedBy.value,
            gmDecisionBy: gmDecisionBy.value,
            status: rejStatus,
          );
          if (rejector != null && rejector.isNotEmpty) {
            final isGmRejector = ApprovalStatus.rejectedByFactoryManager(
              rejectedBy: rejectedBy.value,
              gmDecisionBy: gmDecisionBy.value,
              qmApprovedBy: qmApprovedBy.value,
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
      } catch (_) {}
    } catch (error) {
      Get.snackbar('خطأ', 'تعذر تحميل التقرير: $error');
    } finally {
      isLoading.value = false;
    }
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
    if (!session.canApproveBranchData(reportBranchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!ApprovalStatus.canTransition(approvalStatus.value, 'Pending_GM')) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(approvalStatus.value)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'حمود يسر';

    try {
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          final res = await HygieneApiService.to.updateStatusWithResponse(
            reportId,
            'Pending_GM',
            approvedBy: '$qmName (مدير الجودة)',
          );
          if (!res.isSuccess) {
            Get.snackbar(
              'تعذر الاعتماد من الخادم',
              res.message.isNotEmpty ? res.message : 'رفض الخادم اعتماد تقرير النظافة',
              backgroundColor: Colors.redAccent,
              colorText: Colors.white,
            );
            return;
          }
        } catch (e) {
          debugPrint('API Hygiene updateStatus QM error: $e');
          Get.snackbar(
            'خطأ في الاتصال',
            'تعذر الاتصال بالخادم: $e',
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
          return;
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
        approvalStatus: 'Pending_GM',
        qmApprovedBy: '$qmName (مدير الجودة)',
        qmApprovedAt: DateTime.now(),
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تقرير نظافة شخصية بانتظار الاعتماد النهائي',
          body: 'قام مدير الجودة ($qmName) باعتماد فحص النظافة الشخصية (رقم #$reportId) وهو بانتظار اعتماد مدير المصنع.',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'FactoryManager',
          branchId: reportBranchId,
        );
        await NotificationService.to.sendNotification(
          title: 'تم اعتماد تقرير النظافة الشخصية من مدير الجودة ✓',
          body: 'قام مدير الجودة ($qmName) باعتماد فحص النظافة الشخصية (رقم #$reportId) وتم تحويله للاعتماد النهائي.',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'QualitySpecialist',
          branchId: reportBranchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد بنجاح',
        'تم اعتماد التقرير من قبل مدير الجودة وتحويله لمدير المصنع للاعتماد النهائي',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث حالة الاعتماد: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
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
    if (!session.canApproveBranchData(reportBranchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty
        ? session.currentUserName.value
        : 'خالد العمري';

    try {
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          final res = await HygieneApiService.to.updateStatusWithResponse(
            reportId,
            'Approved',
            approvedBy: '$gmName (مدير المصنع)',
          );
          if (!res.isSuccess) {
            Get.snackbar(
              'تعذر الاعتماد من الخادم',
              res.message.isNotEmpty ? res.message : 'رفض الخادم الاعتماد النهائي',
              backgroundColor: Colors.redAccent,
              colorText: Colors.white,
            );
            return;
          }
        } catch (e) {
          debugPrint('API Hygiene updateStatus GM error: $e');
          Get.snackbar(
            'خطأ في الاتصال',
            'تعذر الاتصال بالخادم: $e',
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
          return;
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
        approvalStatus: 'Approved',
        gmApprovedBy: '$gmName (مدير المصنع)',
        gmApprovedAt: DateTime.now(),
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تم الاعتماد النهائي لتقرير النظافة الشخصية',
          body: 'قام مدير المصنع ($gmName) بالاعتماد النهائي لتقرير النظافة الشخصية (رقم #$reportId).',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'QualitySpecialist',
          branchId: reportBranchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد النهائي',
        'تم اعتماد التقرير بشكل نهائي من قبل مدير المصنع وأصبح معتمداً رسمياً',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحديث حالة الاعتماد: $e',
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
    if (!session.canApproveBranchData(reportBranchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final rejectorName = session.formattedSignerName;
    final curCount = rejectionCount.value;
    final int newCount;
    final String newStatus;

    if (payload.isDefinitive) {
      // تقرير النظافة: مدير الجودة هو الاعتماد الأخير -> يُغلق نهائياً فوراً بالرفض القاطع
      newCount = (curCount < 2) ? 2 : curCount + 1;
      newStatus = ApprovalStatus.rejectedFinal;
    } else {
      newCount = (curCount == 0) ? 1 : curCount + 1;
      newStatus = payload.hasCorrectiveAction ? 'Corrective_In_Progress' : 'Rejected';
    }

    try {
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          await HygieneApiService.to.updateStatus(
            reportId,
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
            rejectionCount: newCount,
          );
        } catch (e) {
          debugPrint('API Hygiene reject updateStatus error: $e');
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
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
        rejectionCount: newCount,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تم رفض تقرير النظافة الشخصية',
          body: 'تم رفض تقرير النظافة (رقم #$reportId) بواسطة $rejectorName: ${payload.reason}'
              '${payload.hasCorrectiveAction ? "\nالإجراء التصحيحي: ${payload.correctiveAction}" : ""}',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'QualitySpecialist',
          branchId: reportBranchId,
        );

        if (payload.hasCorrectiveAction) {
          await NotificationService.to.sendNotification(
            title: 'إجراء تصحيحي جديد مطلوب تنفيذه',
            body: 'تم رفض تقرير النظافة (رقم #$reportId) وتعيين إجراء تصحيحي: ${payload.correctiveAction}'
                ' — المسؤول: ${payload.correctiveOwner}، يرجى التنفيذ والتوثيق لرفعه لمدير الجودة.',
            reportId: reportId,
            reportCategory: 'Hygiene',
            targetRole: 'QualitySpecialist',
            branchId: reportBranchId,
          );
        }
      }

      Get.snackbar(
        payload.hasCorrectiveAction ? 'تم الرفض وتعيين إجراء تصحيحي' : 'تم الرفض',
        payload.hasCorrectiveAction
            ? 'تم رفض التقرير مع تعيين إجراء تصحيحي للمسؤول المختص'
            : 'تم رفض التقرير وإعادته لأخصائي الجودة للتعديل',
        backgroundColor: payload.hasCorrectiveAction ? Colors.red.shade700 : Colors.orange.shade800,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض التقرير: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير الجودة ورفعه لمدير المصنع
  Future<void> qmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM || !session.canApproveBranchData(reportBranchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية مدير الجودة لاعتماد الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';
    final now = DateTime.now();

    try {
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          await HygieneApiService.to.updateStatus(
            reportId,
            'Pending_GM_Decision',
            approvedBy: qmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API Hygiene qmApproveCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
        approvalStatus: 'Pending_GM_Decision',
        qmApprovedBy: qmName,
        qmApprovedAt: now,
        gmDecisionNotes: notes,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي معتمد من الجودة وبانتظار قرار مدير المصنع',
          body: 'اعتمد $qmFull الإجراء التصحيحي لتقرير النظافة (رقم #$reportId) وتم رفعه لمدير المصنع للقرار النهائي.',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'FactoryManager',
          branchId: reportBranchId,
        );
      }

      Get.snackbar(
        'تم اعتماد مدير الجودة للإجراء التصحيحي',
        'تم رفع الإجراء التصحيحي إلى مدير المصنع لاتخاذ القرار النهائي',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفض الإجراء التصحيحي من قبل مدير الجودة وإعادته للمسؤول للتعديل
  Future<void> qmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM || !session.canApproveBranchData(reportBranchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية مدير الجودة لرفض الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';
    final curCount = rejectionCount.value;
    final bool isDefinitive = curCount >= 1;
    final int newCount = isDefinitive ? (curCount + 1) : 1;
    final String newStatus = isDefinitive ? ApprovalStatus.rejectedFinal : 'Corrective_In_Progress';

    try {
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          await HygieneApiService.to.updateStatus(
            reportId,
            newStatus,
            approvedBy: qmFull,
            rejectionReason: rejectionReason.value ?? notes,
            gmDecision: 'Rejected',
            gmDecisionBy: qmFull,
            gmDecisionNotes: notes,
            rejectionCount: newCount,
          );
        } catch (e) {
          debugPrint('API Hygiene qmRejectCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
        approvalStatus: newStatus,
        gmDecision: 'Rejected',
        gmDecisionBy: qmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
        rejectionCount: newCount,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: isDefinitive
              ? 'تم استنفاذ المحاولات — إغلاق تقرير النظافة بالرفض النهائي'
              : 'مدير الجودة يرفض الإجراء التصحيحي للتعديل (محاولة 1 من 2)',
          body: isDefinitive
              ? 'رفض $qmFull الإجراء التصحيحي للمرة الثانية وتم إغلاق تقرير النظافة (#$reportId) نهائياً: $notes'
              : 'رفض $qmFull الإجراء التصحيحي لتقرير النظافة (رقم #$reportId) وطلب تعديله: $notes',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: isDefinitive ? 'All' : 'QualitySpecialist',
          branchId: reportBranchId,
        );
      }

      if (isDefinitive) {
        Get.snackbar(
          'رفض قاطع وإغلاق نهائي',
          'تم استنفاذ محاولتي التصحيح، وأُغلق تقرير النظافة نهائياً بالرفض القاطع لمدير الجودة',
          backgroundColor: Colors.red.shade800,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          'تمت إعادة الإجراء التصحيحي للمسؤول (محاولة 1 من 2)',
          'تمت إعادة التقرير للمسؤول لتعديل وتوثيق إجراء تصحيحي مناسب (متبقية فرصة أخيرة)',
          backgroundColor: Colors.orange.shade800,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          duration: const Duration(seconds: 4),
        );
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير المصنع وإغلاق التقرير
  Future<void> gmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM || !session.canApproveBranchData(reportBranchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية اعتماد الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';

    try {
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          await HygieneApiService.to.updateStatus(
            reportId,
            'Closed',
            approvedBy: gmFull,
            gmDecision: 'Approved',
            gmDecisionBy: gmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API Hygiene gmApprove error: $e');
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
        approvalStatus: 'Closed',
        gmApprovedBy: gmName,
        gmApprovedAt: DateTime.now(),
        gmDecision: 'Approved',
        gmDecisionBy: gmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'اعتماد الإجراء التصحيحي وإغلاق التقرير',
          body: 'اعتمد $gmFull الإجراء التصحيحي لتقرير النظافة (رقم #$reportId) وتم إغلاقه نهائياً.',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'All',
          branchId: reportBranchId,
        );
      }

      Get.snackbar(
        'تم اعتماد الإجراء التصحيحي',
        'أُغلق التقرير نهائياً وأصبح الإجراء التصحيحي معتمداً رسمياً',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفض الإجراء التصحيحي قطعياً من قبل مدير المصنع وإغلاق التقرير بالرفض النهائي
  Future<void> gmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM || !session.canApproveBranchData(reportBranchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفض الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';
    final curCount = rejectionCount.value;
    final int newCount = (curCount < 2) ? 2 : curCount;
    final originalQmReason = rejectionReason.value;

    try {
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          await HygieneApiService.to.updateStatus(
            reportId,
            'Rejected_By_GM',
            approvedBy: gmFull,
            rejectionReason: originalQmReason,
            gmDecision: 'Rejected',
            gmDecisionBy: gmFull,
            gmDecisionNotes: notes,
            rejectionCount: newCount,
          );
        } catch (e) {
          debugPrint('API Hygiene gmReject error: $e');
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
        approvalStatus: 'Rejected_By_GM',
        gmDecision: 'Rejected',
        gmDecisionBy: gmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
        rejectionCount: newCount,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'رفض قطعي للإجراء التصحيحي وإغلاق التقرير',
          body: 'رفض $gmFull الإجراء التصحيحي لتقرير النظافة (رقم #$reportId) وتم إغلاق التقرير بالرفض النهائي. السبب: $notes',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'All',
          branchId: reportBranchId,
        );
      }

      Get.snackbar(
        'تم الرفض النهائي وإغلاق التقرير',
        'تم رفض الإجراء التصحيحي قطعياً وإغلاق التقرير بالرفض النهائي',
        backgroundColor: const Color(0xFF8B0000),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفع الإجراء التصحيحي المنفَّذ إلى مدير الجودة للمراجعة والاعتماد
  Future<void> submitCorrectiveAction([String? notes]) async {
    final session = UserSessionService.to;
    if (!session.canEditReports && !session.canCreateHygieneReports && !session.canRejectReports && !session.isAdmin) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفع الإجراء التصحيحي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final submitterName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : session.roleTitle;

    try {
      final effectiveNotes = (notes != null && notes.trim().isNotEmpty) ? notes.trim() : ((correctiveAction.value?.isNotEmpty == true) ? correctiveAction.value! : 'تم إنجاز الإجراء التصحيحي');

      if (Get.isRegistered<HygieneApiService>()) {
        try {
          await HygieneApiService.to.updateStatus(
            reportId,
            'Pending_QM_Decision',
            approvedBy: submitterName,
            correctiveAction: effectiveNotes,
          );
        } catch (e) {
          debugPrint('API Hygiene submitCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateHygieneReportApproval(
        reportId: reportId,
        approvalStatus: 'Pending_QM_Decision',
        correctiveAction: effectiveNotes,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي بانتظار اعتماد مدير الجودة',
          body: 'قام $submitterName بتوثيق ورفع الإجراء التصحيحي لتقرير النظافة (رقم #$reportId) وهو بانتظار مراجعتك واعتمادك.',
          reportId: reportId,
          reportCategory: 'Hygiene',
          targetRole: 'QualityManager',
          branchId: reportBranchId,
        );
      }

      Get.snackbar(
        'تم رفع الإجراء التصحيحي لمدير الجودة',
        'أصبح التقرير بانتظار مراجعة واعتماد مدير الجودة للإجراء التصحيحي',
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفع الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  void printReport() {
    HygieneReportPdfGenerator.generateAndPrintReport(
      employees: employees,
      criteria: criteria,
      complianceMatrix: complianceMatrix,
      correctiveActions: correctiveActions,
      reportDate: reportDate,
      supervisorName: supervisorName,
      approvalStatus: approvalStatus.value,
      qmApprovedBy: qmApprovedBy.value,
      qmApprovedAt: qmApprovedAt.value,
      gmApprovedBy: gmApprovedBy.value,
      gmApprovedAt: gmApprovedAt.value,
      inspectorSignatureBytes: inspectorSignatureBytes.value,
      qmSignatureBytes: qmSignatureBytes.value,
      gmSignatureBytes: gmSignatureBytes.value,
      rejectedSignatureBytes: rejectedSignatureBytes.value,
      rejectedBy: rejectedBy.value,
      gmDecisionBy: gmDecisionBy.value,
    );
  }
}
