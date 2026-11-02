import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../controllers/dynamic_report_form_controller.dart';
import '../models/dynamic_report_models.dart';
import '../widgets/dynamic_field_widget.dart';
import '../widgets/ds/ds.dart';
import '../utils/dynamic_report_color_helper.dart';

class DynamicReportFormView extends StatelessWidget {
  const DynamicReportFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DynamicReportFormController());
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Obx(() {
      final name = controller.report.value?.name ?? 'تعبئة تقرير';
      final isEdit = controller.isEditMode.value;
      final status = controller.existingRecord.value?.approvalStatus;

      final subtitle = !controller.isFormOpen.value
          ? 'أرشيف المسودات والبدء'
          : (isEdit
              ? (status == 'Rejected'
                  ? 'تعديل تقرير مرفوض وإعادة الإرسال'
                  : status == 'Draft'
                      ? 'استكمال مسودة محفوظة'
                      : 'تعديل السجل #${controller.existingRecord.value?.id ?? ""}')
              : 'بدء تقرير جديد');

      return AppScaffold(
        title: name,
        subtitle: subtitle,
        maxContentWidth: 900,
        leading: controller.isFormOpen.value && !controller.isDirectRecordEntry.value
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'العودة لأرشيف المسودات',
                onPressed: () {
                  controller.isFormOpen.value = false;
                },
              )
            : null,
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل نموذج التقرير...');
          }

          final report = controller.report.value;
          if (report == null || report.sections == null) {
            return const AppEmptyState(
              icon: Icons.error_outline_rounded,
              title: 'تعذر تحميل التقرير',
              message: 'حدث خطأ في تحميل هيكل التقرير أو تم حذفه.',
            );
          }

          if (!controller.isFormOpen.value) {
            return _buildArchiveView(context, controller, report, isDark);
          }

          return _buildFormView(context, controller, report, isDark, status, isEdit);
        }),
        bottomNavigationBar: Obx(() {
          if (controller.isLoading.value || !controller.isFormOpen.value) {
            return const SizedBox.shrink();
          }
          return _buildBottomBar(context, controller);
        }),
      );
    });
  }

  // ==================== 1. ARCHIVE & DRAFTS HUB ====================
  Widget _buildArchiveView(
    BuildContext context,
    DynamicReportFormController controller,
    DynamicReport report,
    bool isDark,
  ) {
    final reportColor = DynamicReportColorHelper.getColor(report);

    return RefreshIndicator(
      onRefresh: () => controller.loadDrafts(),
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Hero Card - Header & Start New Report Action
          AppCard(
            padding: const EdgeInsets.all(24),
            margin: const EdgeInsets.only(bottom: 24),
            backgroundColor: isDark
                ? reportColor.withValues(alpha: 0.12)
                : reportColor.withValues(alpha: 0.06),
            borderColor: reportColor.withValues(alpha: 0.25),
            child: Column(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: reportColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: reportColor.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Icon(
                    report.iconData,
                    size: 34,
                    color: reportColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  report.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkInk : AppColors.primaryDark,
                  ),
                ),
                if (report.description != null && report.description!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    report.description!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 13,
                      color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AppButton.primary(
                  label: 'بدء تقرير جديد',
                  icon: Icons.add_circle_outline_rounded,
                  height: 50,
                  width: 240,
                  color: reportColor,
                  onPressed: controller.startNewReport,
                ),
              ],
            ),
          ),

          // Drafts Archive Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.drafts_rounded, size: 18, color: Colors.amber.shade900),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Obx(() => Text(
                    'المسودات المؤرشفة (${controller.drafts.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: isDark ? AppColors.darkInk : AppColors.ink,
                    ),
                  )),
                ),
                const SizedBox(width: 8),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  tooltip: 'تحديث المسودات',
                  onPressed: controller.loadDrafts,
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // Drafts List or Empty State
          Obx(() {
            if (controller.isLoadingDrafts.value) {
              return const Padding(
                padding: EdgeInsets.all(32.0),
                child: AppLoading(message: 'جاري تحميل المسودات المؤرشفة...'),
              );
            }

            if (controller.drafts.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_outlined,
                          size: 38,
                          color: isDark ? AppColors.darkMuted : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'لا توجد مسودات مؤرشفة حالياً',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? AppColors.darkInk : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'انقر على "بدء تقرير جديد" أعلاه لإنشاء نموذج جديد، أو احفظ كمسودة أثناء التعبئة للعودة إليها هنا في أي وقت.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkMuted : Colors.grey.shade500,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: controller.drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final draft = controller.drafts[index];
                final dateStr = draft.updatedAt != null
                    ? DateFormat('yyyy-MM-dd HH:mm').format(draft.updatedAt!)
                    : (draft.createdAt != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(draft.createdAt!)
                        : 'تاريخ غير محدد');

                return AppCard(
                  padding: const EdgeInsets.all(14),
                  onTap: () => controller.resumeDraft(draft),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.edit_note_rounded,
                          color: Colors.amber.shade900,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'مسودة تقرير #${draft.id}',
                                  style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.amber.shade400, width: 0.8),
                                  ),
                                  child: Text(
                                    'مسودة مؤقتة',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(Icons.access_time_rounded, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(Icons.person_outline_rounded, size: 14, color: Colors.grey.shade500),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    draft.createdBy ?? 'غير محدد',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 12,
                                      color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (draft.shiftName != null || draft.branchName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${draft.effectiveBranchName} ${draft.shiftName != null ? "• ${draft.shiftName}" : ""}',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  color: isDark ? AppColors.darkMuted : Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 22),
                        tooltip: 'حذف المسودة',
                        onPressed: () => controller.deleteDraft(draft),
                      ),
                      const SizedBox(width: 4),
                      AppButton.primary(
                        label: 'استكمال',
                        icon: Icons.play_arrow_rounded,
                        height: 38,
                        onPressed: () => controller.resumeDraft(draft),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  // ==================== 2. FORM VIEW ====================
  Widget _buildFormView(
    BuildContext context,
    DynamicReportFormController controller,
    DynamicReport report,
    bool isDark,
    String? status,
    bool isEdit,
  ) {
    final isRejected = status == 'Rejected';
    final isDraft = status == 'Draft';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Form(
        key: controller.formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Rejection Alert Banner (if editing a rejected report)
            if (isEdit && isRejected)
              AppCard(
                backgroundColor: isDark
                    ? AppButton.dangerColor.withValues(alpha: 0.15)
                    : const Color(0xFFFFEBEE),
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppButton.dangerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cancel_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ملاحظات الرفض السابقة${controller.existingRecord.value?.rejectedBy != null ? " (من قِبل ${controller.existingRecord.value?.rejectedBy})" : ""}',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppButton.dangerColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.existingRecord.value?.rejectionReason ?? 'لم يتم تحديد سبب الرفض.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              color: isDark ? AppColors.darkInk : Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'يرجى مراجعة وتصحيح الحقول المطلوبة أدناه ثم إعادة الإرسال للاعتماد.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppButton.dangerColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // 2. Draft Notice Banner (if editing a draft)
            if (isEdit && isDraft)
              AppCard(
                backgroundColor: isDark
                    ? const Color(0xFF5D4037).withValues(alpha: 0.25)
                    : Colors.amber.shade50,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.drafts_rounded, color: Colors.amber.shade800, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'أنت تقوم الآن بتعديل واستكمال مسودة محفوظة (#${controller.existingRecord.value?.id ?? ""}). يمكنك إكمال الفحص وإرسال التقرير للاعتماد أو تحديث المسودة.',
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 12.5,
                          color: isDark ? AppColors.darkInk : Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Inspector Info Header Card
            AppCard(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_pin_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'منفذ الفحص / مُعد التقرير',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: isDark ? AppColors.darkMuted : AppColors.muted,
                          ),
                        ),
                        Text(
                          controller.currentInspectorName,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.darkInk : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 3. Sections & Dynamic Fields
            ...report.sections!.map((section) {
              final sectionBody = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!section.isCollapsible) ...[
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.primaryMedium,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            section.title,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.darkInk : AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (section.description != null && section.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        section.description!,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 13,
                          color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const Divider(height: 24),
                  ],
                  if (section.fields == null || section.fields!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'لا توجد حقول في هذا القسم',
                        style: TextStyle(fontFamily: AppTheme.fontFamily, color: Colors.grey),
                      ),
                    )
                  else
                    ...section.fields!.map((field) {
                      return DynamicFieldWidget(
                        field: field,
                        initialValue: controller.fieldValues[field.id],
                        textController: controller.textControllers[field.id],
                        onChanged: (val) {
                          controller.updateFieldValue(field.id!, val);
                        },
                      );
                    }),
                ],
              );

              return AppCard(
                margin: const EdgeInsets.only(bottom: 16),
                padding: section.isCollapsible ? EdgeInsets.zero : const EdgeInsets.all(16),
                child: section.isCollapsible
                    ? Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.darkInk : AppColors.primaryDark,
                                ),
                              ),
                              if (section.description != null && section.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    section.description!,
                                    textAlign: TextAlign.right,
                                    textDirection: TextDirection.rtl,
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 13,
                                      color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: sectionBody)],
                        ),
                      )
                    : sectionBody,
              );
            }),
          ],
        ),
      ),
    );
  }

  // ==================== 3. BOTTOM NAVIGATION BAR ====================
  Widget _buildBottomBar(BuildContext context, DynamicReportFormController controller) {
    final requiresApproval = controller.report.value?.approvalType != 'none';

    return AppPanel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      radius: 0,
      child: SafeArea(
        child: controller.isSaving.value
            ? const SizedBox(
                height: 48,
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(strokeWidth: 2.5),
                      SizedBox(width: 12),
                      Text(
                        'جاري الحفظ والمعالجة...',
                        style: TextStyle(fontFamily: AppTheme.fontFamily, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              )
            : requiresApproval
                ? Row(
                    children: [
                      // 1. Save as Draft Button
                      Expanded(
                        flex: 2,
                        child: AppButton.outlined(
                          label: 'حفظ كمسودة',
                          icon: Icons.drafts_outlined,
                          height: 48,
                          onPressed: () => controller.saveRecord(isDraft: true),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // 2. Submit for Approval Button
                      Expanded(
                        flex: 3,
                        child: AppButton.primary(
                          label: controller.isEditMode.value ? 'إعادة الإرسال' : 'إرسال للاعتماد',
                          icon: Icons.send_rounded,
                          height: 48,
                          onPressed: () => controller.saveRecord(isDraft: false),
                        ),
                      ),
                    ],
                  )
                : AppButton.primary(
                    label: 'حفظ واعتماد التقرير',
                    icon: Icons.check_circle_rounded,
                    height: 48,
                    expanded: true,
                    onPressed: () => controller.saveRecord(isDraft: false),
                  ),
      ),
    );
  }
}
