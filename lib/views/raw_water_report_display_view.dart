import '../widgets/corrective_action_submit_dialog.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../constants/approval_status.dart';
import '../controllers/raw_water_report_display_controller.dart';
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

class RawWaterReportDisplayView extends StatelessWidget {
  RawWaterReportDisplayView({super.key});

  final RawWaterReportDisplayController controller = Get.put(
    RawWaterReportDisplayController(),
  );

  static const Color _headerLightBlue = Color(0xFFBDD7EE);
  static const Color _tableBorderColor = Color(0xFF8DB4E2);

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تقرير فحص المياه الخام',
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

        if (controller.currentLog.value == null) {
          return const Center(child: AppEmptyState(title: 'لا توجد بيانات للتقرير', icon: Icons.description_outlined));
        }

        final log = controller.log;

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
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.surface,
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 8),
                        _buildReportTitle(),
                        const SizedBox(height: 12),
                        _buildSampleDataSection(log),
                        const SizedBox(height: 16),
                        _buildSectionLabel('ثانياً: الفحص الحسي:'),
                        const SizedBox(height: 8),
                        _buildResultsTable('Sensory'),
                        const SizedBox(height: 16),
                        _buildSectionLabel('ثالثاً: الفحوصات الفيزيائية والكيميائية:'),
                        const SizedBox(height: 8),
                        _buildResultsTable('Physical', cat2: 'Chemical', cat3: 'Physiochemical'),
                        const SizedBox(height: 16),
                        _buildSectionLabel('رابعاً: الفحوصات الميكروبيولوجية:'),
                        const SizedBox(height: 8),
                        Obx(() {
                          final microResults = controller.results.where((r) {
                                final p = controller.parameters[r.parameterId];
                                return p?.category == 'Microbiological';
                              }).toList();
                          final microEmpty = microResults.isEmpty ||
                              microResults.every((r) =>
                                  (r.textResult ?? '').trim().isEmpty &&
                                  r.numericResult == null);
                          final awaiting = controller.log.approvalStatus == 'Awaiting_Micro_Results';
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
                          return _buildResultsTable('Microbiological');
                        }),
                        // دورة اعتماد الميكروبيولوجي المستقلة تحت قسمها
                        if (MicroApprovalCycleCard.shouldShow(log))
                          MicroApprovalCycleCard(
                            log: log,
                            onEnterResults: _showMicroResultsEntryDialog,
                            onApproveQM: _confirmMicroQualityManagerApproval,
                            onApproveGM: _confirmMicroFactoryManagerApproval,
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
                        _buildComplianceDecision(log),
                        const SizedBox(height: 16),
                        _buildNotesSection(log),
                        const SizedBox(height: 24),
                        _buildSignaturesTable(log),
                        const SizedBox(height: 16),
                        _buildFooter(),
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
        bannerColor = const Color(0xFFC62828);
        statusTitle = 'نتائج الفحص الميكروبيولوجي مرفوضة (الفحص الفيزيوكيميائي معتمد)';
        statusSubtitle = 'سبب الرفض: ${log.microRejectionReason ?? log.rejectionReason ?? "غير محدد"}';
        statusIcon = Icons.cancel;
        break;
      case 'Micro_Resample_Pending':
        bannerColor = const Color(0xFFD84315);
        statusTitle = 'مطلوب إعادة سحب عينة ميكروبيولوجية جديدة (الفحص الأولي معتمد)';
        statusSubtitle = 'سبب إعادة السحب: ${log.microRejectionReason ?? log.rejectionReason ?? "غير محدد"} — بانتظار إدخال نتائج العينة الجديدة.';
        statusIcon = Icons.refresh;
        break;
      case 'Micro_Corrective_In_Progress':
        bannerColor = const Color(0xFF1565C0);
        statusTitle = 'إجراء تصحيحي ميكروبيولوجي قيد التنفيذ (الفحص الأولي معتمد)';
        statusSubtitle = (log.correctiveAction ?? '').isNotEmpty
            ? 'الإجراء المطلوب: ${log.correctiveAction} — المسؤول: ${log.correctiveOwner ?? "غير محدد"}'
            : 'جاري تنفيذ الإجراء التصحيحي الخاص بالميكروبيولوجي.';
        statusIcon = Icons.build_circle;
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

  String _approvalStageLabel(String status) {
    switch (status) {
      case 'Pending_QM':
        return 'المرحلة 1 من 2';
      case 'Pending_GM':
        return 'المرحلة 2 من 2';
      case 'Awaiting_Micro_Results':
        return 'بانتظار الميكروبيولوجي';
      case 'Pending_Micro_QM':
        return 'المرحلة 2 — مدير الجودة';
      case 'Pending_Micro_GM':
        return 'المرحلة 2 — مدير المصنع';
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

  Widget _buildRoleActions(BuildContext context, WaterQualityLog log, UserRole currentRole, String status) {
    final session = UserSessionService.to;
    if (status == 'Approved') {
      return Wrap(
        spacing: 12,
        runSpacing: 10,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified, color: Colors.teal, size: 20),
              SizedBox(width: 8),
              Text(
                'التقرير معتمد ومقفل رسمياً.',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.teal),
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
      );
    }

    // QM Action: When Pending_QM
    if (status == 'Pending_QM') {
      if (session.canApproveQM && session.canApproveBranchData(log.branchId)) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'اعتماد مدير الجودة',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                onPressed: () => _confirmQualityManagerApproval(),
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
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مدير الجودة. حسابك الحالي لا يمتلك صلاحية اعتماد مدير الجودة لهذا التقرير.',
        );
      }
    }

    // GM Action: When Pending_GM
    if (status == 'Pending_GM') {
      if (session.canApproveGM && session.canApproveBranchData(log.branchId)) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'الاعتماد النهائي (مدير المصنع)',
                icon: Icons.verified,
                color: const Color(0xFF6A1B9A),
                onPressed: () => _confirmFactoryManagerApproval(),
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
      } else if (session.canApproveGM && !session.canApproveBranchData(log.branchId)) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${log.branchName})، بينما حسابك مسند إلى (${session.assignedBranchName}). لا تملك صلاحية اعتماد تقارير مصنع آخر.',
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'تم اعتماد التقرير من مدير الجودة وهو بانتظار مدير المصنع. حسابك الحالي لا يمتلك صلاحية اعتماد مدير المصنع.',
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
                onPressed: () => _confirmMicroQualityManagerApproval(),
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
      } else {
        return _buildRolePromptCard(
          prompt: 'نتائج الفحص الميكروبيولوجي بانتظار اعتماد مدير الجودة. حسابك الحالي لا يمتلك صلاحية اعتماد مدير الجودة لهذا التقرير.',
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
                onPressed: () => _confirmMicroFactoryManagerApproval(),
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
      } else {
        return _buildRolePromptCard(
          prompt: 'نتائج الفحص الميكروبيولوجي بانتظار الاعتماد النهائي. حسابك الحالي لا يمتلك صلاحية اعتماد مدير المصنع لهذا التقرير.',
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
          title: 'تقرير فحص مياه خام #${log.id}',
          subtitle: log.batchNumber != null && log.batchNumber!.isNotEmpty
              ? 'رقم الدفعة: ${log.batchNumber} • ${log.branchName}'
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
    final log = controller.log;
    final action = await CorrectiveActionSubmitDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص مياه خام #${log.id}${log.batchNumber != null ? " (${log.batchNumber})" : ""}',
      rejectionReason: log.rejectionReason ?? log.microRejectionReason ?? 'غير محدد',
      rejectedBy: log.rejectedBy ?? log.microRejectedBy,
      initialCorrectiveAction: log.correctiveAction,
      correctiveOwner: log.correctiveOwner,
    );
    if (action != null && action.isNotEmpty) {
      controller.submitCorrectiveAction(action);
    }
  }

  /// نافذة إدخال نتائج الفحص الميكروبيولوجي (المرحلة الثانية)
  void _showMicroResultsEntryDialog() async {
    final log = controller.log;
    final existingMicro = controller.results.where((r) {
      final p = controller.parameters[r.parameterId];
      return p?.category == 'Microbiological';
    }).toList();
    final results = await MicroResultsEntryDialog.show(
      Get.context!,
      standards: controller.microbiologicalStandards,
      parameters: controller.parameters,
      existingResults: existingMicro,
      reportTitle: 'تقرير فحص مياه خام #${log.id}${log.batchNumber != null ? " (${log.batchNumber})" : ""}',
    );

    if (results != null) {
      await controller.submitMicrobiologicalResults(results);
    }
  }

  void _confirmMicroQualityManagerApproval() {
    AppDialog.confirm(
      context: Get.context!,
      title: 'اعتماد نتائج الفحص الميكروبيولوجي',
      message: 'هل أنت متأكد من مراجعة واعتماد نتائج الفحص الميكروبيولوجي؟ سيتم رفعها لمدير المصنع للاعتماد النهائي.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'تراجع',
      confirmColor: const Color(0xFF2E7D32),
      onConfirm: () => controller.approveMicroByQualityManager(),
    );
  }

  void _confirmMicroFactoryManagerApproval() {
    AppDialog.confirm(
      context: Get.context!,
      title: 'الاعتماد النهائي لنتائج الفحص الميكروبيولوجي',
      message: 'هل أنت متأكد من الاعتماد النهائي لنتائج الفحص الميكروبيولوجي؟ سيكتمل اعتماد التقرير ويصبح مقفلاً وجاهزاً للطباعة.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'تراجع',
      confirmColor: const Color(0xFF6A1B9A),
      onConfirm: () => controller.approveMicroByFactoryManager(),
    );
  }

  /// شاشة قرار مدير الجودة أو مدير المصنع على الإجراء التصحيحي
  void _showGmDecisionDialog() async {
    final log = controller.log;
    final status = log.approvalStatus;
    final isQmStage = status == 'Pending_QM_Decision';

    final decision = await GmDecisionDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص مياه خام #${log.id}${log.batchNumber != null ? " (${log.batchNumber})" : ""}',
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

  Widget _buildRolePromptCard({required String prompt}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF0D47A1)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              prompt,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF0D47A1)),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmQualityManagerApproval() {
    final name = UserSessionService.to.currentUserName.value;
    AppDialog.confirm(
      context: Get.context!,
      title: 'اعتماد مدير الجودة',
      message: 'هل أنت متأكد من اعتماد هذا التقرير وإحالته لمدير المصنع للاعتماد النهائي؟\nالمعتمد: $name',
      confirmLabel: 'نعم، اعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF2E7D32),
      onConfirm: () => controller.approveByQualityManager(),
    );
  }

  void _confirmFactoryManagerApproval() {
    final name = UserSessionService.to.currentUserName.value;
    AppDialog.confirm(
      context: Get.context!,
      title: 'الاعتماد النهائي (مدير المصنع)',
      message: 'هل تؤكد الاعتماد النهائي لتقرير فحص المياه الخام وختمه رسمياً؟\nالمعتمد: $name',
      confirmLabel: 'اعتماد نهائي',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF6A1B9A),
      onConfirm: () => controller.approveByFactoryManager(),
    );
  }

  void _showMicroRejectDialog(BuildContext context) async {
    final log = controller.log;
    final result = await MicroRejectDialog.show(
      context,
      reportTitle: 'تقرير فحص مياه خام #${log.id}',
      reportSubtitle: 'مصدر المياه: ${log.waterSource ?? ""} • البئر: ${log.wellNumber ?? ""}',
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
    final log = controller.log;
    final payload = await RejectReportDialog.show(
      context,
      reportTitle: 'تقرير فحص مياه خام #${log.id}',
      reportSubtitle: log.batchNumber != null && log.batchNumber!.isNotEmpty
          ? 'رقم الدفعة: ${log.batchNumber} • المصنع: ${log.branchName}'
          : 'المصنع: ${log.branchName}',
      rejectionCount: log.rejectionCount,
    );

    if (payload == null) return;
    controller.rejectReport(payload);
  }

  // ==================== REPORT DISPLAY (PDF REPLICA) ====================

  Widget _buildHeader() {
    return AspectRatio(
      aspectRatio: 475 / 66,
      child: Image.asset(
        'assets/images/selsal_pdf_header.png',
        width: double.infinity,
        fit: BoxFit.fill,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildReportTitle() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF173A5E), width: 1.2),
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFFD6E6F5),
        ),
        child: const Text(
          'تقرير فحص المياه الخام',
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 21, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSampleDataSection(WaterQualityLog log) {
    final formattedDate = DateFormat('yyyy/MM/dd').format(log.createdAt);
    final formattedTime = DateFormat('HH:mm').format(log.createdAt);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أولاً: بيانات العينة:',
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 14, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: _tableBorderColor),
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(2), 2: FlexColumnWidth(1), 3: FlexColumnWidth(2)},
          children: [
            TableRow(children: [_sampleCell('التاريخ', isLabel: true), _sampleCell(formattedDate), _sampleCell('الوقت', isLabel: true), _sampleCell(formattedTime)]),
            TableRow(children: [_sampleCell('مصدر المياه', isLabel: true), _sampleCell(log.waterSource ?? ''), _sampleCell('رقم البئر (إن وجد)', isLabel: true), _sampleCell(log.wellNumber ?? '')]),
            TableRow(children: [_sampleCell('اسم آخذ العينة', isLabel: true), _sampleCell(log.sampleTaker ?? ''), _sampleCell('رقم العينة', isLabel: true), _sampleCell(log.batchNumber ?? '')]),
          ],
        ),
      ],
    );
  }

  Widget _sampleCell(String text, {bool isLabel = false}) {
    return Container(
      color: isLabel ? _headerLightBlue : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: isLabel ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
    );
  }

  Widget _buildResultsTable(String cat1, {String? cat2, String? cat3}) {
    final results = controller.results.where((r) {
      final param = controller.parameters[r.parameterId];
      if (param == null) return false;
      return param.category == cat1 || (cat2 != null && param.category == cat2) || (cat3 != null && param.category == cat3);
    }).toList();

    return Table(
      border: TableBorder.all(color: _tableBorderColor),
      columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(2), 2: FlexColumnWidth(2), 3: FlexColumnWidth(2)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _headerLightBlue),
          children: [_headerCell('الفحص'), _headerCell('معيار القبول'), _headerCell('النتيجة'), _headerCell('الملاحظات')],
        ),
        if (results.isEmpty)
          TableRow(children: [_dataCell('-'), _dataCell(''), _dataCell(''), _dataCell('')])
        else
          ...results.map((r) {
            final param = controller.parameters[r.parameterId];
            final paramName = param?.nameAr ?? '';
            final unit = param?.unit ?? '';
            final stdStr = controller.getStandardString(r.parameterId);
            final isText = param?.inputType == 'Text';
            final resultStr = isText ? (r.textResult ?? '') : (r.numericResult != null ? '${r.numericResult}${unit.isNotEmpty ? ' $unit' : ''}' : '');
            return TableRow(
              decoration: BoxDecoration(color: !r.isCompliant ? const Color(0xFFFFE9E9) : Colors.white),
              children: [
                _dataCell(paramName),
                _dataCell(stdStr),
                _dataCell(resultStr, isBold: true, color: !r.isCompliant ? Colors.red.shade700 : Colors.black87),
                _dataCell(r.notes ?? ''),
              ],
            );
          }),
      ],
    );
  }

  Widget _headerCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
      ),
    );
  }

  Widget _dataCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black87),
      ),
    );
  }

  Widget _buildComplianceDecision(WaterQualityLog log) {
    final isCompliant = log.isCompliant;
    final managerNotified = log.managerNotified ?? false;
    final sourceSuspended = log.sourceSuspended ?? false;
    final ncrNumber = log.ncrNumber ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '- قرار المطابقة:',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _checkRow('مطابق للمواصفات', isCompliant),
            const SizedBox(width: 32),
            _checkRow('غير مطابق', !isCompliant),
          ],
        ),
        if (!isCompliant) ...[
          const SizedBox(height: 12),
          const Text(
            '- في حالة عدم المطابقة:',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 24,
            runSpacing: 8,
            children: [
              _checkRow('تم إخطار مدير الجودة', managerNotified),
              _checkRow('تم تعليق استخدام مصدر المياه', sourceSuspended),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تم فتح NCR رقم:', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                  const SizedBox(width: 6),
                  Container(
                    width: 90,
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.black))),
                    child: Text(ncrNumber, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _checkRow(String label, bool checked) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
        const SizedBox(width: 6),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1.5),
            color: checked ? Colors.black : Colors.white,
          ),
          child: checked ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
        ),
      ],
    );
  }

  Widget _buildNotesSection(WaterQualityLog log) {
    final notes = log.generalNotes ?? '';
    final rejectionReason = log.rejectionReason ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '- الملاحظات:',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14, decoration: TextDecoration.underline),
        ),
        const SizedBox(height: 6),
        if (notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(notes, style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
          ),
        if (rejectionReason.isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملاحظة الرفض / الإعادة للتعديل${log.rejectedBy != null && log.rejectedBy!.isNotEmpty ? " (من: ${log.rejectedBy})" : ""}:',
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rejectionReason,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      if ((log.correctiveAction ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          'الإجراء التصحيحي المطلوب: ${log.correctiveAction}'
                          '${(log.correctiveOwner ?? '').isNotEmpty ? " — المسؤول: ${log.correctiveOwner}" : ""}',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12.5,
                            color: Color(0xFF0D47A1),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 0.8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            notes.isNotEmpty ? notes : 'لا توجد ملاحظات إضافية.',
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildVisualSignaturesBar(BuildContext context, WaterQualityLog log) {
    // المرحلة الأولى من الاعتماد تكتمل قبل إدخال نتائج الميكروبيولوجي
    final isQmDone = log.approvalStatus == 'Approved' ||
        log.approvalStatus == 'Pending_GM' ||
        ApprovalStatus.isMicroStage(log.approvalStatus) ||
        (log.stage1QmApprovedBy ?? log.qmApprovedBy ?? '').isNotEmpty;
    final isGmDone = log.approvalStatus == 'Approved' ||
        log.approvalStatus == 'Awaiting_Micro_Results' ||
        log.approvalStatus == 'Pending_Micro_GM' ||
        (log.stage1GmApprovedBy ?? log.gmApprovedBy ?? '').isNotEmpty;

    // تحديد الجهة التي رفضت التقرير — في حال الرفض الميكروبيولوجي يظل الاعتماد الأولي معتمداً
    final isQmRejected = !ApprovalStatus.isMicroRejected(log.approvalStatus) &&
        ApprovalStatus.rejectedByQualityManager(
          rejectedBy: log.rejectedBy,
          gmDecisionBy: log.gmDecisionBy,
          status: log.approvalStatus,
        );
    final isGmRejected = !ApprovalStatus.isMicroRejected(log.approvalStatus) &&
        ApprovalStatus.rejectedByFactoryManager(
          rejectedBy: log.rejectedBy,
          gmDecisionBy: log.gmDecisionBy,
          status: log.approvalStatus,
        );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: log.qmApprovedBy,
      microQmApprovedBy: log.microQmApprovedBy,
      rejectedBy: log.rejectedBy,
      gmDecisionBy: log.gmDecisionBy,
      status: log.approvalStatus,
    );
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: log.rejectedBy,
      gmDecisionBy: log.gmDecisionBy,
      status: log.approvalStatus,
    );
    // أسماء المرحلة الثانية (اعتماد نتائج الميكروبيولوجي) لها الأولوية
    final effectiveQmName = log.microQmApprovedBy ?? log.qmApprovedBy;
    final effectiveGmName = log.microGmApprovedBy ?? log.gmApprovedBy;
    final effectiveQmDate = log.microQmApprovedAt ?? log.qmApprovedAt;
    final effectiveGmDate = log.microGmApprovedAt ?? log.gmApprovedAt;

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
                  signerName: log.sampleTaker ?? 'أخصائي الجودة',
                  dateStr: DateFormat('yyyy/MM/dd').format(log.createdAt),
                  isApproved: true,
                  signatureBytes: controller.inspectorSignatureBytes.value,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: (log.approvalStatus == 'Closed')
                      ? 'مدير الجودة (معتمد سابقاً)'
                      : (wasQmApproved ? 'اعتماد مدير الجودة (سابقاً)' : 'اعتماد مدير الجودة'),
                  signerName: (isQmRejected || wasQmRejected) && log.approvalStatus != 'Closed'
                      ? (log.rejectedBy ?? 'مدير الجودة')
                      : effectiveQmName ?? (isQmDone || wasQmApproved || log.approvalStatus == 'Closed' ? 'حمود يسر (مدير الجودة)' : 'بانتظار الاعتماد'),
                  dateStr: log.approvalStatus == 'Closed'
                      ? (effectiveQmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveQmDate) : 'معتمد سابقاً')
                      : (effectiveQmDate != null
                          ? DynamicReportPdfGenerator.formatArabicDate(effectiveQmDate)
                          : (isQmDone || wasQmApproved ? 'معتمد' : ((isQmRejected || wasQmRejected) ? 'مرفوض' : 'لم يعتمد بعد'))),
                  isApproved: isQmDone && log.approvalStatus != 'Closed' && !wasQmRejected,
                  isRejected: (isQmRejected || wasQmRejected) && log.approvalStatus != 'Closed',
                  isVoided: log.approvalStatus == 'Closed' || wasQmApproved,
                  signatureBytes: (isQmRejected || wasQmRejected) && log.approvalStatus != 'Closed'
                      ? controller.rejectedSignatureBytes.value
                      : ((isQmDone || wasQmApproved || log.approvalStatus == 'Closed') ? controller.qmSignatureBytes.value : null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSignatureBoxUI(
                  roleTitle: (log.approvalStatus == 'Closed')
                      ? 'اعتماد مدير المصنع (بعد إجراء تصحيحي)'
                      : 'اعتماد مدير المصنع',
                  signerName: isGmRejected && log.approvalStatus != 'Closed'
                      ? (log.gmDecisionBy ?? log.rejectedBy ?? 'مدير المصنع')
                      : (log.gmDecisionBy ?? effectiveGmName ?? (isGmDone || log.approvalStatus == 'Closed' ? 'خالد العمري (مدير المصنع)' : 'بانتظار الاعتماد')),
                  dateStr: log.approvalStatus == 'Closed'
                      ? (effectiveGmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveGmDate) : 'معتمد بعد إجراء تصحيحي')
                      : (effectiveGmDate != null
                          ? DynamicReportPdfGenerator.formatArabicDate(effectiveGmDate)
                          : (isGmDone ? 'معتمد نهائياً' : (isGmRejected ? 'مرفوض' : 'لم يعتمد بعد'))),
                  isApproved: isGmDone || log.approvalStatus == 'Closed',
                  isRejected: isGmRejected && log.approvalStatus != 'Closed',
                  signatureBytes: isGmRejected && log.approvalStatus != 'Closed'
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
    final inspectorName = log.sampleTaker ?? 'أخصائي الجودة';
    final inspectorDate = DateFormat('yyyy/MM/dd').format(log.createdAt);
    final isQmDone = log.approvalStatus == 'Approved' ||
        log.approvalStatus == 'Pending_GM' ||
        log.approvalStatus == 'Closed' ||
        log.approvalStatus == 'Awaiting_Micro_Results' ||
        log.approvalStatus == 'Pending_Micro_GM' ||
        (log.stage1QmApprovedBy ?? log.qmApprovedBy ?? '').isNotEmpty;

    final isQmRejected = !ApprovalStatus.isMicroRejected(log.approvalStatus) &&
        ApprovalStatus.rejectedByQualityManager(
          rejectedBy: log.rejectedBy,
          gmDecisionBy: log.gmDecisionBy,
          status: log.approvalStatus,
        );
    final isGmRejected = !ApprovalStatus.isMicroRejected(log.approvalStatus) &&
        ApprovalStatus.rejectedByFactoryManager(
          rejectedBy: log.rejectedBy,
          gmDecisionBy: log.gmDecisionBy,
          status: log.approvalStatus,
        );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: log.qmApprovedBy,
      microQmApprovedBy: log.microQmApprovedBy,
      rejectedBy: log.rejectedBy,
      gmDecisionBy: log.gmDecisionBy,
      status: log.approvalStatus,
    );
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: log.rejectedBy,
      gmDecisionBy: log.gmDecisionBy,
      status: log.approvalStatus,
    );

    // أسماء وتواريخ المرحلة الثانية (اعتماد نتائج الميكروبيولوجي) لها الأولوية
    final rawQmName = log.microQmApprovedBy ?? log.qmApprovedBy ?? ((isQmDone || wasQmApproved) ? 'حمود يسر' : (wasQmRejected ? (log.rejectedBy ?? 'مدير الجودة') : ''));
    final qmName = (isQmRejected || wasQmRejected) ? (log.rejectedBy ?? 'مدير الجودة') : rawQmName;
    final qmDateRaw = log.microQmApprovedAt ?? log.qmApprovedAt;
    final qmDate = qmDateRaw != null ? DynamicReportPdfGenerator.formatArabicDate(qmDateRaw) : '';

    final rawGmName = log.microGmApprovedBy ?? log.gmApprovedBy ?? '';
    final gmName = isGmRejected ? (log.gmDecisionBy ?? log.rejectedBy ?? 'مدير المصنع') : rawGmName;
    final gmDateRaw = log.microGmApprovedAt ?? log.gmApprovedAt;
    final gmDate = gmDateRaw != null ? DynamicReportPdfGenerator.formatArabicDate(gmDateRaw) : '';

    return Obx(() => Table(
      border: TableBorder.all(color: _tableBorderColor),
      columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1)},
      children: [
        TableRow(
          decoration: const BoxDecoration(color: _headerLightBlue),
          children: [_headerCell('منفذ الفحص'), _headerCell('مدير الجودة'), _headerCell('اعتماد مدير المصنع')],
        ),
        TableRow(children: [
          _buildReportSignatureCell(
            name: 'الاسم: $inspectorName',
            sig: 'مكتمل ومُرسل',
            date: 'التاريخ: $inspectorDate م',
            signatureBytes: controller.inspectorSignatureBytes.value,
            isApproved: true,
          ),
          _buildReportSignatureCell(
            name: 'الاسم: ${qmName.isNotEmpty ? qmName : ".............................."}',
            sig: log.approvalStatus == 'Closed'
                ? 'مرفوض بإجراء تصحيحي'
                : (qmName.isNotEmpty
                    ? (isQmRejected
                        ? 'مرفوض'
                        : (wasQmApproved ? 'معتمد سابقاً (أُلغي برفض الإدارة)' : 'معتمد'))
                    : 'بانتظار الاعتماد'),
            date: log.approvalStatus == 'Closed'
                ? 'التاريخ: ${qmDate.isNotEmpty ? qmDate : "معتمد سابقاً"} م'
                : (qmDate.isNotEmpty ? 'التاريخ: $qmDate م' : 'التاريخ:   /   / 20م'),
            signatureBytes: (isQmRejected && log.approvalStatus != 'Closed')
                ? controller.rejectedSignatureBytes.value
                : ((qmName.isNotEmpty || wasQmApproved || log.approvalStatus == 'Closed') ? controller.qmSignatureBytes.value : null),
            isRejected: isQmRejected && log.approvalStatus != 'Closed',
            isVoided: log.approvalStatus == 'Closed' || wasQmApproved,
            isApproved: !isQmRejected && (qmName.isNotEmpty || log.approvalStatus == 'Closed') && !wasQmApproved,
          ),
          _buildReportSignatureCell(
            name: 'الاسم: ${gmName.isNotEmpty ? gmName : ".............................."}',
            sig: log.approvalStatus == 'Closed'
                ? 'معتمد بعد إجراء تصحيحي'
                : (gmName.isNotEmpty ? (isGmRejected ? 'مرفوض' : 'معتمد') : 'بانتظار الاعتماد'),
            date: log.approvalStatus == 'Closed'
                ? 'التاريخ: ${gmDate.isNotEmpty ? gmDate : "معتمد بعد إجراء تصحيحي"} م'
                : (gmDate.isNotEmpty ? 'التاريخ: $gmDate م' : 'التاريخ:   /   / 20م'),
            signatureBytes: (isGmRejected && log.approvalStatus != 'Closed') ? controller.rejectedSignatureBytes.value : controller.gmSignatureBytes.value,
            isRejected: isGmRejected && log.approvalStatus != 'Closed',
            isApproved: log.approvalStatus == 'Closed' || (gmName.isNotEmpty && !isGmRejected),
          ),
        ]),
      ],
    ));
  }

  Widget _buildReportSignatureCell({
    required String name,
    required String sig,
    required String date,
    Uint8List? signatureBytes,
    bool isRejected = false,
    bool isVoided = false,
    bool isApproved = false,
  }) {
    final cleanSig = sig.replaceAll('[', '').replaceAll(']', '').replaceAll('التوقيع:', '').trim();
    final badgeText = cleanSig.isNotEmpty
        ? cleanSig
        : (isRejected
            ? 'مرفوض'
            : (isVoided
                ? 'معتمد سابقاً (أُلغي برفض الإدارة)'
                : (isApproved ? 'معتمد' : 'بانتظار الاعتماد')));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
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
                          color: isRejected ? const Color(0xFFB71C1C) : Colors.black87,
                          fontWeight: FontWeight.bold,
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
                date,
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

  Widget _buildFooter() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade500), borderRadius: BorderRadius.circular(4)),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: const Text('رقم الوثيقة: SELSAL-IMSF-19-02', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade400),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: const Text('تاريخ الإصدار: 2026/07/15', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
            ),
          ),
          Container(width: 1, height: 30, color: Colors.grey.shade400),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              child: const Text('إصدار رقم: 01', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12)),
            ),
          ),
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


