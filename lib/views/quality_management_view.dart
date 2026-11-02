import '../utils/dynamic_report_color_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import 'final_product_entry_page.dart';
import 'raw_water_entry_page.dart';
import 'raw_material_entry_page.dart';

import '../controllers/dynamic_reports_list_controller.dart';
import '../services/user_session_service.dart';
import '../routes/app_routes.dart';

class QualityManagementView extends StatelessWidget {
  const QualityManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DynamicReportsListController());

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Padding(
              padding: const EdgeInsets.only(
                left: 24,
                right: 24,
                top: 0,
                bottom: 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إدارة الجودة',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Obx(() {
                      final dynamicReports = controller.reports.where((r) => r.isActive && r.categoryId == 1).toList();
                      final session = UserSessionService.to;

                      final gridItems = <Widget>[];

                      if (session.canFillFinalProduct) {
                        gridItems.add(_buildGridItem(
                          title: 'فحص المنتج النهائي',
                          icon: Icons.verified_outlined,
                          color: Colors.orange,
                          onTap: () => Get.to(() => FinalProductEntryPage()),
                        ));
                      }

                      if (session.canFillRawWater) {
                        gridItems.add(_buildGridItem(
                          title: 'فحص المياه الخام',
                          icon: Icons.water_drop_outlined,
                          color: Colors.lightBlue,
                          onTap: () => Get.to(() => RawWaterEntryPage()),
                        ));
                      }

                      if (session.canFillRawMaterial) {
                        gridItems.add(_buildGridItem(
                          title: 'فحص المواد الخام',
                          icon: Icons.inventory_2_outlined,
                          color: const Color(0xFF00695C),
                          onTap: () => Get.to(() => RawMaterialEntryPage()),
                        ));
                      }

                      for (var report in dynamicReports) {
                        if (report.id == null) continue;
                        if (!session.canFillDynamicReport(report.id!, report.categoryId)) continue;
                        gridItems.add(_buildGridItem(
                          title: report.name,
                          icon: report.iconData,
                          color: DynamicReportColorHelper.getColor(report),
                          onTap: () =>
                              Get.toNamed(AppRoutes.dynamicReportForm, arguments: report.id),
                        ));
                      }

                      if (gridItems.isEmpty) {
                        return _buildNoPermissionState();
                      }

                      final isWide = MediaQuery.of(context).size.width > 700;

                      return GridView(
                        padding: const EdgeInsets.only(bottom: 100),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 3 : 2,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          mainAxisExtent: 160,
                        ),
                        children: gridItems,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// تُعرض عند انعدام أية صلاحية إدخال في قسم إدارة الجودة
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
              'لا تملك صلاحية إدخال الفحوصات',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'حسابك الحالي (${UserSessionService.to.roleTitle}) لا يملك صلاحية إدخال أي نوع من الفحوصات. '
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

  Widget _buildGridItem({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: 0.7), color],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              top: -15,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
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
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.white.withValues(alpha: 0.8),
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
