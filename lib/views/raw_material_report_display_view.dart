import '../widgets/corrective_action_submit_dialog.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/approval_status.dart';
import '../controllers/raw_material_report_display_controller.dart';
import '../models/raw_material_models.dart';
import '../services/user_session_service.dart';
import '../utils/dynamic_report_pdf_generator.dart';
import '../widgets/factory_manager_rejection_card.dart';
import '../widgets/gm_decision_dialog.dart';
import '../widgets/reject_report_dialog.dart';
import '../widgets/zoomable_document_view.dart';
import '../widgets/ds/ds.dart';

class RawMaterialReportDisplayView extends StatelessWidget {
  final int reportId;
  late final RawMaterialReportDisplayController controller;

  RawMaterialReportDisplayView({super.key, required this.reportId}) {
    controller = Get.put(
      RawMaterialReportDisplayController(reportId: reportId),
      tag: 'raw_material_display_$reportId',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'استعراض تقرير فحص المواد الخام',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          tooltip: 'تحديث',
          onPressed: () => controller.loadReport(),
        ),
        IconButton(
          icon: const Icon(Icons.print_outlined),
          tooltip: 'طباعة PDF',
          onPressed: () => controller.printPdf(),
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: AppLoading(message: 'جاري تحميل التقرير...'));
        }

        final report = controller.report.value;
        if (report == null) {
          return const Center(child: AppEmptyState(title: 'التقرير غير موجود', icon: Icons.description_outlined));
        }

        if (!UserSessionService.to.canViewBranchData(report.branchId)) {
          return _buildAccessDeniedWidget(context, report);
        }

        return ZoomableDocumentView(
          documentWidth: 794,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // شريط حالة الاعتماد والإجرائات — يتحرك مع باقي المحتوى
                  _buildApprovalActionBar(context, report),
                  const SizedBox(height: 16),
                  // Page 1 Sheet
                  _buildPaperSheet(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader('7 - 1'),
                        const SizedBox(height: 8),
                        _buildTitleBox('نموذج فحص المواد الخام'),
                        const SizedBox(height: 12),
                        _buildReceiptDataTable(report),
                        const SizedBox(height: 14),
                        _buildGeneralChecklistTable(),
                        const SizedBox(height: 14),
                        _buildDecisionAndActionsBox(report),
                        const SizedBox(height: 12),
                        _buildNotesBox(report.generalNotes, 'الملاحظات:'),
                        const SizedBox(height: 20),
                        _buildFooter('SELSAL-IMSF-19-03'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Page 2 Sheet (Specialized Annex)
                  _buildPaperSheet(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader('7 - 2'),
                        const SizedBox(height: 8),
                        _buildTitleBox('نموذج فحص المواد الخام'),
                        const SizedBox(height: 12),
                        _buildAnnexHeader(report),
                        const SizedBox(height: 14),
                        _buildAnnexChecklistTable(),
                        const SizedBox(height: 14),
                        _buildNotesBox(report.annexNotes, 'ملاحظات:'),
                        const SizedBox(height: 20),
                        _buildSignaturesTable(report),
                        const SizedBox(height: 20),
                        _buildFooter(report.annexCode),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  // ==================== PAPER SHEET CONTAINER ====================

  Widget _buildPaperSheet(BuildContext context, {required Widget child}) {
    return Container(
      width: 794,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  // ==================== APPROVAL ACTION BAR ====================

  Widget _buildApprovalActionBar(BuildContext context, RawMaterialReport report) {
    final status = report.approvalStatus;

    Color bannerColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    switch (status) {
      case 'Draft':
        bannerColor = Colors.grey.shade700;
        statusTitle = 'مسودة (Draft)';
        statusSubtitle = 'التقرير لم يتم رفعه للاعتماد بعد.';
        statusIcon = Icons.edit_note;
        break;
      case 'Pending_QS':
        bannerColor = const Color(0xFFF57F17); // Amber for Quality Supervisor
        statusTitle = 'بانتظار اعتماد مشرف الجودة (Pending QS)';
        statusSubtitle = 'تم إرسال التقرير وهو بانتظار مراجعة واعتماد مشرف الجودة.';
        statusIcon = Icons.person_search;
        break;
      case 'Pending_QM':
        bannerColor = const Color(0xFFE65100); // Orange
        statusTitle = 'بانتظار اعتماد مدير الجودة (Pending QM)';
        statusSubtitle = 'تم إرسال التقرير وهو بانتظار مراجعة واعتماد مدير الجودة.';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Pending_GM':
        bannerColor = const Color(0xFF6A1B9A); // Purple
        statusTitle = 'بانتظار اعتماد مدير المصنع (Pending GM)';
        statusSubtitle = 'تم اعتماد التقرير من مدير الجودة وبانتظار الاعتماد النهائي لمدير المصنع.';
        statusIcon = Icons.verified_user;
        break;
      case 'Approved':
        bannerColor = const Color(0xFF2E7D32); // Green
        statusTitle = 'مُعتمد نهائياً (Approved)';
        statusSubtitle = 'تم اعتماد التقرير رسمياً من جميع المستويات وهو مقفل وجاهز للطباعة.';
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        bannerColor = const Color(0xFFC62828); // Red
        final rejectorLabel = (report.rejectedBy != null && report.rejectedBy!.isNotEmpty) ? ' من قِبل ${report.rejectedBy}' : '';
        statusTitle = 'تم رفض التقرير$rejectorLabel';
        statusSubtitle = 'سبب الرفض: ${report.rejectionReason ?? "غير محدد"}';
        statusIcon = Icons.cancel;
        break;
      case 'Corrective_In_Progress':
        bannerColor = const Color(0xFF1565C0); // Blue
        statusTitle = 'الإجراء التصحيحي قيد التنفيذ';
        statusSubtitle = (report.correctiveAction ?? '').isNotEmpty
            ? 'الإجراء المطلوب: ${report.correctiveAction} — المسؤول: ${report.correctiveOwner ?? "غير محدد"}'
            : 'المسؤول المختص يعمل على تنفيذ الإجراء التصحيحي.';
        statusIcon = Icons.build_circle;
        break;
      case 'Pending_QM_Decision':
        bannerColor = const Color(0xFFEF6C00); // Orange
        statusTitle = 'بانتظار اعتماد مدير الجودة للإجراء التصحيحي';
        statusSubtitle = 'تم تنفيذ وتوثيق الإجراء التصحيحي وهو بانتظار مراجعة واعتماد مدير الجودة.';
        statusIcon = Icons.fact_check_outlined;
        break;
      case 'Pending_GM_Decision':
        bannerColor = const Color(0xFFAD6800); // Dark Amber
        statusTitle = 'بانتظار اعتماد مدير المصنع للإجراء التصحيحي';
        statusSubtitle = 'تم اعتماد الإجراء التصحيحي من مدير الجودة وهو بانتظار قرار مدير المصنع النهائي.';
        statusIcon = Icons.pending_actions;
        break;
      case 'Rejected_By_GM':
        bannerColor = const Color(0xFF8B0000); // Dark Red
        statusTitle = 'مرفوض نهائياً — انتهاء دورة الاعتماد';
        statusSubtitle = (report.gmDecisionNotes ?? '').isNotEmpty
            ? 'تم رفض الإجراء التصحيحي: ${report.gmDecisionNotes} (انتهت دورة الاعتماد بالرفض النهائي)'
            : 'تم رفض الإجراء التصحيحي من مدير المصنع، وانتهت دورة الاعتماد بالرفض النهائي للتقرير دون إمكانية تصحيح إضافي.';
        statusIcon = Icons.cancel_presentation;
        break;
      case 'Closed':
        bannerColor = const Color(0xFF2E7D32); // Green
        statusTitle = 'معتمد بعد إجراء تصحيحي';
        statusSubtitle = 'تم اعتماد الإجراء التصحيحي من مدير المصنع وإغلاق التقرير نهائياً.';
        statusIcon = Icons.task_alt;
        break;
      default:
        bannerColor = Colors.blueGrey;
        statusTitle = status;
        statusSubtitle = '';
        statusIcon = Icons.info;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerColor.withValues(alpha: 0.22)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          // Banner Top
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: bannerColor.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: bannerColor, shape: BoxShape.circle),
                  child: Icon(statusIcon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
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
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: bannerColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _approvalStageLabel(status),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: bannerColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Visual Signatures Bar
          _buildVisualSignaturesBar(context, report),

          // Actions Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildRoleActions(context, report, status),
          ),
        ],
      ),
    );
  }

  String _approvalStageLabel(String status) {
    switch (status) {
      case 'Pending_QS':
        return 'المرحلة 1 من 3';
      case 'Pending_QM':
        return 'المرحلة 2 من 3';
      case 'Pending_GM':
        return 'المرحلة 3 من 3';
      case 'Approved':
        return 'مكتمل';
      case 'Rejected':
      case 'Corrective_In_Progress':
        return 'يتطلب إجراء';
      case 'Rejected_By_GM':
        return 'مرفوض نهائياً';
      case 'Pending_QM_Decision':
        return 'بانتظار مدير الجودة';
      case 'Pending_GM_Decision':
        return 'بانتظار قرار المدير';
      case 'Closed':
        return 'مغلق';
      case 'Draft':
        return 'غير مرفوع';
      default:
        return 'حالة التقرير';
    }
  }

  Widget _buildRoleActions(BuildContext context, RawMaterialReport report, String status) {
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    final hasBranchAccess = session != null && session.canApproveBranchData(report.branchId);

    if (status == 'Approved' || status == 'Closed') {
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.verified, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(
                status == 'Closed' ? 'تم اعتماد الإجراء التصحيحي وإغلاق التقرير نهائياً.' : 'التقرير معتمد ومقفل رسمياً.',
                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.teal),
              ),
            ],
          ),
          ElevatedButton.icon(
            onPressed: () => controller.printPdf(),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('طباعة التقرير الرسمي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4472C4), foregroundColor: Colors.white),
          ),
        ],
      );
    }

    if (status == 'Pending_QS') {
      if (session != null && session.canApproveQSupervisor && hasBranchAccess) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'اعتماد مشرف الجودة',
                icon: Icons.check_circle_outline,
                color: const Color(0xFFF57F17),
                onPressed: () => _confirmQualitySupervisorApproval(context),
              ),
            ),
            if (session.canRejectReports) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.outlined(
                  label: 'رفض / إعادة للتعديل',
                  icon: Icons.cancel_outlined,
                  foregroundColor: Colors.redAccent,
                  color: Colors.redAccent,
                  onPressed: () => _showRejectDialog(context),
                ),
              ),
            ],
          ],
        );
      } else if (session != null && session.canApproveQSupervisor && !hasBranchAccess) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${report.effectiveBranchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مشرف الجودة. للقيام بالاعتماد، يجب أن يملك حسابك صلاحية اعتماد مشرف الجودة (approve_qsupervisor).',
        );
      }
    }

    if (status == 'Pending_QM') {
      if (session != null && session.canApproveQM && hasBranchAccess) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'اعتماد مدير الجودة',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                onPressed: () => _confirmQualityManagerApproval(context),
              ),
            ),
            if (session.canRejectReports) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.outlined(
                  label: 'رفض / إعادة للتعديل',
                  icon: Icons.cancel_outlined,
                  foregroundColor: Colors.redAccent,
                  color: Colors.redAccent,
                  onPressed: () => _showRejectDialog(context),
                ),
              ),
            ],
          ],
        );
      } else if (session != null && session.canApproveQM && !hasBranchAccess) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${report.effectiveBranchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مدير الجودة. للقيام بالاعتماد، يجب أن يملك حسابك صلاحية اعتماد مدير الجودة (approve_qm).',
        );
      }
    }

    if (status == 'Pending_GM') {
      if (session != null && session.canApproveGM && hasBranchAccess) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'اعتماد مدير المصنع',
                icon: Icons.verified,
                color: const Color(0xFF6A1B9A),
                onPressed: () => _confirmFactoryManagerApproval(context),
              ),
            ),
            if (session.canRejectReports) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.outlined(
                  label: 'رفض التقرير',
                  icon: Icons.cancel_outlined,
                  foregroundColor: Colors.redAccent,
                  color: Colors.redAccent,
                  onPressed: () => _showRejectDialog(context),
                ),
              ),
            ],
          ],
        );
      } else if (session != null && session.canApproveGM && !hasBranchAccess) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${report.effectiveBranchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مدير المصنع. للقيام بالاعتماد، يجب أن يملك حسابك صلاحية الاعتماد النهائي (approve_gm).',
        );
      }
    }

    if (ApprovalStatus.requiresCorrectiveAction(status) || status == 'Closed') {
      return _buildCorrectiveActionCard(context, report);
    }

    return const SizedBox.shrink();
  }

  Widget _buildRolePromptCard({required String prompt}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              prompt,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                color: Colors.amber.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmQualitySupervisorApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'اعتماد مشرف الجودة',
      message: 'هل أنت متأكد من مراجعة واعتماد هذا التقرير؟ سيتم رفعه لمدير الجودة.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFFF57F17),
      onConfirm: () => controller.approveByQualitySupervisor(),
    );
  }

  void _confirmQualityManagerApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'اعتماد مدير الجودة',
      message: 'هل أنت متأكد من مراجعة واعتماد هذا التقرير؟ سيتم رفعه لمدير المصنع للاعتماد النهائي.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF2E7D32),
      onConfirm: () => controller.approveByQualityManager(),
    );
  }

  void _confirmFactoryManagerApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'الاعتماد النهائي',
      message: 'هل أنت متأكد من الاعتماد النهائي لهذا التقرير؟ سيصبح مقفلاً وجاهزاً للطباعة.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF6A1B9A),
      onConfirm: () => controller.approveByFactoryManager(),
    );
  }

  /// بطاقة الإجراء التصحيحي
  Widget _buildCorrectiveActionCard(BuildContext context, RawMaterialReport report) {
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    final status = report.approvalStatus;
    final canQmDecide = ApprovalStatus.qmCanDecide(status) &&
        session != null &&
        session.canApproveQM &&
        session.canApproveBranchData(report.branchId);
    final canGmDecide = ApprovalStatus.gmCanDecide(status) &&
        session != null &&
        session.canApproveGM &&
        session.canApproveBranchData(report.branchId);
    final canDecide = canQmDecide || canGmDecide;
    final canSubmit = (status == 'Rejected' || status == 'Corrective_In_Progress') &&
        session != null &&
        (session.canEditReports || session.canCreateRawMaterialReports || session.canRejectReports || session.isAdmin) &&
        session.canApproveBranchData(report.branchId);

    return Column(
      children: [
        FactoryManagerRejectionCard(
          title: 'تقرير فحص مادة خام #${report.id}',
          subtitle: '${report.materialName} • تشغيلة ${report.batchNumber}',
          status: status,
          rejectionReason: report.rejectionReason,
          rejectedBy: report.rejectedBy,
          rejectionCategory: report.rejectionCategory,
          severity: report.severityLevel,
          affectedProducts: report.affectedProducts,
          immediateAction: report.immediateAction,
          correctiveAction: report.correctiveAction,
          correctiveOwner: report.correctiveOwner,
          correctiveDueDate: report.correctiveDueDate,
          gmDecision: report.gmDecision,
          gmDecisionBy: report.gmDecisionBy,
          gmDecisionNotes: report.gmDecisionNotes,
          onApprove: canDecide ? () => _showGmDecisionDialog() : null,
          onReject: canDecide ? () => _showGmDecisionDialog() : null,
        ),
        if (canSubmit) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSubmitCorrectiveDialog(report),
              icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 18),
              label: const Text(
                'توثيق وإرسال الإجراء التصحيحي لمدير الجودة',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showSubmitCorrectiveDialog(RawMaterialReport report) async {
    final action = await CorrectiveActionSubmitDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص مادة خام #${report.id} (${report.materialName})',
      rejectionReason: report.rejectionReason ?? 'غير محدد',
      rejectedBy: report.rejectedBy,
      initialCorrectiveAction: report.correctiveAction,
      correctiveOwner: report.correctiveOwner,
    );
    if (action != null && action.isNotEmpty) {
      controller.submitCorrectiveAction(action);
    }
  }

  /// شاشة قرار مدير الجودة أو مدير المصنع على الإجراء التصحيحي
  void _showGmDecisionDialog() async {
    final report = controller.report.value;
    if (report == null) return;
    final status = report.approvalStatus;
    final isQmStage = status == 'Pending_QM_Decision';

    final decision = await GmDecisionDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص مادة خام #${report.id} (${report.materialName})',
      correctiveAction: report.correctiveAction ?? 'غير محدد',
      correctiveOwner: report.correctiveOwner ?? 'غير محدد',
      severity: report.severityLevel,
      decisionTitle: isQmStage
          ? 'قرار مدير الجودة على الإجراء التصحيحي'
          : 'القرار النهائي لمدير المصنع على الإجراء التصحيحي',
      isFinalStage: !isQmStage,
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

  Widget _buildVisualSignaturesBar(BuildContext context, RawMaterialReport report) {
    final status = report.approvalStatus;
    final bool isClosed = status == 'Closed';
    final wasQsApproved = ApprovalStatus.wasApprovedByQsPriorToRejection(
      qsApprovedBy: report.labResponsibleName,
      status: status,
    );
    final isQsDone = status == 'Approved' || status == 'Pending_GM' || status == 'Pending_QM' || isClosed || wasQsApproved;
    final isQmDone = status == 'Approved' || status == 'Pending_GM';
    final isGmDone = status == 'Approved' || isClosed;

    final hasCorrectiveAction = (report.correctiveAction ?? '').trim().isNotEmpty ||
        (report.rejectionReason ?? '').trim().isNotEmpty;
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      status: status,
    );
    final isQmCorrective = (isClosed || status == 'Pending_GM_Decision' || status == 'Rejected_By_GM') && (hasCorrectiveAction || wasQmRejected);

    // تحديد الجهة التي رفضت التقرير لعرض توقيعها باللون الأحمر
    final isQsRejected = ApprovalStatus.rejectedByQualitySupervisor(
      rejectedBy: report.rejectedBy,
      qsApprovedBy: report.labResponsibleName,
      status: status,
    );
    final isQmRejected = ApprovalStatus.rejectedByQualityManager(
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      qmApprovedBy: report.qmApprovedBy,
      qsApprovedBy: report.labResponsibleName,
      status: status,
    );
    final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      status: status,
    );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: report.qmApprovedBy,
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      status: status,
    );
    final bool isRejectorGm = (report.gmDecisionBy != null && report.gmDecisionBy == report.rejectedBy) ||
        (report.rejectedBy != null && (report.rejectedBy!.contains('مدير المصنع') || report.rejectedBy!.contains('العمري')));

    final qsDate = isQsRejected
        ? 'مرفوض'
        : (report.labResponsibleAt != null
            ? DynamicReportPdfGenerator.formatArabicDate(report.labResponsibleAt!)
            : (isQsDone ? 'معتمد' : 'لم يعتمد بعد'));
    final qmDate = isClosed
        ? (report.qmApprovedAt != null ? DynamicReportPdfGenerator.formatArabicDate(report.qmApprovedAt!) : 'معتمد سابقاً')
        : (isQmCorrective
            ? 'مرفوض بإجراء تصحيحي'
            : (report.qmApprovedAt != null
                ? DynamicReportPdfGenerator.formatArabicDate(report.qmApprovedAt!)
                : (isQmDone ? 'معتمد' : (isQmRejected || wasQmRejected ? 'مرفوض' : (wasQmApproved ? 'معتمد سابقاً' : 'لم يعتمد بعد')))));
    final gmDate = isClosed
        ? (report.gmDecisionAt != null
            ? DynamicReportPdfGenerator.formatArabicDate(report.gmDecisionAt!)
            : 'معتمد بعد إجراء تصحيحي')
        : (report.gmApprovedAt != null
            ? DynamicReportPdfGenerator.formatArabicDate(report.gmApprovedAt!)
            : (isGmDone ? 'معتمد نهائياً' : (isGmRejected ? 'مرفوض' : 'لم يعتمد بعد')));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.draw_rounded, size: 14, color: Color(0xFF004D40)),
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
          Obx(() => Row(
            children: [
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: 'منفذ الفحص (مفتش الجودة)',
                  signerName: report.inspectorName.isNotEmpty ? report.inspectorName : 'مفتش الجودة',
                  dateStr: report.dateStr,
                  isApproved: true,
                  signatureBytes: controller.inspectorSignatureBytes.value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: 'اعتماد مشرف الجودة',
                  signerName: isQsRejected
                      ? (report.rejectedBy ?? 'مشرف الجودة')
                      : report.labResponsibleName ?? (isQsDone ? 'مشرف الجودة' : 'بانتظار الاعتماد'),
                  dateStr: qsDate,
                  isApproved: isQsDone && !isQsRejected,
                  isRejected: isQsRejected,
                  signatureBytes: isQsRejected
                      ? controller.rejectedSignatureBytes.value
                      : (isQsDone ? controller.qsSignatureBytes.value : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: isClosed
                      ? 'مدير الجودة (معتمد سابقاً)'
                      : (isQmCorrective
                          ? 'مراجعة مدير الجودة (إجراء تصحيحي)'
                          : (wasQmApproved ? 'اعتماد مدير الجودة (سابقاً)' : 'اعتماد مدير الجودة')),
                  signerName: isClosed
                      ? (report.qmApprovedBy ?? 'أ. حمود يسر (مدير الجودة)')
                      : (isQmCorrective
                          ? (report.rejectedBy ?? report.qmApprovedBy ?? 'أ. حمود يسر (مدير الجودة)')
                          : (report.qmApprovedBy ?? (!isRejectorGm ? report.rejectedBy : null) ?? (isQmDone || wasQmApproved ? 'حمود يسر (مدير الجودة)' : 'بانتظار الاعتماد'))),
                  dateStr: qmDate,
                  isApproved: isQmDone && !isQmCorrective && !isClosed,
                  isRejected: (isQmRejected || wasQmRejected || isQmCorrective || (!isRejectorGm && report.rejectedBy != null)) && !isClosed,
                  isVoided: isClosed || wasQmApproved,
                  signatureBytes: isClosed
                      ? controller.qmSignatureBytes.value
                      : ((isQmRejected || wasQmRejected || isQmCorrective || (!isRejectorGm && report.rejectedBy != null))
                          ? (controller.rejectedSignatureBytes.value ?? controller.qmSignatureBytes.value)
                          : ((isQmDone || wasQmApproved) ? controller.qmSignatureBytes.value : null)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: isClosed ? 'اعتماد مدير المصنع (بعد إجراء تصحيحي)' : 'اعتماد مدير المصنع',
                  signerName: isGmRejected && !isClosed
                      ? (report.gmDecisionBy ?? report.rejectedBy ?? 'مدير المصنع')
                      : (report.gmDecisionBy ?? report.gmApprovedBy ?? (isGmDone || isClosed ? 'خالد العمري (مدير المصنع)' : 'بانتظار الاعتماد')),
                  dateStr: gmDate,
                  isApproved: isGmDone || isClosed,
                  isRejected: isGmRejected && !isClosed,
                  signatureBytes: isGmRejected && !isClosed
                      ? controller.rejectedSignatureBytes.value
                      : ((isGmDone || isClosed) ? controller.gmSignatureBytes.value : null),
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }

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
    final Color boxColor = isRejected
        ? const Color(0xFFFFEBEE)
        : (isVoided
            ? const Color(0xFFFFF8E1)
            : (isApproved ? const Color(0xFFF1F8E9) : Colors.white));
    final Color borderColor = isRejected
        ? const Color(0xFFE53935)
        : (isVoided
            ? const Color(0xFFFFB300)
            : (isApproved ? const Color(0xFF81C784) : Colors.grey.shade300));
    final Color titleColor = isRejected
        ? const Color(0xFFC62828)
        : (isVoided
            ? const Color(0xFFB78103)
            : (isApproved ? const Color(0xFF2E7D32) : Colors.blueGrey.shade800));
    final Color nameColor =
        isRejected ? const Color(0xFFC62828) : (isVoided ? const Color(0xFFB78103) : Colors.black87);

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
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
                      const Icon(Icons.cancel_rounded, size: 12, color: Color(0xFFC62828))
                    else if (isVoided)
                      const Icon(Icons.history_edu_rounded, size: 12, color: Color(0xFFB78103))
                    else if (isApproved)
                      const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF2E7D32)),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  signerName,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
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
                    fontSize: 9.5,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (signatureBytes != null && (isApproved || isRejected || isVoided))
              Positioned.fill(
                child: Opacity(
                  opacity: 0.42,
                  child: Center(
                    child: Image.memory(
                      signatureBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(BuildContext context) async {
    final report = controller.report.value;
    final payload = await RejectReportDialog.show(
      context,
      reportTitle: 'تقرير فحص مادة خام #${report?.id ?? "?"}',
      reportSubtitle: report != null
          ? '${report.materialName} • تشغيلة ${report.batchNumber} • المورد: ${report.supplierName}'
          : null,
    );

    if (payload == null) return;
    controller.rejectReport(payload);
  }

  // ==================== DOCUMENT COMPONENTS ====================

  Widget _buildHeader(String pageNumber) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(
            'assets/images/selsal_pdf_header.png',
            width: double.infinity,
            height: 60,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/logo.png', height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.water_drop, color: Colors.teal)),
                    const SizedBox(width: 8),
                    const Text('مصنع سلسال للمياه\nSELSAL WATER FACTORY', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerLeft, // in RTL this places it on the top corner
          child: Text(pageNumber, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11)),
        ),
      ],
    );
  }

  Widget _buildTitleBox(String title) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black, width: 1.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14)),
      ),
    );
  }

  Widget _buildReceiptDataTable(RawMaterialReport report) {
    Widget cell(String label, String value, {bool isLabel = false}) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: isLabel ? const Color(0xFFBDD7EE) : Colors.white,
        alignment: Alignment.centerRight,
        child: Text(
          isLabel ? label : value,
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: isLabel ? FontWeight.bold : FontWeight.normal, fontSize: 11),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('أولاً: بيانات الاستلام:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Table(
          border: TableBorder.all(color: const Color(0xFF8DB4E2), width: 0.8),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(2.0),
            2: FlexColumnWidth(1.2),
            3: FlexColumnWidth(2.0),
          },
          children: [
            TableRow(children: [
              cell('التاريخ', '', isLabel: true),
              cell('', report.dateStr),
              cell('الوقت', '', isLabel: true),
              cell('', report.timeStr),
            ]),
            TableRow(children: [
              cell('اسم المورد', '', isLabel: true),
              cell('', report.supplierName),
              cell('رقم أمر الشراء', '', isLabel: true),
              cell('', report.poNumber),
            ]),
            TableRow(children: [
              cell('اسم المادة', '', isLabel: true),
              cell('', report.materialName),
              cell('رقم إذن الاستلام', '', isLabel: true),
              cell('', report.receiptNumber),
            ]),
            TableRow(children: [
              cell('الكمية المستلمة', '', isLabel: true),
              cell('', report.receivedQuantity),
              cell('الكمية المفحوصة', '', isLabel: true),
              cell('', report.inspectedQuantity),
            ]),
            TableRow(children: [
              cell('الكمية المقبولة', '', isLabel: true),
              cell('', report.acceptedQuantity),
              cell('الكمية المرفوضة', '', isLabel: true),
              cell('', report.rejectedQuantity),
            ]),
            TableRow(children: [
              cell('اسم المفتش', '', isLabel: true),
              cell('', report.inspectorName),
              cell('رقم التشغيلة', '', isLabel: true),
              cell('', report.batchNumber),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _buildGeneralChecklistTable() {
    Widget th(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        color: const Color(0xFFBDD7EE),
        alignment: Alignment.center,
        child: Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
      );
    }

    Widget td(String text, {Alignment alignment = Alignment.centerRight, Color? bg}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
        alignment: alignment,
        color: bg ?? Colors.white,
        child: Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10.5)),
      );
    }

    Widget tdCheck(bool checked) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Icon(
          checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: checked ? const Color(0xFF2E7D32) : Colors.grey.shade400,
        ),
      );
    }

    Widget tdCross(bool checked) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Icon(
          checked ? Icons.cancel_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: checked ? const Color(0xFFC62828) : Colors.grey.shade400,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ثانياً: نتائج الفحص العام:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        Table(
          border: TableBorder.all(color: const Color(0xFF8DB4E2), width: 0.8),
          columnWidths: const {
            0: FlexColumnWidth(3.0),
            1: FlexColumnWidth(2.5),
            2: FlexColumnWidth(1.8),
            3: FlexColumnWidth(1.0),
            4: FlexColumnWidth(1.0),
            5: FlexColumnWidth(2.5),
          },
          children: [
            TableRow(children: [
              th('بند الفحص'),
              th('معيار القبول'),
              th('النتيجة'),
              th('مطابق'),
              th('غير مطابق'),
              th('الملاحظات'),
            ]),
            ...controller.generalResults.map((r) {
              final isCompliant = r.isCompliant == true;
              final isNon = r.isCompliant == false;
              final bg = isNon ? const Color(0xFFFFEEEE) : Colors.white;

              return TableRow(
                decoration: BoxDecoration(color: bg),
                children: [
                  td(r.itemName, bg: bg),
                  td(r.acceptanceCriteria, bg: bg),
                  td(r.resultValue ?? (isCompliant ? 'مطابق' : ''), alignment: Alignment.center, bg: bg),
                  tdCheck(isCompliant),
                  tdCross(isNon),
                  td(r.notes ?? '', bg: bg),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildDecisionAndActionsBox(RawMaterialReport report) {
    Widget checkItem(String label, bool isChecked, {Color? color}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isChecked ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
            size: 17,
            color: isChecked ? (color ?? const Color(0xFF0D47A1)) : Colors.grey.shade400,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: isChecked ? FontWeight.bold : FontWeight.normal, fontSize: 11.5),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF8DB4E2), width: 0.8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decision
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('قرار الجودة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                checkItem('مقبول للاستخدام.', report.qualityDecision == 'Accepted', color: const Color(0xFF2E7D32)),
                const SizedBox(height: 3),
                checkItem('مقبول بشروط.', report.qualityDecision == 'AcceptedWithConditions', color: const Color(0xFFE65100)),
                const SizedBox(height: 3),
                checkItem('حجز (HOLD)', report.qualityDecision == 'Hold', color: const Color(0xFFF57F17)),
                const SizedBox(height: 3),
                checkItem('مرفوض (REJECT)', report.qualityDecision == 'Reject', color: const Color(0xFFC62828)),
              ],
            ),
          ),
          Container(width: 1, height: 95, color: const Color(0xFF8DB4E2)),
          const SizedBox(width: 14),
          // Actions
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الإجراءات المتخذة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                checkItem('وضع بطاقة HOLD.', report.actionHold),
                const SizedBox(height: 3),
                checkItem('وضع بطاقة REJECT.', report.actionReject, color: const Color(0xFFC62828)),
                const SizedBox(height: 3),
                checkItem('إعادة للمورد.', report.actionReturnToSupplier),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      report.actionNcr ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 17,
                      color: report.actionNcr ? const Color(0xFFC62828) : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'تم فتح NCR رقم: ${report.ncrNumber ?? '........'}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnexHeader(RawMaterialReport report) {
    return Column(
      children: [
        Text(report.annexTitle, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text('رقم الملحق: ${report.annexCode}', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildAnnexChecklistTable() {
    Widget th(String text) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        color: const Color(0xFFBDD7EE),
        alignment: Alignment.center,
        child: Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
      );
    }

    Widget td(String text, {Alignment alignment = Alignment.centerRight, Color? bg}) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        alignment: alignment,
        color: bg ?? Colors.white,
        child: Text(text, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
      );
    }

    Widget tdCheck(bool checked) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Icon(
          checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: checked ? const Color(0xFF2E7D32) : Colors.grey.shade400,
        ),
      );
    }

    Widget tdCross(bool checked) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        child: Icon(
          checked ? Icons.cancel_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: checked ? const Color(0xFFC62828) : Colors.grey.shade400,
        ),
      );
    }

    return Table(
      border: TableBorder.all(color: const Color(0xFF8DB4E2), width: 0.8),
      columnWidths: const {
        0: FlexColumnWidth(3.5),
        1: FlexColumnWidth(3.0),
        2: FlexColumnWidth(1.2),
        3: FlexColumnWidth(1.2),
        4: FlexColumnWidth(3.0),
      },
      children: [
        TableRow(children: [
          th('بند الفحص'),
          th('معيار القبول'),
          th('مطابق'),
          th('غير مطابق'),
          th('الملاحظات'),
        ]),
        ...controller.annexResults.map((r) {
          final isCompliant = r.isCompliant == true;
          final isNon = r.isCompliant == false;
          final bg = isNon ? const Color(0xFFFFEEEE) : Colors.white;

          return TableRow(
            decoration: BoxDecoration(color: bg),
            children: [
              td(r.itemName, bg: bg),
              td(r.acceptanceCriteria, bg: bg),
              tdCheck(isCompliant),
              tdCross(isNon),
              td(r.notes ?? '', bg: bg),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildNotesBox(String? notes, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF8DB4E2), width: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            notes != null && notes.isNotEmpty ? notes : 'لا توجد ملاحظات إضافية.',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildSignaturesTable(RawMaterialReport report) {
    final inspector = report.inspectorName;

    Widget sigCol(String title, String name, String date,
        {Uint8List? signatureBytes, bool isApproved = true, bool isRejected = false, bool isVoided = false}) {
      final Color headerColor = isRejected
          ? const Color(0xFFFFCDD2)
          : (isVoided
              ? const Color(0xFFFFF9C4)
              : (isApproved ? const Color(0xFFC8E6C9) : const Color(0xFFBDD7EE)));
      final Color borderColor = isRejected
          ? const Color(0xFFC62828)
          : (isVoided
              ? Colors.orange.shade800
              : (isApproved ? Colors.green.shade700 : const Color(0xFF8DB4E2)));
      final Color textColor = isRejected
          ? const Color(0xFFC62828)
          : (isVoided
              ? Colors.orange.shade900
              : (isApproved ? Colors.green.shade800 : Colors.black87));

      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor,
              width: (isRejected || isVoided) ? 1.4 : 0.8,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: headerColor,
                    alignment: Alignment.center,
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 10.5,
                        color: textColor,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الاسم: $name',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.5,
                            color: textColor,
                            fontWeight: (isRejected || isApproved || isVoided) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          isRejected
                              ? 'التوقيع: [مرفوض]'
                              : (isVoided
                                  ? 'التوقيع: [طلب إجراء تصحيحي]'
                                  : 'التوقيع: ${name.isNotEmpty ? "معتمد إلكترونياً" : "................"}'),
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.5,
                            fontWeight: (isRejected || isApproved || isVoided) ? FontWeight.bold : FontWeight.normal,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'التاريخ: ${date.isNotEmpty ? date : "2026/  /  م"}',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.5,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (signatureBytes != null && (isApproved || isRejected || isVoided) && name.isNotEmpty)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.42,
                    child: Center(
                      child: Image.memory(
                        signatureBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Obx(() {
      final status = report.approvalStatus;
      final bool isClosed = status == 'Closed';
      final wasQsApproved = ApprovalStatus.wasApprovedByQsPriorToRejection(
        qsApprovedBy: report.labResponsibleName,
        status: status,
      );
      final isQsDone = status == 'Approved' ||
          status == 'Pending_GM' ||
          status == 'Pending_QM' ||
          isClosed ||
          wasQsApproved;
      final isQmDone = status == 'Approved' || status == 'Pending_GM';
      final isGmDone = status == 'Approved' || isClosed;

      final hasCorrectiveAction = (report.correctiveAction ?? '').trim().isNotEmpty ||
          (report.rejectionReason ?? '').trim().isNotEmpty;
      final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
        rejectedBy: report.rejectedBy,
        gmDecisionBy: report.gmDecisionBy,
        status: status,
      );
      final isQmCorrective = (isClosed || status == 'Pending_GM_Decision' || status == 'Rejected_By_GM') && (hasCorrectiveAction || wasQmRejected);
      final bool isRejectorGm = (report.gmDecisionBy != null && report.gmDecisionBy == report.rejectedBy) ||
          (report.rejectedBy != null && (report.rejectedBy!.contains('مدير المصنع') || report.rejectedBy!.contains('العمري')));

      final isQsRejected = ApprovalStatus.rejectedByQualitySupervisor(
        rejectedBy: report.rejectedBy,
        qsApprovedBy: report.labResponsibleName,
        status: status,
      );
      final isQmRejected = ApprovalStatus.rejectedByQualityManager(
        rejectedBy: report.rejectedBy,
        gmDecisionBy: report.gmDecisionBy,
        qmApprovedBy: report.qmApprovedBy,
        qsApprovedBy: report.labResponsibleName,
        status: status,
      );
      final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
        rejectedBy: report.rejectedBy,
        gmDecisionBy: report.gmDecisionBy,
        status: status,
      );
      final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
        qmApprovedBy: report.qmApprovedBy,
        rejectedBy: report.rejectedBy,
        gmDecisionBy: report.gmDecisionBy,
        status: status,
      );

      final qsName = isQsRejected
          ? (report.rejectedBy ?? 'مشرف الجودة')
          : report.labResponsibleName ?? (isQsDone ? 'مشرف الجودة' : '');
      final qsDateStr = isQsRejected
          ? 'مرفوض'
          : (report.labResponsibleAt != null
              ? DynamicReportPdfGenerator.formatArabicDate(report.labResponsibleAt!)
              : (isQsDone ? DynamicReportPdfGenerator.formatArabicDate(DateTime.now()) : ''));

      final qmTitle = isClosed
          ? 'مدير الجودة (معتمد سابقاً)'
          : (isQmCorrective ? 'مراجعة مدير الجودة (إجراء تصحيحي)' : (wasQmApproved ? 'اعتماد مدير الجودة (سابقاً)' : 'اعتماد مدير الجودة'));
      final qmName = isClosed
          ? (report.qmApprovedBy ?? 'أ. حمود يسر (مدير الجودة)')
          : (isQmCorrective
              ? (report.rejectedBy ?? report.qmApprovedBy ?? 'أ. حمود يسر (مدير الجودة)')
              : (isQmRejected || wasQmRejected
                  ? (report.rejectedBy ?? 'مدير الجودة')
                  : (report.qmApprovedBy ?? (!isRejectorGm ? report.rejectedBy : null) ?? (isQmDone || wasQmApproved ? 'حمود يسر (مدير الجودة)' : ''))));
      final qmDateStr = isClosed
          ? (report.qmApprovedAt != null ? DynamicReportPdfGenerator.formatArabicDate(report.qmApprovedAt!) : 'معتمد سابقاً')
          : (isQmCorrective
              ? 'طلب إجراء تصحيحي'
              : (report.qmApprovedAt != null
                  ? DynamicReportPdfGenerator.formatArabicDate(report.qmApprovedAt!)
                  : (isQmDone || wasQmApproved || isQmRejected || wasQmRejected
                      ? DynamicReportPdfGenerator.formatArabicDate(DateTime.now())
                      : '')));

      final gmTitle = isClosed ? 'اعتماد مدير المصنع (بعد إجراء تصحيحي)' : 'اعتماد مدير المصنع';
      final gmName = isGmRejected && !isClosed
          ? (report.gmDecisionBy ?? report.rejectedBy ?? 'مدير المصنع')
          : (report.gmDecisionBy ?? report.gmApprovedBy ?? (isGmDone ? 'خالد العمري (مدير المصنع)' : ''));
      final gmDateStr = isClosed
          ? (report.gmDecisionAt != null
              ? DynamicReportPdfGenerator.formatArabicDate(report.gmDecisionAt!)
              : 'معتمد بعد إجراء تصحيحي')
          : (report.gmApprovedAt != null
              ? DynamicReportPdfGenerator.formatArabicDate(report.gmApprovedAt!)
              : (isGmDone || isGmRejected
                  ? DynamicReportPdfGenerator.formatArabicDate(DateTime.now())
                  : ''));

      return Row(
        children: [
          sigCol(
            'مفتش الجودة',
            inspector,
            report.dateStr,
            signatureBytes: controller.inspectorSignatureBytes.value,
            isApproved: true,
          ),
          const SizedBox(width: 6),
          sigCol(
            'مشرف الجودة',
            qsName,
            qsDateStr,
            signatureBytes: isQsRejected
                ? controller.rejectedSignatureBytes.value
                : (isQsDone ? controller.qsSignatureBytes.value : null),
            isApproved: isQsDone && !isQsRejected,
            isRejected: isQsRejected,
          ),
          const SizedBox(width: 6),
          sigCol(
            qmTitle,
            qmName,
            qmDateStr,
            signatureBytes: isClosed
                ? controller.qmSignatureBytes.value
                : (isQmCorrective
                    ? (controller.rejectedSignatureBytes.value ?? controller.qmSignatureBytes.value)
                    : (isQmRejected || wasQmRejected || (!isRejectorGm && report.rejectedBy != null))
                        ? controller.rejectedSignatureBytes.value
                        : ((isQmDone || wasQmApproved) ? controller.qmSignatureBytes.value : null)),
            isApproved: isQmDone && !isQmCorrective && !isClosed,
            isRejected: (isQmRejected || wasQmRejected || isQmCorrective || (!isRejectorGm && report.rejectedBy != null)) && !isClosed,
            isVoided: isClosed || wasQmApproved,
          ),
          const SizedBox(width: 6),
          sigCol(
            gmTitle,
            gmName,
            gmDateStr,
            signatureBytes: isGmRejected && !isClosed
                ? controller.rejectedSignatureBytes.value
                : ((isGmDone || isClosed) ? controller.gmSignatureBytes.value : null),
            isApproved: isGmDone || isClosed,
            isRejected: isGmRejected && !isClosed,
          ),
        ],
      );
    });
  }

  Widget _buildFooter(String docNum) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [
          Text('رقم الوثيقة: $docNum', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
          const Text('تاريخ الاصدار: 2026/07/15', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11)),
          const Text('إصدار رقم: 01', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedWidget(BuildContext context, RawMaterialReport report) {
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
              child: Icon(Icons.lock_person_rounded, size: 56, color: Colors.red.shade700),
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
              'هذا التقرير يتبع لـ (${report.effectiveBranchName}).\nحسابك الحالي مقيد بصلاحيات (${session.assignedBranchName}).\nلا يمكنك استعراض أو تعديل أو اعتماد تقارير مصانع أخرى.',
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
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF004D40),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
