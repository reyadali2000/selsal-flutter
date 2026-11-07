import '../widgets/corrective_action_submit_dialog.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../constants/approval_status.dart';
import '../controllers/final_product_report_display_controller.dart';
import '../models/water_quality_models.dart';
import '../services/pdf/arabic_pdf_service.dart';
import '../services/user_session_service.dart';
import '../utils/dynamic_report_pdf_generator.dart';
import '../widgets/factory_manager_rejection_card.dart';
import '../widgets/gm_decision_dialog.dart';
import '../widgets/micro_results_entry_dialog.dart';
import '../widgets/micro_approval_cycle_card.dart';
import '../widgets/notification_bell.dart';
import '../widgets/reject_report_dialog.dart';
import '../widgets/micro_reject_dialog.dart';
import '../widgets/zoomable_document_view.dart';
import '../widgets/ds/ds.dart';

class FinalProductReportDisplayView extends StatelessWidget {
  FinalProductReportDisplayView({super.key});

  final FinalProductReportDisplayController controller =
      Get.put(FinalProductReportDisplayController());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تقرير فحص المنتج النهائي',
      actions: [
        const NotificationBell(),
        if (UserSessionService.to.canExportPdf)
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'طباعة / تصدير PDF',
            onPressed: controller.printReport,
          ),
      ],
      body: Obx(() {
        if (controller.isLoading.value && controller.currentLog.value == null) {
          return const Center(child: AppLoading(message: 'جاري تحميل التقرير...'));
        }

        final log = controller.currentLog.value ?? controller.log;

        if (!UserSessionService.to.canViewBranchData(log.branchId)) {
          return _buildAccessDeniedWidget(context, log);
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
                  // 1. Interactive Approval Status Banner & Action Buttons (يسكرول مع التقرير)
                  _buildApprovalActionBar(context, log),
                  const SizedBox(height: 16),

                  // 2. The Report Form Container
                  Container(
                    width: 794,
                    color: Colors.white,
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildDocumentHeader(log),
                        const SizedBox(height: 20),
                        _buildBatchInfoTable(log),
                        const SizedBox(height: 20),
                        _buildSectionTitle('ثانياً: الفحص الظاهري والتغليف:'),
                        const SizedBox(height: 8),
                        _buildResultsTable(controller.sensoryResults),
                        const SizedBox(height: 20),
                        _buildSectionTitle('ثالثاً: الفحوصات الفيزيائية والكيميائية:'),
                        const SizedBox(height: 8),
                        _buildResultsTable(controller.physioChemicalResults),
                        const SizedBox(height: 20),
                        _buildSectionTitle('رابعاً: الفحوصات الميكروبيولوجية:'),
                        const SizedBox(height: 8),
                        Obx(() {
                          final microResults = controller.microbiologicalResults;
                          final microEmpty = microResults.isEmpty ||
                              microResults.every((r) =>
                                  (r.textResult ?? '').trim().isEmpty &&
                                  r.numericResult == null);
                          final awaiting = ApprovalStatus.isMicroStage(log.approvalStatus) &&
                              log.approvalStatus == 'Awaiting_Micro_Results';
                          if (microEmpty) {
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE0F7FA),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.teal.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.science_outlined, color: Colors.teal.shade800, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      awaiting
                                          ? 'بانتظار إدخال النتائج — تصل خلال 24 ساعة من أخذ العينة وستتطلب جولة اعتماد ثانية.'
                                          : 'لم تُسجَّل نتائج للفحوصات الميكروبيولوجية بعد.',
                                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: Color(0xFF006064)),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return _buildResultsTable(controller.microbiologicalResults);
                        }),
                        // دورة اعتماد الميكروبيولوجي المستقلة تحت قسمها
                        if (MicroApprovalCycleCard.shouldShow(log))
                          MicroApprovalCycleCard(
                            log: log,
                            onEnterResults: _showMicroResultsEntryDialog,
                            onApproveQM: () => _confirmMicroQualityManagerApproval(context),
                            onApproveGM: () => _confirmMicroFactoryManagerApproval(context),
                            onReject: () => _showMicroRejectDialog(context),
                            canEnter: UserSessionService.to.canEditReports ||
                                UserSessionService.to.canCreateWaterReports ||
                                UserSessionService.to.isAdmin,
                            canApproveQM: UserSessionService.to.canApproveQM &&
                                UserSessionService.to.canApproveBranchData(log.branchId),
                            canApproveGM: UserSessionService.to.canApproveGM &&
                                UserSessionService.to.canApproveBranchData(log.branchId),
                            canReject: UserSessionService.to.canRejectReports,
                          ),
                        const SizedBox(height: 20),
                        _buildComplianceSection(log),
                        const SizedBox(height: 16),
                        _buildNotesSection(log),
                        const SizedBox(height: 24),
                        _buildSignaturesTable(log),
                        const SizedBox(height: 12),
                        _buildStandardNotice(),
                        const SizedBox(height: 16),
                        _buildDocumentFooter(),
                        const SizedBox(height: 30),
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

  Widget _buildApprovalActionBar(BuildContext context, WaterQualityLog log) {
    final status = log.approvalStatus;
    final session = UserSessionService.to;
    final currentRole = session.currentRole.value;

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
      case 'Pending_QM':
        bannerColor = const Color(0xFFE65100); // Orange
        statusTitle = 'بانتظار اعتماد مدير الجودة (Pending QM)';
        statusSubtitle = 'تم إرسال التقرير وهو بانتظار مراجعة واعتماد مدير الجودة (حمود يسر).';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Pending_GM':
        bannerColor = const Color(0xFF6A1B9A); // Purple
        statusTitle = 'بانتظار اعتماد مدير المصنع (Pending GM)';
        statusSubtitle = 'تم اعتماد التقرير من مدير الجودة وبانتظار الاعتماد النهائي لمدير المصنع (خالد العمري).';
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
        final rejectorLabel = (log.rejectedBy != null && log.rejectedBy!.isNotEmpty) ? ' من قِبل ${log.rejectedBy}' : '';
        statusTitle = 'تم رفض التقرير$rejectorLabel';
        statusSubtitle = 'سبب الرفض: ${log.rejectionReason ?? "غير محدد"}';
        statusIcon = Icons.cancel;
        break;
      case 'Corrective_In_Progress':
        bannerColor = const Color(0xFF1565C0); // Blue
        statusTitle = 'الإجراء التصحيحي قيد التنفيذ';
        statusSubtitle = (log.correctiveAction ?? '').isNotEmpty
            ? 'الإجراء المطلوب: ${log.correctiveAction} — المسؤول: ${log.correctiveOwner ?? "غير محدد"}'
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
        statusSubtitle = (log.gmDecisionNotes ?? '').isNotEmpty
            ? 'تم رفض الإجراء التصحيحي: ${log.gmDecisionNotes} (انتهت دورة الاعتماد بالرفض النهائي)'
            : 'تم رفض الإجراء التصحيحي من مدير المصنع، وانتهت دورة الاعتماد بالرفض النهائي للتقرير دون إمكانية تصحيح إضافي.';
        statusIcon = Icons.cancel_presentation;
        break;
      case 'Closed':
        bannerColor = const Color(0xFF2E7D32); // Green
        statusTitle = 'معتمد بعد إجراء تصحيحي';
        statusSubtitle = 'تم اعتماد الإجراء التصحيحي من مدير المصنع وإغلاق التقرير نهائياً.';
        statusIcon = Icons.task_alt;
        break;
      case 'Awaiting_Micro_Results':
        bannerColor = const Color(0xFF00838F); // Teal
        statusTitle = 'معتمد مبدئياً — بانتظار نتائج الفحص الميكروبيولوجي';
        statusSubtitle = 'اعتُمد التقرير من مدير الجودة ومدير المصنع. بانتظار إدخال نتائج الفحص الميكروبيولوجي ثم جولة اعتماد ثانية.';
        statusIcon = Icons.science_outlined;
        break;
      case 'Pending_Micro_QM':
        bannerColor = const Color(0xFFE65100); // Orange
        statusTitle = 'بانتظار اعتماد مدير الجودة لنتائج الفحص الميكروبيولوجي';
        statusSubtitle = 'أُدخلت نتائج الفحص الميكروبيولوجي وهي بانتظار مراجعة واعتماد مدير الجودة.';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Pending_Micro_GM':
        bannerColor = const Color(0xFF6A1B9A); // Purple
        statusTitle = 'بانتظار اعتماد مدير المصنع لنتائج الفحص الميكروبيولوجي';
        statusSubtitle = 'اعتمد مدير الجودة نتائج الفحص الميكروبيولوجي وبانتظار الاعتماد النهائي لمدير المصنع.';
        statusIcon = Icons.verified_user;
        break;
      case 'Micro_Rejected':
        bannerColor = const Color(0xFFC62828); // Red
        statusTitle = 'نتائج الفحص الميكروبيولوجي مرفوضة (الفحص الفيزيوكيميائي معتمد)';
        statusSubtitle = 'سبب الرفض: ${log.microRejectionReason ?? log.rejectionReason ?? "غير محدد"}';
        statusIcon = Icons.cancel;
        break;
      case 'Micro_Resample_Pending':
        bannerColor = const Color(0xFFD84315); // Deep Orange
        statusTitle = 'مطلوب إعادة سحب عينة ميكروبيولوجية جديدة (الفحص الأولي معتمد)';
        statusSubtitle = 'سبب إعادة السحب: ${log.microRejectionReason ?? log.rejectionReason ?? "غير محدد"} — بانتظار إدخال نتائج العينة الجديدة.';
        statusIcon = Icons.refresh;
        break;
      case 'Micro_Corrective_In_Progress':
        bannerColor = const Color(0xFF1565C0); // Blue
        statusTitle = 'إجراء تصحيحي ميكروبيولوجي قيد التنفيذ (الفحص الأولي معتمد)';
        statusSubtitle = (log.correctiveAction ?? '').isNotEmpty
            ? 'الإجراء المطلوب: ${log.correctiveAction} — المسؤول: ${log.correctiveOwner ?? "غير محدد"}'
            : 'جاري تنفيذ الإجراء التصحيحي الخاص بعدم المطابقة الميكروبيولوجية.';
        statusIcon = Icons.build_circle;
        break;
      default:
        bannerColor = Colors.blueGrey;
        statusTitle = status;
        statusSubtitle = '';
        statusIcon = Icons.info;
    }

    return Container(
      width: 794,
      decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
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
              ],
            ),
          ),

          // Visual Signatures Bar
          _buildVisualSignaturesBar(context, log),

          // Actions Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildRoleActions(context, log, currentRole, status),
          ),
        ],
      ),
    );
  }
  Widget _buildRoleActions(BuildContext context, WaterQualityLog log, UserRole currentRole, String status) {
    final session = UserSessionService.to;
    if (status == 'Approved' || status == 'Closed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
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
                    status == 'Closed' ? 'معتمد بعد إجراء تصحيحي ومقفل رسمياً.' : 'التقرير معتمد ومقفل رسمياً.',
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.teal),
                  ),
                ],
              ),
              if (UserSessionService.to.canExportPdf)
                ElevatedButton.icon(
                  onPressed: controller.printReport,
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text('طباعة التقرير الرسمي', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4472C4), foregroundColor: Colors.white),
                ),
            ],
          ),
          if (status == 'Closed') ...[
            const SizedBox(height: 12),
            _buildCorrectiveActionSection(log, status),
          ],
        ],
      );
    }

    if (status == 'Pending_QM') {
      if (session.canApproveQM && session.canApproveBranchData(log.branchId)) {
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
      } else if (session.canApproveQM && !session.canApproveBranchData(log.branchId)) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${log.branchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
          targetRole: UserRole.qualityManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مدير الجودة. للقيام بالاعتماد، يجب أن يملك حسابك صلاحية اعتماد مدير الجودة (approve_qm).',
          targetRole: UserRole.qualityManager,
        );
      }
    }

    if (status == 'Pending_GM') {
      if (session.canApproveGM && session.canApproveBranchData(log.branchId)) {
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
      } else if (session.canApproveGM && !session.canApproveBranchData(log.branchId)) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${log.branchName})، بينما حسابك مسند إلى (${session.assignedBranchName}). لا تملك صلاحية اعتماد تقارير مصنع آخر.',
          targetRole: UserRole.factoryManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مدير المصنع. للقيام بالاعتماد، يجب أن يملك حسابك صلاحية الاعتماد النهائي (approve_gm).',
          targetRole: UserRole.factoryManager,
        );
      }
    }

    if (status == 'Awaiting_Micro_Results' || status == 'Micro_Resample_Pending') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.gmDecision == 'Approved' || log.rejectionReason != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _buildCorrectiveActionSection(log, status),
            ),
          _buildAwaitingMicroResultsBannerAndButton(log),
        ],
      );
    }

    if (status == 'Pending_Micro_QM') {
      if (session.canApproveQM && session.canApproveBranchData(log.branchId)) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'اعتماد نتائج الميكروبيولوجي — مدير الجودة',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                onPressed: () => _confirmMicroQualityManagerApproval(context),
              ),
            ),
            if (session.canRejectReports) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.outlined(
                  label: 'رفض النتائج',
                  icon: Icons.cancel_outlined,
                  foregroundColor: Colors.redAccent,
                  color: Colors.redAccent,
                  onPressed: () => _showMicroRejectDialog(context),
                ),
              ),
            ],
          ],
        );
      } else if (session.canApproveQM && !session.canApproveBranchData(log.branchId)) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${log.branchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
          targetRole: UserRole.qualityManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'نتائج الفحص الميكروبيولوجي بانتظار اعتماد مدير الجودة. حسابك الحالي لا يمتلك صلاحية اعتماد مدير الجودة لهذا التقرير.',
          targetRole: UserRole.qualityManager,
        );
      }
    }

    if (status == 'Pending_Micro_GM') {
      if (session.canApproveGM && session.canApproveBranchData(log.branchId)) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'الاعتماد النهائي للنتائج — مدير المصنع',
                icon: Icons.verified,
                color: const Color(0xFF6A1B9A),
                onPressed: () => _confirmMicroFactoryManagerApproval(context),
              ),
            ),
            if (session.canRejectReports) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.outlined(
                  label: 'رفض النتائج',
                  icon: Icons.cancel_outlined,
                  foregroundColor: Colors.redAccent,
                  color: Colors.redAccent,
                  onPressed: () => _showMicroRejectDialog(context),
                ),
              ),
            ],
          ],
        );
      } else if (session.canApproveGM && !session.canApproveBranchData(log.branchId)) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${log.branchName})، بينما حسابك مسند إلى (${session.assignedBranchName}). لا تملك صلاحية اعتماد تقارير مصنع آخر.',
          targetRole: UserRole.factoryManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'نتائج الفحص الميكروبيولوجي بانتظار الاعتماد النهائي لمدير المصنع. حسابك الحالي لا يمتلك صلاحية اعتماد مدير المصنع.',
          targetRole: UserRole.factoryManager,
        );
      }
    }

    if (status == 'Rejected' ||
        status == 'Corrective_In_Progress' ||
        status == 'Micro_Rejected' ||
        status == 'Micro_Corrective_In_Progress' ||
        status == 'Pending_QM_Decision' ||
        status == 'Pending_GM_Decision' ||
        status == 'Rejected_By_GM' ||
        status == 'Closed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCorrectiveActionSection(log, status),
          if ((status == 'Closed' && log.microResultsPending) ||
              status == 'Micro_Rejected' ||
              status == 'Micro_Corrective_In_Progress') ...[
            const SizedBox(height: 12),
            _buildAwaitingMicroResultsBannerAndButton(log),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }



  /// قسم الإجراء التصحيحي — يعرض بطاقة مدير المصنع الكاملة وأزرار الإجراءات
    Widget _buildAwaitingMicroResultsBannerAndButton(WaterQualityLog log) {
    final session = UserSessionService.to;
    final canEnter = session.canEditReports ||
        session.canCreateWaterReports ||
        session.isAdmin;
    if (canEnter && session.canApproveBranchData(log.branchId)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.teal.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.teal.shade800, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'هذا التقرير معتمد مبدئياً. ما إن تصل نتائج الفحص الميكروبيولوجي (خلال 24 ساعة)، '
                    'أدخلها لتُرسل لجولة الاعتماد الثانية.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: Color(0xFF006064), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: AppButton.primary(
              label: 'إدخال نتائج الفحص الميكروبيولوجي',
              icon: Icons.science_outlined,
              color: const Color(0xFF00838F),
              onPressed: () => _showMicroResultsEntryDialog(),
            ),
          ),
        ],
      );
    } else {
      return _buildRolePromptCard(
        prompt: session.canApproveBranchData(log.branchId)
            ? 'التقرير معتمد مبدئياً وبانتظار إدخال نتائج الفحص الميكروبيولوجي من أخصائي الجودة.'
            : 'هذا التقرير يتبع لـ (${log.branchName})، بينما حسابك مسند إلى فرع آخر.',
        targetRole: UserRole.qualitySpecialist,
      );
    }
  }

  Widget _buildCorrectiveActionSection(WaterQualityLog log, String status) {
    final session = UserSessionService.to;
    final canQmDecide = ApprovalStatus.qmCanDecide(status) &&
        session.canApproveQM &&
        session.canApproveBranchData(log.branchId);
    final canGmDecide = ApprovalStatus.gmCanDecide(status) &&
        session.canApproveGM &&
        session.canApproveBranchData(log.branchId);
    final canDecide = canQmDecide || canGmDecide;
    final canSubmit = (status == 'Rejected' ||
            status == 'Corrective_In_Progress' ||
            status == 'Micro_Rejected' ||
            status == 'Micro_Corrective_In_Progress') &&
        (session.canEditReports || session.canCreateWaterReports || session.canRejectReports || session.isAdmin) &&
        session.canApproveBranchData(log.branchId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactoryManagerRejectionCard(
          title: 'تقرير فحص منتج نهائي #${log.id}',
          subtitle: log.batchNumber != null && log.batchNumber!.isNotEmpty
              ? 'رقم التشغيلة: ${log.batchNumber} • ${log.branchName}'
              : log.branchName,
          status: status,
          rejectionReason: log.rejectionReason ?? log.microRejectionReason,
          rejectedBy: log.rejectedBy ?? log.microRejectedBy,
          rejectionCategory: log.rejectionCategory,
          severity: log.severityLevel,
          affectedProducts: log.affectedProducts,
          immediateAction: log.immediateAction,
          correctiveAction: log.correctiveAction,
          correctiveOwner: log.correctiveOwner,
          correctiveDueDate: log.correctiveDueDate,
          gmDecision: log.gmDecision,
          gmDecisionBy: log.gmDecisionBy,
          gmDecisionNotes: log.gmDecisionNotes,
          rejectionCount: log.rejectionCount,
          onApprove: canDecide ? () => _showGmDecisionDialog() : null,
          onReject: canDecide ? () => _showGmDecisionDialog() : null,
        ),
        if (canSubmit) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSubmitCorrectiveDialog(),
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

  void _showSubmitCorrectiveDialog() async {
    final log = controller.currentLog.value ?? controller.log;
    final action = await CorrectiveActionSubmitDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص منتج نهائي #${log.id}${log.batchNumber != null ? " (${log.batchNumber})" : ""}',
      rejectionReason: log.rejectionReason ?? log.microRejectionReason ?? 'غير محدد',
      rejectedBy: log.rejectedBy ?? log.microRejectedBy,
      initialCorrectiveAction: log.correctiveAction,
      correctiveOwner: log.correctiveOwner,
    );
    if (action != null && action.isNotEmpty) {
      controller.submitCorrectiveAction(action);
    }
  }

  /// شاشة قرار مدير الجودة أو مدير المصنع على الإجراء التصحيحي
  void _showGmDecisionDialog() async {
    final log = controller.currentLog.value ?? controller.log;
    final status = log.approvalStatus;
    final isQmStage = status == 'Pending_QM_Decision';

    final decision = await GmDecisionDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص منتج نهائي #${log.id}${log.batchNumber != null ? " (${log.batchNumber})" : ""}',
      correctiveAction: log.correctiveAction ?? 'غير محدد',
      correctiveOwner: log.correctiveOwner ?? 'غير محدد',
      severity: log.severityLevel,
      decisionTitle: isQmStage
          ? 'قرار مدير الجودة على الإجراء التصحيحي'
          : 'القرار النهائي لمدير المصنع على الإجراء التصحيحي',
      isFinalStage: !isQmStage,
      rejectionCount: log.rejectionCount,
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

  Widget _buildRolePromptCard({required String prompt, UserRole? targetRole}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prompt,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmQualityManagerApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'اعتماد مدير الجودة',
      message: 'هل أنت متأكد من مراجعة واعتماد هذا التقرير؟ سيتم رفعه لمدير المصنع.',
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

  void _showMicroResultsEntryDialog() async {
    final log = controller.currentLog.value ?? controller.log;
    final results = await MicroResultsEntryDialog.show(
      Get.context!,
      standards: controller.microbiologicalStandards,
      parameters: controller.parameters,
      existingResults: controller.microbiologicalResults,
      reportTitle: 'تقرير فحص منتج نهائي #${log.id}${log.batchNumber != null ? " (${log.batchNumber})" : ""}',
    );

    if (results != null) {
      await controller.submitMicrobiologicalResults(results);
    }
  }

  void _confirmMicroQualityManagerApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'اعتماد نتائج الفحص الميكروبيولوجي',
      message: 'هل أنت متأكد من مراجعة واعتماد نتائج الفحص الميكروبيولوجي؟ سيتم رفعها لمدير المصنع للاعتماد النهائي.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF2E7D32),
      onConfirm: () => controller.approveMicroByQualityManager(),
    );
  }

  void _confirmMicroFactoryManagerApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'الاعتماد النهائي لنتائج الفحص الميكروبيولوجي',
      message: 'هل أنت متأكد من الاعتماد النهائي لنتائج الفحص الميكروبيولوجي؟ سيكتمل اعتماد التقرير ويصبح مقفلاً وجاهزاً للطباعة.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF6A1B9A),
      onConfirm: () => controller.approveMicroByFactoryManager(),
    );
  }

  void _showMicroRejectDialog(BuildContext context) async {
    final log = controller.currentLog.value ?? controller.log;
    final result = await MicroRejectDialog.show(
      context,
      reportTitle: 'تقرير فحص منتج نهائي #${log.id}',
      reportSubtitle: log.batchNumber != null && log.batchNumber!.isNotEmpty
          ? 'رقم التشغيلة: ${log.batchNumber} • المنتج: ${log.productName ?? ""}'
          : 'المنتج: ${log.productName ?? ""}',
    );

    if (result == null) return;
    controller.rejectMicroReport(
      reason: result.reason,
      actionType: result.actionType,
      correctiveAction: result.correctiveAction,
      correctiveOwner: result.correctiveOwner,
      dueDate: result.dueDate,
      notes: result.notes,
    );
  }

  void _showRejectDialog(BuildContext context) async {
    final log = controller.currentLog.value ?? controller.log;
    final payload = await RejectReportDialog.show(
      context,
      reportTitle: 'تقرير فحص منتج نهائي #${log.id}',
      reportSubtitle: log.batchNumber != null && log.batchNumber!.isNotEmpty
          ? 'رقم التشغيلة: ${log.batchNumber} • المنتج: ${log.productName ?? ""}'
          : 'المنتج: ${log.productName ?? ""}',
      rejectionCount: log.rejectionCount,
    );

    if (payload == null) return;
    controller.rejectReport(payload);
  }

  Widget _buildDocumentHeader(WaterQualityLog log) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 475 / 66,
          child: Image.asset(
            'assets/images/selsal_pdf_header.png',
            width: double.infinity,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 44,
                      errorBuilder: (_, __, ___) => const Icon(Icons.water_drop, size: 36, color: Color(0xFF004D40)),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مصنع سلسال للمياه',
                          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF004D40)),
                        ),
                        Text(
                          'SELSAL WATER FACTORY',
                          style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF173A5E), width: 1.2),
              borderRadius: BorderRadius.circular(6),
              color: const Color(0xFFD6E6F5),
            ),
            child: const Text(
              'تقرير فحص المنتج النهائي',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF173A5E),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontFamily: 'Tajawal',
        fontWeight: FontWeight.bold,
        fontSize: 14,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildBatchInfoTable(WaterQualityLog log) {
    final location = log.samplingLocation ?? 'أثناء التشغيل';
    final dateStr = DateFormat('yyyy/MM/dd').format(log.createdAt);
    final timeStr = DateFormat('HH:mm').format(log.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('أولاً: بيانات التشغيلة:'),
        const SizedBox(height: 6),
        Table(
          border: TableBorder.all(color: const Color(0xFF8DB4E2), width: 1),
          columnWidths: const {
            0: FlexColumnWidth(1.2),
            1: FlexColumnWidth(2.5),
          },
          children: [
            _buildTableRow('اسم المنتج', log.productName ?? 'مصنع سلسال للمياة المعبأة (وادي العين)'),
            _buildTableRow('حجم العبوة', log.bottleSize ?? '330 مل'),
            _buildTableRow('رقم التشغيلة', log.batchNumber ?? '-'),
            _buildTableRow('تاريخ الإنتاج', log.productionDate ?? dateStr),
            _buildTableRow('وقت أخذ العينة', log.samplingTime ?? timeStr),
            TableRow(
              children: [
                Container(
                  color: const Color(0xFFBDD7EE),
                  padding: const EdgeInsets.all(8.0),
                  alignment: Alignment.centerRight,
                  child: const Text('مكان أخذ العينة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 4.0,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildCheckItem('بداية التشغيل', location == 'بداية التشغيل'),
                      _buildCheckItem('أثناء التشغيل', location == 'أثناء التشغيل'),
                      _buildCheckItem('نهاية التشغيل', location == 'نهاية التشغيل'),
                    ],
                  ),
                ),
              ],
            ),
            _buildTableRow('الكمية المنتجة', log.producedQuantity ?? '5000 كرتون'),
            _buildTableRow('اسم آخذ العينة', log.sampleTaker ?? 'صلاح الجابري'),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String value) {
    return TableRow(
      children: [
        Container(
          color: const Color(0xFFBDD7EE),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          alignment: Alignment.centerRight,
          child: Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(value, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
        ),
      ],
    );
  }

  Widget _buildCheckItem(String title, bool isChecked) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isChecked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: isChecked ? const Color(0xFF007791) : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(title, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildResultsTable(List<WaterQualityResult> resultsList) {
    return Table(
      border: TableBorder.all(color: const Color(0xFF8DB4E2), width: 1),
      columnWidths: const {
        0: FlexColumnWidth(2.5),
        1: FlexColumnWidth(2.0),
        2: FlexColumnWidth(1.5),
        3: FlexColumnWidth(1.8),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFFBDD7EE)),
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('الفحص', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('معيار القبول', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('النتيجة', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text('الملاحظات', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        ...resultsList.map((r) {
          final param = controller.parameters[r.parameterId];
          final paramName = param != null ? param.nameAr : '-';
          final unit = (param?.unit != null && param!.unit!.isNotEmpty) ? ' ${param.unit}' : '';
          final resultText = r.numericResult != null
              ? '${r.numericResult}$unit'
              : (r.textResult ?? '-');

          final dynamicStd = controller.getStandardString(r.parameterId);
          final standardLimit = dynamicStd.isNotEmpty ? dynamicStd : _getStandardLimit(paramName);
          final isNonCompliant = !r.isCompliant;

          return TableRow(
            decoration: isNonCompliant ? BoxDecoration(color: Colors.red.shade50) : null,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(paramName, style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(standardLimit, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  resultText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isNonCompliant ? Colors.red.shade900 : Colors.black87,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(r.notes ?? '', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isNonCompliant ? Colors.red.shade900 : Colors.black87)),
              ),
            ],
          );
        }),
      ],
    );
  }

  String _getStandardLimit(String paramName) {
    if (paramName.contains('المواد الغريبة') || paramName.contains('الشوائب')) return 'خالية تماماً';
    if (paramName.contains('المظهر')) return 'طبيعي';
    if (paramName.contains('سلامة العبوة')) return 'بدون تشققات أو تشوهات';
    if (paramName.contains('إحكام الغلق')) return 'لا يوجد تسريب';
    if (paramName.contains('نظافة العبوة')) return 'نظيفة';
    if (paramName.contains('جودة الطباعة')) return 'واضحة';
    if (paramName.contains('رقم التشغيلة')) return 'صحيح';
    if (paramName.contains('تاريخ الإنتاج')) return 'صحيح';
    if (paramName.contains('تاريخ الانتهاء')) return 'صحيح';
    if (paramName.contains('البطاقة التعريفية')) return 'مطابقة';
    if (paramName.contains('التغليف النهائي')) return 'مطابق';

    if (paramName.contains('اللون')) return 'عديم اللون';
    if (paramName.contains('الطعم')) return 'مستساغ';
    if (paramName.contains('الرائحة')) return 'مقبولة';
    if (paramName.contains('العكارة')) return '1 وحدة (NTU) أو < 5';
    if (paramName.contains('درجة الحرارة')) return '-';
    if (paramName.contains('pH') || paramName.contains('الرقم الهيدروجيني')) return '6.5 - 8.5';
    if (paramName.contains('TDS') || paramName.contains('الصلبة الذائبة')) return '100 - 500 mg/l';
    if (paramName.contains('التوصيلية')) return '-';
    if (paramName.contains('العسر الكلي')) return '< 500 mg/l';
    if (paramName.contains('القلوية الكلية')) return '< 200 mg/l';
    if (paramName.contains('الكالسيوم')) return '< 350 mg/l';
    if (paramName.contains('المغنسيوم')) return '< 150 mg/l';
    if (paramName.contains('البوتاسيوم')) return '1 - 10 mg/l';
    if (paramName.contains('الصوديوم')) return '< 200 mg/l';
    if (paramName.contains('الفلورايد')) return '0.7 - 1.5 mg/l';
    if (paramName.contains('الكلورايد')) return '< 250 mg/l';
    if (paramName.contains('الحديد')) return '< 0.3 mg/l';
    if (paramName.contains('النترات')) return '< 50 mg/l';
    if (paramName.contains('الكبريتات')) return '< 250 mg/l';
    if (paramName.contains('البيكربونات')) return '< 250 mg/l';
    if (paramName.contains('الأوزون')) return '0.25 - 0.45 mg/l';
    if (paramName.contains('الكلور')) return '0.2 - 0.5 ppm';

    if (paramName.contains('البكتيريا') || paramName.contains('TPC')) return 'خالية تماماً';
    if (paramName.contains('القولونيات')) return 'خالية تماماً';
    if (paramName.contains('E. coli')) return 'خالية تماماً';
    if (paramName.contains('الخمائر') || paramName.contains('الفطريات')) return 'خالية تماماً';

    return '-';
  }

  Widget _buildComplianceSection(WaterQualityLog log) {
    final isComp = log.isCompliant;
    final isIsolated = log.isIsolated == true;
    final isHold = log.isHoldIssued == true;
    final isReject = log.isRejectIssued == true;
    final ncr = log.ncrNumber ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('- قرار المطابقة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              _buildCheckItem('المنتج مطابق للمواصفات.', isComp),
              const SizedBox(height: 6),
              _buildCheckItem('المنتج غير مطابق.', !isComp),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('- في حالة عدم المطابقة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              _buildCheckItem('تم العزل.', isIsolated),
              const SizedBox(height: 2),
              _buildCheckItem('تم إصدار بطاقة HOLD', isHold),
              const SizedBox(height: 2),
              _buildCheckItem('تم إصدار بطاقة REJECT', isReject),
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildCheckItem('تم فتح NCR رقم: ', ncr.isNotEmpty),
                  Text(ncr.isNotEmpty ? ncr : '________________', style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotesSection(WaterQualityLog log) {
    final hasRejection = log.rejectionReason != null && log.rejectionReason!.isNotEmpty;
    final rejector = log.rejectedBy ?? 'المعتمد';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('- الملاحظات:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 4),
        if (hasRejection)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.cancel, color: Colors.red, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '⚠️ ملاحظة الرفض ($rejector): ${log.rejectionReason}',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            log.generalNotes != null && log.generalNotes!.isNotEmpty
                ? log.generalNotes!
                : 'لا توجد ملاحظات إضافية.',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualSignaturesBar(BuildContext context, WaterQualityLog log) {
    final curLog = controller.currentLog.value ?? log;
    // المرحلة الأولى من الاعتماد تكتمل قبل إدخال نتائج الميكروبيولوجي
    final isQmDone = curLog.approvalStatus == 'Approved' ||
        curLog.approvalStatus == 'Closed' ||
        curLog.approvalStatus == 'Pending_GM' ||
        ApprovalStatus.isMicroStage(curLog.approvalStatus) ||
        (curLog.stage1QmApprovedBy ?? curLog.qmApprovedBy ?? '').isNotEmpty;
    final isGmDone = curLog.approvalStatus == 'Approved' ||
        curLog.approvalStatus == 'Closed' ||
        curLog.approvalStatus == 'Awaiting_Micro_Results' ||
        curLog.approvalStatus == 'Pending_Micro_GM' ||
        (curLog.stage1GmApprovedBy ?? curLog.gmApprovedBy ?? '').isNotEmpty;

    // تحديد الجهة التي رفضت التقرير — في حال الرفض الميكروبيولوجي المنفصل يظل الاعتماد الأولي معتمداً
    final isQmRejected = curLog.approvalStatus != 'Closed' &&
        !ApprovalStatus.isMicroRejected(curLog.approvalStatus) &&
        ApprovalStatus.rejectedByQualityManager(
          rejectedBy: curLog.rejectedBy,
          gmDecisionBy: curLog.gmDecisionBy,
          status: curLog.approvalStatus,
        );
    final isGmRejected = curLog.approvalStatus != 'Closed' &&
        !ApprovalStatus.isMicroRejected(curLog.approvalStatus) &&
        ApprovalStatus.rejectedByFactoryManager(
          rejectedBy: curLog.rejectedBy,
          gmDecisionBy: curLog.gmDecisionBy,
          status: curLog.approvalStatus,
        );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: curLog.qmApprovedBy,
      microQmApprovedBy: curLog.microQmApprovedBy,
      rejectedBy: curLog.rejectedBy,
      gmDecisionBy: curLog.gmDecisionBy,
      status: curLog.approvalStatus,
    );
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: curLog.rejectedBy,
      gmDecisionBy: curLog.gmDecisionBy,
      status: curLog.approvalStatus,
    );
    // أسماء المرحلة الثانية (اعتماد نتائج الميكروبيولوجي) لها الأولوية
    final effectiveQmName = curLog.microQmApprovedBy ?? curLog.qmApprovedBy;
    final effectiveGmName = curLog.microGmApprovedBy ?? curLog.gmApprovedBy;
    final effectiveQmDate = curLog.microQmApprovedAt ?? curLog.qmApprovedAt;
    final effectiveGmDate = curLog.microGmApprovedAt ?? curLog.gmApprovedAt;

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
              const Icon(Icons.draw_rounded, size: 14, color: AppColors.primaryDark),
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
                  roleTitle: 'منفذ الفحص / إعداد',
                  signerName: curLog.sampleTaker ?? 'صلاح الجابري',
                  dateStr: DateFormat('yyyy/MM/dd').format(curLog.createdAt),
                  isApproved: true,
                  signatureBytes: controller.inspectorSignatureBytes.value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: (curLog.approvalStatus == 'Closed')
                      ? 'مدير الجودة (معتمد سابقاً)'
                      : (wasQmApproved ? 'اعتماد مدير الجودة (سابقاً)' : 'اعتماد مدير الجودة'),
                  signerName: (isQmRejected || wasQmRejected) && curLog.approvalStatus != 'Closed'
                      ? (curLog.rejectedBy ?? 'مدير الجودة')
                      : effectiveQmName ?? (isQmDone || wasQmApproved || curLog.approvalStatus == 'Closed' ? 'حمود يسر (مدير الجودة)' : 'بانتظار الاعتماد'),
                  dateStr: curLog.approvalStatus == 'Closed'
                      ? (effectiveQmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveQmDate) : 'معتمد سابقاً')
                      : (effectiveQmDate != null
                          ? DynamicReportPdfGenerator.formatArabicDate(effectiveQmDate)
                          : (isQmDone || wasQmApproved ? 'معتمد' : ((isQmRejected || wasQmRejected) ? 'مرفوض' : 'لم يعتمد بعد'))),
                  isApproved: isQmDone && curLog.approvalStatus != 'Closed' && !wasQmRejected,
                  isRejected: (isQmRejected || wasQmRejected) && curLog.approvalStatus != 'Closed',
                  isVoided: curLog.approvalStatus == 'Closed' || wasQmApproved,
                  signatureBytes: (isQmRejected || wasQmRejected) && curLog.approvalStatus != 'Closed'
                      ? controller.rejectedSignatureBytes.value
                      : ((isQmDone || wasQmApproved || curLog.approvalStatus == 'Closed') ? controller.qmSignatureBytes.value : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: (curLog.approvalStatus == 'Closed')
                      ? 'اعتماد مدير المصنع (بعد إجراء تصحيحي)'
                      : 'اعتماد مدير المصنع',
                  signerName: isGmRejected && curLog.approvalStatus != 'Closed'
                      ? (curLog.gmDecisionBy ?? curLog.rejectedBy ?? 'مدير المصنع')
                      : (curLog.gmDecisionBy ?? effectiveGmName ?? (isGmDone || curLog.approvalStatus == 'Closed' ? 'خالد العمري (مدير المصنع)' : 'بانتظار الاعتماد')),
                  dateStr: curLog.approvalStatus == 'Closed'
                      ? (effectiveGmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveGmDate) : 'معتمد بعد إجراء تصحيحي')
                      : (effectiveGmDate != null
                          ? DynamicReportPdfGenerator.formatArabicDate(effectiveGmDate)
                          : (isGmDone ? 'معتمد نهائياً' : (isGmRejected ? 'مرفوض' : 'لم يعتمد بعد'))),
                  isApproved: isGmDone || curLog.approvalStatus == 'Closed',
                  isRejected: isGmRejected && curLog.approvalStatus != 'Closed',
                  signatureBytes: isGmRejected && curLog.approvalStatus != 'Closed'
                      ? controller.rejectedSignatureBytes.value
                      : controller.gmSignatureBytes.value,
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
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? const Color(0xFFFFEBEE)
                        : (isVoided
                            ? const Color(0xFFFFF8E1)
                            : (isApproved ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1))),
                    border: Border.all(
                      color: isRejected
                          ? const Color(0xFFC62828)
                          : (isVoided
                              ? const Color(0xFFFFB300)
                              : (isApproved ? const Color(0xFF2E7D32) : const Color(0xFFF57F17))),
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isRejected
                        ? 'مرفوض'
                        : (isVoided
                            ? 'معتمد سابقاً (أُلغي برفض الإدارة)'
                            : (isApproved ? 'معتمد' : 'بانتظار الاعتماد')),
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isRejected
                          ? const Color(0xFFB71C1C)
                          : (isVoided
                              ? const Color(0xFFB78103)
                              : (isApproved ? const Color(0xFF1B5E20) : const Color(0xFFE65100))),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 2),
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

  Widget _buildSignaturesTable(WaterQualityLog log) {
    return Obx(() {
      final curLog = controller.currentLog.value ?? log;
      final sampleTakerName = curLog.sampleTaker ?? 'صلاح الجابري';
      final isQmDone = curLog.approvalStatus == 'Approved' ||
          curLog.approvalStatus == 'Closed' ||
          curLog.approvalStatus == 'Pending_GM' ||
          ApprovalStatus.isMicroStage(curLog.approvalStatus) ||
          (curLog.stage1QmApprovedBy ?? curLog.qmApprovedBy ?? '').isNotEmpty;
      final isGmDone = curLog.approvalStatus == 'Approved' ||
          curLog.approvalStatus == 'Closed' ||
          curLog.approvalStatus == 'Awaiting_Micro_Results' ||
          curLog.approvalStatus == 'Pending_Micro_GM' ||
          (curLog.stage1GmApprovedBy ?? curLog.gmApprovedBy ?? '').isNotEmpty;

      final isQmRejected = curLog.approvalStatus != 'Closed' &&
          !ApprovalStatus.isMicroRejected(curLog.approvalStatus) &&
          ApprovalStatus.rejectedByQualityManager(
            rejectedBy: curLog.rejectedBy,
            gmDecisionBy: curLog.gmDecisionBy,
            status: curLog.approvalStatus,
          );
      final isGmRejected = curLog.approvalStatus != 'Closed' &&
          !ApprovalStatus.isMicroRejected(curLog.approvalStatus) &&
          ApprovalStatus.rejectedByFactoryManager(
            rejectedBy: curLog.rejectedBy,
            gmDecisionBy: curLog.gmDecisionBy,
            status: curLog.approvalStatus,
          );
      final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
        qmApprovedBy: curLog.qmApprovedBy,
        microQmApprovedBy: curLog.microQmApprovedBy,
        rejectedBy: curLog.rejectedBy,
        gmDecisionBy: curLog.gmDecisionBy,
        status: curLog.approvalStatus,
      );

      // أسماء وتواريخ المرحلة الثانية (اعتماد نتائج الميكروبيولوجي) لها الأولوية
      final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
        rejectedBy: curLog.rejectedBy,
        gmDecisionBy: curLog.gmDecisionBy,
        status: curLog.approvalStatus,
      );
      final rawQmName = curLog.microQmApprovedBy ?? curLog.qmApprovedBy ?? ((isQmDone || wasQmApproved) ? 'حمود يسر' : (wasQmRejected ? (curLog.rejectedBy ?? 'مدير الجودة') : '________________'));
      final qmName = (isQmRejected || wasQmRejected) ? (curLog.rejectedBy ?? 'مدير الجودة') : rawQmName;

      final rawGmName = curLog.microGmApprovedBy ?? curLog.gmApprovedBy ?? (isGmDone ? 'خالد العمري' : '________________');
      final gmName = isGmRejected ? (curLog.gmDecisionBy ?? curLog.rejectedBy ?? 'مدير المصنع') : rawGmName;

      final effectiveQmDate = curLog.microQmApprovedAt ?? curLog.qmApprovedAt;
      final effectiveGmDate = curLog.microGmApprovedAt ?? curLog.gmApprovedAt;
      final qmDate = effectiveQmDate != null
          ? DynamicReportPdfGenerator.formatArabicDate(effectiveQmDate)
          : (isQmDone || wasQmApproved || isQmRejected ? 'معتمد' : '  /  / 2026م');
      final gmDate = effectiveGmDate != null
          ? DynamicReportPdfGenerator.formatArabicDate(effectiveGmDate)
          : (isGmDone || isGmRejected ? 'معتمد' : '  /  / 2026م');
      final entryDate = DateFormat('yyyy/MM/dd').format(curLog.createdAt);

      final isClosed = curLog.approvalStatus == 'Closed';
      final qmSig = isClosed
          ? '[معتمد سابقاً]'
          : ((isQmRejected || wasQmRejected)
              ? '[مرفوض]'
              : (isQmDone
                  ? '[معتمد إلكترونياً]'
                  : (wasQmApproved ? '[معتمد سابقاً - أُلغي برفض الإدارة]' : 'بانتظار الاعتماد')));
      final gmSig = isClosed
          ? '[معتمد بعد إجراء تصحيحي]'
          : (isGmRejected ? '[مرفوض]' : (isGmDone ? '[معتمد إلكترونياً]' : 'بانتظار الاعتماد'));

      return Table(
        border: TableBorder.all(color: const Color(0xFF8DB4E2), width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFBDD7EE)),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: Text('منفذ الفحص', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: Text('مدير الجودة', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6.0),
                child: Text('اعتماد مدير المصنع', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          TableRow(
            children: [
              _buildSigBox(sampleTakerName, 'مكتمل ومُرسل', entryDate, controller.inspectorSignatureBytes.value),
              _buildSigBox(
                qmName,
                qmSig,
                qmDate,
                (isQmRejected && !isClosed) ? controller.rejectedSignatureBytes.value : ((isQmDone || wasQmApproved || isClosed) ? controller.qmSignatureBytes.value : null),
                isQmRejected && !isClosed,
                isClosed || wasQmApproved,
              ),
              _buildSigBox(
                gmName,
                gmSig,
                gmDate,
                (isGmRejected && !isClosed) ? controller.rejectedSignatureBytes.value : ((isGmDone || isClosed) ? controller.gmSignatureBytes.value : null),
                isGmRejected && !isClosed,
              ),
            ],
          ),
        ],
      );
    });
  }

  Widget _buildSigBox(String name, String sig, String date, [Uint8List? signatureBytes, bool isRejected = false, bool isVoided = false]) {
    final isApproved = sig.contains('معتمد') || sig.contains('مكتمل');
    final cleanSig = sig.replaceAll('[', '').replaceAll(']', '').replaceAll('التوقيع:', '').trim();
    final badgeText = cleanSig.isNotEmpty ? cleanSig : (isRejected ? 'مرفوض' : (isVoided ? 'معتمد سابقاً (أُلغي برفض الإدارة)' : (isApproved ? 'معتمد' : 'بانتظار الاعتماد')));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Builder(
                builder: (context) {
                  final parsed = ArabicPdfService.splitNameAndRole(name);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الاسم: ${parsed.name}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isRejected ? const Color(0xFFB71C1C) : Colors.black87,
                        ),
                      ),
                      if (parsed.role != null) ...[
                        const SizedBox(height: 1.5),
                        Text(
                          parsed.role!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 9.5,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRejected
                      ? const Color(0xFFFFEBEE)
                      : (isVoided
                          ? const Color(0xFFFFF8E1)
                          : (isApproved ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1))),
                  border: Border.all(
                    color: isRejected
                        ? const Color(0xFFC62828)
                        : (isVoided
                            ? const Color(0xFFFFB300)
                            : (isApproved ? const Color(0xFF2E7D32) : const Color(0xFFF57F17))),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isRejected
                        ? const Color(0xFFB71C1C)
                        : (isVoided
                            ? const Color(0xFFB78103)
                            : (isApproved ? const Color(0xFF1B5E20) : const Color(0xFFE65100))),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'التاريخ: $date',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  color: isRejected ? const Color(0xFFB71C1C) : Colors.grey.shade700,
                ),
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
    );
  }

  Widget _buildStandardNotice() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('- ملاحظة:', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 11, color: Colors.grey.shade800)),
        Text('- كل الفحوصات وفق اشتراطات المواصفة القياسية اليمنية المعتمدة لمياه الشرب المعبأ 2620:2024 YSMO.', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade700)),
        Text('- تدرج فقط الاختبارات التي يقرر المصنع تنفيذها ضمن برنامج المراقبة، أو وفق المواصفة القياسية اليمنية وخطة الـ HACCP.', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade700)),
      ],
    );
  }

  Widget _buildDocumentFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black54),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          Text('رقم الوثيقة: SELSAL-IMSF-19-05', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text('تاريخ الاصدار: 2026/07/15', style: TextStyle(fontSize: 11)),
          Text('إصدار رقم: 01', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildAccessDeniedWidget(BuildContext context, WaterQualityLog log) {
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
              'هذا التقرير يتبع لـ (${log.branchName}).\nحسابك الحالي مقيد بصلاحيات (${session.assignedBranchName}).\nلا يمكنك استعراض أو تعديل أو اعتماد تقارير مصانع أخرى.',
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
                backgroundColor: AppColors.primaryDark,
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
