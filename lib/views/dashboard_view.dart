import '../models/dynamic_report_models.dart';
import '../utils/dynamic_report_color_helper.dart';
import '../constants/approval_status.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/dashboard_controller.dart';
import '../models/role_model.dart';
import '../services/user_session_service.dart';
import '../services/api/dynamic_reports_api_service.dart';
import '../widgets/permission_guard.dart';
import '../widgets/ds/ds.dart';
import '../routes/app_routes.dart';
import 'raw_water_entry_page.dart';
import 'final_product_entry_page.dart';
import 'hygiene_report_view.dart';
import '../models/worker_commitment_models.dart';
import '../services/daily_workers_commitment_service.dart';
import 'daily_workers_commitment_view.dart';
import '../models/factory_compliance_models.dart';
import '../services/factory_reports_compliance_service.dart';
import 'factory_reports_compliance_view.dart';

class DashboardView extends StatelessWidget {
  DashboardView({super.key});

  final DashboardController controller = Get.find<DashboardController>();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => controller.loadStats(),
      color: AppColors.primaryDark,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 126),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _buildDashboardChildren(context),
            ),
          ),
        ),
      ),
    );
  }

  /// تبني أقسام لوحة التحكم حسب صلاحيات المستخدم النشط — كل شخص يرى ما يحتاجه في عمله فقط
  List<Widget> _buildDashboardChildren(BuildContext context) {
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;

    // صلاحية الاطلاع على بيانات الجودة أو سلامة الغذاء
    final canViewQuality = session?.canViewReports ?? false;
    final canViewHealth = session?.canViewHealthReports ?? false;
    final canViewAnyReports = canViewQuality || canViewHealth;

    // صلاحيات سلسلة الاعتماد والتعديل
    final canApprove = (session?.canApproveQM ?? false) ||
        (session?.canApproveGM ?? false) ||
        (session?.canRejectReports ?? false);
    final canEdit = session?.canEditReports ?? false;

    // صلاحيات الورديات والنماذج الديناميكية والإدخال
    final canShifts = (session?.canViewShifts ?? false) || (session?.canManageShifts ?? false);
    final canDynamic =
        (session?.canFillDynamicReports ?? false) || (session?.canDesignDynamicReports ?? false);
    // ignore: unused_local_variable
    final canCreate = (session?.canCreateWaterReports ?? false) ||
        (session?.canCreateHygieneReports ?? false) ||
        (session?.canCreateRawMaterialReports ?? false);
    final canWorkersCommitment = session?.canViewDailyWorkersCommitment ?? false;
    final canFactoryCompliance = session?.canViewFactoryComplianceReport ?? false;

    final children = <Widget>[];

    // 1. Welcome Banner — للجميع
    children.add(_buildOverview(context));
    children.add(const SizedBox(height: 14));

    // 2. Factory Selector — للجميع
    children.add(_buildFactorySelector(context));
    children.add(const SizedBox(height: 14));

    // 3. Active Shift Status — للجميع
    children.add(_buildActiveShiftBanner(context));

    // 4. Timeframe Filter — لمن يطّلع على البيانات
    if (canViewAnyReports) {
      children.add(const SizedBox(height: 14));
      children.add(_buildTimeframeFilter(context));
    }

    // 5. Factory Comparison — لمن يطّلع على جودة جميع المصانع
    if (canViewQuality) {
      children.add(const SizedBox(height: 16));
      children.add(_buildFactoryComparisonCard(context));
    }

    // 6. Pending Approvals Alert — للمعتمدين ومن يصحّح التقارير المرفوضة
    if (canApprove || canEdit) {
      children.add(const SizedBox(height: 14));
      children.add(_buildApprovalAlert(context));
    }

    final canViewExecutiveCorrective = (session?.canApproveGM ?? false) ||
        (session?.canApproveQM ?? false) ||
        (session?.isAdmin ?? false) ||
        (session?.currentRole.value == UserRole.generalManager) ||
        (session?.currentRole.value == UserRole.factoryManager);

    // 6.5 Corrective Actions Card — للمدراء والمعتمدين التنفيذيين فقط
    if (canViewExecutiveCorrective) {
      children.add(const SizedBox(height: 14));
      children.add(_buildCorrectiveActionsCard(context));
    }

    // 7. Non-compliance Alert — تم حذفه بناء على رغبة المستخدم

    // 8. Quick Actions — لمن يستطيع التنفيذ (معطل مؤقتاً بالتعليق بناءً على رغبة المستخدم)
    // if (canCreate || canDynamic || canApprove || canWorkersCommitment || canFactoryCompliance) {
    //   children.add(const SizedBox(height: 14));
    //   children.add(_buildQuickActions(context));
    // }

    // 9. Key Metrics — لمن يطّلع على البيانات (معطل مؤقتاً بالتعليق بناءً على رغبة المستخدم)
    // if (canViewAnyReports) {
    //   children.add(const SizedBox(height: 24));
    //   children.add(const _SectionTitle(
    //       title: 'مؤشرات الأداء ومطابقة الجودة', icon: Icons.auto_awesome_rounded));
    //   children.add(const SizedBox(height: 12));
    //   children.add(_buildStats(context));
    // }

    // 10. Critical Water Parameters — لمن يطّلع على جودة المياه (معطل مؤقتاً بالتعليق بناءً على رغبة المستخدم)
    // if (canViewQuality) {
    //   children.add(const SizedBox(height: 20));
    //   children.add(_buildKeyParametersRadar(context));
    // }

    // 11. 7-Day Performance & Trends — لمشاهدي الجودة أو الورديات
    if (canViewQuality || canShifts) {
      children.add(const SizedBox(height: 20));
      children.add(_buildProductionCard());
    }

    // 12. Shifts Distribution — لصلاحيات الورديات
    if (canShifts) {
      children.add(const SizedBox(height: 20));
      children.add(_buildShiftDistributionCard());
    }

    // 12.5 Daily Workers Attendance & Shift Commitment — خاص بالإدارة
    if (canWorkersCommitment) {
      children.add(const SizedBox(height: 20));
      children.add(_buildWorkersCommitmentManagementCard(context));
    }

    // 12.6 Factory Reports Compliance & Analysis — خاص بالإدارة
    if (canFactoryCompliance) {
      children.add(const SizedBox(height: 20));
      children.add(_buildFactoryComplianceManagementCard(context));
    }

    // 13. Dynamic Reports Summary — لصلاحيات النماذج الديناميكية
    if (canDynamic) {
      children.add(const SizedBox(height: 20));
      children.add(_buildDynamicReportsCard(context));
    }

    // 14. Recent Activity — لمن يطّلع على البيانات
    if (canViewAnyReports) {
      children.add(const SizedBox(height: 20));
      children.add(_buildRecentActivityStream(context));
    }


    return children;
  }

  Widget _buildOverview(BuildContext context) {
    return Obx(() {
      final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
      final userName = session?.currentUserName.value ?? 'صلاح الجابري';
      final role = session?.currentRole.value ?? UserRole.qualitySpecialist;
      final roleTitle = session?.roleLabels[role] ?? 'أخصائي الجودة';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [AppColors.primaryDarkest, AppColors.primaryDark, AppColors.primaryMedium],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: -30,
              bottom: -50,
              child: Container(
                height: 130,
                width: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_outlined, color: Colors.white, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  roleTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Tajawal',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'مرحباً بك، $userName',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'المؤشرات التشغيلية ونسب مطابقة المياه ضمن النطاق الطبيعي.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 12,
                              height: 1.5,
                              fontFamily: 'Tajawal',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                      ),
                      child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 30),
                    ),
                  ],
                ),

              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildTimeframeFilter(BuildContext context) {
    final timeframes = [
      {'key': 'today', 'label': 'اليوم'},
      {'key': 'week', 'label': 'هذا الأسبوع'},
      {'key': 'month', 'label': 'هذا الشهر'},
      {'key': 'all', 'label': 'كافة السجلات'},
    ];

    return Obx(() {
      final current = controller.selectedTimeframe.value;

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: timeframes.map((tf) {
            final isSelected = current == tf['key'];
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.changeTimeframe(tf['key']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimary : AppColors.primaryDark) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      tf['label']!,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  /// محول اختيار المصنع (كافة المصانع | مصنع أرتل | مصنع سنحان)
  Widget _buildFactorySelector(BuildContext context) {
    return Obx(() {
      final session = UserSessionService.to;
      if (session.isBranchRestricted) {
        final bName = session.assignedBranchName;
        final bId = session.assignedBranchId;
        final isPlant2 = bId == 2;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isPlant2
                  ? const [Color(0xFF4A148C), Color(0xFF6A1B9A)]
                  : const [Color(0xFF003853), Color(0xFF006699)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.factory_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'نطاق الإشراف والبيانات المعتمدة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      bName,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white38),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'مقفل للمصنع',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      final selectedId = controller.selectedBranchId.value;

      final tabs = [
        {'id': 0, 'label': 'كافة المصانع', 'icon': Icons.corporate_fare_rounded},
        {'id': 1, 'label': 'مصنع أرتل (الرئيسي)', 'icon': Icons.factory_rounded},
        {'id': 2, 'label': 'مصنع سنحان (الثاني)', 'icon': Icons.factory_outlined},
      ];

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkBorder : AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: tabs.map((t) {
            final id = t['id'] as int;
            final isSelected = selectedId == id;
            final isPlant2 = id == 2;

            return Expanded(
              child: GestureDetector(
                onTap: () => controller.switchBranch(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: isPlant2
                                ? const [Color(0xFF6A1B9A), Color(0xFF8E24AA)]
                                : const [Color(0xFF003853), Color(0xFF007791)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isSelected ? null : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (isPlant2 ? const Color(0xFF8E24AA) : const Color(0xFF007791))
                                  .withValues(alpha: 0.28),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        t['icon'] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : AppColors.muted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          t['label'] as String,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.muted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  /// شريط الوردية النشطة الآن والموسم التشغيلي
  Widget _buildActiveShiftBanner(BuildContext context) {
    return Obx(() {
      final shiftName = controller.activeShiftName.value;
      final shiftTime = controller.activeShiftTime.value;
      final season = controller.currentSeasonName.value;
      final selectedId = controller.selectedBranchId.value;

      String factoryLabel = 'المصنع الحالي';
      if (selectedId == 1) {
        factoryLabel = 'مصنع أرتل';
      } else if (selectedId == 2) {
        factoryLabel = 'مصنع سنحان';
      } else {
        factoryLabel = 'متابعة المصنعين';
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF00A896).withValues(alpha: 0.35)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A896).withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00A896).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.schedule_rounded, color: Color(0xFF00A896), size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00A896).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.radar_rounded, size: 10, color: Color(0xFF00A896)),
                            SizedBox(width: 3),
                            Text(
                              'نشطة الآن',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00A896),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          factoryLabel,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$shiftName ($shiftTime)',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003853),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'الموسم: $season',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                      color: Colors.grey.shade500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => Get.toNamed(AppRoutes.shifts),
              icon: const Icon(Icons.tune_rounded, size: 13),
              label: const Text(
                'الورديات',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003853),
                side: BorderSide(color: Colors.grey.shade300),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      );
    });
  }

  /// بطاقة مقارنة أداء المصنعين (تظهر عند اختيار "كافة المصانع")
  Widget _buildFactoryComparisonCard(BuildContext context) {
    return Obx(() {
      if (controller.selectedBranchId.value != 0) return const SizedBox.shrink();
      final comp = controller.factoryComparison;
      if (comp.isEmpty) return const SizedBox.shrink();

      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF003853).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.compare_arrows_rounded, color: Color(0xFF003853), size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'مقارنة أداء المصنعين التشغيلي',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF003853),
                        ),
                      ),
                      Text(
                        'ملخص عينات الجودة ونسبة الامتثال لكل مصنع',
                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: comp.map((c) {
                final bId = c['branch_id'] as int;
                final isPlant1 = bId == 1;
                final bName = isPlant1 ? 'مصنع أرتل' : 'مصنع سنحان';
                final total = c['totalSamples'] ?? 0;
                final rate = (c['complianceRate'] as num?)?.toDouble() ?? 100.0;
                final brandColor = isPlant1 ? const Color(0xFF007791) : const Color(0xFF8E24AA);

                return Expanded(
                  child: Container(
                    margin: EdgeInsets.only(left: isPlant1 ? 5 : 0, right: isPlant1 ? 0 : 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: brandColor.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: brandColor.withValues(alpha: 0.22)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                bName,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: brandColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(Icons.factory_rounded, size: 15, color: brandColor),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$total عينة',
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF003853),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: rate >= 90 ? Colors.green.shade100 : Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${rate.toStringAsFixed(0)}% مطابقة',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: rate >= 90 ? Colors.green.shade800 : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (rate / 100).clamp(0.0, 1.0),
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                            minHeight: 5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => controller.switchBranch(bId),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: brandColor,
                              side: BorderSide(color: brandColor.withValues(alpha: 0.4)),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text(
                              'استعراض المصنع',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
    });
  }

  // ignore: unused_element
  Widget _buildKeyParametersRadar(BuildContext context) {
    return Obx(() {
      final params = controller.keyParameters;
      if (params.isEmpty) return const SizedBox.shrink();
      final isWide = MediaQuery.of(context).size.width > 700;

      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPanelHeader(
              title: 'رادار القياسات الكيميائية والفيزيائية',
              subtitle: 'أحدث قراءات الفحص المعملي المباشر ونطاق المطابقة',
              icon: Icons.science_rounded,
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isWide ? 4 : 2,
                childAspectRatio: isWide ? 1.6 : 1.55,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: params.length,
              itemBuilder: (ctx, i) {
                final p = params[i];
                final isCompliant = p['is_compliant'] == 1;
                final res = p['numeric_result'];
                final valStr = res != null ? (res is double ? res.toStringAsFixed(1) : '$res') : '-';
                final unit = p['unit'] ?? '';

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCompliant ? const Color(0xFFF6FBF9) : const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCompliant ? const Color(0xFFB7EB8F) : const Color(0xFFFFA39E),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            p['name_ar'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.ink,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isCompliant ? Colors.green.shade100 : Colors.red.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isCompliant ? Icons.check : Icons.close,
                              size: 10,
                              color: isCompliant ? Colors.green.shade800 : Colors.red.shade800,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            valStr,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: isCompliant ? AppColors.success : Colors.red.shade800,
                            ),
                          ),
                          if (unit.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text(
                              unit,
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        'المعيار: ${p['standard'] ?? "-"}',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 9,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildApprovalAlert(BuildContext context) {
    return Obx(() {
      final count = controller.pendingApprovalsCount.value;
      final role = Get.isRegistered<UserSessionService>()
          ? UserSessionService.to.currentRole.value
          : UserRole.qualityManager;

      String roleTitle;
      String actionMessage;
      Color cardColor;
      Color textColor;
      IconData alertIcon;

      if (role == UserRole.qualityManager) {
        roleTitle = 'مدير الجودة';
        actionMessage = 'لديك $count تقرير بانتظار اعتمادك ومراجعتك';
        cardColor = const Color(0xFFFFF8E1);
        textColor = const Color(0xFFB78103);
        alertIcon = Icons.approval_rounded;
      } else if (role == UserRole.factoryManager) {
        roleTitle = 'مدير المصنع';
        actionMessage = 'لديك $count تقرير بانتظار اعتمادك النهائي';
        cardColor = const Color(0xFFF3E5F5);
        textColor = const Color(0xFF6A1B9A);
        alertIcon = Icons.verified_user_rounded;
      } else {
        roleTitle = 'أخصائي الجودة';
        actionMessage = count > 0 ? 'لديك $count تقرير مرفوض بحاجة لمراجعتك' : 'لا توجد تقارير مرفوضة';
        cardColor = count > 0 ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
        textColor = count > 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32);
        alertIcon = count > 0 ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
      }

      if (count == 0) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFA5D6A7)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 22),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'جميع الفحوصات والتقارير معتمدة ومحدثة بالكامل',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showPendingApprovalsSheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'سجل الاعتماد',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: textColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: textColor.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: textColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(alertIcon, color: textColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'مركز الاعتمادات ($roleTitle)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: textColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    actionMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.88),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () => _showPendingApprovalsSheet(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                'معاينة',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    });
  }

  // ignore: unused_element
  Widget _buildQuickActions(BuildContext context) {
    final session = UserSessionService.to;
    final showInspection = session.canCreateWaterReports || session.canCreateHygieneReports ||
        session.canCreateRawMaterialReports ||
        session.canFillDynamicReports;
    final showBuilder = session.canDesignDynamicReports;
    final showDynamicManagement = session.canDesignDynamicReports || session.canFillDynamicReports;
    final showApprovals = session.canApproveQM || session.canApproveGM || session.canRejectReports;
    final showWorkersCommitment = session.canViewDailyWorkersCommitment;
    final showFactoryCompliance = session.canViewFactoryComplianceReport;

    if (!showInspection && !showBuilder && !showDynamicManagement && !showApprovals && !showWorkersCommitment && !showFactoryCompliance) {
      return const SizedBox.shrink();
    }

    final actionItems = <Widget>[];

    if (showInspection) {
      actionItems.add(_QuickActionCard(
        title: 'فحص فوري',
        subtitle: 'تعبئة تقرير جديد',
        icon: Icons.post_add_rounded,
        color: const Color(0xFF0288D1),
        onTap: () => _showNewInspectionModal(context),
      ));
    }
    if (showBuilder) {
      actionItems.add(_QuickActionCard(
        title: 'منشئ التقارير',
        subtitle: 'تصميم نموذج مخصص',
        icon: Icons.dashboard_customize_rounded,
        color: const Color(0xFF6A1B9A),
        onTap: () => Get.toNamed(AppRoutes.dynamicReportBuilder),
      ));
    }
    if (showDynamicManagement) {
      actionItems.add(_QuickActionCard(
        title: 'التقارير الديناميكية',
        subtitle: 'إدارة النماذج والسجلات',
        icon: Icons.table_chart_rounded,
        color: const Color(0xFF007791),
        onTap: () => Get.toNamed(AppRoutes.dynamicReportsManagement),
      ));
    }
    if (showApprovals) {
      actionItems.add(_QuickActionCard(
        title: 'مركز الاعتمادات',
        subtitle: 'استعراض السجلات المعلقة',
        icon: Icons.verified_outlined,
        color: const Color(0xFF2E7D32),
        onTap: () => _showPendingApprovalsSheet(context),
      ));
    }
    if (showWorkersCommitment) {
      actionItems.add(_QuickActionCard(
        title: 'التزام العمالة',
        subtitle: 'لوحة الورديات والبيان',
        icon: Icons.assignment_ind_rounded,
        color: const Color(0xFF003853),
        onTap: () => Get.to(() => DailyWorkersCommitmentView()),
      ));
    }
    if (showFactoryCompliance) {
      actionItems.add(_QuickActionCard(
        title: 'التزام المصانع',
        subtitle: 'التقارير والمتخلفة',
        icon: Icons.fact_check_rounded,
        color: const Color(0xFF007791),
        onTap: () => Get.to(() => const FactoryReportsComplianceView()),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'الإجراءات السريعة', icon: Icons.bolt_rounded),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (ctx, constraints) {
            int columns = constraints.maxWidth > 900
                ? actionItems.length
                : (constraints.maxWidth > 550 ? (actionItems.length > 3 ? 3 : 2) : 2);
            if (columns > actionItems.length) columns = actionItems.length;
            if (columns <= 0) columns = 1;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actionItems.map((card) {
                final itemWidth = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
                return SizedBox(
                  width: itemWidth.clamp(140.0, double.infinity),
                  child: card,
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildStats(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 768;

    final card1 = Obx(() => _StatCard(
      title: 'عينات المياه',
      value: '${controller.totalSamples.value}',
      caption: 'عينة مسجلة',
      icon: Icons.science_outlined,
      color: AppColors.primaryDark,
    ));

    final card2 = Obx(() => _StatCard(
      title: 'نسبة المطابقة',
      value: '${controller.complianceRate.value.toStringAsFixed(1)}%',
      caption: 'ضمن المواصفات',
      icon: Icons.verified_rounded,
      color: AppColors.success,
    ));

    final card3 = Obx(() => _StatCard(
      title: 'سجلات التقارير',
      value: '${controller.dynamicRecordsCount.value}',
      caption: '${controller.dynamicReportsCount.value} نموذج نشط',
      icon: Icons.library_books_outlined,
      color: const Color(0xFF007791),
    ));

    final card4 = Obx(() => _StatCard(
      title: 'التقارير المعتمدة',
      value: '${controller.dynamicApprovedCount.value}',
      caption: '${controller.dynamicPendingCount.value} قيد الاعتماد',
      icon: Icons.task_alt_rounded,
      color: const Color(0xFF2E7D32),
    ));

    if (isWide) {
      return Row(
        children: [
          Expanded(child: card1),
          const SizedBox(width: 12),
          Expanded(child: card2),
          const SizedBox(width: 12),
          Expanded(child: card3),
          const SizedBox(width: 12),
          Expanded(child: card4),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: 12),
            Expanded(child: card2),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: card3),
            const SizedBox(width: 12),
            Expanded(child: card4),
          ],
        ),
      ],
    );
  }

  Widget _buildProductionCard() {
    return Obx(() {
      final days = controller.weeklyDays;
      final max = controller.weeklyMaxCount.value;
      final trend = controller.weeklyTrendPercentage.value;
      final total = controller.thisWeekTotal.value;

      Color trendColor = AppColors.success;
      IconData trendIcon = Icons.trending_up_rounded;
      String trendText = 'تحسن مؤشر الفحوصات والإنتاج بنسبة +${trend.toStringAsFixed(0)}% عن الأسبوع السابق';

      if (trend < 0) {
        trendColor = Colors.orange.shade800;
        trendIcon = Icons.trending_down_rounded;
        trendText = 'انخفاض في عدد الفحوصات بنسبة ${trend.abs().toStringAsFixed(0)}% عن الأسبوع السابق';
      } else if (trend == 0) {
        trendColor = const Color(0xFF007791);
        trendIcon = Icons.trending_flat_rounded;
        trendText = 'استقرار معدل الفحوصات الأسبوعية بواقع $total عينة مسجلة';
      }

      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPanelHeader(
              title: 'حجم الفحوصات اليومية',
              subtitle: 'آخر 7 أيام (إجمالي: $total فحصاً مسجلاً)',
              icon: Icons.bar_chart_rounded,
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 158,
              child: days.isEmpty
                  ? const Center(child: Text('لا توجد بيانات للفترة المحددة', style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey)))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(days.length, (index) {
                        final d = days[index];
                        final count = d['count'] as int;
                        final isToday = d['isToday'] as bool;
                        final double normalizedVal = max > 0 ? (count / max).clamp(0.08, 1.0) : 0.08;

                        return _Bar(
                          value: normalizedVal,
                          label: d['dayName'] as String,
                          active: isToday,
                          count: count,
                        );
                      }),
                    ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: trendColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(trendIcon, color: trendColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trendText,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        color: trendColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildShiftDistributionCard() {
    return Obx(() {
      final list = controller.shiftsList;
      final s1 = controller.shift1Count.value;
      final s2 = controller.shift2Count.value;
      final s3 = controller.shift3Count.value;
      final total = list.isNotEmpty
          ? list.fold<int>(0, (sum, item) => sum + ((item['count'] as int?) ?? 0))
          : (s1 + s2 + s3);

      final colors = [
        const Color(0xFF0288D1),
        const Color(0xFF6A1B9A),
        const Color(0xFFE65100),
        const Color(0xFF00A896),
      ];

      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPanelHeader(
              title: 'توزيع الفحوصات حسب الورديات',
              subtitle: 'نشاط الفحص التشغيلي للورديات المعتمدة بالمصنع',
              icon: Icons.access_time_filled_rounded,
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (list.isNotEmpty)
                      ...list.asMap().entries.map((entry) {
                        final i = entry.key;
                        final shift = entry.value;
                        final count = (shift['count'] as int?) ?? 0;
                        final p = total > 0 ? (count / total) : 0.0;
                        if (p <= 0) return const SizedBox.shrink();
                        return Expanded(
                          flex: (p * 100).round().clamp(1, 100),
                          child: Container(color: colors[i % colors.length]),
                        );
                      })
                    else ...[
                      if (s1 > 0)
                        Expanded(
                          flex: total > 0 ? ((s1 / total) * 100).round().clamp(1, 100) : 1,
                          child: Container(color: const Color(0xFF0288D1)),
                        ),
                      if (s2 > 0)
                        Expanded(
                          flex: total > 0 ? ((s2 / total) * 100).round().clamp(1, 100) : 1,
                          child: Container(color: const Color(0xFF6A1B9A)),
                        ),
                      if (s3 > 0)
                        Expanded(
                          flex: total > 0 ? ((s3 / total) * 100).round().clamp(1, 100) : 1,
                          child: Container(color: const Color(0xFFE65100)),
                        ),
                    ],
                    if (total == 0)
                      Expanded(
                        child: Container(color: Colors.grey.shade300),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (list.isNotEmpty)
              Wrap(
                alignment: WrapAlignment.spaceAround,
                spacing: 12,
                runSpacing: 10,
                children: list.asMap().entries.map((entry) {
                  final i = entry.key;
                  final shift = entry.value;
                  return _buildShiftBadge(
                    name: shift['name'] ?? 'وردية',
                    time: '${shift['start_time'] ?? ""} - ${shift['end_time'] ?? ""}',
                    count: (shift['count'] as int?) ?? 0,
                    color: colors[i % colors.length],
                  );
                }).toList(),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildShiftBadge(
                    name: 'الوردية الأولى',
                    time: '06:00 - 14:00',
                    count: s1,
                    color: const Color(0xFF0288D1),
                  ),
                  _buildShiftBadge(
                    name: 'الوردية الثانية',
                    time: '14:00 - 22:00',
                    count: s2,
                    color: const Color(0xFF6A1B9A),
                  ),
                  _buildShiftBadge(
                    name: 'الوردية الثالثة',
                    time: '22:00 - 06:00',
                    count: s3,
                    color: const Color(0xFFE65100),
                  ),
                ],
              ),
          ],
        ),
      );
    });
  }

  Widget _buildShiftBadge({
    required String name,
    required String time,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count فحص',
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.bold,
            fontSize: 11,
            color: AppColors.ink,
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 9,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  /// بطاقة متابعة التزام العمالة والورديات (خاصة بالإدارة)
  Widget _buildWorkersCommitmentManagementCard(BuildContext context) {
    final now = DateTime.now();
    return Obx(() {
      final selectedBranchId = controller.selectedBranchId.value;
      final branchFilter = selectedBranchId == 0 ? null : selectedBranchId;

      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: Theme.of(context).brightness == Brightness.dark ? const [Color(0xFF0369A1), Color(0xFF0EA5E9)] : const [Color(0xFF003853), Color(0xFF007791)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF007791).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'متابعة التزام العمالة والورديات',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF382A02) : const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_rounded, size: 11, color: Color(0xFFB78103)),
                                        SizedBox(width: 3),
                                        Text(
                                          'خاص بالإدارة 👑',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB78103),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'متابعة الحضور وتوزيع الورديات ومطابقة النظافة الشخصية شهرياً',
                                style: TextStyle(fontFamily: 'Tajawal', color: AppColors.muted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => Get.to(() => DailyWorkersCommitmentView()),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                            label: const Text(
                              'عرض الكشف الكامل',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimary : const Color(0xFF003853),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isCompact) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Get.to(() => DailyWorkersCommitmentView()),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text(
                            'عرض الكشف الكامل',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853),
                            side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<WorkersCommitmentKPISummary>(
              future: DailyWorkersCommitmentService.instance.getKPISummary(
                year: now.year,
                month: now.month,
                branchId: branchFilter,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }

                final summary = snapshot.data ?? const WorkersCommitmentKPISummary(
                  totalRegisteredWorkers: 0,
                  totalAttendedWorkers: 0,
                  avgAttendanceRate: 0.0,
                  avgHygieneScore: 0.0,
                  totalShiftsCovered: 0,
                  targetWorkingDays: 0,
                );

                return Column(
                  children: [
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isWide = constraints.maxWidth > 550;
                        final kpi1 = _buildCommitmentMiniCard(
                          title: 'نسبة الحضور للشهر',
                          value: '${summary.avgAttendanceRate.toStringAsFixed(1)}%',
                          sub: '${summary.totalAttendedWorkers} من ${summary.totalRegisteredWorkers} عمال',
                          icon: Icons.how_to_reg_rounded,
                          color: const Color(0xFF007791),
                        );
                        final kpi2 = _buildCommitmentMiniCard(
                          title: 'مطابقة النظافة العامة',
                          value: '${summary.avgHygieneScore.toStringAsFixed(1)}%',
                          sub: 'متوسط الفحص الشخصي',
                          icon: Icons.verified_user_rounded,
                          color: AppColors.success,
                        );
                        final kpi3 = _buildCommitmentMiniCard(
                          title: 'إجمالي الورديات المنجزة',
                          value: '${summary.totalShiftsCovered}',
                          sub: 'صباحية / مسائية / ليلية',
                          icon: Icons.access_time_filled_rounded,
                          color: const Color(0xFFE65100),
                        );
                        final kpi4 = _buildCommitmentMiniCard(
                          title: 'أيام التفتيش المسجلة',
                          value: '${summary.targetWorkingDays}',
                          sub: 'يوم عمل خلال ${now.month}/${now.year}',
                          icon: Icons.calendar_today_rounded,
                          color: const Color(0xFF6A1B9A),
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(child: kpi1),
                              const SizedBox(width: 10),
                              Expanded(child: kpi2),
                              const SizedBox(width: 10),
                              Expanded(child: kpi3),
                              const SizedBox(width: 10),
                              Expanded(child: kpi4),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: kpi1),
                                const SizedBox(width: 10),
                                Expanded(child: kpi2),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: kpi3),
                                const SizedBox(width: 10),
                                Expanded(child: kpi4),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0B243A) : const Color(0xFF007791).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF0EA5E9).withValues(alpha: 0.3) : const Color(0xFF007791).withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF007791), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'يتم احتساب الحضور والورديات تلقائياً وحصرياً من تقارير فحص النظافة الشخصية المعتمدة.',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11.5,
                                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : const Color(0xFF003853),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            onPressed: () => Get.to(() => DailyWorkersCommitmentView()),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                            label: const Text(
                              'طباعة الكشف (A4)',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF007791),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCommitmentMiniCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(Get.context!).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.darkPrimaryLight : color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 15, color: isDark ? AppColors.darkPrimaryLight : color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.darkInk : AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 9.5,
              color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// بطاقة متابعة وتحليل التزام المصانع بالفحوصات والتقارير اليومية (خاصة بالإدارة)
  Widget _buildFactoryComplianceManagementCard(BuildContext context) {
    final now = DateTime.now();
    return Obx(() {
      final selectedBranchId = controller.selectedBranchId.value;
      final branchIdToQuery = selectedBranchId == 0 ? 1 : selectedBranchId;
      final branchName = selectedBranchId == 2 ? 'مصنع سنحان' : (selectedBranchId == 1 ? 'مصنع أرتل' : 'كافة المصانع');

      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 600;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: Theme.of(context).brightness == Brightness.dark ? const [Color(0xFF0369A1), Color(0xFF005B7F)] : const [Color(0xFF002B40), Color(0xFF005B7F)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF003853).withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.fact_check_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'تحليل التزام المصانع بالفحوصات',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF382A02) : const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.5)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.shield_rounded, size: 11, color: Color(0xFFB78103)),
                                        SizedBox(width: 3),
                                        Text(
                                          'خاص بالإدارة 👑',
                                          style: TextStyle(
                                            fontFamily: 'Tajawal',
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFB78103),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'متابعة الفحوصات المنجزة والتكرار والتقارير المتخلفة لـ $branchName اليوم',
                                style: const TextStyle(fontFamily: 'Tajawal', color: AppColors.muted, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!isCompact) ...[
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => Get.to(() => const FactoryReportsComplianceView()),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                            label: const Text(
                              'التحليل الكامل',
                              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimary : const Color(0xFF003853),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (isCompact) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Get.to(() => const FactoryReportsComplianceView()),
                          icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                          label: const Text(
                            'التحليل الكامل',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853),
                            side: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853)),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<FactoryDailyComplianceReport>(
              future: FactoryReportsComplianceService.instance.getFactoryDailyCompliance(
                date: now,
                branchId: branchIdToQuery,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      ),
                    ),
                  );
                }

                final rep = snapshot.data ?? FactoryDailyComplianceReport(
                  branchId: branchIdToQuery,
                  branchName: branchName,
                  date: now,
                  totalActiveReports: 0,
                  executedReportsCount: 0,
                  missedReportsCount: 0,
                  totalInspectionsCount: 0,
                  complianceRate: 0.0,
                  executedReports: [],
                  missedReports: [],
                  allReports: [],
                );

                return Column(
                  children: [
                    LayoutBuilder(
                      builder: (ctx, constraints) {
                        final isWide = constraints.maxWidth > 550;
                        final kpi1 = _buildCommitmentMiniCard(
                          title: 'نسبة الالتزام اليوم',
                          value: '${rep.complianceRate.toStringAsFixed(1)}%',
                          sub: rep.complianceGrade,
                          icon: Icons.pie_chart_rounded,
                          color: rep.complianceColor,
                        );
                        final kpi2 = _buildCommitmentMiniCard(
                          title: 'الفحوصات المنشأة',
                          value: '${rep.totalInspectionsCount}',
                          sub: 'سجلات مدخلة اليوم',
                          icon: Icons.repeat_rounded,
                          color: const Color(0xFF007791),
                        );
                        final kpi3 = _buildCommitmentMiniCard(
                          title: 'التقارير المنجزة',
                          value: '${rep.executedReportsCount}/${rep.totalActiveReports}',
                          sub: 'من إجمالي النماذج المفعلة',
                          icon: Icons.check_circle_outline_rounded,
                          color: AppColors.success,
                        );
                        final kpi4 = _buildCommitmentMiniCard(
                          title: 'التقارير المتخلفة',
                          value: '${rep.missedReportsCount}',
                          sub: rep.missedReportsCount > 0 ? 'لم تنفذ اليوم' : 'لا يوجد تقصير',
                          icon: Icons.warning_amber_rounded,
                          color: rep.missedReportsCount > 0 ? const Color(0xFFC62828) : Colors.grey,
                        );

                        if (isWide) {
                          return Row(
                            children: [
                              Expanded(child: kpi1),
                              const SizedBox(width: 10),
                              Expanded(child: kpi2),
                              const SizedBox(width: 10),
                              Expanded(child: kpi3),
                              const SizedBox(width: 10),
                              Expanded(child: kpi4),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: kpi1),
                                const SizedBox(width: 10),
                                Expanded(child: kpi2),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: kpi3),
                                const SizedBox(width: 10),
                                Expanded(child: kpi4),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Builder(
                      builder: (bCtx) {
                        final isDark = Theme.of(bCtx).brightness == Brightness.dark;
                        final alertBg = rep.missedReportsCount > 0
                            ? (isDark ? const Color(0xFF381215) : const Color(0xFFFFEBEE))
                            : (isDark ? const Color(0xFF0B291A) : const Color(0xFFE8F5E9));
                        final alertBorder = rep.missedReportsCount > 0
                            ? (isDark ? const Color(0xFFEF4444).withValues(alpha: 0.4) : const Color(0xFFFFCDD2))
                            : (isDark ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFA5D6A7));
                        final alertColor = rep.missedReportsCount > 0
                            ? (isDark ? const Color(0xFFFF8A80) : const Color(0xFFC62828))
                            : (isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32));
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: alertBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: alertBorder),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                rep.missedReportsCount > 0
                                    ? Icons.warning_amber_rounded
                                    : Icons.verified_rounded,
                                color: alertColor,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  rep.missedReportsCount > 0
                                      ? 'تنبيه إداري: يوجد ${rep.missedReportsCount} تقارير وفحوصات مفعلة لم يقم بها المصنع اليوم (${rep.missedReports.take(2).map((m) => m.reportName).join('، ')}...).'
                                      : 'تهانينا: التزام كامل بنسبة 100% — تم إجراء كافة الفحوصات والتقارير المقررة لهذا اليوم.',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11.5,
                                    color: alertColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: () => Get.to(() => const FactoryReportsComplianceView()),
                                icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                                label: const Text(
                                  'تقرير المصانع',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: alertColor,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }

  /// بطاقة الإجراءات التصحيحية — تعرض لمدير المصنع كل التقارير المرفوضة
  /// التي تتطلب قراراً أو متابعة، مع ملخص سبب الرفض والتأثير والإجراء والحالة.
  Widget _buildCorrectiveActionsCard(BuildContext context) {
    return Obx(() {
      final items = controller.correctiveActionItems;
      final count = controller.correctiveActionCount.value;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.18)),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC62828).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.build_circle, color: Color(0xFFC62828), size: 21),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (ctx) {
                          final isDark = Theme.of(ctx).brightness == Brightness.dark;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الإجراءات التصحيحية',
                                style: TextStyle(fontFamily: 'Tajawal', color: isDark ? AppColors.darkInk : AppColors.ink, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'تقارير مرفوضة تتطلب قراراً أو متابعة',
                                style: TextStyle(fontFamily: 'Tajawal', color: isDark ? AppColors.darkMuted : AppColors.muted, fontSize: 11),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFC62828).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC62828).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC62828),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 38, color: Colors.green.shade400),
                    const SizedBox(height: 8),
                    const Text(
                      'لا توجد إجراءات تصحيحية معلقة',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length > 5 ? 5 : items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  return _buildCorrectiveActionTile(context, item);
                },
              ),
            if (items.length > 5) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showAllCorrectiveActions(context),
                  icon: const Icon(Icons.list_alt, size: 16),
                  label: const Text(
                    'عرض كل الإجراءات التصحيحية',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFC62828),
                    side: const BorderSide(color: Color(0xFFC62828)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    });
  }

  Widget _buildCorrectiveActionTile(BuildContext context, Map<String, dynamic> item) {
    final status = item['approval_status'] as String? ?? 'Rejected';
    final statusColor = ApprovalStatus.color(status);
    final severity = item['severity_level'] as String?;
    final title = item['title'] as String? ?? 'تقرير';
    final reason = item['rejection_reason'] as String? ?? '';
    final correctiveAction = item['corrective_action'] as String? ?? '';
    final owner = item['corrective_owner'] as String? ?? '';

    return InkWell(
      onTap: () => controller.openPendingItem(item),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: statusColor.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ApprovalStatus.icon(status), size: 15, color: statusColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (severity != null && severity.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: SeverityLevel.color(severity).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      severity,
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: SeverityLevel.color(severity),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (reason.isNotEmpty)
              Text(
                'السبب: $reason',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.red.shade900, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            if (correctiveAction.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'الإجراء: $correctiveAction${owner.isNotEmpty ? " — $owner" : ""}',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.blue.shade900, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    ApprovalStatus.shortLabel(status),
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// عرض كل الإجراءات التصحيحية في نافذة منفصلة
  void _showAllCorrectiveActions(BuildContext context) {
    Get.bottomSheet(
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.build_circle, color: Color(0xFFC62828), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'جميع الإجراءات التصحيحية',
                      style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 16),
              Expanded(
                child: Obx(() {
                  final items = controller.correctiveActionItems;
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 54, color: Colors.green.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد إجراءات تصحيحية معلقة',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) => _buildCorrectiveActionTile(context, items[index]),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  isScrollControlled: true,
);
  }

  Widget _buildDynamicReportsCard(BuildContext context) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFF007791).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.table_view_rounded, color: Color(0xFF007791), size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(
                      builder: (ctx) {
                        final isDark = Theme.of(ctx).brightness == Brightness.dark;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'نظام التقارير المخصصة',
                              style: TextStyle(fontFamily: 'Tajawal', color: isDark ? AppColors.darkInk : AppColors.ink, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'متابعة النماذج الديناميكية والاعتمادات',
                              style: TextStyle(fontFamily: 'Tajawal', color: isDark ? AppColors.darkMuted : AppColors.muted, fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              PermissionGuard(
                permissionCode: SystemPermissions.designDynamicReports,
                child: TextButton(
                  onPressed: () => Get.toNamed(AppRoutes.dynamicReportsManagement),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('إدارة النماذج', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF007791))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Obx(() {
            final approved = controller.dynamicApprovedCount.value;
            final pending = controller.dynamicPendingCount.value;
            final rejected = controller.dynamicRejectedCount.value;
            final total = controller.dynamicRecordsCount.value;

            return Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildReportMiniStat('المعتمدة', '$approved', Colors.green.shade700, Icons.check_circle_outline),
                    _buildReportMiniStat('قيد المراجعة', '$pending', Colors.orange.shade800, Icons.pending_outlined),
                    _buildReportMiniStat('المرفوضة', '$rejected', Colors.red.shade700, Icons.highlight_off_rounded),
                    _buildReportMiniStat('الإجمالي', '$total', AppColors.primaryDark, Icons.folder_open_rounded),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReportMiniStat(String label, String val, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(val, style: TextStyle(fontFamily: 'Tajawal', fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildRecentActivityStream(BuildContext context) {
    return Obx(() {
      final items = controller.recentActivities;
      if (items.isEmpty) {
        return const SizedBox.shrink();
      }

      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPanelHeader(
              title: 'آخر السجلات المسجلة',
              subtitle: 'سجل الفحوصات والتقارير المكتملة مؤخراً',
              icon: Icons.history_rounded,
            ),
            const SizedBox(height: 14),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 14),
              itemBuilder: (ctx, i) {
                final item = items[i];
                final isDyn = item['type'] == 'dynamic';
                final isCompliant = item['is_compliant'] == true;

                return InkWell(
                  onTap: () => controller.openPendingItem(item),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: isCompliant ? Colors.green.shade50 : Colors.red.shade50,
                          child: Icon(
                            isCompliant ? Icons.check_rounded : Icons.priority_high_rounded,
                            size: 16,
                            color: isCompliant ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] ?? 'فحص',
                                style: const TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    isDyn ? 'تقرير مخصص' : (item['category'] ?? 'فحص مياه'),
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (item['branch_name'] != null && (item['branch_name'] as String).isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: (item['branch_id'] as int? ?? 1) == 2
                                            ? Colors.purple.shade50
                                            : Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        (item['branch_id'] as int? ?? 1) == 2 ? 'مصنع سنحان' : 'مصنع أرتل',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: (item['branch_id'] as int? ?? 1) == 2
                                              ? Colors.purple.shade800
                                              : const Color(0xFF003853),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (item['shift_name'] != null && (item['shift_name'] as String).isNotEmpty) ...[
                                    const SizedBox(width: 4),
                                    Text(
                                      '• ${item['shift_name']}',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 9.5,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    });
  }

  void _showPendingApprovalsSheet(BuildContext context) {
    Get.bottomSheet(
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.pending_actions_rounded, color: Colors.amber.shade900, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'التقارير والسجلات المعلقة',
                      style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                  Obx(() => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Text(
                      '${controller.pendingApprovalsCount.value} معلق',
                      style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                    ),
                  )),
                ],
              ),
              const Divider(height: 24),
              Expanded(
                child: Obx(() {
                  if (controller.pendingItems.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline_rounded, size: 54, color: Colors.green.shade400),
                          const SizedBox(height: 12),
                          const Text(
                            'لا توجد تقارير معلقة بانتظار الاعتماد',
                            style: TextStyle(fontFamily: 'Tajawal', fontSize: 15, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: controller.pendingItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, index) {
                      final item = controller.pendingItems[index];
                      final isDynamic = item['type'] == 'dynamic';
                      final status = item['approval_status'] as String? ?? '';
                      String statusText = 'قيد الاعتماد';
                      Color statusColor = Colors.orange.shade800;
                      if (status == 'Pending_QM') {
                        statusText = 'بانتظار اعتماد مدير الجودة';
                        statusColor = Colors.orange.shade800;
                      } else if (status == 'Pending_GM') {
                        statusText = 'بانتظار اعتماد مدير المصنع';
                        statusColor = Colors.purple.shade800;
                      } else if (status == 'Pending_GM_Decision') {
                        statusText = 'بانتظار قرار مدير المصنع على الإجراء التصحيحي';
                        statusColor = Colors.indigo.shade800;
                      } else if (status == 'Corrective_In_Progress') {
                        statusText = 'الإجراء التصحيحي قيد التنفيذ';
                        statusColor = Colors.blue.shade800;
                      } else if (status == 'Rejected_By_GM') {
                        statusText = 'مرفوض نهائياً — انتهاء دورة الاعتماد';
                        statusColor = Colors.red.shade900;
                      } else if (status == 'Awaiting_Micro_Results') {
                        statusText = 'معتمد مبدئياً — بانتظار نتائج الميكروبيولوجي';
                        statusColor = Colors.teal.shade800;
                      } else if (status == 'Pending_Micro_QM') {
                        statusText = 'بانتظار اعتماد نتائج الميكروبيولوجي (مدير الجودة)';
                        statusColor = Colors.orange.shade800;
                      } else if (status == 'Pending_Micro_GM') {
                        statusText = 'بانتظار اعتماد نتائج الميكروبيولوجي (مدير المصنع)';
                        statusColor = Colors.purple.shade800;
                      } else if (status == 'Rejected') {
                        statusText = 'مرفوض — بحاجة لتوثيق إجراء تصحيحي';
                        statusColor = Colors.red.shade800;
                      } else if (status == 'Closed') {
                        statusText = 'معتمد بعد إجراء تصحيحي';
                        statusColor = Colors.green.shade800;
                      }

                      return Material(
                        color: Colors.grey.shade50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isDynamic
                                ? DynamicReportColorHelper.getColorByKey(
                                    item['icon']?.toString(),
                                    item['report_id'] as int?,
                                    item['title']?.toString(),
                                  ).withValues(alpha: 0.12)
                                : AppColors.primaryLightest,
                            child: Icon(
                              isDynamic ? DynamicReport.getIconData(item['icon']?.toString()) : Icons.science_outlined,
                              color: isDynamic
                                  ? DynamicReportColorHelper.getColorByKey(
                                      item['icon']?.toString(),
                                      item['report_id'] as int?,
                                      item['title']?.toString(),
                                    )
                                  : AppColors.primaryDark,
                            ),
                          ),
                          title: Text(
                            item['title'] ?? 'تقرير',
                            style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                statusText,
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            Get.back();
                            controller.openPendingItem(item);
                          },
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  isScrollControlled: true,
);
  }

  void _showNewInspectionModal(BuildContext context) async {
    final dynReports = await DynamicReportsApiService.to.getTemplates();

    if (!context.mounted) return;

    Get.bottomSheet(
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
            decoration: BoxDecoration(
               color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'بدء فحص أو تعبئة تقرير جديد',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'اختر التقرير المطلوب تعبئته لإدخال القراءات وحفظها:',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
              ),
              const Divider(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    if (UserSessionService.to.canCreateWaterReports ||
                        UserSessionService.to.canCreateHygieneReports) ...[
                      const Text('الفحوصات القياسية الأساسية', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      if (UserSessionService.to.canCreateWaterReports) ...[
                        _buildInspectionChoiceItem(context,
                          icon: Icons.water_drop_outlined,
                          color: const Color(0xFF0288D1),
                          title: 'تقرير فحص المياه الخام',
                          subtitle: 'فحوصات الآبار والخطوط قبل المعالجة',
                          onTap: () {
                            Get.back();
                            Get.to(() => RawWaterEntryPage());
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildInspectionChoiceItem(context,
                          icon: Icons.local_drink_outlined,
                          color: const Color(0xFF2E7D32),
                          title: 'تقرير فحص المنتج النهائي',
                          subtitle: 'فحوصات خطوط التعبئة وعبوات المياه',
                          onTap: () {
                            Get.back();
                            Get.to(() => FinalProductEntryPage());
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (UserSessionService.to.canCreateHygieneReports)
                        _buildInspectionChoiceItem(context,
                          icon: Icons.cleaning_services_outlined,
                          color: const Color(0xFF6A1B9A),
                          title: 'تقرير فحص النظافة العامة',
                          subtitle: 'فحص نظافة صالات الإنتاج والعاملين والمعدات',
                          onTap: () {
                            Get.back();
                            Get.to(() => HygieneReportView());
                          },
                        ),
                    ],
                    if (dynReports.isNotEmpty && (UserSessionService.to.canFillDynamicReports || dynReports.any((r) => UserSessionService.to.canFillDynamicReport(r.id, r.categoryId)))) ...[
                      const SizedBox(height: 16),
                      const Text('التقارير الديناميكية المخصصة', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      ...dynReports.where((r) => UserSessionService.to.canFillDynamicReport(r.id, r.categoryId)).map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildInspectionChoiceItem(context,
                          icon: r.iconData,
                          color: const Color(0xFF007791),
                          title: r.name,
                          subtitle: r.description?.isNotEmpty == true ? r.description! : 'تقرير مخصص',
                          onTap: () {
                            Get.back();
                            Get.toNamed(AppRoutes.dynamicReportForm, arguments: r.id);
                          },
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
  isScrollControlled: true,
);
  }

  Widget _buildInspectionChoiceItem(BuildContext context,{
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primaryLightest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Builder(
          builder: (ctx) => Icon(icon, size: 17, color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkPrimaryLight : AppColors.primaryDark),
        ),
      ),
      const SizedBox(width: 8),
      Builder(
        builder: (ctx) => Text(
          title,
          style: TextStyle(
            fontFamily: 'Tajawal',
            color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String title, value, caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: isDark ? AppColors.darkMuted : AppColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          Text(
            caption,
            style: TextStyle(
              fontFamily: 'Tajawal',
              color: isDark ? AppColors.darkMuted : AppColors.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Builder(
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: isDark ? 0.02 : 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? AppColors.darkInk : AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 10,
                            color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.value,
    required this.label,
    required this.active,
    required this.count,
  });

  final double value;
  final String label;
  final bool active;
  final int count;

  @override
  Widget build(BuildContext context) {
    final gradient = active
        ? const LinearGradient(
            colors: [Color(0xFF20B486), AppColors.success],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          )
        : const LinearGradient(
            colors: [AppColors.primaryDark, AppColors.primaryMedium],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          );

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (count > 0)
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: active ? AppColors.success : AppColors.muted,
                ),
              )
            else
              const SizedBox(height: 12),
            const SizedBox(height: 4),
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: 18,
                  height: 104 * value,
                  decoration: BoxDecoration(
                    gradient: gradient,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              active ? '$label (اليوم)' : label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                color: active ? AppColors.success : AppColors.muted,
                fontSize: 10,
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

