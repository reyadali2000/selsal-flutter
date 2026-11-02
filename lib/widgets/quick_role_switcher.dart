import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../services/theme_service.dart';
import '../services/user_session_service.dart';
import '../services/user_database_service.dart';
import '../services/notification_service.dart';

class QuickRoleSwitcher extends StatelessWidget {
  final bool isCompact;
  const QuickRoleSwitcher({super.key, this.isCompact = false});

  @override
  Widget build(BuildContext context) {
    final session = UserSessionService.to;

    return Obx(() {
      final role = session.currentRole.value;
      final roleName = session.roleTitle;
      final roleColor = session.roleColor;
      final roleIcon = session.roleIcon;

      if (isCompact) {
        return IconButton(
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: 1.5),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Icon(roleIcon, key: ValueKey(role), color: Colors.white, size: 18),
            ),
          ),
          tooltip: 'تبديل الصلاحية: $roleName',
          onPressed: () => showRoleDialog(context),
        );
      }

      return InkWell(
        onTap: () => showRoleDialog(context),
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white70, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: Icon(roleIcon, key: ValueKey(role), color: Colors.white, size: 16),
              ),
              const SizedBox(width: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: Text(
                  roleName,
                  key: ValueKey(roleName),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
            ],
          ),
        ),
      );
    });
  }

  static void showRoleDialog([BuildContext? context]) {
    final session = UserSessionService.to;

    final isDark = ThemeService.to.isDarkMode.value;
    Get.bottomSheet(
      Material(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Obx(() {
          final activeRole = session.currentRole.value;
          final activeBranchId = session.assignedBranchId;
          final activeUsername = session.currentUser.value?.username ?? '';

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.switch_account_rounded, color: isDark ? AppColors.darkPrimaryLight : const Color(0xFF0D47A1)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'تبديل الحساب والدور (اختبار عزل المصانع)',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppColors.darkInk : const Color(0xFF003853),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر المستخدم للتبديل الفوري ومعاينة عزل البيانات لكل مصنع:',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 14),

                // قسم مدراء المصانع (المعزولة)
                const Text(
                  'مدراء المصانع (عزل تام للتقارير)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.factoryManager,
                  branchId: 1,
                  title: 'خالد العمري (مدير مصنع أرتل)',
                  subtitle: 'يقتصر على مصنع أرتل فقط (تقارير وورديات واعتماد)',
                  icon: Icons.factory_rounded,
                  color: const Color(0xFF003853),
                  isSelected: activeRole == UserRole.factoryManager && activeBranchId == 1,
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.factoryManager,
                  branchId: 2,
                  title: 'محمد الحاج (مدير مصنع سنحان)',
                  subtitle: 'يقتصر على مصنع سنحان فقط (تقارير وورديات واعتماد)',
                  icon: Icons.factory_outlined,
                  color: const Color(0xFF4A148C),
                  isSelected: activeRole == UserRole.factoryManager && activeBranchId == 2,
                ),

                const SizedBox(height: 12),
                // قسم أخصائيي الجودة (الفاحصين)
                const Text(
                  'مهندسو الجودة الميدانيون',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF007791),
                  ),
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.qualitySpecialist,
                  branchId: 1,
                  title: 'صلاح الجابري (مهندس الجودة)',
                  subtitle: 'تسجيل قراءات وفحوصات مصنع أرتل',
                  icon: Icons.science_outlined,
                  color: const Color(0xFF007791),
                  isSelected: activeRole == UserRole.qualitySpecialist && activeBranchId == 1,
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.qualitySpecialist,
                  branchId: 2,
                  title: 'أسامة الشجاع (مهندس جودة سنحان)',
                  subtitle: 'تسجيل قراءات وفحوصات مصنع سنحان',
                  icon: Icons.biotech_outlined,
                  color: const Color(0xFF00838F),
                  isSelected: activeRole == UserRole.qualitySpecialist && activeBranchId == 2,
                ),
                const SizedBox(height: 12),
                // قسم مهندسي سلامة الغذاء
                const Text(
                  'مهندسو سلامة الغذاء',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.foodSafetyEngineer,
                  branchId: 1,
                  username: 'basheer_fs',
                  title: 'بشير القدسي (مهندس سلامة الغذاء - أرتل)',
                  subtitle: 'نماذج سلامة الغذاء والتفتيش الصحي لمصنع أرتل',
                  icon: Icons.health_and_safety_outlined,
                  color: const Color(0xFFE65100),
                  isSelected: activeRole == UserRole.foodSafetyEngineer && activeBranchId == 1 && activeUsername == 'basheer_fs',
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.foodSafetyEngineer,
                  branchId: 2,
                  username: 'amjad_fs',
                  title: 'أمجد الخدشي (مهندس سلامة الغذاء - سنحان)',
                  subtitle: 'نماذج سلامة الغذاء والتفتيش الصحي لمصنع سنحان',
                  icon: Icons.health_and_safety_outlined,
                  color: const Color(0xFFBF360C),
                  isSelected: activeRole == UserRole.foodSafetyEngineer && activeBranchId == 2 && activeUsername == 'amjad_fs',
                ),

                const SizedBox(height: 12),
                // قسم الإشراف العام
                const Text(
                  'الإشراف العام (الوصول لكلا المصنعين)',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.qualityManager,
                  branchId: null,
                  username: 'qm',
                  title: 'حمود يسر (مدير الرقابة)',
                  subtitle: 'إشراف شامل واعتماد المستوى الأول لكافة المصانع',
                  icon: Icons.verified_user_outlined,
                  color: const Color(0xFF2E7D32),
                  isSelected: activeRole == UserRole.qualityManager && (activeBranchId == null || activeBranchId == 0) && activeUsername == 'qm',
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.qualityManager,
                  branchId: null,
                  username: 'nabil',
                  title: 'نبيل مراد (مهندس توكيد الجودة)',
                  subtitle: 'إشراف شامل واعتماد المستوى الأول لكافة المصانع',
                  icon: Icons.verified_user_outlined,
                  color: const Color(0xFF2E7D32),
                  isSelected: activeRole == UserRole.qualityManager && (activeBranchId == null || activeBranchId == 0) && activeUsername == 'nabil',
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.generalManager,
                  branchId: null,
                  title: 'أ. مازن الجلال (المدير العام)',
                  subtitle: 'صلاحية عليا شاملة لكافة المصانع والتقارير',
                  icon: Icons.supervisor_account_rounded,
                  color: const Color(0xFF0D47A1),
                  isSelected: activeRole == UserRole.generalManager,
                ),
                const SizedBox(height: 6),
                _buildRoleOption(
                  role: UserRole.admin,
                  branchId: null,
                  title: 'مسؤول النظام (المدير التقني)',
                  subtitle: 'صلاحية عليا شاملة وإدارة المستخدمين لكافة المصانع',
                  icon: Icons.admin_panel_settings_rounded,
                  color: const Color(0xFF37474F),
                  isSelected: activeRole == UserRole.admin,
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        }),
        ),
      ),
      isScrollControlled: true,
    );
  }

  static Widget _buildRoleOption({
    required UserRole role,
    int? branchId,
    String? username,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () async {
        // إذا حُدِّد اسم مستخدم (مهندسو سلامة الغذاء يتشاركون نفس الدور والفرع)،
        // نتبدّل إلى ذلك المستخدم بالتحديد بدوره
        if (username != null) {
          final user = await UserDatabaseService.instance.getUserByUsername(username);
          if (user != null) {
            await UserSessionService.to.switchToUser(user);
          }
        } else {
          UserSessionService.to.switchRole(role, branchId: branchId);
        }
        if (Get.isRegistered<NotificationService>()) {
          NotificationService.to.loadNotifications();
        }
        // Small delay so user sees the radio indicator & card highlight animate
        await Future.delayed(const Duration(milliseconds: 220));
        if (Get.isBottomSheetOpen == true) {
          Get.back();
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Builder(
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final effColor = (color == const Color(0xFF003853) && isDark) ? AppColors.darkPrimaryLight : color;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? effColor.withValues(alpha: isDark ? 0.22 : 0.12)
                  : (isDark ? const Color(0xFF1A273D) : Colors.grey.shade50),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? (isDark ? AppColors.darkPrimaryLight : effColor)
                    : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: effColor.withValues(alpha: isDark ? 0.3 : 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? effColor : effColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : (isDark ? AppColors.darkPrimaryLight : effColor),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isSelected
                              ? (isDark ? Colors.white : effColor)
                              : (isDark ? AppColors.darkInk : Colors.black87),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          color: isDark ? AppColors.darkMuted : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: isSelected
                      ? Icon(Icons.check_circle, key: const ValueKey('checked'), color: isDark ? AppColors.darkPrimaryLight : effColor, size: 24)
                      : Icon(Icons.radio_button_unchecked, key: const ValueKey('unchecked'), color: isDark ? AppColors.darkMuted : Colors.grey.shade400, size: 22),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

