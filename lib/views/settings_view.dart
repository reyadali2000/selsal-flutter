import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../routes/app_routes.dart';
import '../services/theme_service.dart';
import '../services/user_database_service.dart';
import '../services/user_session_service.dart';
import '../services/user_signature_service.dart';
import '../widgets/user_signature_pad_dialog.dart';


class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = UserSessionService.to;
    // الوحدات الإدارية المتاحة للمستخدم الحالي (تُخفى الأقسام بأكملها إن خلت)
    final adminTilesVisible = session.canManageUsers ||
        session.canManageRoles ||
        session.canDesignDynamicReports;
    final qualityTilesVisible = session.canManageSettings;
    final packagesTilesVisible = session.canManageProducts;
    final workersTilesVisible = session.canManageDailyWorkers;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(left: 18, right: 18, top: 8, bottom: 120),
            children: [
              _buildUserProfileCard(context),
              const SizedBox(height: 16),
              _buildQuickStatusRow(context),
          if (adminTilesVisible) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              title: 'إدارة النظام والأمان',
              icon: Icons.admin_panel_settings_rounded,
              color: const Color(0xFF003853),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context: context,
              children: _interleaveWithDividers([
                if (session.canManageUsers)
                  _buildModernTile(
                    title: 'إدارة حسابات المستخدمين',
                    subtitle: 'إضافة وتعديل حسابات الكادر وتعيين الصلاحيات',
                    icon: Icons.people_alt_rounded,
                    gradientColors: const [Color(0xFF007791), Color(0xFF00A896)],
                    onTap: () => Get.toNamed(AppRoutes.usersManagement),
                  ),
                if (session.canManageRoles)
                  _buildModernTile(
                    title: 'إدارة الأدوار والصلاحيات المخصصة',
                    subtitle: 'إنشاء مسميات وظيفية مخصصة وتحديد الصلاحيات بدقة',
                    icon: Icons.shield_rounded,
                    gradientColors: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                    badgeText: 'مخصص',
                    badgeColor: const Color(0xFF2E7D32),
                    onTap: () => Get.toNamed(AppRoutes.rolesManagement),
                  ),
                if (session.canDesignDynamicReports)
                  _buildModernTile(
                    title: 'قوالب التقارير الديناميكية',
                    subtitle: 'بناء وتخصيص نماذج الفحص الميداني والمختبري',
                    icon: Icons.dashboard_customize_rounded,
                    gradientColors: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    onTap: () => Get.toNamed(AppRoutes.dynamicReportsManagement),
                  ),

              ]),
            ),
          ],
          if (qualityTilesVisible) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              title: 'معايير الجودة والمصنع',
              icon: Icons.biotech_rounded,
              color: const Color(0xFF007791),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context: context,
              children: [
                _buildModernTile(
                  title: 'المعايير والمواصفات القياسية (SFDA / SASO)',
                  subtitle: 'حدود TDS، الكلور، الرقم الهيدروجيني pH، والبرومات',
                  icon: Icons.science_rounded,
                  gradientColors: const [Color(0xFF2E7D32), Color(0xFF43A047)],
                  onTap: () => _showStandardsDialog(context),
                ),
                _buildDivider(),
                _buildModernTile(
                  title: 'المحطات وخطوط الإنتاج',
                  subtitle: 'إدارة خطوط التعبئة ومحطات التناضح العكسي RO',
                  icon: Icons.factory_rounded,
                  gradientColors: const [Color(0xFFE65100), Color(0xFFFB8C00)],
                  onTap: () => _showPlantInfoDialog(context),
                ),
              ],
            ),
          ],
          if (packagesTilesVisible) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              title: 'العبوات والمصانع',
              icon: Icons.water_drop_rounded,
              color: const Color(0xFF00838F),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context: context,
              children: [
                _buildModernTile(
                  title: 'إدارة العبوات وربطها بالمصانع',
                  subtitle: 'تخصيص أحجام العبوات وتعيين المصنع لكل عبوة (مصنع أرتل / مصنع سنحان)',
                  icon: Icons.inventory_2_rounded,
                  gradientColors: const [Color(0xFF00838F), Color(0xFF00ACC1)],
                  badgeText: 'جديد',
                  badgeColor: const Color(0xFF2E7D32),
                  onTap: () => Get.toNamed(AppRoutes.packagesManagement),
                ),
              ],
            ),
          ],
          if (workersTilesVisible) ...[
            const SizedBox(height: 24),
            _buildSectionHeader(
              title: 'العمالة اليومية',
              icon: Icons.engineering_rounded,
              color: const Color(0xFF5D4037),
            ),
            const SizedBox(height: 12),
            _buildSettingsCard(
              context: context,
              children: [
                _buildModernTile(
                  title: 'سجل العمالة اليومية',
                  subtitle: 'إضافة العمال اليوميين وربطهم بالمصانع — مصدر الاقتراحات التلقائية في فحص النظافة الشخصية',
                  icon: Icons.engineering_rounded,
                  gradientColors: const [Color(0xFF5D4037), Color(0xFF8D6E63)],
                  badgeText: 'جديد',
                  badgeColor: const Color(0xFF2E7D32),
                  onTap: () => Get.toNamed(AppRoutes.dailyWorkersManagement),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'المظهر والعرض',
            icon: Icons.dark_mode_rounded,
            color: Colors.indigo.shade800,
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            context: context,
            children: [
              Obx(() {
                final isDark = ThemeService.to.isDarkMode.value;
                return SwitchListTile(
                  value: isDark,
                  onChanged: (v) => ThemeService.to.setDarkMode(v),
                  activeColor: isDark ? AppColors.darkPrimaryLight : AppColors.primaryDark,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  secondary: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          isDark
                              ? const Color(0xFF1A237E)
                              : const Color(0xFF007791),
                          isDark
                              ? const Color(0xFF3949AB)
                              : const Color(0xFF00ACC1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'الوضع الليلي',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    isDark
                        ? 'مفعّل — خلفيات داكنة مريحة للعين'
                        : 'معطّل — الوضع الفاتح الافتراضي',
                    style: const TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(
            title: 'أمان الحساب والجلسة',
            icon: Icons.lock_person_rounded,
            color: Colors.blueGrey.shade800,
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            context: context,
            children: _interleaveWithDividers([
              if (session.canManageSignature)
                _buildModernTile(
                  title: 'التوقيع الرقمي المعتمد',
                  subtitle: 'رفع صورة توقيع PNG معزولة الخلفية أو رسم توقيعك للتقارير',
                  icon: Icons.draw_rounded,
                  gradientColors: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  onTap: () => _showMySignatureDialog(context),
                ),
              if (session.canChangePassword)
                _buildModernTile(
                  title: 'تغيير كلمة المرور',
                  subtitle: 'تحديث كلمة مرور حسابك للدخول للنظام',
                  icon: Icons.password_rounded,
                  gradientColors: const [Color(0xFF37474F), Color(0xFF546E7A)],
                  onTap: () => _showChangePasswordDialog(context),
                ),
              _buildModernTile(
                title: 'تسجيل الخروج من النظام',
                subtitle: 'إنهاء الجلسة الحالية والعودة لشاشة الدخول',
                icon: Icons.logout_rounded,
                gradientColors: const [Color(0xFFC62828), Color(0xFFE53935)],
                isDestructive: true,
                onTap: () => _confirmLogout(context),
              ),
            ]),
          ),
          const SizedBox(height: 28),
          _buildSystemFooter(),
          const SizedBox(height: 36),
        ],
      ),
    ),
  ),
);
  }

  /// بطاقة الملف الشخصي للمستخدم النشط
  Widget _buildUserProfileCard(BuildContext context) {
    return Obx(() {
      final user = UserSessionService.to.currentUser.value;
      final userName = user?.fullName ?? 'مستخدم غير مسجل';
      final roleTitle = user?.displayRoleTitle ?? 'دور غير محدد';
      final roleColor = user?.roleBadgeColor ?? const Color(0xFF007791);

      return Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF003853), Color(0xFF005B7F), Color(0xFF007791)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF003853).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // تزيين خلفي أنيق
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      // الصورة الرمزية مع مؤشر الاتصال
                      Stack(
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  Colors.white.withValues(alpha: 0.8),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Text(
                                userName.isNotEmpty ? userName[0] : 'U',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF003853),
                                  fontFamily: 'Tajawal',
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      // الاسم والدور
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontFamily: 'Tajawal',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        user?.roleIcon ?? Icons.verified_user_rounded,
                                        size: 13,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        roleTitle,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontFamily: 'Tajawal',
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'متصل ومصرح',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: Color(0xFFB2EBF2),
                                      fontFamily: 'Tajawal',
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  /// شريط الحالة السريع
  Widget _buildQuickStatusRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildStatusMiniCard(context,
            title: 'قاعدة البيانات',
            value: 'SQLite محلية',
            icon: Icons.storage_rounded,
            color: const Color(0xFF007791),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatusMiniCard(context,
            title: 'حالة الاعتماد',
            value: 'مطابق SFDA',
            icon: Icons.verified_rounded,
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatusMiniCard(context,
            title: 'إصدار النظام',
            value: 'v2.5.0 حديث',
            icon: Icons.new_releases_rounded,
            color: const Color(0xFFE65100),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusMiniCard(BuildContext context,{
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effColor = (color == const Color(0xFF007791) && isDark) ? AppColors.darkPrimaryLight : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: effColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                    fontFamily: 'Tajawal',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: effColor,
              fontFamily: 'Tajawal',
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// رأس القسم
  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color color,
  }) {
    final isDark = (Get.context != null && Theme.of(Get.context!).brightness == Brightness.dark);
    final effColor = isDark ? AppColors.darkPrimaryLight : color;
    return Row(
      children: [
        Icon(icon, color: effColor, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: effColor,
              fontFamily: 'Tajawal',
            ),
          ),
        ),
      ],
    );
  }

  /// بطاقة حاوية لمجموعة إعدادات
  Widget _buildSettingsCard({required BuildContext context, required List<Widget> children}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? AppColors.darkSurface : Theme.of(context).colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.08 : 0.03),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  /// عنصر إعدادات عصري
  Widget _buildModernTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // أيقونة بخلفية تدرج لوني
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              // النصوص
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Builder(
                            builder: (ctx) {
                              final isDark = Theme.of(ctx).brightness == Brightness.dark;
                              return Text(
                                title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDestructive
                                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFC62828))
                                      : (isDark ? AppColors.darkInk : const Color(0xFF1E293B)),
                                  fontFamily: 'Tajawal',
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                        ),
                        if (badgeText != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: (badgeColor ?? const Color(0xFF2E7D32)).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badgeText,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor ?? const Color(0xFF2E7D32),
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Builder(
                      builder: (ctx) {
                        final isDark = Theme.of(ctx).brightness == Brightness.dark;
                        return Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                            fontFamily: 'Tajawal',
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: isDark ? AppColors.darkMuted : Colors.grey.shade400,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    final isDark = (Get.context != null && Theme.of(Get.context!).brightness == Brightness.dark);
    return Divider(height: 1, thickness: 1, color: isDark ? AppColors.darkBorder : Colors.grey.shade100, indent: 70, endIndent: 16);
  }

  /// يدمج العناصر المرئية مع فواصل بينها دون فواصل زائدة في الأطراف
  List<Widget> _interleaveWithDividers(List<Widget> tiles) {
    final result = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      if (i > 0) result.add(_buildDivider());
      result.add(tiles[i]);
    }
    return result;
  }

  /// تذييل النظام ومعلومات الترخيص
  Widget _buildSystemFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.verified_user_rounded, size: 16, color: Colors.teal.shade700),
            const SizedBox(width: 6),
            Text(
              'نظام إدارة الجودة والرقابة الذاتية - مياه وادي العين',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade700,
                fontFamily: 'Tajawal',
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'الإصدار 2.5.0 • متوافق مع متطلبات الهيئة العامة للغذاء والدواء SFDA',
          style: TextStyle(
            fontSize: 10.5,
            color: Colors.grey.shade500,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }

  /// نافذة حوار المواصفات القياسية
  void _showStandardsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.science_rounded, color: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المعايير والمواصفات القياسية المعتمدة',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildStandardItem('الأملاح الذائبة الكلية (TDS)', '100 - 250 ملغ/لتر', 'SASO GSO 1025'),
                _buildStandardItem('الرقم الهيدروجيني (pH)', '6.5 - 8.5', 'SASO GSO 1025'),
                _buildStandardItem('الكلور المتبقي الحر', '0.2 - 0.5 جزء في المليون', 'مياه معالجة'),
                _buildStandardItem('البرومات (Bromate)', 'أقل من 10 ميكروغرام/لتر', 'حد إلزامي SFDA'),
                _buildStandardItem('التعقيم بالأوزون', '0.05 - 0.2 ملغ/لتر عند التعبئة', 'نقاء بيولوجي'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003853),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('إغلاق', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardItem(String param, String limit, String standard) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  param,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF003853),
                  ),
                ),
                Text(
                  standard,
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              limit,
              style: const TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// نافذة معلومات المصنع وخطوط الإنتاج
  void _showPlantInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.factory_rounded, color: Color(0xFFE65100)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المحطات وخطوط الإنتاج',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'المنشأة: مصنع مياه وادي العين',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                '• خط التعبئة 1: عبوات 330 مل و 200 مل\n• خط التعبئة 2: عبوات 600 مل و 1.5 لتر\n• خط الجالون: عبوات 5 جالون\n• محطة المعالجة والتنقية: التناضح العكسي RO والأوزون',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700, height: 1.6),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003853),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('موافق', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }

  /// نافذة تغيير كلمة المرور
  void _showChangePasswordDialog(BuildContext context) {
    final passCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.password_rounded, color: Color(0xFF003853)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تغيير كلمة المرور',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور الجديدة',
                  labelStyle: const TextStyle(fontFamily: 'Tajawal'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () async {
                final password = passCtrl.text.trim();
                final confirm = confirmCtrl.text.trim();
                if (password.length < 4) {
                  Get.snackbar('تنبيه', 'يجب أن تتكون كلمة المرور من 4 أحرف على الأقل',
                      backgroundColor: Colors.amber.shade900, colorText: Colors.white);
                  return;
                }
                if (password != confirm) {
                  Get.snackbar('خطأ', 'كلمتا المرور غير متطابقين',
                      backgroundColor: Colors.redAccent, colorText: Colors.white);
                  return;
                }

                final user = UserSessionService.to.currentUser.value;
                if (user != null && user.id != null) {
                  await UserDatabaseService.instance.changePassword(user.id!, password);
                  if (ctx.mounted) Navigator.pop(ctx);
                  Get.snackbar(
                    'تم بنجاح',
                    'تم تحديث كلمة المرور الخاصة بك بنجاح',
                    backgroundColor: const Color(0xFF2E7D32),
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                    margin: const EdgeInsets.all(12),
                    borderRadius: 12,
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003853),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// تأكيد تسجيل الخروج
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          actionsOverflowButtonSpacing: 8,
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFC62828)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'تسجيل الخروج',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من هذا الحساب؟',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                UserSessionService.to.logout();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('تسجيل الخروج', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// إدارة التوقيع الرقمي المعتمد للمستخدم المسجل حالياً
  void _showMySignatureDialog(BuildContext context) async {
    final user = UserSessionService.to.currentUser.value;
    if (user == null || user.id == null) {
      Get.snackbar('تنبيه', 'يرجى تسجيل الدخول أولاً لإدارة التوقيع', backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    Uint8List? currentSignature = await UserSignatureService.instance.getCustomUserSignatureBytes(user.id!);
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.draw_rounded, color: Color(0xFF0D47A1), size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'توقيعي الرقمي المعتمد',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ارفع صورة توقيعك الشخصي كملف PNG معزول الخلفية (شفاف) أو ارسمه بيدك. سيتم إدراج هذا التوقيع تلقائياً في خانات اعتمادك للتقارير.',
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: Colors.grey.shade700, height: 1.4),
                  ),
                  const SizedBox(height: 14),

                  // مربع المعاينة
                  Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                       color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentSignature != null ? const Color(0xFF0D47A1) : Colors.grey.shade300,
                        width: currentSignature != null ? 1.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(painter: CheckerboardPainter()),
                          ),
                          Center(
                            child: currentSignature != null
                                ? Image.memory(
                                    currentSignature!,
                                    fit: BoxFit.contain,
                                  )
                                : Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.image_not_supported_outlined, size: 36, color: Colors.grey.shade400),
                                      const SizedBox(height: 6),
                                      Text(
                                        'لا يوجد توقيع مخصص مسجل حالياً\n(يتم استخدام التوقيع الافتراضي التلقائي للنظام)',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // أزرار العمليات
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final bytes = await UserSignatureService.instance.pickSignaturePngFromDevice();
                            if (bytes != null) {
                              setDialogState(() {
                                currentSignature = bytes;
                              });
                            }
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text('رفع PNG', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0D47A1),
                            side: const BorderSide(color: Color(0xFF0D47A1)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final bytes = await UserSignatureService.instance.pickSignatureImageFromGallery();
                            if (bytes != null) {
                              setDialogState(() {
                                currentSignature = bytes;
                              });
                            }
                          },
                          icon: const Icon(Icons.photo_library_rounded, size: 16),
                          label: const Text('المعرض', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blueGrey.shade700,
                            side: BorderSide(color: Colors.blueGrey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final bytes = await UserSignaturePadDialog.show(
                              context,
                              title: 'رسم توقيع: ${user.fullName}',
                              initialSignature: currentSignature,
                            );
                            if (bytes != null) {
                              setDialogState(() {
                                currentSignature = bytes;
                              });
                            }
                          },
                          icon: const Icon(Icons.gesture_rounded, size: 16),
                          label: const Text('رسم يدوي', style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF2E7D32)),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (currentSignature != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            currentSignature = null;
                          });
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.redAccent),
                        label: const Text(
                          'إلغاء التوقيع المخصص واستعادة الافتراضي',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    if (currentSignature != null) {
                      final synced = await UserSignatureService.instance.saveUserSignature(
                        userId: user.id!,
                        pngBytes: currentSignature!,
                        signatureType: 'uploaded_png',
                      );
                      Get.snackbar(
                        'تم الحفظ',
                        synced
                            ? 'تم حفظ ومزامنة توقيعك الرقمي مع السيرفر بنجاح'
                            : 'تم حفظ التوقيع محلياً ولكن تعذرت مزامنته مع السيرفر الآن',
                        backgroundColor: synced ? const Color(0xFF2E7D32) : Colors.orange,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.TOP,
                      );
                    } else {
                      await UserSignatureService.instance.deleteUserSignature(user.id!);
                      Get.snackbar(
                        'تمت الاستعادة',
                        'تمت استعادة التوقيع الافتراضي التلقائي للنظام بنجاح',
                        backgroundColor: Colors.blueGrey,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.TOP,
                      );
                    }
                  } catch (e) {
                    Get.snackbar('خطأ', 'فشل حفظ التوقيع: $e', backgroundColor: Colors.redAccent, colorText: Colors.white);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003853),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('حفظ التوقيع', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

