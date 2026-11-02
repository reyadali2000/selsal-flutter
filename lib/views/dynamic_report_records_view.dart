import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/approval_status.dart';
import '../controllers/dynamic_report_records_controller.dart';
import '../models/dynamic_report_models.dart';
import '../routes/app_routes.dart';
import '../services/user_session_service.dart';
import '../utils/dynamic_report_pdf_generator.dart';
import '../widgets/branch_filter_selector.dart';
import '../widgets/ds/ds.dart';
import 'dynamic_report_display_view.dart';

class DynamicReportRecordsView extends StatelessWidget {
  const DynamicReportRecordsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DynamicReportRecordsController());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : AppColors.canvas,
        appBar: AppBar(
          title: Obx(() => Text(
            controller.reportName.value,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          )),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
          actions: [
            Obx(() {
              if (!UserSessionService.to.canFilterByBranch) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: BranchFilterSelector(
                  compact: true,
                  onChanged: () => controller.loadRecords(),
                ),
              );
            }),
          ],
        ),
        body: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: isDark ? theme.colorScheme.surface : Colors.white,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.canvas,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Obx(() => TextField(
                      controller: controller.searchController,
                      onChanged: (val) => controller.searchQuery.value = val,
                      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13.5),
                      decoration: InputDecoration(
                        hintText: 'بحث برقم السجل أو التاريخ...',
                        hintStyle: const TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primaryDark),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (controller.searchQuery.value.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                                onPressed: () {
                                  controller.searchController.clear();
                                  controller.searchQuery.value = '';
                                },
                              ),
                            IconButton(
                              icon: const Icon(Icons.calendar_month, color: AppColors.primaryDark),
                              tooltip: 'اختيار تاريخ',
                              onPressed: () => controller.selectDate(context),
                            ),
                          ],
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        border: InputBorder.none,
                      ),
                    )),
                  ),
                ),
              ),
            ),
            // شريط فلترة الحالات
            Obx(() {
              final statuses = controller.availableStatuses;
              if (statuses.isEmpty) return const SizedBox.shrink();
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark ? theme.colorScheme.surface : Colors.white,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildStatusChip(
                            controller,
                            label: 'الكل',
                            value: 'all',
                            count: controller.records.length,
                          ),
                          const SizedBox(width: 6),
                          ...statuses.map((s) {
                            final count = controller.records
                                .where((r) => r.approvalStatus == s)
                                .length;
                            return Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: _buildStatusChip(
                                controller,
                                label: ApprovalStatus.shortLabel(s),
                                value: s,
                                count: count,
                                color: ApprovalStatus.color(s),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            Expanded(
              child: Obx(() {
                if (controller.isLoading.value) {
                  return const AppLoading(message: 'جاري تحميل سجلات التقرير...');
                }

                final displayRecords = controller.filteredRecords;

                if (displayRecords.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: AppEmptyState(
                        icon: Icons.assignment_outlined,
                        title: controller.searchQuery.value.isNotEmpty
                            ? 'لا توجد نتائج مطابقة'
                            : 'لا توجد سجلات بعد',
                        message: controller.searchQuery.value.isNotEmpty
                            ? 'لم نتمكن من إيجاد سجلات تطابق "${controller.searchQuery.value}"'
                            : 'لم يتم إدخال أي سجلات لهذا التقرير بعد',
                      ),
                    ),
                  );
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: ListView.builder(
                      itemCount: displayRecords.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final record = displayRecords[index];
                        final dateStr = DynamicReportPdfGenerator.formatArabicDate(record.createdAt);
                        final status = record.approvalStatus;

                        Color statusColor;
                        Color statusBgColor;
                        String statusText;
                        IconData statusIcon;

                        switch (status) {
                          case 'Approved':
                          case 'معتمد':
                            statusColor = const Color(0xFF2E7D32);
                            statusBgColor = const Color(0xFFE8F5E9);
                            statusText = 'معتمد نهائياً';
                            statusIcon = Icons.check_circle_rounded;
                            break;
                          case 'Pending_GM':
                            statusColor = const Color(0xFF6A1B9A);
                            statusBgColor = const Color(0xFFF3E5F5);
                            statusText = 'بانتظار اعتماد مدير المصنع';
                            statusIcon = Icons.admin_panel_settings_rounded;
                            break;
                          case 'Pending_QM':
                            statusColor = const Color(0xFFE65100);
                            statusBgColor = const Color(0xFFFFF3E0);
                            statusText = 'بانتظار اعتماد مدير الجودة';
                            statusIcon = Icons.pending_actions_rounded;
                            break;
                          case 'Rejected':
                          case 'مرفوض':
                            statusColor = const Color(0xFFC62828);
                            statusBgColor = const Color(0xFFFFEBEE);
                            statusText = 'مرفوض — تصحيحي مطلوب';
                            statusIcon = Icons.cancel_rounded;
                            break;
                          case 'Corrective_In_Progress':
                            statusColor = const Color(0xFF1565C0);
                            statusBgColor = const Color(0xFFE3F2FD);
                            statusText = 'تصحيحي قيد التنفيذ';
                            statusIcon = Icons.build_circle;
                            break;
                          case 'Pending_GM_Decision':
                            statusColor = const Color(0xFFAD6800);
                            statusBgColor = const Color(0xFFFFF8E1);
                            statusText = 'بانتظار قرار مدير المصنع';
                            statusIcon = Icons.pending_actions;
                            break;
                          case 'Rejected_By_GM':
                            statusColor = const Color(0xFF8B0000);
                            statusBgColor = const Color(0xFFFFEBEE);
                            statusText = 'مرفوض نهائياً';
                            statusIcon = Icons.cancel_presentation;
                            break;
                          case 'Closed':
                            statusColor = const Color(0xFF2E7D32);
                            statusBgColor = const Color(0xFFE8F5E9);
                            statusText = 'معتمد بعد إجراء تصحيحي';
                            statusIcon = Icons.task_alt;
                            break;
                          case 'Draft':
                          case 'مسودة':
                            statusColor = Colors.blueGrey.shade700;
                            statusBgColor = Colors.blueGrey.shade50;
                            statusText = 'مسودة مؤقتة';
                            statusIcon = Icons.drafts_rounded;
                            break;
                          default:
                            statusColor = Colors.blueGrey;
                            statusBgColor = Colors.blueGrey.shade50;
                            statusText = record.status ?? 'مكتمل';
                            statusIcon = Icons.info_outline;
                        }

                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 12),
                          onTap: () async {
                            if (Get.isRegistered<DynamicReportDisplayController>()) {
                              Get.delete<DynamicReportDisplayController>();
                            }
                            await Get.toNamed('/dynamic-report-display', arguments: {
                              'reportId': controller.reportId,
                              'recordId': record.id,
                            });
                            controller.loadRecords();
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: statusColor.withValues(alpha: 0.12),
                                    child: Icon(statusIcon, color: statusColor, size: 22),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'سجل رقم #${record.id}',
                                          style: const TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'مُعد السجل: ${DynamicReportPdfGenerator.formatCreatorName(record.createdBy)}',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: statusBgColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                                    ),
                                    child: Text(
                                      statusText,
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 18),
                              Row(
                                children: [
                                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 6),
                                  Text(
                                    dateStr,
                                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700),
                                  ),
                                  const Spacer(),
                                  if ((status == 'Draft' || status == 'مسودة') &&
                                      UserSessionService.to.canEditReports) ...[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit_note_rounded,
                                        color: AppColors.primaryDark,
                                        size: 22,
                                      ),
                                      tooltip: 'استكمال المسودة',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () async {
                                        final res = await Get.toNamed(AppRoutes.dynamicReportForm, arguments: {
                                          'reportId': controller.reportId,
                                          'recordId': record.id,
                                        });
                                        if (res == true) controller.loadRecords();
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if ((status == 'Draft' || status == 'مسودة') &&
                                      UserSessionService.to.canDeleteReports) ...[
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                      tooltip: 'حذف السجل',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        _confirmDeleteRecord(context, controller, record);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey.shade400),
                                ],
                              ),
                              if (record.rejectionReason != null && record.rejectionReason!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    'سبب الرفض: ${record.rejectionReason}',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11,
                                      color: Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(
    DynamicReportRecordsController controller, {
    required String label,
    required String value,
    required int count,
    Color? color,
  }) {
    final selected = controller.statusFilter.value == value;
    final chipColor = color ?? AppColors.primaryDark;
    return GestureDetector(
      onTap: () => controller.statusFilter.value = value,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? chipColor : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? chipColor : chipColor.withValues(alpha: 0.3),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : chipColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: selected ? Colors.white : chipColor.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRecord(BuildContext context, DynamicReportRecordsController controller, DynamicReportRecord record) {
    AppDialog.confirm(
      context: context,
      title: 'تأكيد حذف السجل',
      message: 'هل أنت متأكد من حذف السجل رقم (${record.id})؟ لن يمكنك التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف',
      confirmColor: Colors.redAccent,
      onConfirm: () => controller.deleteRecord(record.id!),
    );
  }
}
