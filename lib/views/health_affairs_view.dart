import '../utils/dynamic_report_color_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../models/role_model.dart';
import '../services/user_session_service.dart';
import 'hygiene_report_view.dart';
import '../controllers/hygiene_report_controller.dart';
import '../controllers/dynamic_reports_list_controller.dart';
import '../routes/app_routes.dart';

class HealthAffairsCategory {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String permissionCode;

  HealthAffairsCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.permissionCode,
  });
}

class HealthAffairsView extends StatelessWidget {
  HealthAffairsView({super.key});

  final List<HealthAffairsCategory> _categories = [
    HealthAffairsCategory(
      title: 'فحص النظافة الشخصية',
      icon: Icons.clean_hands_rounded,
      color: Colors.teal,
      permissionCode: SystemPermissions.createHygieneReports,
      onTap: () {
        Get.put(HygieneReportController());
        Get.to(() => HygieneReportView());
      },
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final dynamicController = Get.put(DynamicReportsListController());
    final isWide = MediaQuery.of(context).size.width > 700;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Obx(() {
                // الاشتراك في تغييرات الجلسة لتطبيق الإخفاء فوراً
                UserSessionService.to.currentUser.value;
                final session = UserSessionService.to;

                final dynamicReports = dynamicController.reports.where((r) => r.isActive && r.categoryId == 2).toList();

                final allCategories = _categories
                    .where((c) {
                      if (c.permissionCode == SystemPermissions.createHygieneReports) {
                        return session.canFillHygiene;
                      }
                      return session.hasPermissionCode(c.permissionCode);
                    })
                    .toList();

                for (var report in dynamicReports) {
                  if (report.id == null) continue;
                  if (!session.canFillDynamicReport(report.id!, report.categoryId)) continue;
                  allCategories.add(
                    HealthAffairsCategory(
                      title: report.name,
                      icon: report.iconData,
                      color: DynamicReportColorHelper.getColor(report),
                      permissionCode: SystemPermissions.fillDynamicReportCode(report.id!),
                      onTap: () {
                        Get.toNamed(AppRoutes.dynamicReportForm, arguments: report.id);
                      },
                    )
                  );
                }

                if (allCategories.isEmpty) {
                  return _buildNoPermissionState();
                }

                return GridView.builder(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 100),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isWide ? 3 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 160,
                  ),
                  itemCount: allCategories.length,
                  itemBuilder: (context, index) {
                    final cat = allCategories[index];
                    return _buildCategoryCard(context, cat);
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 20, right: 20, bottom: 16),
      child: Row(
        children: [
          const Icon(Icons.health_and_safety_rounded, color: AppColors.primaryDark, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'سلامة الغذاء',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
                fontFamily: 'Tajawal',
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// تُعرض عند انعدام أية صلاحية في قسم سلامة الغذاء
  Widget _buildNoPermissionState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              'لا تملك صلاحية الدخول لقسم سلامة الغذاء',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'حسابك الحالي (${UserSessionService.to.roleTitle}) لا يملك صلاحية الوصول لفحوصات سلامة الغذاء. '
              'يرجى التواصل مع مسؤول النظام.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12.5,
                height: 1.6,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, HealthAffairsCategory cat) {
    return InkWell(
      onTap: cat.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cat.color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: cat.color.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -25,
              bottom: -25,
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cat.color.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          cat.color.withValues(alpha: 0.9),
                          cat.color.withValues(alpha: 0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(cat.icon, size: 28, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    cat.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: cat.color.withValues(alpha: 0.8),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
