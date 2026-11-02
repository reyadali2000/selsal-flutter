import '../widgets/corrective_action_submit_dialog.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../models/dynamic_report_models.dart';
import '../models/rejection_payload.dart';
import '../services/api/dynamic_reports_api_service.dart';
import '../services/user_signature_service.dart';
import '../services/user_session_service.dart';
import '../services/notification_service.dart';
import '../services/sync/sync_manager.dart';

import '../utils/dynamic_report_pdf_generator.dart';
import '../constants/app_colors.dart';
import '../constants/approval_status.dart';
import '../routes/app_routes.dart';
import '../widgets/factory_manager_rejection_card.dart';
import '../widgets/gm_decision_dialog.dart';
import '../widgets/reject_report_dialog.dart';
import '../widgets/zoomable_document_view.dart';

class DynamicReportDisplayController extends GetxController {
  final isLoading = true.obs;
  final isRefreshing = false.obs;
  final isProcessingAction = false.obs;
  final refreshTrigger = 0.obs;
  final ScrollController scrollController = ScrollController();

  int? reportId;
  late final int recordId;

  final report = Rx<DynamicReport?>(null);
  final currentRecord = Rx<DynamicReportRecord?>(null);

  List<DynamicReportValue> values = [];
  final approvals = <ReportApproval>[].obs;
  final inspectorSignatureBytes = Rx<Uint8List?>(null);
  final qsSignatureBytes = Rx<Uint8List?>(null);
  final qmSignatureBytes = Rx<Uint8List?>(null);
  final gmSignatureBytes = Rx<Uint8List?>(null);
  final rejectedSignatureBytes = Rx<Uint8List?>(null);

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null &&
        (args['recordId'] != null || args['reportId'] != null)) {
      if (args['reportId'] != null) {
        reportId = args['reportId'] as int;
      }
      if (args['recordId'] != null) {
        recordId = args['recordId'] as int;
      }
      loadData();
      // تسجيل شاشة عرض السجل في المزامنة اللحظية (تحديث دوري صامت)
      if (Get.isRegistered<SyncManager>()) {
        SyncManager.to.registerRefresher(
          'dynamic_record_$recordId',
          () => loadData(silent: true),
        );
      }
    } else {
      Get.snackbar('خطأ', 'البيانات مفقودة');
      Get.back();
    }
  }

  @override
  void onClose() {
    if (Get.isRegistered<SyncManager>()) {
      try {
        SyncManager.to.unregisterRefresher('dynamic_record_$recordId');
      } catch (_) {
        // recordId لم يُضبط (أُغلقت الشاشة مبكراً)
      }
    }
    scrollController.dispose();
    super.onClose();
  }

  Future<void> loadData({bool silent = false}) async {
    final isFirstLoad = currentRecord.value == null;
    if (isFirstLoad && !silent) {
      isLoading.value = true;
    } else if (!silent) {
      isRefreshing.value = true;
    }

    double? savedOffset;
    if (scrollController.hasClients) {
      savedOffset = scrollController.offset;
    }
    try {
      final rec = await DynamicReportsApiService.to.getRecordDetails(recordId);
      if (rec == null) {
        if (!silent) {
          Get.snackbar('خطأ', 'لم يتم العثور على سجل التقرير');
          Get.back();
        }
        return;
      }

      // فحص ذكي في الخلفية: إذا لم تتغير حالة التقرير ولا تاريخ التعديل، لا تلمس الشاشة ولا تعيد بناء الـ PDF
      if (silent && currentRecord.value != null) {
        final prev = currentRecord.value!;
        final bool isUnchanged =
            prev.approvalStatus == rec.approvalStatus &&
            prev.updatedAt == rec.updatedAt &&
            prev.rejectionReason == rec.rejectionReason &&
            prev.status == rec.status &&
            prev.gmDecision == rec.gmDecision &&
            prev.qsApprovedBy == rec.qsApprovedBy &&
            prev.qmApprovedBy == rec.qmApprovedBy &&
            prev.gmApprovedBy == rec.gmApprovedBy &&
            prev.correctiveAction == rec.correctiveAction;
        if (isUnchanged) {
          // البيانات متطابقة تماماً - إنهاء فوراً بدون وميض أو إعادة رسم
          return;
        }
      }

      currentRecord.value = rec;
      reportId = rec.reportId;
      report.value = await DynamicReportsApiService.to.getTemplateDetails(
        rec.reportId,
      );
      if (report.value == null ||
          !UserSessionService.to.canViewDynamicReport(
            report.value!.id,
            report.value!.categoryId,
          )) {
        if (!silent) {
          Get.snackbar('غير مصرح', 'لا تملك صلاحية استعراض هذا التقرير');
          Get.back();
        }
        return;
      }

      if (!UserSessionService.to.canViewBranchData(rec.branchId)) {
        if (!silent) {
          Get.snackbar(
            'غير مصرح',
            'غير مصرح لك باستعراض سجلات تابعة لمصنع آخر',
          );
          Get.back();
        }
        return;
      }
      final recordData = await DynamicReportsApiService.to
          .getRecordDetailsWithValues(recordId);
      values = recordData?['values'] ?? [];

      // استرجاع مسار الاعتماد والتوقيعات الرقمية المجمدة
      approvals.value = await DynamicReportsApiService.to.getApprovalTrail(
        recordId,
      );

      // حساب التوقيعات في متغيرات محلية أولاً لمنع تصفيرها المفاجئ وتفادي رمشة الشاشة
      Uint8List? newInspSig;
      Uint8List? newQsSig;
      Uint8List? newQmSig;
      Uint8List? newGmSig;
      Uint8List? newRejSig;

      // جلب توقيع منفذ الفحص / مُعد التقرير (سواء كان توقيع PNG مرفوع أو توقيع معتمد)
      final creatorName = DynamicReportRecord.sanitizeCreatorName(
        rec.createdBy,
      );
      newInspSig = await UserSignatureService.instance.getSignatureBytesForUser(
        userName: creatorName,
        userPosition: 'أخصائي الجودة / منفذ الفحص',
      );

      for (var app in approvals) {
        if (newQsSig == null &&
            (app.stepName?.contains('مشرف') == true ||
                app.actionByPosition?.contains('مشرف') == true ||
                app.newStatus == 'Pending_QM')) {
          Uint8List? latest;
          if (app.actedByUserId != null) {
            latest = await UserSignatureService.instance
                .getCustomUserSignatureBytes(app.actedByUserId!);
          }
          if (latest == null &&
              app.actedBy != null &&
              app.actedBy!.isNotEmpty) {
            latest = await UserSignatureService.instance
                .getSignatureBytesForUser(
                  userName: app.actedBy!,
                  userPosition: 'مشرف الجودة والرقابة',
                );
          }
          newQsSig = latest ?? app.signatureBytes;
        }
        if (newQmSig == null &&
            (app.stepName?.contains('مدير الجودة') == true ||
                app.stepName == 'اعتماد مدير الجودة' ||
                app.actionByPosition?.contains('مدير الجودة') == true ||
                app.newStatus == 'Pending_GM')) {
          Uint8List? latest;
          if (app.actedByUserId != null) {
            latest = await UserSignatureService.instance
                .getCustomUserSignatureBytes(app.actedByUserId!);
          }
          if (latest == null &&
              app.actedBy != null &&
              app.actedBy!.isNotEmpty) {
            latest = await UserSignatureService.instance
                .getSignatureBytesForUser(
                  userName: app.actedBy!,
                  userPosition: 'مدير الجودة',
                );
          }
          newQmSig = latest ?? app.signatureBytes;
        }
        if (newGmSig == null &&
            (app.stepName?.contains('المصنع') == true ||
                app.actionByPosition?.contains('المصنع') == true ||
                app.newStatus == 'Approved')) {
          Uint8List? latest;
          if (app.actedByUserId != null) {
            latest = await UserSignatureService.instance
                .getCustomUserSignatureBytes(app.actedByUserId!);
          }
          if (latest == null &&
              app.actedBy != null &&
              app.actedBy!.isNotEmpty) {
            latest = await UserSignatureService.instance
                .getSignatureBytesForUser(
                  userName: app.actedBy!,
                  userPosition: 'مدير المصنع',
                );
          }
          newGmSig = latest ?? app.signatureBytes;
        }
      }

      // توقيع المعتمد في حال لم يُجلب من مسار الاعتماد
      final bool isClosed = rec.approvalStatus == 'Closed';
      final wasQsApproved = ApprovalStatus.wasApprovedByQsPriorToRejection(
        qsApprovedBy: rec.qsApprovedBy,
        status: rec.approvalStatus,
      );
      final isQsDone =
          rec.approvalStatus == 'Approved' ||
          rec.approvalStatus == 'Pending_GM' ||
          rec.approvalStatus == 'Pending_QM' ||
          isClosed ||
          wasQsApproved;
      final isQmDone =
          rec.approvalStatus == 'Approved' ||
          rec.approvalStatus == 'Pending_GM';
      final isGmDone = rec.approvalStatus == 'Approved' || isClosed;

      if (newQsSig == null &&
          isQsDone &&
          rec.qsApprovedBy != null &&
          rec.qsApprovedBy!.isNotEmpty) {
        newQsSig = await UserSignatureService.instance.getSignatureBytesForUser(
          userName: rec.qsApprovedBy!,
          userPosition: 'مشرف الجودة والرقابة',
        );
      }
      if (newQmSig == null && (isQmDone || isClosed)) {
        final isGmRejector =
            (rec.gmDecisionBy != null && rec.gmDecisionBy == rec.rejectedBy) ||
            (rec.rejectedBy != null &&
                (rec.rejectedBy!.contains('مدير المصنع') ||
                    rec.rejectedBy!.contains('العمري'))) ||
            ApprovalStatus.rejectedByFactoryManager(
              rejectedBy: rec.rejectedBy,
              gmDecisionBy: rec.gmDecisionBy,
              status: rec.approvalStatus,
            );
        final qmUser =
            rec.qmApprovedBy ??
            (!isGmRejector ? rec.rejectedBy : null);
        if (qmUser != null && qmUser.isNotEmpty) {
          newQmSig = await UserSignatureService.instance.getSignatureBytesForUser(
            userName: qmUser,
            userPosition: 'مدير توكيد ورقابة الجودة',
          );
        }
      }
      if (newGmSig == null && isGmDone) {
        final gmUser = rec.gmDecisionBy ?? rec.gmApprovedBy;
        if (gmUser != null && gmUser.isNotEmpty) {
          newGmSig = await UserSignatureService.instance.getSignatureBytesForUser(
            userName: gmUser,
            userPosition: 'مدير مصنع وادي العين',
          );
        }
      }

      // تحميل توقيع الجهة التي رفضت التقرير أو طلبت إجراءً تصحيحياً (لعرضه بلون أحمر/كهرماني)
      if (ApprovalStatus.isRejectedStatus(rec.approvalStatus) || isClosed) {
        final rejector =
            ApprovalStatus.rejectorName(
              rejectedBy: rec.rejectedBy,
              gmDecisionBy: rec.gmDecisionBy,
              status: rec.approvalStatus,
            ) ??
            rec.rejectedBy;
        if (rejector != null && rejector.isNotEmpty) {
          final isGmRejector = ApprovalStatus.rejectedByFactoryManager(
            rejectedBy: rec.rejectedBy,
            gmDecisionBy: rec.gmDecisionBy,
            status: rec.approvalStatus,
          );
          final isQsRejector = ApprovalStatus.rejectedByQualitySupervisor(
            rejectedBy: rec.rejectedBy,
            qsApprovedBy: rec.qsApprovedBy,
            status: rec.approvalStatus,
          );
          newRejSig = await UserSignatureService.instance
              .getSignatureBytesForUser(
                userName: rejector,
                userPosition:
                    isGmRejector
                        ? 'مدير مصنع وادي العين'
                        : (isQsRejector
                            ? 'مشرف الجودة والرقابة'
                            : 'مدير توكيد ورقابة الجودة'),
              );
        }
      }

      // تطبيق التوقيعات بسلاسة دفعة واحدة
      inspectorSignatureBytes.value = newInspSig;
      qsSignatureBytes.value = newQsSig;
      qmSignatureBytes.value = newQmSig;
      gmSignatureBytes.value = newGmSig;
      rejectedSignatureBytes.value = newRejSig;

      refreshTrigger.value++;
    } catch (e) {
      if (!silent) {
        Get.snackbar('خطأ', 'حدث خطأ أثناء جلب تفاصيل التقرير');
      } else {
        debugPrint('silent refresh dynamic record error: $e');
      }
    } finally {
      isLoading.value = false;
      isRefreshing.value = false;

      if (!silent && savedOffset != null && savedOffset > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (scrollController.hasClients &&
              (scrollController.offset - savedOffset!).abs() > 1.0) {
            scrollController.jumpTo(savedOffset);
          }
        });
      }
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
    if (!session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    final curSt = currentRecord.value?.approvalStatus ?? '';
    if (!ApprovalStatus.canTransition(curSt, 'Pending_QM')) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(curSt)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    // Use fullName from session; backend resolves from Users table by userId as fallback
    final qsName =
        (session.currentUser.value?.fullName ?? '').trim().isNotEmpty
            ? session.currentUser.value!.fullName.trim()
            : session.currentUserName.value.trim().isNotEmpty
            ? session.currentUserName.value.trim()
            : '';
    final roleTitle =
        session.currentUser.value?.jobTitle?.trim() ??
        session.currentUser.value?.displayRoleTitle ??
        '';
    final userId = session.currentUser.value?.id;

    isProcessingAction.value = true;
    try {
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: 'Pending_QM',
        actorUserId: userId,
        actorName: qsName,
        actorPosition: roleTitle,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'تقرير ديناميكي بانتظار اعتماد الجودة',
          body:
              'قام مشرف الجودة ($qsName) بمراجعة تقرير (${report.value?.name ?? ""}) وهو بانتظار اعتماد مدير الجودة.',
          reportId: recordId,
          reportCategory: 'Dynamic Report',
          targetRole: 'QualityManager',
          branchId: currentRecord.value?.branchId,
        );
      }
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'حدث خطأ أثناء اعتماد مشرف الجودة: $e',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
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
    if (!session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    // Use fullName from session; backend resolves from Users table by userId as fallback
    final qmName =
        (session.currentUser.value?.fullName ?? '').trim().isNotEmpty
            ? session.currentUser.value!.fullName.trim()
            : session.currentUserName.value.trim().isNotEmpty
            ? session.currentUserName.value.trim()
            : '';
    final roleTitle =
        session.currentUser.value?.jobTitle?.trim() ??
        session.currentUser.value?.displayRoleTitle ??
        '';
    final userId = session.currentUser.value?.id;

    final isSingleLevel = report.value?.approvalType == 'single_level';
    final nextStatus = isSingleLevel ? 'Approved' : 'Pending_GM';
    final curSt = currentRecord.value?.approvalStatus ?? '';
    if (!ApprovalStatus.canTransition(curSt, nextStatus)) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(curSt)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    isProcessingAction.value = true;
    try {

      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: nextStatus,
        actorUserId: userId,
        actorName: qmName,
        actorPosition: roleTitle,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        if (isSingleLevel) {
          NotificationService.to.sendNotification(
            title: 'اكتمل الاعتماد',
            body:
                'قام مدير الجودة ($qmName) باعتماد تقرير (${report.value?.name ?? ""}) سجل (#$recordId) وتم إغلاقه.',
            reportId: recordId,
            reportCategory: 'Dynamic Report',
            targetRole: 'All',
            branchId: currentRecord.value?.branchId,
          );
        } else {
          NotificationService.to.sendNotification(
            title: 'تقرير ديناميكي بانتظار الاعتماد النهائي',
            body:
                'قام مدير الجودة ($qmName) باعتماد تقرير (${report.value?.name ?? ""}) سجل (#$recordId) وهو بانتظار اعتماد مدير المصنع.',
            reportId: recordId,
            reportCategory: 'Dynamic Report',
            targetRole: 'FactoryManager',
            branchId: currentRecord.value?.branchId,
          );
          NotificationService.to.sendNotification(
            title: 'تم اعتماد التقرير الديناميكي من مدير الجودة ✓',
            body:
                'قام مدير الجودة ($qmName) باعتماد تقرير (${report.value?.name ?? ""}) سجل (#$recordId) وتم تحويله للاعتماد النهائي.',
            reportId: recordId,
            reportCategory: 'Dynamic Report',
            targetRole: 'QualitySpecialist',
            branchId: currentRecord.value?.branchId,
          );
        }
      }

      Get.snackbar(
        'تم الاعتماد بنجاح',
        isSingleLevel
            ? 'تم اعتماد التقرير من قبل مدير الجودة بشكل نهائي وتم إغلاق التقرير'
            : 'تم اعتماد التقرير من قبل مدير الجودة ورفعه لمدير المصنع للاعتماد النهائي',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل تحديث حالة الاعتماد: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
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
    if (!session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }
    final curSt = currentRecord.value?.approvalStatus ?? '';
    if (!ApprovalStatus.canTransition(curSt, 'Approved')) {
      Get.snackbar(
        'تنبيه',
        'لا يمكن اعتماد التقرير في حالته الحالية (${ApprovalStatus.label(curSt)})',
        backgroundColor: Colors.orange.shade800,
        colorText: Colors.white,
      );
      return;
    }

    // Use fullName from session; backend resolves from Users table by userId as fallback
    final gmName =
        (session.currentUser.value?.fullName ?? '').trim().isNotEmpty
            ? session.currentUser.value!.fullName.trim()
            : session.currentUserName.value.trim().isNotEmpty
            ? session.currentUserName.value.trim()
            : '';
    final roleTitle =
        session.currentUser.value?.jobTitle?.trim() ??
        session.currentUser.value?.displayRoleTitle ??
        '';
    final userId = session.currentUser.value?.id;

    isProcessingAction.value = true;
    try {
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: 'Approved',
        actorUserId: userId,
        actorName: gmName,
        actorPosition: roleTitle,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'تم الاعتماد النهائي للتقرير',
          body:
              'قام مدير المصنع ($gmName) بالاعتماد النهائي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId).',
          reportId: recordId,
          reportCategory: 'Dynamic Report',
          targetRole: 'QualitySpecialist',
          branchId: currentRecord.value?.branchId,
        );
      }

      Get.snackbar(
        'تم الاعتماد النهائي',
        'تم اعتماد التقرير بشكل نهائي من قبل مدير المصنع وأصبح مقفلاً وجاهزاً للطباعة والأرشفة',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل تحديث حالة الاعتماد: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
    }
  }

  Future<void> rejectRecord(RejectionPayload payload) async {
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
    if (!session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا يمكنك اعتماد أو رفض تقارير فرع آخر غير مسند إليك',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    if (!payload.isValid) {
      Get.snackbar(
        'تنبيه',
        'يرجى كتابة سبب الرفض',
        backgroundColor: Colors.amber.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final rejectorName =
        '${session.currentUserName.value} (${session.roleTitle})';
    final userId = session.currentUser.value?.id;
    final newStatus =
        payload.hasCorrectiveAction ? 'Corrective_In_Progress' : 'Rejected';

    isProcessingAction.value = true;
    try {
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: newStatus,
        rejectionReason: payload.reason,
        rejectedBy: rejectorName,
        rejectedAt: DateTime.now(),
        actorUserId: userId,
        actorName: session.currentUserName.value,
        actorPosition: session.roleTitle,
        rejectionCategory: payload.category,
        severityLevel: payload.severity,
        rejectionNotes: payload.notes,
        affectedProducts: payload.affectedProducts,
        immediateAction: payload.immediateAction,
        correctiveAction: payload.correctiveAction,
        correctiveOwner: payload.correctiveOwner,
        correctiveDueDate: payload.dueDate,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'تم رفض التقرير',
          body:
              'تم رفض تقرير (${report.value?.name ?? ""}) سجل (#$recordId) بواسطة $rejectorName: ${payload.reason}'
              '${payload.hasCorrectiveAction ? "\nالإجراء التصحيحي: ${payload.correctiveAction}" : ""}',
          reportId: recordId,
          reportCategory: 'Dynamic Report',
          targetRole: 'QualitySpecialist',
          branchId: currentRecord.value?.branchId,
        );

        if (payload.hasCorrectiveAction) {
          NotificationService.to.sendNotification(
            title: 'إجراء تصحيحي جديد مطلوب تنفيذه',
            body:
                'تم رفض تقرير (${report.value?.name ?? ""}) سجل (#$recordId) وتعيين إجراء تصحيحي: ${payload.correctiveAction}'
                ' — المسؤول: ${payload.correctiveOwner}، يرجى التنفيذ والتوثيق لرفعه لمدير الجودة.',
            reportId: recordId,
            reportCategory: 'Dynamic Report',
            targetRole: 'QualitySpecialist',
            branchId: currentRecord.value?.branchId,
          );
        }
      }

      Get.snackbar(
        payload.hasCorrectiveAction
            ? 'تم الرفض وتعيين إجراء تصحيحي'
            : 'تم الرفض',
        payload.hasCorrectiveAction
            ? 'تم رفض التقرير مع تعيين إجراء تصحيحي للمسؤول المختص'
            : 'تم رفض التقرير وإعادته مع ملاحظات الرفض',
        backgroundColor: const Color(0xFFC62828),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل رفض التقرير: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير الجودة:
  /// - إذا كان التقرير أحادي المستوى (single_level لا يتضمن مدير المصنع) يُغلق نهائياً بالاعتماد (Closed).
  /// - إذا كان التقرير ثنائي أو ثلاثي المستوى يُرفع لمدير المصنع (Pending_GM_Decision) كمرحلة أخيرة.
  Future<void> qmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM ||
        !session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية مدير الجودة لاعتماد الإجراء التصحيحي على هذا التقرير',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final qmName =
        session.currentUserName.value.isNotEmpty
            ? session.currentUserName.value
            : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';
    final userId = session.currentUser.value?.id;
    final isSingleLevel = report.value?.approvalType == 'single_level';
    final targetStatus = isSingleLevel ? 'Closed' : 'Pending_GM_Decision';
    final now = DateTime.now();

    isProcessingAction.value = true;
    try {
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: targetStatus,
        qmApprovedBy: qmName,
        qmApprovedAt: now,
        actorUserId: userId,
        actorName: qmName,
        actorPosition: session.roleTitle,
        gmDecision: isSingleLevel ? 'Approved' : null,
        gmDecisionBy: isSingleLevel ? qmFull : null,
        gmDecisionAt: isSingleLevel ? now : null,
        gmDecisionNotes: notes,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        if (isSingleLevel) {
          NotificationService.to.sendNotification(
            title: 'اعتماد الإجراء التصحيحي وإغلاق التقرير',
            body:
                'اعتمد $qmFull الإجراء التصحيحي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId) وتم إغلاقه نهائياً.',
            reportId: recordId,
            reportCategory: 'Dynamic Report',
            targetRole: 'All',
            branchId: currentRecord.value?.branchId,
          );
        } else {
          NotificationService.to.sendNotification(
            title: 'إجراء تصحيحي معتمد من الجودة وبانتظار قرار مدير المصنع',
            body:
                'اعتمد $qmFull الإجراء التصحيحي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId) وتم رفعه لمدير المصنع للقرار النهائي.',
            reportId: recordId,
            reportCategory: 'Dynamic Report',
            targetRole: 'FactoryManager',
            branchId: currentRecord.value?.branchId,
          );
        }
      }

      Get.snackbar(
        isSingleLevel
            ? 'تم اعتماد الإجراء التصحيحي وإغلاق التقرير'
            : 'تم اعتماد مدير الجودة للإجراء التصحيحي',
        isSingleLevel
            ? 'أُغلق التقرير نهائياً بالاعتماد (مسار أحادي المستوى)'
            : 'تم رفع الإجراء التصحيحي إلى مدير المصنع لاتخاذ القرار النهائي',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل اعتماد الإجراء التصحيحي: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
    }
  }

  /// رفض الإجراء التصحيحي من قبل مدير الجودة:
  /// - إذا كان التقرير أحادي المستوى (single_level بدون مدير مصنع) يُغلق بالرفض النهائي (Rejected_By_GM).
  /// - إذا كان التقرير يتضمن مدير المصنع يعود للمسؤول لتعديل الإجراء التصحيحي (Corrective_In_Progress).
  Future<void> qmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveQM ||
        !session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية مدير الجودة لرفض الإجراء التصحيحي على هذا التقرير',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final qmName =
        session.currentUserName.value.isNotEmpty
            ? session.currentUserName.value
            : 'مدير الجودة';
    final qmFull = '$qmName (مدير الجودة)';
    final userId = session.currentUser.value?.id;
    final isSingleLevel = report.value?.approvalType == 'single_level';
    final targetStatus =
        isSingleLevel ? 'Rejected_By_GM' : 'Corrective_In_Progress';

    isProcessingAction.value = true;
    try {
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: targetStatus,
        actorUserId: userId,
        actorName: qmName,
        actorPosition: session.roleTitle,
        gmDecision: 'Rejected',
        gmDecisionBy: qmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title:
              isSingleLevel
                  ? 'رفض نهائي للإجراء التصحيحي وإغلاق التقرير'
                  : 'مدير الجودة يرفض الإجراء التصحيحي للتعديل',
          body:
              isSingleLevel
                  ? 'رفض $qmFull الإجراء التصحيحي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId) وأُغلق التقرير بالرفض النهائي. السبب: $notes'
                  : 'رفض $qmFull الإجراء التصحيحي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId) وطلب تعديله: $notes',
          reportId: recordId,
          reportCategory: 'Dynamic Report',
          targetRole: 'QualitySpecialist',
          branchId: currentRecord.value?.branchId,
        );
      }

      Get.snackbar(
        isSingleLevel
            ? 'تم الرفض النهائي وإغلاق التقرير'
            : 'تمت إعادة الإجراء التصحيحي للمسؤول',
        isSingleLevel
            ? 'أُغلق التقرير نهائياً بالرفض القاطع'
            : 'تمت إعادة التقرير للمسؤول لتعديل وتوثيق إجراء تصحيحي مناسب',
        backgroundColor:
            isSingleLevel ? const Color(0xFF8B0000) : const Color(0xFFE65100),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل رفض الإجراء التصحيحي: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
    }
  }

  /// اعتماد الإجراء التصحيحي من قبل مدير المصنع وإغلاق التقرير
  Future<void> gmApproveCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM ||
        !session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية اعتماد الإجراء التصحيحي على هذا التقرير',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final gmName =
        session.currentUserName.value.isNotEmpty
            ? session.currentUserName.value
            : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';
    final userId = session.currentUser.value?.id;

    isProcessingAction.value = true;
    try {
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: 'Closed',
        gmApprovedBy: gmName,
        gmApprovedAt: DateTime.now(),
        actorUserId: userId,
        actorName: gmName,
        actorPosition: session.roleTitle,
        gmDecision: 'Approved',
        gmDecisionBy: gmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'اعتماد الإجراء التصحيحي وإغلاق التقرير',
          body:
              'اعتمد $gmFull الإجراء التصحيحي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId) وتم إغلاقه نهائياً.',
          reportId: recordId,
          reportCategory: 'Dynamic Report',
          targetRole: 'All',
          branchId: currentRecord.value?.branchId,
        );
      }

      Get.snackbar(
        'تم اعتماد الإجراء التصحيحي',
        'أُغلق التقرير نهائياً وأصبح الإجراء التصحيحي معتمداً رسمياً',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل اعتماد الإجراء التصحيحي: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
    }
  }

  /// رفض الإجراء التصحيحي قطعياً من قبل مدير المصنع وإغلاق التقرير بالرفض النهائي
  Future<void> gmRejectCorrectiveAction(String notes) async {
    final session = UserSessionService.to;
    if (!session.canApproveGM ||
        !session.canApproveBranchData(currentRecord.value?.branchId)) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية رفض الإجراء التصحيحي على هذا التقرير',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final gmName =
        session.currentUserName.value.isNotEmpty
            ? session.currentUserName.value
            : 'مدير المصنع';
    final gmFull = '$gmName (مدير المصنع)';
    final userId = session.currentUser.value?.id;

    isProcessingAction.value = true;
    try {
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: 'Rejected_By_GM',
        actorUserId: userId,
        actorName: gmName,
        actorPosition: session.roleTitle,
        gmDecision: 'Rejected',
        gmDecisionBy: gmFull,
        gmDecisionAt: DateTime.now(),
        gmDecisionNotes: notes,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'رفض قطعي للإجراء التصحيحي وإغلاق التقرير',
          body:
              'رفض $gmFull الإجراء التصحيحي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId) وتم إغلاق التقرير بالرفض النهائي. السبب: $notes',
          reportId: recordId,
          reportCategory: 'Dynamic Report',
          targetRole: 'All',
          branchId: currentRecord.value?.branchId,
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
      Get.snackbar(
        'خطأ',
        'فشل رفض الإجراء التصحيحي: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
    }
  }

  /// رفع الإجراء التصحيحي المنفَّذ إلى مدير الجودة للمراجعة والاعتماد
  Future<void> submitCorrectiveAction([String? notes]) async {
    final session = UserSessionService.to;
    if (!session.canEditReports &&
        !session.canFillDynamicReports &&
        !session.canRejectReports &&
        !session.isAdmin) {
      Get.snackbar(
        'غير مصرح',
        'لا تملك صلاحية رفع الإجراء التصحيحي',
        backgroundColor: Colors.red.shade700,
        colorText: Colors.white,
      );
      return;
    }

    final submitterName =
        session.currentUserName.value.isNotEmpty
            ? session.currentUserName.value
            : session.roleTitle;
    final userId = session.currentUser.value?.id;

    isProcessingAction.value = true;
    try {
      final effectiveNotes =
          (notes != null && notes.trim().isNotEmpty)
              ? notes.trim()
              : (currentRecord.value?.correctiveAction ??
                  'تم إنجاز الإجراء التصحيحي');
      await DynamicReportsApiService.to.addApproval(
        recordId: recordId,
        approvalStatus: 'Pending_QM_Decision',
        actorUserId: userId,
        actorName: submitterName,
        actorPosition: session.roleTitle,
        correctiveAction: effectiveNotes,
      );

      await loadData();

      if (Get.isRegistered<NotificationService>()) {
        NotificationService.to.sendNotification(
          title: 'إجراء تصحيحي بانتظار اعتماد مدير الجودة',
          body:
              'قام $submitterName بتوثيق ورفع الإجراء التصحيحي لتقرير (${report.value?.name ?? ""}) سجل (#$recordId) وهو بانتظار مراجعتك واعتمادك.',
          reportId: recordId,
          reportCategory: 'Dynamic Report',
          targetRole: 'QualityManager',
          branchId: currentRecord.value?.branchId,
        );
      }

      Get.snackbar(
        'تم رفع الإجراء التصحيحي لمدير الجودة',
        'أصبح التقرير بانتظار مراجعة واعتماد مدير الجودة للإجراء التصحيحي',
        backgroundColor: const Color(0xFF1565C0),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل رفع الإجراء التصحيحي: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    } finally {
      isProcessingAction.value = false;
    }
  }
}

class DynamicReportDisplayView extends StatelessWidget {
  const DynamicReportDisplayView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DynamicReportDisplayController());

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Obx(() {
          final title = controller.report.value?.name ?? 'عرض التقرير';
          return Text(
            title,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          );
        }),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 1,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final rep = controller.report.value;
        final record = controller.currentRecord.value;
        if (rep == null || record == null) {
          return const Center(child: Text('عذراً، لم يتم العثور على التقرير.'));
        }

        if (!UserSessionService.to.canViewBranchData(record.branchId)) {
          return _buildAccessDeniedWidget(context, record);
        }

        final hasApproval = rep.approvalType != 'none';
        final isLandscape = rep.orientation == 'landscape';
        final double docWidth = isLandscape ? 1028 : 794;

        // قراءة المتغيرات التفاعلية داخل Obx لضمان إعادة الرسم التلقائي عند المزامنة وجلب التوقيعات
        final int trigger = controller.refreshTrigger.value;
        final Uint8List? qsSig = controller.qsSignatureBytes.value;
        final Uint8List? qmSig = controller.qmSignatureBytes.value;
        final Uint8List? gmSig = controller.gmSignatureBytes.value;
        final Uint8List? inspSig = controller.inspectorSignatureBytes.value;
        final Uint8List? rejSig = controller.rejectedSignatureBytes.value;

        final String sigHash =
            '${qsSig?.length ?? 0}_${qmSig?.length ?? 0}_${gmSig?.length ?? 0}_${rejSig?.length ?? 0}';
        final String statusKey = record.approvalStatus;
        final String updatedAtKey = record.updatedAt?.toIso8601String() ?? '';

        return Stack(
          children: [
            PdfPreview.builder(
              key: ValueKey(
                'pdf_preview_${controller.recordId}_${trigger}_${statusKey}_${sigHash}_$updatedAtKey',
              ),
              build:
                  (format) => DynamicReportPdfGenerator.generate(
                    report: rep,
                    record: record,
                    values: controller.values,
                    approvals: controller.approvals,
                    qsSignatureBytes: qsSig,
                    qmSignatureBytes: qmSig,
                    gmSignatureBytes: gmSig,
                    creatorSignatureBytes: inspSig,
                    rejectedSignatureBytes: rejSig,
                  ),
              allowSharing: true,
              allowPrinting: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              initialPageFormat:
                  isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4,
              pagesBuilder:
                  (context, pages) => ZoomableDocumentView(
                    documentWidth: docWidth,
                    scrollController: controller.scrollController,
                    storageKey: PageStorageKey(
                      'zoomable_doc_${controller.recordId}',
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasApproval)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildApprovalActionBar(
                              context,
                              controller,
                              record,
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildGeneralInfoBar(context, record),
                          ),
                        for (int i = 0; i < pages.length; i++)
                          Container(
                            margin: const EdgeInsets.only(
                              left: 8,
                              right: 8,
                              top: 4,
                              bottom: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: AspectRatio(
                              aspectRatio: pages[i].aspectRatio,
                              child: Image(
                                image: pages[i].image,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
            ),
            Obx(() {
              if (controller.isRefreshing.value) {
                return const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00838F),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
        );
      }),
    );
  }

  Widget _buildApprovalActionBar(
    BuildContext context,
    DynamicReportDisplayController controller,
    DynamicReportRecord record,
  ) {
    return Obx(() {
      final session = UserSessionService.to;
      final currentRole = session.currentRole.value;
      final status = record.approvalStatus;

      Color bannerColor;
      String statusTitle;
      String statusSubtitle;
      IconData statusIcon;

      switch (status) {
        case 'Pending_QS':
          bannerColor = const Color(0xFFF57C00); // Amber/Orange
          statusTitle = 'التقرير بانتظار اعتماد مشرف الجودة';
          statusSubtitle =
              'تم إرسال التقرير ومقفلاً بانتظار مراجعة واعتماد مشرف الجودة.';
          statusIcon = Icons.playlist_add_check_circle_rounded;
          break;
        case 'Pending_QM':
          bannerColor = const Color(0xFFE65100); // Orange
          statusTitle = 'التقرير بانتظار اعتماد مدير الجودة';
          statusSubtitle =
              'تم إرسال التقرير ومقفلاً بانتظار مراجعة واعتماد إدارة الجودة.';
          statusIcon = Icons.pending_actions_rounded;
          break;
        case 'Pending_GM':
          bannerColor = const Color(0xFF6A1B9A); // Purple
          statusTitle = 'التقرير بانتظار اعتماد مدير المصنع (الاعتماد النهائي)';
          statusSubtitle =
              'تم اعتماده من مدير الجودة وهو الآن بانتظار توقيع واعتماد مدير المصنع.';
          statusIcon = Icons.admin_panel_settings_rounded;
          break;
        case 'Approved':
          bannerColor = const Color(0xFF2E7D32); // Green
          statusTitle = 'مُعتمد نهائياً (Approved)';
          statusSubtitle =
              'تم اعتماد التقرير رسمياً وهو مقفل وجاهز للطباعة والأرشفة.';
          statusIcon = Icons.verified_rounded;
          break;
        case 'Rejected':
          bannerColor = const Color(0xFFC62828); // Red
          final rejectorLabel =
              (record.rejectedBy != null && record.rejectedBy!.isNotEmpty)
                  ? ' من قِبل ${record.rejectedBy}'
                  : '';
          statusTitle = 'تم رفض التقرير$rejectorLabel';
          statusSubtitle = 'سبب الرفض: ${record.rejectionReason ?? "غير محدد"}';
          statusIcon = Icons.cancel_rounded;
          break;
        case 'Corrective_In_Progress':
          bannerColor = const Color(0xFF1565C0); // Blue
          statusTitle = 'الإجراء التصحيحي قيد التنفيذ';
          statusSubtitle =
              (record.correctiveAction ?? '').isNotEmpty
                  ? 'الإجراء المطلوب: ${record.correctiveAction} — المسؤول: ${record.correctiveOwner ?? "غير محدد"}'
                  : 'المسؤول المختص يعمل على تنفيذ الإجراء التصحيحي.';
          statusIcon = Icons.build_circle;
          break;
        case 'Pending_QM_Decision':
          bannerColor = const Color(0xFFEF6C00); // Orange
          statusTitle = 'بانتظار اعتماد مدير الجودة للإجراء التصحيحي';
          statusSubtitle =
              'تم تنفيذ وتوثيق الإجراء التصحيحي وهو بانتظار مراجعة واعتماد مدير الجودة.';
          statusIcon = Icons.fact_check_outlined;
          break;
        case 'Pending_GM_Decision':
          bannerColor = const Color(0xFFAD6800); // Dark Amber
          statusTitle = 'بانتظار اعتماد مدير المصنع للإجراء التصحيحي';
          statusSubtitle =
              'تم اعتماد الإجراء التصحيحي من مدير الجودة وهو بانتظار قرار مدير المصنع النهائي.';
          statusIcon = Icons.pending_actions;
          break;
        case 'Rejected_By_GM':
          bannerColor = const Color(0xFF8B0000); // Dark Red
          statusTitle = 'مرفوض نهائياً — انتهاء دورة الاعتماد';
          statusSubtitle =
              (record.gmDecisionNotes ?? '').isNotEmpty
                  ? 'تم رفض الإجراء التصحيحي: ${record.gmDecisionNotes} (انتهت دورة الاعتماد بالرفض النهائي)'
                  : 'تم رفض الإجراء التصحيحي من مدير المصنع، وانتهت دورة الاعتماد بالرفض النهائي للتقرير دون إمكانية تصحيح إضافي.';
          statusIcon = Icons.cancel_presentation;
          break;
        case 'Closed':
          bannerColor = const Color(0xFF2E7D32); // Green
          statusTitle = 'معتمد بعد إجراء تصحيحي';
          statusSubtitle =
              'تم اعتماد الإجراء التصحيحي من مدير المصنع وإغلاق التقرير نهائياً.';
          statusIcon = Icons.task_alt;
          break;
        case 'Draft':
        case 'مسودة':
          bannerColor = const Color(0xFF455A64); // Blue Grey
          statusTitle = 'مسودة غير مكتملة (Draft)';
          statusSubtitle = 'التقرير محفوظ كمسودة ولم يُرسل للاعتماد بعد.';
          statusIcon = Icons.drafts_rounded;
          break;
        default:
          bannerColor = Colors.blueGrey;
          statusTitle = status;
          statusSubtitle = '';
          statusIcon = Icons.info_outline;
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Banner Top
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: bannerColor.withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: bannerColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: bannerColor,
                          ),
                        ),
                        if (statusSubtitle.isNotEmpty)
                          Text(
                            statusSubtitle,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.person_pin_rounded,
                              size: 15,
                              color: bannerColor.withValues(alpha: 0.9),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'منفذ الفحص: ${DynamicReportRecord.sanitizeCreatorName(record.createdBy)}',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DynamicReportPdfGenerator.formatArabicDate(
                                record.createdAt,
                              ),
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        if (record.branchName != null ||
                            record.shiftName != null) ...[
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              if (record.branchName != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF003853,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.factory_rounded,
                                        size: 11,
                                        color: Color(0xFF003853),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        record.branchName!,
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF003853),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (record.shiftName != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF007791,
                                    ).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.schedule_rounded,
                                        size: 11,
                                        color: Color(0xFF007791),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        record.shiftName!,
                                        style: const TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF007791),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Visual Signatures Bar
            _buildVisualSignaturesBar(context, controller, record),

            // Actions Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: _buildRoleActions(
                context,
                controller,
                record,
                currentRole,
                status,
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVisualSignaturesBar(
    BuildContext context,
    DynamicReportDisplayController controller,
    DynamicReportRecord record,
  ) {
    final isThreeLevel = controller.report.value?.approvalType == 'three_level';
    final bool isClosed = record.approvalStatus == 'Closed';
    final wasQsApproved = ApprovalStatus.wasApprovedByQsPriorToRejection(
      qsApprovedBy: record.qsApprovedBy,
      status: record.approvalStatus,
    );
    final isQsDone =
        record.approvalStatus == 'Approved' ||
        record.approvalStatus == 'Pending_GM' ||
        record.approvalStatus == 'Pending_QM' ||
        isClosed ||
        wasQsApproved;
    final isQmDone =
        record.approvalStatus == 'Approved' ||
        record.approvalStatus == 'Pending_GM';
    final isGmDone = record.approvalStatus == 'Approved' || isClosed;

    // تحديد الجهة التي رفضت التقرير لعرض توقيعها باللون الأحمر
    final isQsRejected = ApprovalStatus.rejectedByQualitySupervisor(
      rejectedBy: record.rejectedBy,
      qsApprovedBy: record.qsApprovedBy,
      status: record.approvalStatus,
    );
    final isQmRejected = ApprovalStatus.rejectedByQualityManager(
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      qmApprovedBy: record.qmApprovedBy,
      qsApprovedBy: record.qsApprovedBy,
      status: record.approvalStatus,
    );
    final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      status: record.approvalStatus,
    );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: record.qmApprovedBy,
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      status: record.approvalStatus,
    );
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      status: record.approvalStatus,
    );
    final bool isRejectorGm =
        (record.gmDecisionBy != null &&
            record.gmDecisionBy == record.rejectedBy) ||
        (record.rejectedBy != null &&
            (record.rejectedBy!.contains('مدير المصنع') ||
                record.rejectedBy!.contains('العمري')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.draw_rounded,
                size: 14,
                color: AppColors.primaryDark,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'حالة التوقيعات الرقمية المعتمدة (Visual Overlay Signatures)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: 'منفذ الفحص / إعداد',
                  signerName: DynamicReportRecord.sanitizeCreatorName(
                    record.createdBy,
                  ),
                  dateStr: DynamicReportPdfGenerator.formatArabicDate(
                    record.createdAt,
                  ),
                  isApproved: true,
                  signatureBytes: controller.inspectorSignatureBytes.value,
                ),
              ),
              if (isThreeLevel) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSignatureBoxUI(
                    roleTitle: 'اعتماد مشرف الجودة',
                    signerName:
                        isQsRejected
                            ? (record.rejectedBy ?? 'مشرف الجودة')
                            : record.qsApprovedBy ??
                                (isQsDone ? 'مشرف الجودة' : 'بانتظار الاعتماد'),
                    dateStr:
                        isQsRejected
                            ? (record.rejectedAt != null
                                ? DynamicReportPdfGenerator.formatArabicDate(
                                  record.rejectedAt!,
                                )
                                : 'مرفوض')
                            : (record.qsApprovedAt != null
                                ? DynamicReportPdfGenerator.formatArabicDate(
                                  record.qsApprovedAt!,
                                )
                                : (isQsDone ? 'معتمد' : 'لم يعتمد بعد')),
                    isApproved: isQsDone && !isQsRejected,
                    isRejected: isQsRejected,
                    signatureBytes:
                        isQsRejected
                            ? controller.rejectedSignatureBytes.value
                            : (isQsDone
                                ? controller.qsSignatureBytes.value
                                : null),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle:
                      isClosed
                          ? 'مدير الجودة (معتمد سابقاً)'
                          : (wasQmApproved
                              ? 'اعتماد مدير الجودة (سابقاً)'
                              : 'اعتماد مدير الجودة'),
                  signerName:
                      record.qmApprovedBy ??
                      (!isRejectorGm ? record.rejectedBy : null) ??
                      '(مدير الجودة)',
                  dateStr:
                      isClosed
                          ? (record.qmApprovedAt != null
                              ? DynamicReportPdfGenerator.formatArabicDate(
                                record.qmApprovedAt!,
                              )
                              : (record.rejectedAt != null
                                  ? DynamicReportPdfGenerator.formatArabicDate(
                                    record.rejectedAt!,
                                  )
                                  : DynamicReportPdfGenerator.formatArabicDate(
                                    DateTime.now(),
                                  )))
                          : (record.qmApprovedAt != null
                              ? DynamicReportPdfGenerator.formatArabicDate(
                                record.qmApprovedAt!,
                              )
                              : (isQmDone || wasQmApproved
                                  ? 'معتمد'
                                  : (isQmRejected ? 'مرفوض' : 'لم يعتمد بعد'))),
                  isApproved: isQmDone && !isClosed,
                  isRejected: (isQmRejected || wasQmRejected) && !isClosed,
                  isVoided: isClosed || wasQmApproved,
                  signatureBytes:
                      isClosed
                          ? controller.qmSignatureBytes.value
                          : ((isQmRejected || wasQmRejected)
                              ? controller.rejectedSignatureBytes.value
                              : ((isQmDone || wasQmApproved)
                                  ? controller.qmSignatureBytes.value
                                  : null)),
                ),
              ),
              if (controller.report.value?.approvalType != 'single_level') ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSignatureBoxUI(
                    roleTitle:
                        isClosed
                            ? 'اعتماد مدير المصنع (بعد إجراء تصحيحي)'
                            : 'اعتماد مدير المصنع',
                    signerName:
                        isGmRejected
                            ? (record.gmDecisionBy ??
                                record.rejectedBy ??
                                'مدير المصنع')
                            : (record.gmDecisionBy ??
                                record.gmApprovedBy ??
                                (isGmDone
                                    ? 'د. خالد العمري (مدير المصنع)'
                                    : 'بانتظار الاعتماد')),
                    dateStr:
                        isClosed
                            ? (record.gmDecisionAt != null
                                ? DynamicReportPdfGenerator.formatArabicDate(
                                  record.gmDecisionAt!,
                                )
                                : (record.gmApprovedAt != null
                                    ? DynamicReportPdfGenerator.formatArabicDate(
                                      record.gmApprovedAt!,
                                    )
                                    : 'معتمد بعد إجراء تصحيحي'))
                            : (record.gmApprovedAt != null
                                ? DynamicReportPdfGenerator.formatArabicDate(
                                  record.gmApprovedAt!,
                                )
                                : (isGmDone
                                    ? 'معتمد نهائياً'
                                    : (isGmRejected
                                        ? 'مرفوض'
                                        : 'لم يعتمد بعد'))),
                    isApproved: isGmDone || isClosed,
                    isRejected: isGmRejected,
                    signatureBytes:
                        isGmRejected
                            ? controller.rejectedSignatureBytes.value
                            : (isGmDone
                                ? controller.gmSignatureBytes.value
                                : null),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// مربع اعتماد ذو أبعاد ثابتة تماماً (Zero Layout Shift)
  /// التوقيع متراكب كلياً فوق النصوص بخلفية شفافة وتعتيم 0.42 كالختم اليدوي
  Widget _buildSignatureBoxUI({
    required String roleTitle,
    required String signerName,
    required String dateStr,
    required bool isApproved,
    Uint8List? signatureBytes,
    bool isRejected = false,
    bool isVoided = false,
  }) {
    // ألوان المربع: أخضر للاعتماد، أحمر للرفض، كهرماني للمعتمد سابقاً الملغى، رمادي للانتظار
    final Color boxColor =
        isRejected
            ? const Color(0xFFFFEBEE)
            : (isVoided
                ? const Color(0xFFFFF8E1)
                : (isApproved ? const Color(0xFFF1F8E9) : Colors.white));
    final Color borderColor =
        isRejected
            ? const Color(0xFFE53935)
            : (isVoided
                ? const Color(0xFFFFB300)
                : (isApproved
                    ? const Color(0xFF81C784)
                    : Colors.grey.shade300));
    final Color titleColor =
        isRejected
            ? const Color(0xFFC62828)
            : (isVoided
                ? const Color(0xFFB78103)
                : (isApproved
                    ? const Color(0xFF2E7D32)
                    : Colors.blueGrey.shade800));
    final Color nameColor =
        isRejected
            ? const Color(0xFFC62828)
            : (isVoided ? const Color(0xFFB78103) : Colors.black87);

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        roleTitle,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRejected)
                      const Icon(
                        Icons.cancel_rounded,
                        size: 12,
                        color: Color(0xFFC62828),
                      )
                    else if (isVoided)
                      const Icon(
                        Icons.history_edu_rounded,
                        size: 12,
                        color: Color(0xFFB78103),
                      )
                    else if (isApproved)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: Color(0xFF2E7D32),
                      ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  signerName,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    fontWeight:
                        isApproved ? FontWeight.bold : FontWeight.normal,
                    color: nameColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 9,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
            if ((isApproved || isRejected || isVoided) &&
                signatureBytes != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.42,
                  child: Center(
                    child: Image.memory(signatureBytes, fit: BoxFit.contain),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleActions(
    BuildContext context,
    DynamicReportDisplayController controller,
    DynamicReportRecord record,
    UserRole currentRole,
    String status,
  ) {
    if (status == 'Approved') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 18),
          const SizedBox(width: 8),
          const Text(
            'التقرير معتمد ومقفل رسمياً ولا يمكن تعديله.',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      );
    }

    if (status == 'Rejected' ||
        status == 'Corrective_In_Progress' ||
        status == 'Pending_QM_Decision' ||
        status == 'Pending_GM_Decision' ||
        status == 'Rejected_By_GM' ||
        status == 'Closed') {
      return _buildCorrectiveActionSection(controller, record, status);
    }

    if (status == 'Draft' || status == 'مسودة') {
      if (!UserSessionService.to.canEditReports) return const SizedBox.shrink();
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final res = await Get.toNamed(
              AppRoutes.dynamicReportForm,
              arguments: {
                'reportId': controller.reportId,
                'recordId': record.id,
              },
            );
            if (res == true) {
              controller.loadData();
            }
          },
          icon: const Icon(Icons.edit_document, color: Colors.white, size: 20),
          label: const Text(
            'استكمال المسودة وإرسالها للاعتماد',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryDark,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
    }

    if (status == 'Pending_QS') {
      if (UserSessionService.to.canApproveQSupervisor &&
          UserSessionService.to.canApproveBranchData(record.branchId)) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    controller.isProcessingAction.value
                        ? null
                        : () => _confirmApproval(
                          context,
                          title: 'اعتماد مشرف الجودة',
                          message:
                              'هل أنت متأكد من مراجعة واعتماد هذا التقرير؟ سيتم رفعه لمدير الجودة.',
                          confirmBtnColor: const Color(0xFFF57C00),
                          onConfirm: controller.approveByQualitySupervisor,
                        ),
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF57C00),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: const Text(
                  'اعتماد مشرف الجودة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (UserSessionService.to.canRejectReports) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      controller.isProcessingAction.value
                          ? null
                          : () => _showRejectDialog(context, controller),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  label: const Text(
                    'رفض / إعادة للتعديل',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else if (UserSessionService.to.canApproveQSupervisor &&
          !UserSessionService.to.canApproveBranchData(record.branchId)) {
        return _buildRolePromptCard(
          prompt:
              'هذا التقرير يتبع لـ (${record.effectiveBranchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
          targetRole: UserRole.qualityManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt:
              'التقرير بانتظار اعتماد مشرف الجودة. للقيام بالاعتماد، يجب أن يملك حسابك صلاحية اعتماد مشرف الجودة.',
          targetRole: UserRole.qualityManager,
        );
      }
    }

    if (status == 'Pending_QM') {
      if (UserSessionService.to.canApproveQM &&
          UserSessionService.to.canApproveBranchData(record.branchId)) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    controller.isProcessingAction.value
                        ? null
                        : () {
                          final isSingle =
                              controller.report.value?.approvalType ==
                              'single_level';
                          _confirmApproval(
                            context,
                            title: 'اعتماد مدير الجودة',
                            message:
                                isSingle
                                    ? 'هل أنت متأكد من مراجعة واعتماد هذا التقرير؟ سيصبح التقرير معتمداً ومقفلاً نهائياً.'
                                    : 'هل أنت متأكد من مراجعة واعتماد هذا التقرير؟ سيتم رفعه لمدير المصنع للاعتماد النهائي.',
                            confirmBtnColor: const Color(0xFF2E7D32),
                            onConfirm: controller.approveByQualityManager,
                          );
                        },
                icon: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 18,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: const Text(
                  'اعتماد مدير الجودة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (UserSessionService.to.canRejectReports) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      controller.isProcessingAction.value
                          ? null
                          : () => _showRejectDialog(context, controller),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  label: const Text(
                    'رفض / إعادة للتعديل',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else if (UserSessionService.to.canApproveQM &&
          !UserSessionService.to.canApproveBranchData(record.branchId)) {
        return _buildRolePromptCard(
          prompt:
              'هذا التقرير يتبع لـ (${record.effectiveBranchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
          targetRole: UserRole.qualityManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt:
              'التقرير بانتظار اعتماد مدير الجودة. للقيام بالاعتماد، يجب أن يملك حسابك صلاحية اعتماد الجودة.',
          targetRole: UserRole.qualityManager,
        );
      }
    }

    if (status == 'Pending_GM') {
      if (controller.report.value?.approvalType == 'single_level') {
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified, color: Color(0xFF2E7D32), size: 18),
            const SizedBox(width: 8),
            const Text(
              'التقرير معتمد (مسار اعتماد أحادي) ولا يتطلب اعتماد مدير المصنع.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        );
      }

      if (UserSessionService.to.canApproveGM &&
          UserSessionService.to.canApproveBranchData(record.branchId)) {
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    controller.isProcessingAction.value
                        ? null
                        : () => _confirmApproval(
                          context,
                          title: 'الاعتماد النهائي لمدير المصنع',
                          message:
                              'هل أنت متأكد من الاعتماد النهائي لهذا التقرير؟ سيصبح مقفلاً وجاهزاً للطباعة والأرشفة.',
                          confirmBtnColor: const Color(0xFF6A1B9A),
                          onConfirm: controller.approveByFactoryManager,
                        ),
                icon: const Icon(Icons.verified, color: Colors.white, size: 18),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                label: const Text(
                  'اعتماد مدير المصنع',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (UserSessionService.to.canRejectReports) ...[
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      controller.isProcessingAction.value
                          ? null
                          : () => _showRejectDialog(context, controller),
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: Colors.redAccent,
                    size: 18,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  label: const Text(
                    'رفض التقرير',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      } else if (UserSessionService.to.canApproveGM &&
          !UserSessionService.to.canApproveBranchData(record.branchId)) {
        return _buildRolePromptCard(
          prompt:
              'هذا التقرير يتبع لـ (${record.effectiveBranchName})، بينما حسابك مسند إلى (${UserSessionService.to.assignedBranchName}). لا تملك صلاحية اعتماد تقارير مصنع آخر.',
          targetRole: UserRole.factoryManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt:
              'التقرير بانتظار اعتماد مدير المصنع. للقيام بالاعتماد، بدّل دورك إلى "مدير المصنع".',
          targetRole: UserRole.factoryManager,
        );
      }
    }

    return const SizedBox.shrink();
  }

  Widget _buildRolePromptCard({required String prompt, UserRole? targetRole}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade800,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prompt,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                color: Colors.orange.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmApproval(
    BuildContext context, {
    required String title,
    required String message,
    required Color confirmBtnColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            title: Text(
              title,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              message,
              style: const TextStyle(fontFamily: 'Tajawal'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'إلغاء',
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmBtnColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'تأكيد الاعتماد',
                  style: TextStyle(fontFamily: 'Tajawal'),
                ),
              ),
            ],
          ),
    );
  }

  /// قسم الإجراء التصحيحي — يعرض بطاقة الإجراء التصحيحي الكاملة وأزرار الإجراءات
  Widget _buildCorrectiveActionSection(
    DynamicReportDisplayController controller,
    DynamicReportRecord record,
    String status,
  ) {
    final session = UserSessionService.to;
    final canQmDecide =
        ApprovalStatus.qmCanDecide(status) &&
        session.canApproveQM &&
        session.canApproveBranchData(record.branchId);
    final canGmDecide =
        ApprovalStatus.gmCanDecide(status) &&
        session.canApproveGM &&
        session.canApproveBranchData(record.branchId);
    final canDecide = canQmDecide || canGmDecide;
    final canSubmit =
        (status == 'Rejected' || status == 'Corrective_In_Progress') &&
        (session.canEditReports ||
            session.canFillDynamicReports ||
            session.canRejectReports ||
            session.isAdmin) &&
        session.canApproveBranchData(record.branchId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactoryManagerRejectionCard(
          title: '${controller.report.value?.name ?? "تقرير"} #${record.id}',
          subtitle: record.effectiveBranchName,
          status: status,
          rejectionReason: record.rejectionReason,
          rejectedBy: record.rejectedBy,
          rejectionCategory: record.rejectionCategory,
          severity: record.severityLevel,
          affectedProducts: record.affectedProducts,
          immediateAction: record.immediateAction,
          correctiveAction: record.correctiveAction,
          correctiveOwner: record.correctiveOwner,
          correctiveDueDate: record.correctiveDueDate,
          gmDecision: record.gmDecision,
          gmDecisionBy: record.gmDecisionBy,
          gmDecisionNotes: record.gmDecisionNotes,
          onApprove: canDecide ? () => _showGmDecisionDialog(controller) : null,
          onReject: canDecide ? () => _showGmDecisionDialog(controller) : null,
        ),
        if (canSubmit) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSubmitCorrectiveDialog(controller, record),
              icon: const Icon(
                Icons.assignment_turned_in_rounded,
                color: Colors.white,
                size: 18,
              ),
              label: const Text(
                'توثيق وإرسال الإجراء التصحيحي لمدير الجودة',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showSubmitCorrectiveDialog(
    DynamicReportDisplayController controller,
    DynamicReportRecord record,
  ) async {
    final action = await CorrectiveActionSubmitDialog.show(
      Get.context!,
      reportTitle: '${controller.report.value?.name ?? "تقرير"} #${record.id}',
      rejectionReason: record.rejectionReason ?? 'غير محدد',
      rejectedBy: record.rejectedBy,
      initialCorrectiveAction: record.correctiveAction,
      correctiveOwner: record.correctiveOwner,
    );
    if (action != null && action.isNotEmpty) {
      controller.submitCorrectiveAction(action);
    }
  }

  /// شاشة قرار مدير الجودة أو مدير المصنع على الإجراء التصحيحي
  void _showGmDecisionDialog(DynamicReportDisplayController controller) async {
    final record = controller.currentRecord.value;
    if (record == null) return;
    final status = record.approvalStatus;
    final isQmStage = status == 'Pending_QM_Decision';
    final isSingleLevel = controller.report.value?.approvalType == 'single_level';

    final decision = await GmDecisionDialog.show(
      Get.context!,
      reportTitle: '${controller.report.value?.name ?? "تقرير"} #${record.id}',
      correctiveAction: record.correctiveAction ?? 'غير محدد',
      correctiveOwner: record.correctiveOwner ?? 'غير محدد',
      severity: record.severityLevel,
      decisionTitle: isQmStage
          ? 'قرار مدير الجودة على الإجراء التصحيحي'
          : 'القرار النهائي لمدير المصنع على الإجراء التصحيحي',
      isFinalStage: isQmStage ? isSingleLevel : true,
    );

    if (decision == null) return;
    if (isQmStage) {
      if (decision.isApproved) {
        controller.qmApproveCorrectiveAction(decision.notes);
      } else {
        controller.qmRejectCorrectiveAction(decision.notes);
      }
    } else {
      if (decision.isApproved) {
        controller.gmApproveCorrectiveAction(decision.notes);
      } else {
        controller.gmRejectCorrectiveAction(decision.notes);
      }
    }
  }

  void _showRejectDialog(
    BuildContext context,
    DynamicReportDisplayController controller,
  ) async {
    final record = controller.currentRecord.value;
    final payload = await RejectReportDialog.show(
      context,
      reportTitle:
          '${controller.report.value?.name ?? "تقرير"} #${record?.id ?? "?"}',
      reportSubtitle: record?.effectiveBranchName,
    );

    if (payload == null) return;
    controller.rejectRecord(payload);
  }

  Widget _buildGeneralInfoBar(
    BuildContext context,
    DynamicReportRecord record,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFF007791),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_pin_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'منفذ الفحص: ${DynamicReportRecord.sanitizeCreatorName(record.createdBy)}',
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF007791),
                  ),
                ),
                Text(
                  'تاريخ التعبئة: ${DynamicReportPdfGenerator.formatArabicDate(record.createdAt)}',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedWidget(
    BuildContext context,
    DynamicReportRecord record,
  ) {
    final session = UserSessionService.to;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.red.shade200, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_rounded,
                size: 56,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'وصول مقيد - عزل بيانات الفروع',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'هذا التقرير يتبع لـ (${record.effectiveBranchName}).\nحسابك الحالي مقيد بصلاحيات (${session.assignedBranchName}).\nلا يمكنك استعراض أو تعديل أو اعتماد تقارير مصانع أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              label: const Text(
                'العودة إلى تقارير مصنعك',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
