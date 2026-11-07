import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_assets.dart';
import '../constants/app_modules.dart';
import '../models/role_model.dart';
import '../widgets/ds/ds.dart';
import 'dashboard_view.dart';
import 'reports_view.dart';
import 'quality_management_view.dart';
import '../widgets/water_background.dart';
import 'shifts_view.dart';
import 'settings_view.dart';
import 'health_affairs_view.dart';

import '../widgets/notification_bell.dart';
import '../widgets/sync_status_indicator.dart';
import '../widgets/permission_guard.dart';
import '../services/biometric_settings_service.dart';
import '../services/user_session_service.dart';
import '../services/notification_service.dart';
import '../routes/app_routes.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  /// الوحدات المرئية للمستخدم الحالي بناءً على صلاحياته
  List<HomeModule> get _visibleModules {
    final session = UserSessionService.to;
    return HomeModule.values.where((m) => session.canAccessModule(m)).toList();
  }

  Widget _pageForModule(HomeModule module) {
    switch (module) {
      case HomeModule.dashboard:
        return DashboardView();
      case HomeModule.reports:
        return ReportsView();
      case HomeModule.quality:
        return const QualityManagementView();
      case HomeModule.health:
        return HealthAffairsView();
      case HomeModule.shifts:
        return const ShiftsView();
      case HomeModule.settings:
        return const SettingsView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // إعادة البناء فوراً عند تغيير المستخدم/الدور النشط لتطبيق الإخفاء
      UserSessionService.to.currentUser.value;

      final modules = _visibleModules;
      if (modules.isEmpty) {
        return const _NoAccessScreen();
      }
      final clampedIndex = _currentIndex.clamp(0, modules.length - 1);
      if (clampedIndex != _currentIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _currentIndex = clampedIndex);
        });
      }
      final currentTitle = modules[clampedIndex].title;

      return LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 950;

          if (isDesktop) {
            return Scaffold(
              key: _scaffoldKey,
              resizeToAvoidBottomInset: false,
              backgroundColor: AppColors.canvas,
              body: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  children: [
                    // 1. Permanent Desktop Sidebar
                    _buildSidebar(isPermanent: true),

                    // 2. Main Desktop Content Area
                    Expanded(
                      child: Stack(
                        children: [
                          const Positioned.fill(child: WaterBackground()),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.center,
                                  colors: [
                                    AppColors.primaryDark.withValues(alpha: 0.94),
                                    AppColors.primaryMedium.withValues(alpha: 0.70),
                                    AppColors.canvas.withValues(alpha: 0.12),
                                  ],
                                  stops: const [0, 0.22, 0.55],
                                ),
                              ),
                            ),
                          ),

                          // Desktop Modern Top Bar
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: SafeArea(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: modules[clampedIndex].color.withValues(alpha: 0.25),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(modules[clampedIndex].icon, color: Colors.white, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          currentTitle,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20,
                                            fontFamily: 'Tajawal',
                                          ),
                                        ),
                                      ),
                                      const SyncStatusIndicator(),
                                      const SizedBox(width: 8),
                                      const NotificationBell(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Full-Height Desktop Content (no bottom floating nav bar!)
                          Positioned.fill(
                            top: 90,
                            child: IndexedStack(
                              index: clampedIndex,
                              children: modules.map(_pageForModule).toList(),
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

          // Mobile / Small Screen Layout
          return Scaffold(
            key: _scaffoldKey,
            resizeToAvoidBottomInset: false,
            backgroundColor: AppColors.canvas,
            drawer: _buildSidebar(isPermanent: false),
            body: Stack(
              children: [
                const Positioned.fill(child: WaterBackground()),

                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          AppColors.primaryDark.withValues(alpha: 0.94),
                          AppColors.primaryMedium.withValues(alpha: 0.70),
                          AppColors.canvas.withValues(alpha: 0.12),
                        ],
                        stops: const [0, 0.22, 0.55],
                      ),
                    ),
                  ),
                ),

                // Mobile Header
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1150),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                          child: Directionality(
                            textDirection: TextDirection.rtl,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.menu_rounded, color: Colors.white),
                                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      currentTitle,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                  const SyncStatusIndicator(),
                                  const SizedBox(width: 4),
                                  const NotificationBell(),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Mobile Main Content Page
                Positioned.fill(
                  top: 104,
                  child: IndexedStack(
                    index: clampedIndex,
                    children: modules.map(_pageForModule).toList(),
                  ),
                ),

                // Floating Navigation Bar (Mobile only)
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _buildFloatingNavBar(modules, clampedIndex),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  Widget _buildFloatingNavBar(List<HomeModule> modules, int currentIndex) {
    final count = modules.length;
    final barHeight = count == 1 ? 0.0 : 75.0;

    return SizedBox(
      height: count == 1 ? 0 : 95, // 75 for the bar + 20 for the protruding circle
      child: count == 1
          ? const SizedBox.shrink()
          : Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // 1. Background Bar
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: barHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryDark.withValues(alpha: 0.08),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. The Moving Glowing Circle
                Positioned(
                  top: 0,
                  bottom: 20, // Push it up by 20 to protrude
                  left: 0,
                  right: 0,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutBack,
                      alignment: Alignment(_getAlignmentX(currentIndex, count), 0),
                      child: FractionallySizedBox(
                        widthFactor: 1 / count,
                        child: Center(
                          child: Container(
                            width: 65,
                            height: 65,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primaryDark,
                                  AppColors.primaryMedium,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryMedium.withValues(alpha: 0.5),
                                  blurRadius: 16,
                                  spreadRadius: 4,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder: (child, animation) =>
                                  ScaleTransition(scale: animation, child: child),
                              child: Icon(
                                modules[currentIndex].icon,
                                key: ValueKey<int>(currentIndex),
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. The Clickable Icons Row
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: barHeight,
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      children: [
                        for (var i = 0; i < count; i++)
                          Expanded(
                            child: _buildNavItem(i, modules[i].icon, () {
                              setState(() => _currentIndex = i);
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// حساب موضع المؤشر المتوهج أفقياً بناءً على موقعه ضمن الوحدات المرئية (RTL)
  double _getAlignmentX(int index, int count) {
    if (count <= 1) return 0.0;
    // في RTL: المؤشر الأول على أقصى اليمين (1.0) والأخير على أقصى اليسار (-1.0)
    return 1.0 - (2.0 * index / (count - 1));
  }

  Widget _buildNavItem(int index, IconData icon, VoidCallback onTap) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 75,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: isSelected ? 0.0 : 1.0, // Hide the grey icon if selected
            child: Icon(icon, color: const Color(0xFF94A3B8), size: 26),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar({bool isPermanent = false}) {
    final session = UserSessionService.to;
    final notif = NotificationService.to;
    final modules = _visibleModules;

    final content = Column(
      children: [
        // 1. Luxury Gradient Header & Profile Card
        _buildDrawerHeader(session, isPermanent: isPermanent),

        // 2. Scrollable Navigation List
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              if (modules.isNotEmpty) ...[
                _buildDrawerSectionTitle('الأقسام التشغيلية'),
                const SizedBox(height: 6),
                for (final module in modules)
                  if (module != HomeModule.settings)
                    _buildDrawerModuleItem(
                      module: module,
                      visibleModules: modules,
                      isPermanent: isPermanent,
                    ),
              ],

              // التقارير الديناميكية تُخفى تماماً لمن لا يملك صلاحية التصميم
              PermissionGuard(
                permissionCode: SystemPermissions.designDynamicReports,
                fallback: const SizedBox.shrink(),
                child: _buildDrawerActionItem(
                  title: 'التقارير الديناميكية',
                  subtitle: 'منشئ التقارير والنماذج',
                  icon: Icons.dynamic_form_rounded,
                  color: const Color(0xFF00BFA5),
                  onTap: () {
                    if (!isPermanent) Get.back();
                    Get.toNamed(AppRoutes.dynamicReportsManagement);
                  },
                ),
              ),

              const SizedBox(height: 16),
              _buildDrawerSectionTitle('النظام والحساب'),
              const SizedBox(height: 6),
              Obx(() {
                final unread = notif.unreadCount.value;
                return _buildDrawerActionItem(
                  title: 'مركز الإشعارات',
                  icon: Icons.notifications_active_rounded,
                  color: const Color(0xFF0288D1),
                  badge: unread > 0 ? '$unread' : null,
                  badgeColor: Colors.redAccent,
                  onTap: () {
                    if (!isPermanent) Get.back();
                    NotificationBell.showNotificationsSheet(context);
                  },
                );
              }),
              _buildBiometricToggleItem(),
              if (modules.contains(HomeModule.settings))
                _buildDrawerModuleItem(
                  module: HomeModule.settings,
                  visibleModules: modules,
                  titleOverride: 'إعدادات النظام',
                  isPermanent: isPermanent,
                ),
            ],
          ),
        ),

        // 3. Modern Footer with Logout
        _buildDrawerFooter(),
      ],
    );

    if (isPermanent) {
      return Container(
        width: 290,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(-2, 0),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: content,
        ),
      );
    }

    return Drawer(
      width: 320,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(32)),
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      child: content,
    );
  }

  /// عنصر درج مرتبط بوحدة رئيسية — يختفي إن لم تكن الوحدة مرئية للمستخدم
  Widget _buildDrawerModuleItem({
    required HomeModule module,
    required List<HomeModule> visibleModules,
    String? titleOverride,
    bool isPermanent = false,
  }) {
    final index = visibleModules.indexOf(module);
    if (index < 0) return const SizedBox.shrink();

    return _buildDrawerItem(
      index: index,
      title: titleOverride ?? module.title,
      icon: module.icon,
      color: module.color,
      isPermanent: isPermanent,
    );
  }

  Widget _buildDrawerHeader(UserSessionService session, {bool isPermanent = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        left: 20,
        right: 20,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF031B4E), // Deep luxury navy
            Color(0xFF0A3B8B),
            Color(0xFF007791), // Water cyan
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33031B4E),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo & Company Info Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Image.asset(
                  AppAssets.logo,
                  height: 38,
                  width: 38,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.water_drop,
                    color: Color(0xFF0D47A1),
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مصنع مياه وادي العين',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'نظام مراقبة وضمان الجودة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Active User & Role Glass Card
          Obx(() {
            final activeRole = session.currentRole.value;
            final roleName = session.roleTitle;
            final userName = session.currentUserName.value;
            final roleColor = session.roleColor;
            final roleIcon = session.roleIcon;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: roleColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                      child: Icon(roleIcon, key: ValueKey(activeRole), color: roleColor, size: 20),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                          child: Text(
                            userName,
                            key: ValueKey(userName),
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                            child: Text(
                              roleName,
                              key: ValueKey(roleName),
                              style: const TextStyle(
                                fontFamily: 'Tajawal',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDrawerSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required int index,
    required String title,
    required IconData icon,
    required Color color,
    bool isPermanent = false,
  }) {
    final isSelected = _currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: isSelected ? AppColors.primaryDark : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        elevation: isSelected ? 4 : 0,
        shadowColor: isSelected ? AppColors.primaryDark.withValues(alpha: 0.3) : Colors.transparent,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withValues(alpha: 0.2) : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
              color: isSelected ? Colors.white : const Color(0xFF1E293B),
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 14)
              : null,
          onTap: () {
            if (!isPermanent) Get.back();
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }

  /// عنصر تفعيل/تعطيل البصمة لتسجيل الدخول السريع (اختياري للمستخدم)
  Widget _buildBiometricToggleItem() {
    return FutureBuilder<bool>(
      future: BiometricSettingsService.instance.isEnabled(),
      builder: (context, snapshot) {
        final enabled = snapshot.data ?? false;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          child: ListTile(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (enabled ? const Color(0xFF2E7D32) : Colors.grey).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                color: enabled ? const Color(0xFF2E7D32) : Colors.grey,
                size: 20,
              ),
            ),
            title: Text(
              'تسجيل الدخول بالبصمة',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF1E293B),
              ),
            ),
            subtitle: Text(
              enabled ? 'مفعّلة — سيُطلب مسح البصمة عند الدخول' : 'معطّلة — تسجيل دخول يدوي',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
            trailing: Switch(
              value: enabled,
              activeThumbColor: const Color(0xFF2E7D32),
              onChanged: (newValue) async {
                await BiometricSettingsService.instance.setEnabled(newValue);
                Get.snackbar(
                  newValue ? 'تم التفعيل' : 'تم التعطيل',
                  newValue
                      ? 'ستظهر البصمة كخيار لتسجيل الدخول السريع'
                      : 'سيتم تسجيل الدخول يدوياً في المرة القادمة',
                  backgroundColor: newValue ? Colors.green : Colors.grey,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 2),
                );
                // إعادة بناء السايد بار لإظهار الحالة الجديدة
                if (mounted) setState(() {});
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerActionItem({
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    String? badge,
    Color? badgeColor,
    required VoidCallback onTap,
  }) {    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : const Icon(Icons.arrow_back_ios_rounded, color: Colors.grey, size: 14),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surface,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        children: [
          // Version info
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.verified_outlined, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text(
                'إصدار 2.5.0 • مياه وادي العين',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Logout button
          InkWell(
            onTap: () => _confirmLogout(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'تسجيل الخروج',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout() {
    AppDialog.confirm(
      context: context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
      confirmLabel: 'خروج',
      cancelLabel: 'إلغاء',
      confirmColor: Colors.redAccent,
      onConfirm: () {
        Get.back(); // close drawer if open
        Get.offAllNamed(AppRoutes.login);
      },
    );
  }
}

class NotificationBellSheetContent extends StatelessWidget {
  const NotificationBellSheetContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const NotificationBell();
  }
}

/// تُعرض إذا لم يملك المستخدم أية وحدة مرئية (نادر، يدل على خطأ في إعداد الدور)
class _NoAccessScreen extends StatelessWidget {
  const _NoAccessScreen();

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 18),
                Text(
                  'لا توجد أقسام متاحة لحسابك',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'حسابك لا يملك صلاحية الدخول لأي قسم من النظام. يرجى التواصل مع مسؤول النظام.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 13,
                    height: 1.6,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 24),
                AppButton.primary(
                  label: 'تسجيل الخروج',
                  icon: Icons.logout_rounded,
                  color: Colors.redAccent,
                  onPressed: () => UserSessionService.to.logout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
