import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import '../constants/approval_status.dart';
import '../models/raw_material_models.dart';
import '../models/rejection_payload.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../services/user_session_service.dart';
import '../services/user_signature_service.dart';
import '../services/api/api.dart';
import '../utils/raw_material_report_pdf_generator.dart';

class RawMaterialReportDisplayController extends GetxController {
  final int reportId;
  RawMaterialReportDisplayController({required this.reportId});

  final report = Rx<RawMaterialReport?>(null);
  final generalResults = <RawMaterialItemResult>[].obs;
  final annexResults = <RawMaterialItemResult>[].obs;
  final isLoading = false.obs;
  final isPrinting = false.obs;

  final inspectorSignatureBytes = Rx<Uint8List?>(null);
  final qsSignatureBytes = Rx<Uint8List?>(null);
  final qmSignatureBytes = Rx<Uint8List?>(null);
  final gmSignatureBytes = Rx<Uint8List?>(null);
  final rejectedSignatureBytes = Rx<Uint8List?>(null);

  @override
  void onInit() {
    super.onInit();
    loadReport();
  }

  Future<void> loadReport() async {
    try {
      isLoading.value = true;

      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          final apiDetails = await RawMaterialsApiService.to.getReportDetails(reportId);
          if (apiDetails != null && apiDetails['report'] != null) {
            report.value = RawMaterialReport.fromMap(Map<String, dynamic>.from(apiDetails['report']));
            if (apiDetails['generalResults'] is List) {
              generalResults.value = (apiDetails['generalResults'] as List)
                  .map((e) => RawMaterialItemResult.fromMap(Map<String, dynamic>.from(e)))
                  .toList();
            }
            if (apiDetails['annexResults'] is List) {
              annexResults.value = (apiDetails['annexResults'] as List)
                  .map((e) => RawMaterialItemResult.fromMap(Map<String, dynamic>.from(e)))
                  .toList();
            }
          }
        } catch (e) {
          debugPrint('API load raw material details error: $e');
        }
      }

      if (report.value == null) {
        final data = await DatabaseHelper.instance.getRawMaterialReportDetails(reportId);
        if (data != null) {
          report.value = data['report'] as RawMaterialReport;
          generalResults.value = data['generalResults'] as List<RawMaterialItemResult>;
          annexResults.value = data['annexResults'] as List<RawMaterialItemResult>;
        }
      }

        // Load visual overlay signatures
        try {
          final rep = report.value!;
          final sigService = UserSignatureService.instance;
          inspectorSignatureBytes.value = await sigService.getSignatureBytesForUser(
            userName: rep.inspectorName.isNotEmpty ? rep.inspectorName : 'مفتش الجودة',
            userPosition: 'مفتش الجودة / منفذ الفحص',
          );

          // اعتماد مشرف الجودة يُحتسب من حالة التقرير وليس فقط من وجود اسم المشرف،
          // لأن بعض التقارير تأتي من الـ API دون حقل lab_responsible_name رغم تجاوزها
          // لمرحلة مشرف الجودة (مما يجعل التوقيع يظهر في الطباعة ولا يظهر في العرض).
          final bool isClosed = rep.approvalStatus == 'Closed';
          final wasQsApproved = ApprovalStatus.wasApprovedByQsPriorToRejection(
            qsApprovedBy: rep.labResponsibleName,
            status: rep.approvalStatus,
          );
          final isQsDone = rep.approvalStatus == 'Approved' ||
              rep.approvalStatus == 'Pending_GM' ||
              rep.approvalStatus == 'Pending_QM' ||
              isClosed ||
              wasQsApproved;
          final qsSignerName =
              (rep.labResponsibleName != null && rep.labResponsibleName!.isNotEmpty)
                  ? rep.labResponsibleName!
                  : (isQsDone ? 'مشرف الجودة' : '');

          if (qsSignerName.isNotEmpty) {
            qsSignatureBytes.value = await sigService.getSignatureBytesForUser(
              userName: qsSignerName,
              userPosition: 'مشرف الجودة',
            );
          } else {
            qsSignatureBytes.value = null;
          }

          final bool isRejectorGm = (rep.gmDecisionBy != null && rep.gmDecisionBy == rep.rejectedBy) ||
              (rep.rejectedBy != null && (rep.rejectedBy!.contains('مدير المصنع') || rep.rejectedBy!.contains('العمري')));
          final qmUser = rep.qmApprovedBy ?? (!isRejectorGm ? rep.rejectedBy : null) ?? (isClosed ? 'حمود يسر' : null);
          if (qmUser != null && qmUser.isNotEmpty) {
            qmSignatureBytes.value = await sigService.getSignatureBytesForUser(
              userName: qmUser,
              userPosition: 'مدير الجودة',
            );
          } else {
            qmSignatureBytes.value = null;
          }

          final gmUser = rep.gmDecisionBy ?? rep.gmApprovedBy;
          if (gmUser != null && gmUser.isNotEmpty) {
            gmSignatureBytes.value = await sigService.getSignatureBytesForUser(
              userName: gmUser,
              userPosition: 'مدير المصنع',
            );
          } else {
            gmSignatureBytes.value = null;
          }

          // تحميل توقيع الجهة التي رفضت التقرير أو طلبت إجراءً تصحيحياً
          final rejStatus = rep.approvalStatus;
          if (ApprovalStatus.isRejectedStatus(rejStatus) || isClosed) {
            final rejector = ApprovalStatus.rejectorName(
              rejectedBy: rep.rejectedBy,
              gmDecisionBy: rep.gmDecisionBy,
              status: rejStatus,
            );
            if (rejector != null && rejector.isNotEmpty) {
              final isGmRejector = ApprovalStatus.rejectedByFactoryManager(
                rejectedBy: rep.rejectedBy,
                gmDecisionBy: rep.gmDecisionBy,
                status: rejStatus,
              );
              final isQsRejector = ApprovalStatus.rejectedByQualitySupervisor(
                rejectedBy: rep.rejectedBy,
                qsApprovedBy: rep.labResponsibleName,
                status: rejStatus,
              );
              rejectedSignatureBytes.value = await sigService.getSignatureBytesForUser(
                userName: rejector,
                userPosition: isGmRejector
                    ? 'مدير المصنع'
                    : (isQsRejector ? 'مشرف الجودة' : 'مدير الجودة'),
              );
            } else {
              rejectedSignatureBytes.value = null;
            }
          } else {
            rejectedSignatureBytes.value = null;
          }
        } catch (_) {}
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل بيانات التقرير: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> approveByQualitySupervisor() async {
    final session = UserSessionService.to;
    if (!session.canApproveQSupervisor) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد مشرف الجودة في حسابك الحالي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    if (!session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    final curSt = report.value?.approvalStatus ?? '';
    if (!ApprovalStatus.canTransition(curSt, 'Pending_QM')) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(curSt)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    final qsName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مشرف الجودة';

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            'Pending_QM',
            approvedBy: '$qsName (مشرف الجودة)',
          );
        } catch (e) {
          debugPrint('API update raw material approval QS error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
        reportId: reportId,
        approvalStatus: 'Pending_QM',
        labResponsibleName: '$qsName (مشرف الجودة)',
        labResponsibleAt: DateTime.now(),
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تقرير فحص مادة خام بانتظار اعتماد مدير الجودة',
          body: 'قام مشرف الجودة ($qsName) باعتماد فحص (${report.value?.materialName}) وهو بانتظار مراجعة مدير الجودة.',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'QualityManager',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد بنجاح',
        'تم اعتماد التقرير من قبل مشرف الجودة وتحويله لمدير الجودة',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل الاعتماد: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
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
    if (!session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    final curSt = report.value?.approvalStatus ?? '';
    if (!ApprovalStatus.canTransition(curSt, 'Pending_GM')) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(curSt)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'حمود يسر';

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            'Pending_GM',
            approvedBy: '$qmName (مدير الجودة)',
          );
        } catch (e) {
          debugPrint('API update raw material approval QM error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
        reportId: reportId,
        approvalStatus: 'Pending_GM',
        qmApprovedBy: '$qmName (مدير الجودة)',
        qmApprovedAt: DateTime.now(),
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تقرير فحص مادة خام بانتظار الاعتماد النهائي',
          body: 'قام مدير الجودة ($qmName) باعتماد فحص (${report.value?.materialName}) وهو بانتظار اعتماد مدير المصنع.',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'FactoryManager',
          branchId: report.value?.branchId,
        );
        await NotificationService.to.sendNotification(
          title: 'تم اعتماد تقرير فحص المادة الخام من مدير الجودة ✓',
          body: 'قام مدير الجودة ($qmName) باعتماد فحص (${report.value?.materialName}) وتم تحويله للاعتماد النهائي.',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'QualitySpecialist',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد بنجاح',
        'تم اعتماد التقرير من قبل مدير الجودة وتحويله لمدير المصنع للاعتماد النهائي',
        backgroundColor: Colors.green.shade600,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل الاعتماد: $e',
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
    if (!session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'خالد العمري';

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            'Approved',
            approvedBy: '$gmName (مدير المصنع)',
          );
        } catch (e) {
          debugPrint('API update raw material approval GM error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
        reportId: reportId,
        approvalStatus: 'Approved',
        gmApprovedBy: '$gmName (مدير المصنع)',
        gmApprovedAt: DateTime.now(),
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تم الاعتماد النهائي لتقرير فحص المادة الخام',
          body: 'قام مدير المصنع ($gmName) بالاعتماد النهائي لتقرير فحص (${report.value?.materialName}).',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'QualitySpecialist',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد النهائي',
        'تم اعتماد التقرير بشكل نهائي من قبل مدير المصنع وأصبح معتمداً رسمياً',
        backgroundColor: Colors.green.shade700,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل الاعتماد: $e',
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
    if (!session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final rejectorName = '${session.currentUserName.value} (${session.roleTitle})';
    final newStatus = payload.hasCorrectiveAction ? 'Corrective_In_Progress' : 'Rejected';

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            newStatus,
            rejectionReason: payload.reason,
            approvedBy: rejectorName,
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
          debugPrint('API update raw material reject error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
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
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'تم رفض تقرير فحص المادة الخام',
          body: 'تم رفض تقرير (${report.value?.materialName}) بواسطة $rejectorName: ${payload.reason}'
              '${payload.hasCorrectiveAction ? "\nالإجراء التصحيحي: ${payload.correctiveAction}" : ""}',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'QualitySpecialist',
          branchId: report.value?.branchId,
        );

        if (payload.hasCorrectiveAction) {
          await NotificationService.to.sendNotification(
            title: 'إجراء تصحيحي جديد مطلوب تنفيذه',
            body: 'تم رفض تقرير (${report.value?.materialName}) وتعيين إجراء تصحيحي: ${payload.correctiveAction}'
                ' — المسؤول: ${payload.correctiveOwner}، يرجى التنفيذ والتوثيق لرفعه لمدير الجودة.',
            reportId: reportId,
            reportCategory: 'Raw Material',
            targetRole: 'QualitySpecialist',
            branchId: report.value?.branchId,
          );
        }
      }

      Get.snackbar(
        payload.hasCorrectiveAction ? 'تم الرفض وتعيين إجراء تصحيحي' : 'تم الرفض',
        payload.hasCorrectiveAction
            ? 'تم رفض التقرير مع تعيين إجراء تصحيحي للمسؤول المختص'
            : 'تم رفض التقرير وإعادته للتعديل',
        backgroundColor: payload.hasCorrectiveAction ? Colors.red.shade700 : Colors.orange.shade800,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض التقرير: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير الجودة ورفعه لمدير المصنع
  Future<void> qmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM || !session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية مدير الجودة لاعتماد الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';
    final now = DateTime.now();

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            'Pending_GM_Decision',
            approvedBy: qmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API update raw material QM corrective approve error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
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
          body: 'اعتمد $qmFull الإجراء التصحيحي لتقرير (${report.value?.materialName}) وتم رفعه لمدير المصنع للقرار النهائي.',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'FactoryManager',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تم اعتماد مدير الجودة للإجراء التصحيحي',
        'تم رفع الإجراء التصحيحي إلى مدير المصنع لاتخاذ القرار النهائي',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفض الإجراء التصحيحي من قبل مدير الجودة وإعادته للمسؤول للتعديل
  Future<void> qmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM || !session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية مدير الجودة لرفض الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final qmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            'Corrective_In_Progress',
            approvedBy: qmFull,
            gmDecision: 'Rejected',
            gmDecisionBy: qmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API update raw material QM corrective reject error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
        reportId: reportId,
        approvalStatus: 'Corrective_In_Progress',
        gmDecision: 'Rejected',
        gmDecisionBy: qmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'مدير الجودة يرفض الإجراء التصحيحي للتعديل',
          body: 'رفض $qmFull الإجراء التصحيحي لتقرير (${report.value?.materialName}) وطلب تعديله: $notes',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'QualitySpecialist',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تمت إعادة الإجراء التصحيحي للمسؤول',
        'تمت إعادة التقرير للمسؤول لتعديل وتوثيق إجراء تصحيحي مناسب',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير المصنع وإغلاق التقرير
  Future<void> gmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM || !session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية اعتماد الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            'Closed',
            approvedBy: gmFull,
            gmDecision: 'Approved',
            gmDecisionBy: gmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API update raw material GM corrective approve error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
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
          body: 'اعتمد $gmFull الإجراء التصحيحي لتقرير (${report.value?.materialName}) وتم إغلاقه نهائياً.',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'All',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تم اعتماد الإجراء التصحيحي',
        'أُغلق التقرير نهائياً وأصبح الإجراء التصحيحي معتمداً رسمياً',
        backgroundColor: Colors.teal.shade700,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل اعتماد الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفض الإجراء التصحيحي قطعياً من قبل مدير المصنع وإغلاق التقرير بالرفض النهائي
  Future<void> gmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM || !session.canApproveBranchData(report.value?.branchId)) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفض الإجراء التصحيحي على هذا التقرير',
          backgroundColor: Colors.red.shade700, colorText: Colors.white);
      return;
    }

    final gmName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';

    try {
      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateApproval(
            reportId,
            'Rejected_By_GM',
            approvedBy: gmFull,
            gmDecision: 'Rejected',
            gmDecisionBy: gmFull,
            gmDecisionNotes: notes,
          );
        } catch (e) {
          debugPrint('API update raw material GM corrective reject error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
        reportId: reportId,
        approvalStatus: 'Rejected_By_GM',
        gmDecision: 'Rejected',
        gmDecisionBy: gmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'رفض قطعي للإجراء التصحيحي وإغلاق التقرير',
          body: 'رفض $gmFull الإجراء التصحيحي لتقرير (${report.value?.materialName}) وتم إغلاق التقرير بالرفض النهائي. السبب: $notes',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'All',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تم الرفض النهائي وإغلاق التقرير',
        'تم رفض الإجراء التصحيحي قطعياً وإغلاق التقرير بالرفض النهائي',
        backgroundColor: const Color(0xFF8B0000),
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفض الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  /// رفع الإجراء التصحيحي المنفَّذ إلى مدير الجودة للمراجعة والاعتماد
  Future<void> submitCorrectiveAction([String? notes]) async {
    final session = UserSessionService.to;
    if (!session.canEditReports && !session.canCreateRawMaterialReports && !session.canRejectReports && !session.isAdmin) {
      Get.snackbar('غير مصرح', 'لا تملك صلاحية رفع الإجراء التصحيحي',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return;
    }

    final submitterName = session.currentUserName.value.isNotEmpty ? session.currentUserName.value : session.roleTitle;

    try {
      final effectiveNotes = (notes != null && notes.trim().isNotEmpty) ? notes.trim() : (report.value?.correctiveAction ?? 'تم إنجاز الإجراء التصحيحي');

      if (Get.isRegistered<RawMaterialsApiService>()) {
        try {
          await RawMaterialsApiService.to.updateStatus(
            reportId,
            'Pending_QM_Decision',
            approvedBy: submitterName,
            correctiveAction: effectiveNotes,
          );
        } catch (e) {
          debugPrint('API raw materials submitCorrectiveAction error: $e');
        }
      }

      await DatabaseHelper.instance.updateRawMaterialReportApproval(
        reportId: reportId,
        approvalStatus: 'Pending_QM_Decision',
        correctiveAction: effectiveNotes,
      );

      await loadReport();

      if (Get.isRegistered<NotificationService>()) {
        await NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي بانتظار اعتماد مدير الجودة',
          body: 'قام $submitterName بتوثيق ورفع الإجراء التصحيحي لتقرير (${report.value?.materialName}) وهو بانتظار مراجعتك واعتمادك.',
          reportId: reportId,
          reportCategory: 'Raw Material',
          targetRole: 'QualityManager',
          branchId: report.value?.branchId,
        );
      }

      Get.snackbar(
        'تم رفع الإجراء التصحيحي لمدير الجودة',
        'أصبح التقرير بانتظار مراجعة واعتماد مدير الجودة للإجراء التصحيحي',
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل رفع الإجراء التصحيحي: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }

  Future<void> printPdf() async {
    if (report.value == null) return;
    try {
      isPrinting.value = true;
      final pdfBytes = await RawMaterialReportPdfGenerator.generate(
        report: report.value!,
        generalResults: generalResults,
        annexResults: annexResults,
        inspectorSignatureBytes: inspectorSignatureBytes.value,
      qsSignatureBytes: qsSignatureBytes.value,
        qmSignatureBytes: qmSignatureBytes.value,
        gmSignatureBytes: gmSignatureBytes.value,
      );

      await Printing.layoutPdf(
        onLayout: (_) => pdfBytes,
        name: 'Raw_Material_${report.value!.materialName}_${report.value!.batchNumber}.pdf',
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل طباعة التقرير: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isPrinting.value = false;
    }
  }
}
