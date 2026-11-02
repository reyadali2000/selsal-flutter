import '../utils/dynamic_report_color_helper.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dynamic_reports_list_controller.dart';
import '../controllers/reports_controller.dart';
import '../models/role_model.dart';
import '../routes/app_routes.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';
import 'final_product_reports_page.dart';
import 'hygiene_reports_list_view.dart';
import 'raw_material_reports_page.dart';
import 'raw_water_reports_page.dart';

enum ReportDepartment { quality, foodSafety, maintenance }

extension ReportDepartmentDetails on ReportDepartment {
  String get title {
    switch (this) {
      case ReportDepartment.quality: return 'إدارة الجودة';
      case ReportDepartment.foodSafety: return 'سلامة الغذاء';
      case ReportDepartment.maintenance: return 'الصيانة';
    }
  }

  String get subtitle {
    switch (this) {
      case ReportDepartment.quality: return 'فحوصات الجودة والمواصفات';
      case ReportDepartment.foodSafety: return 'النظافة والسلامة التشغيلية';
      case ReportDepartment.maintenance: return 'الفحص والصيانة الوقائية';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportDepartment.quality: return Icons.verified_outlined;
      case ReportDepartment.foodSafety: return Icons.health_and_safety_outlined;
      case ReportDepartment.maintenance: return Icons.build_outlined;
    }
  }

  Color get color {
    switch (this) {
      case ReportDepartment.quality: return const Color(0xFF0277BD);
      case ReportDepartment.foodSafety: return const Color(0xFF00897B);
      case ReportDepartment.maintenance: return const Color(0xFF6D4C41);
    }
  }
}

class ReportCategory {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String permissionCode;
  final ReportDepartment department;
  final bool isComingSoon;

  ReportCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.permissionCode,
    this.department = ReportDepartment.quality,
    this.isComingSoon = false,
  });
}

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final ReportsController controller = Get.find<ReportsController>();
  ReportDepartment _selectedDepartment = ReportDepartment.quality;

  void _showComingSoonSnackbar() {
    AppToast.info('سيتم توفير هذا التقرير قريباً', title: 'قريباً');
  }

  bool _isComingSoon(ReportCategory cat) {
    return cat.isComingSoon || cat.onTap == _showComingSoonSnackbar;
  }

  ReportDepartment _departmentForDynamicReport(
    dynamic report,
    Iterable<dynamic> dynamicCategories,
  ) {
    var categoryName = '';
    for (final category in dynamicCategories) {
      if (category.id == report.categoryId) {
        categoryName = category.name.toString().toLowerCase();
        break;
      }
    }

    if (categoryName.contains('صيانة') || categoryName.contains('maintenance')) {
      return ReportDepartment.maintenance;
    }
    if (categoryName.contains('سلامة') ||
        categoryName.contains('غذاء') ||
        categoryName.contains('food') ||
        categoryName.contains('safety')) {
      return ReportDepartment.foodSafety;
    }
    return ReportDepartment.quality;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).size.width >= 950 ? 40 : 135,
                      ),
                      child: _buildCategoriesGrid(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesGrid(BuildContext context) {
    final dynamicController = Get.isRegistered<DynamicReportsListController>()
        ? Get.find<DynamicReportsListController>()
        : Get.put(DynamicReportsListController());

    return Obx(() {
      UserSessionService.to.currentUser.value;
      final session = UserSessionService.to;
      final allCategories = <ReportCategory>[];

      if (session.canViewFinalProduct) {
        allCategories.add(
          ReportCategory(
            title: 'تقرير فحص المنتج النهائي',
            icon: Icons.verified_outlined,
            color: Colors.orange,
            permissionCode: SystemPermissions.viewFinalProduct,
            onTap: () => Get.to(() => FinalProductReportsPage()),
          ),
        );
      }

      if (session.canViewRawWater) {
        allCategories.add(
          ReportCategory(
            title: 'تقرير فحص المياه الخام',
            icon: Icons.water_drop_outlined,
            color: Colors.lightBlue,
            permissionCode: SystemPermissions.viewRawWater,
            onTap: () => Get.to(() => RawWaterReportsPage()),
          ),
        );
      }

      if (session.canViewRawMaterial) {
        allCategories.add(
          ReportCategory(
            title: 'تقرير فحص مواد خام',
            icon: Icons.inventory_2_outlined,
            color: const Color(0xFF00695C),
            permissionCode: SystemPermissions.viewRawMaterial,
            onTap: () => Get.to(() => RawMaterialReportsPage()),
          ),
        );
      }

      if (session.canViewHygiene) {
        allCategories.add(
          ReportCategory(
            title: 'تقارير النظافة الشخصية',
            icon: Icons.clean_hands_outlined,
            color: Colors.teal,
            permissionCode: SystemPermissions.viewHygiene,
            department: ReportDepartment.foodSafety,
            onTap: () => Get.to(() => HygieneReportsListView()),
          ),
        );
      }

      final dynamicReports = dynamicController.reports.where((r) => r.isActive).toList();
      for (var report in dynamicReports) {
        if (report.id == null) continue;
        if (!session.canViewDynamicReport(report.id!, report.categoryId)) continue;
        allCategories.add(
          ReportCategory(
            title: report.name,
            icon: report.iconData,
            color: DynamicReportColorHelper.getColor(report),
            permissionCode: SystemPermissions.viewDynamicReportCode(report.id!),
            department: _departmentForDynamicReport(report, dynamicController.categories),
            onTap: () {
              Get.toNamed(AppRoutes.dynamicReportRecords, arguments: report.id);
            },
          ),
        );
      }

      final query = controller.searchQuery.value.trim().toLowerCase();
      final categories = query.isEmpty
          ? allCategories
          : allCategories.where((c) => c.title.toLowerCase().contains(query)).toList();

      if (query.isEmpty && categories.isNotEmpty && !categories.any((c) => c.department == _selectedDepartment)) {
        final firstAvailable = ReportDepartment.values.firstWhereOrNull((d) => categories.any((c) => c.department == d));
        if (firstAvailable != null && _selectedDepartment != firstAvailable) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedDepartment = firstAvailable);
          });
        }
      }

      final visibleCategories = query.isEmpty
          ? categories.where((c) => c.department == _selectedDepartment).toList()
          : categories;

      if (categories.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: AppCard(
            padding: const EdgeInsets.all(20),
            child: AppEmptyState(
              icon: query.isEmpty ? Icons.lock_outline : Icons.search_off_rounded,
              title: query.isEmpty
                  ? 'لا تملك صلاحية استعراض أي نوع من التقارير'
                  : 'لا توجد أنواع تقارير تطابق "$query"',
              message: query.isEmpty
                  ? 'حسابك الحالي (${UserSessionService.to.roleTitle}) لا يشمل صلاحيات استعراض. يرجى التواصل مع مسؤول النظام.'
                  : null,
            ),
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDepartmentSelector(categories),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
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
                const Text(
                  'أنواع التقارير',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                    fontFamily: 'Tajawal',
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${visibleCategories.length}',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (visibleCategories.isEmpty)
            _buildDepartmentEmptyState()
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    mainAxisExtent: 160,
                  ),
                  itemCount: visibleCategories.length,
                  itemBuilder: (context, index) {
                    final cat = visibleCategories[index];
                    final comingSoon = _isComingSoon(cat);
                    return _buildCategoryCard(cat, comingSoon);
                  },
                );
              },
            ),
        ],
      );
    });
  }

  Widget _buildDepartmentSelector(List<ReportCategory> categories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('أقسام التقارير', style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          const SizedBox(height: 4),
          const Text('اختر القسم لعرض تقاريره فقط', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            children: ReportDepartment.values
                .where((department) => department != ReportDepartment.maintenance)
                .map((department) {
              final isSelected = department == _selectedDepartment;
              final count = categories.where((c) => c.department == department).length;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDepartment = department),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
                      decoration: BoxDecoration(
                        color: isSelected ? department.color.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? department.color : Colors.grey.withValues(alpha: 0.2), width: isSelected ? 1.4 : 1),
                      ),
                      child: Column(
                        children: [
                          Icon(department.icon, size: 21, color: department.color),
                          const SizedBox(height: 5),
                          Text(department.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, fontWeight: FontWeight.bold, color: isSelected ? department.color : null)),
                          Text('$count تقرير', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentEmptyState() {
    final department = _selectedDepartment;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: department.color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: department.color.withValues(alpha: 0.18)),
        ),
        child: Column(
          children: [
            Icon(department.icon, color: department.color, size: 32),
            const SizedBox(height: 8),
            Text('لا توجد تقارير متاحة في ${department.title}', style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(department.subtitle, textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(ReportCategory cat, bool comingSoon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: InkWell(
        onTap: cat.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: isDark
                  ? [cat.color.withValues(alpha: 0.2), Theme.of(context).colorScheme.surface]
                  : [cat.color.withValues(alpha: 0.14), Colors.white],
              stops: const [0.0, 0.55],
            ),
            boxShadow: [
              BoxShadow(
                color: cat.color.withValues(alpha: 0.13),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: cat.color.withValues(alpha: 0.18), width: 1.4),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -28,
                bottom: -28,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cat.color.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cat.color.withValues(alpha: 0.05),
                  ),
                ),
              ),
              if (comingSoon)
                Positioned(
                  left: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade500.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      'قريباً',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cat.color.withValues(alpha: 0.9),
                            cat.color.withValues(alpha: 0.65),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: cat.color.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(cat.icon, size: 26, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(
                      cat.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Tajawal',
                        color: comingSoon ? Colors.grey.shade600 : null,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          comingSoon ? 'غير متاح' : 'عرض السجلات',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            color: cat.color.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 11,
                          color: cat.color.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 20, right: 20, bottom: 16),
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? theme.colorScheme.surface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: isDark ? Colors.white12 : AppColors.border, width: 1.2),
        ),
        child: Obx(() => TextField(
          controller: controller.searchController,
          onChanged: controller.onSearchChanged,
          decoration: InputDecoration(
            hintText: 'بحث في التقارير والسجلات...',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontFamily: 'Tajawal',
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.primaryDark,
            ),
            suffixIcon: controller.searchQuery.value.isNotEmpty
                ? Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.clear_rounded, color: Colors.grey, size: 16),
                      padding: EdgeInsets.zero,
                      onPressed: controller.clearSearch,
                    ),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        )),
      ),
    );
  }

}
