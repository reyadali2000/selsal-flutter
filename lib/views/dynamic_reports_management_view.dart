import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dynamic_reports_list_controller.dart';
import '../models/dynamic_report_models.dart';
import '../routes/app_routes.dart';
import '../services/api/dynamic_reports_api_service.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';

class DynamicReportsManagementView extends StatelessWidget {
  const DynamicReportsManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DynamicReportsListController());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : AppColors.canvas,
        appBar: AppBar(
          title: const Text(
            'إدارة التقارير الديناميكية',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.white,
            ),
          ),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 1,
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل التقارير...');
          }

          final visibleReports = UserSessionService.to.canDesignDynamicReports
              ? controller.reports
              : controller.reports.where((r) => UserSessionService.to.canViewDynamicReport(r.id, r.categoryId)).toList();

          if (visibleReports.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AppEmptyState(
                  icon: Icons.description_outlined,
                  title: 'لا توجد تقارير حالياً',
                  message: UserSessionService.to.canDesignDynamicReports
                      ? 'ابدأ بإنشاء قالب تقرير جديد بالضغط على الزر أدناه'
                      : 'لا تتوفر لديك صلاحية لأي تقارير ديناميكية حالياً',
                ),
              ),
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: ListView.builder(
                itemCount: visibleReports.length,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemBuilder: (context, index) {
                  final report = visibleReports[index];
                  return _buildReportCard(context, controller, report, index);
                },
              ),
            ),
          );
        }),
        floatingActionButton: UserSessionService.to.canDesignDynamicReports
            ? FloatingActionButton.extended(
                onPressed: () async {
                  final res = await Get.toNamed(AppRoutes.dynamicReportBuilder);
                  if (res == true) controller.loadData();
                },
                label: const Text(
                  'إنشاء تقرير جديد',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
                icon: const Icon(Icons.add_rounded),
                backgroundColor: AppColors.primaryDark,
              )
            : null,
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    DynamicReportsListController controller,
    DynamicReportReportInfo report,
    int index,
  ) {
    final isLandscape = report.orientation == 'landscape';
    final accent = isLandscape ? const Color(0xFF6A1B9A) : const Color(0xFF0D47A1);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // شريط علوي ملوّن + الرأس
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(report.iconData, size: 24, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                          fontSize: 15.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (report.description != null && report.description!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          report.description!,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildOrientationBadge(isLandscape, accent),
              ],
            ),
          ),
          // الإحصائيات
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: FutureBuilder<List<int>>(
              future: _loadReportStats(report.id!),
              builder: (context, snapshot) {
                final sectionsCount = snapshot.data?.elementAtOrNull(0) ?? 0;
                final fieldsCount = snapshot.data?.elementAtOrNull(1) ?? 0;
                return Row(
                  children: [
                    _buildStatChip(
                      icon: Icons.dashboard_outlined,
                      label: '$sectionsCount قسم',
                      color: const Color(0xFF007791),
                    ),
                    const SizedBox(width: 8),
                    _buildStatChip(
                      icon: Icons.list_alt_rounded,
                      label: '$fieldsCount حقل',
                      color: const Color(0xFF6A1B9A),
                    ),
                    const Spacer(),
                    // شارة الحالة
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: report.isActive
                            ? const Color(0xFF118A68).withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: report.isActive
                              ? const Color(0xFF118A68).withValues(alpha: 0.35)
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            report.isActive ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
                            size: 12,
                            color: report.isActive ? const Color(0xFF118A68) : Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            report.isActive ? 'مُفعّل' : 'مُعطّل',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: report.isActive ? const Color(0xFF118A68) : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // الأزرار
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                if (UserSessionService.to.canDesignDynamicReports) ...[
                  _buildActionButton(
                    icon: Icons.edit_outlined,
                    label: 'تعديل',
                    color: Colors.orange.shade700,
                    onTap: () async {
                      final res = await Get.toNamed(AppRoutes.dynamicReportBuilder, arguments: report.id);
                      if (res == true) controller.loadData();
                    },
                  ),
                  const SizedBox(width: 6),
                ],
                if (UserSessionService.to.canFillDynamicReport(report.id, report.categoryId)) ...[
                  Expanded(
                    child: AppButton.primary(
                      label: 'تعبئة التقرير',
                      icon: Icons.assignment_outlined,
                      color: AppColors.primaryDark,
                      onPressed: () {
                        if (report.isActive) {
                          Get.toNamed(AppRoutes.dynamicReportForm, arguments: report.id);
                        } else {
                          AppToast.warning('التقرير غير مفعل', title: 'تنبيه');
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (UserSessionService.to.canDeleteReports)
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: 'حذف',
                    color: Colors.redAccent,
                    onTap: () => _confirmDeleteReport(context, controller, report),
                  ),
                if (UserSessionService.to.canDesignDynamicReports &&
                    !UserSessionService.to.canFillDynamicInCategory(report.categoryId)) ...[
                  const SizedBox(width: 6),
                  _buildActionButton(
                    icon: report.isActive ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                    label: report.isActive ? 'تعطيل' : 'تفعيل',
                    color: report.isActive ? Colors.green.shade700 : Colors.grey.shade600,
                    onTap: () => controller.toggleReportActive(report, !report.isActive),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// تحميل عدد الأقسام والحقول لتقرير ما
  Future<List<int>> _loadReportStats(int reportId) async {
    try {
      final report = await DynamicReportsApiService.to.getTemplateDetails(reportId);
      if (report == null) return [0, 0];
      final sectionsCount = report.sections?.length ?? 0;
      final fieldsCount = report.sections?.fold<int>(
            0,
            (sum, s) => sum + (s.fields?.length ?? 0),
          ) ??
          0;
      return [sectionsCount, fieldsCount];
    } catch (_) {
      return [0, 0];
    }
  }

  Widget _buildOrientationBadge(bool isLandscape, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLandscape ? Icons.stay_current_landscape_rounded : Icons.stay_current_portrait_rounded,
            size: 13,
            color: accent,
          ),
          const SizedBox(width: 4),
          Text(
            isLandscape ? 'عرضي' : 'طولي',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteReport(BuildContext context, DynamicReportsListController controller, DynamicReportReportInfo report) {
    AppDialog.confirm(
      context: context,
      title: 'تأكيد حذف التقرير',
      message: 'هل أنت متأكد من حذف التقرير "${report.name}"؟\n\nتنبيه: سيتم حذف جميع الأقسام والحقول والسجلات المدخلة المرتبطة بهذا التقرير نهائياً ولا يمكن التراجع عن هذه الخطوة.',
      confirmLabel: 'حذف نهائي',
      confirmColor: Colors.red,
      onConfirm: () => controller.deleteReport(report.id!),
    );
  }
}

/// نوع مساعد لتجنب الخلط بين DynamicReport والمعلومات المعروضة
typedef DynamicReportReportInfo = DynamicReport;

