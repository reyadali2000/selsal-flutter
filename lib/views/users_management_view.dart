import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/role_model.dart';
import '../routes/app_routes.dart';
import '../services/api/api.dart';
import '../services/roles_database_service.dart';
import '../services/user_database_service.dart';
import '../services/user_session_service.dart';
import '../services/user_signature_service.dart';
import '../widgets/branch_filter_selector.dart';
import '../widgets/ds/ds.dart';

class UsersManagementController extends GetxController {
  final isLoading = true.obs;
  final users = <UserModel>[].obs;
  final availableRoles = <RoleModel>[].obs;
  final searchQuery = ''.obs;
  final selectedRoleFilter = Rx<UserRole?>(null);

  @override
  void onInit() {
    super.onInit();
    loadUsers();
    if (Get.isRegistered<UserSessionService>()) {
      ever(UserSessionService.to.activeBranchFilter, (_) => loadUsers());
    }
  }

  Future<void> loadUsers() async {
    isLoading.value = true;
    try {
      if (Get.isRegistered<AuthApiService>()) {
        final list = await AuthApiService.to.getAllUsers();
        final rList = await AuthApiService.to.getAllRoles();
        users.value = list;
        availableRoles.value = rList;

        // عكس مستخدمي السيرفر على قاعدة البيانات المحلية (SQLite) بنفس معرّفاتهم،
        // لضمان سلامة قيود المفاتيح الأجنبية في الجداول المحلية (user_signatures وغيرها)
        try {
          for (final u in list) {
            await UserDatabaseService.instance.upsertServerUser(u);
          }
        } catch (e) {
          debugPrint('Error mirroring server users to local DB: $e');
        }
      } else {
        final branchId = UserSessionService.to.effectiveBranchFilter;
        final list = await UserDatabaseService.instance.getAllUsers(branchId: branchId);
        final rList = await RolesDatabaseService.instance.getAllRoles();
        users.value = list;
        availableRoles.value = rList;
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل بيانات المستخدمين: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  List<UserModel> get filteredUsers {
    final branchFilter = UserSessionService.to.effectiveBranchFilter;
    return users.where((u) {
      final query = searchQuery.value.trim().toLowerCase();
      final matchesSearch = query.isEmpty ||
          u.fullName.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          (u.phone ?? '').contains(query) ||
          (u.jobTitle ?? '').toLowerCase().contains(query);

      final matchesRole = selectedRoleFilter.value == null || u.role == selectedRoleFilter.value;
      final matchesBranch = branchFilter == null || u.branchId == branchFilter;

      return matchesSearch && matchesRole && matchesBranch;
    }).toList();
  }

  int get totalUsersCount => users.length;
  int get activeUsersCount => users.where((u) => u.isActive).length;
  int get inactiveUsersCount => users.where((u) => !u.isActive).length;

  Future<void> toggleUserStatus(UserModel user) async {
    final newStatus = !user.isActive;

    // منع تعطيل مسؤول النظام الوحيد
    if (!newStatus && user.role == UserRole.admin) {
      final activeAdmins = users.where((u) => u.role == UserRole.admin && u.isActive).length;
      if (activeAdmins <= 1) {
        Get.snackbar('تنبيه', 'لا يمكن تعطيل مسؤول النظام الوحيد في التطبيق.',
            backgroundColor: Colors.orange.shade800, colorText: Colors.white);
        return;
      }
    }

    try {
      if (Get.isRegistered<AuthApiService>()) {
        await AuthApiService.to.toggleUserStatus(user.id!, newStatus);
      } else {
        await UserDatabaseService.instance.toggleUserStatus(user.id!, newStatus);
      }
      await loadUsers();
      Get.snackbar(
        'تم التحديث',
        newStatus ? 'تم تفعيل حساب ${user.fullName} بنجاح' : 'تم تعطيل حساب ${user.fullName}',
        backgroundColor: newStatus ? const Color(0xFF2E7D32) : Colors.blueGrey,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تغيير حالة المستخدم: $e');
    }
  }

  Future<bool> saveUser({
    int? id,
    required String fullName,
    required String username,
    required UserRole role,
    int? branchId,
    String? customRoleTitle,
    String? email,
    String? phone,
    String? jobTitle,
    String? password,
    int? avatarColor,
    bool isActive = true,
  }) async {
    try {
      final chosenColor = avatarColor ?? UserModel.defaultColorForRole(role).toARGB32();
      final effectiveBranchId = UserSessionService.to.isBranchRestricted
          ? UserSessionService.to.assignedBranchId
          : branchId;

      if (Get.isRegistered<AuthApiService>()) {
        final userData = {
          'id': id ?? 0,
          'fullName': fullName.trim(),
          'username': username.trim().toLowerCase(),
          'role': customRoleTitle ?? UserModel.roleToString(role),
          'branchId': effectiveBranchId,
          'email': email?.trim(),
          'phone': phone?.trim(),
          'jobTitle': jobTitle?.trim() ?? (customRoleTitle ?? UserModel.defaultJobTitleForRole(role)),
          'password': password?.trim(),
          'isActive': isActive,
        };
        await AuthApiService.to.saveUser(userData);
      }

      try {
        if (id == null) {
          final newUser = UserModel(
            branchId: effectiveBranchId,
            fullName: fullName.trim(),
            username: username.trim().toLowerCase(),
            role: role,
            customRoleTitle: customRoleTitle,
            email: email?.trim(),
            phone: phone?.trim(),
            jobTitle: jobTitle?.trim() ?? (customRoleTitle ?? UserModel.defaultJobTitleForRole(role)),
            passwordHash: password?.trim().isNotEmpty == true ? password!.trim() : '123456',
            isActive: isActive,
            avatarColor: chosenColor,
          );
          await UserDatabaseService.instance.createUser(newUser);
        } else {
          final existing = users.firstWhereOrNull((u) => u.id == id);
          if (existing != null) {
            final updated = existing.copyWith(
              branchId: effectiveBranchId,
              fullName: fullName.trim(),
              username: username.trim().toLowerCase(),
              role: role,
              customRoleTitle: customRoleTitle,
              email: email?.trim(),
              phone: phone?.trim(),
              jobTitle: jobTitle?.trim() ?? (customRoleTitle ?? UserModel.defaultJobTitleForRole(role)),
              passwordHash: password?.trim().isNotEmpty == true ? password!.trim() : existing.passwordHash,
              isActive: isActive,
              avatarColor: chosenColor,
            );
            await UserDatabaseService.instance.updateUser(updated);
          }
        }
      } catch (_) {}

      await loadUsers();

      Get.snackbar(
        'تم بنجاح',
        id == null ? 'تمت إضافة المستخدم "$fullName" بنجاح' : 'تم تحديث بيانات المستخدم "$fullName" بنجاح',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        duration: const Duration(seconds: 3),
      );

      return true;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل حفظ بيانات المستخدم: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
      );
      return false;
    }
  }

  /// تغيير كلمة مرور مستخدم (رمز PIN مُلغى)
  Future<bool> changeUserPassword(int userId, {String? newPassword}) async {
    try {
      if (newPassword != null && newPassword.trim().isNotEmpty) {
        if (Get.isRegistered<AuthApiService>()) {
          await AuthApiService.to.saveUser({'id': userId, 'password': newPassword.trim()});
        } else {
          await UserDatabaseService.instance.changePassword(userId, newPassword.trim());
        }
      }
      await loadUsers();
      Get.snackbar(
        'تم بنجاح',
        'تم تحديث بيانات الأمان بنجاح',
        backgroundColor: const Color(0xFF2E7D32),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (e) {
      Get.snackbar(
        'خطأ',
        'فشل تحديث بيانات الأمان: $e',
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
      );
      return false;
    }
  }

  Future<void> deleteUser(UserModel user) async {
    try {
      if (Get.isRegistered<AuthApiService>()) {
        await AuthApiService.to.toggleUserStatus(user.id!, false);
      } else {
        await UserDatabaseService.instance.deleteUser(user.id!);
      }
      await loadUsers();
      Get.snackbar('تم الحذف', 'تم حذف حساب ${user.fullName} بنجاح',
          backgroundColor: Colors.blueGrey, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('تنبيه', e.toString().replaceAll('Exception: ', ''),
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    }
  }


}

class UsersManagementView extends StatelessWidget {
  const UsersManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UsersManagementController());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'إدارة المستخدمين والصلاحيات',
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
          actions: [
            Obx(() {
              if (!UserSessionService.to.canFilterByBranch) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: BranchFilterSelector(
                  compact: true,
                  onChanged: () => controller.loadUsers(),
                ),
              );
            }),
            IconButton(
              icon: const Icon(Icons.shield_outlined),
              tooltip: 'الأدوار والصلاحيات المخصصة',
              onPressed: () => Get.toNamed(AppRoutes.rolesManagement)?.then((_) => controller.loadUsers()),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث القائمة',
              onPressed: controller.loadUsers,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showUserDialog(context, controller),
          backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimary : AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text(
            'إضافة مستخدم جديد',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل سجلات المستخدمين...');
          }

          final list = controller.filteredUsers;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: RefreshIndicator(
                onRefresh: controller.loadUsers,
                child: ListView(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 90),
                  children: [
                    // 1. شريط الإحصائيات السريعة
                    _buildStatsOverview(context, controller),
                    const SizedBox(height: 16),

                    // 2. حقل البحث
                    _buildSearchBar(context, controller),
                    const SizedBox(height: 12),

                    // 3. رقائق الفلترة حسب الدور الوظيفي
                    _buildRoleFilterChips(controller),
                    const SizedBox(height: 16),

                    // 4. قائمة المستخدمين
                    if (list.isEmpty)
                      _buildEmptyState()
                    else
                      ...list.map((u) => _buildUserCard(context, controller, u)),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context, UsersManagementController controller) {
    return Row(
      children: [
        Expanded(
          child: _buildStatMiniCard(
            context,
            title: 'إجمالي الحسابات',
            count: controller.totalUsersCount,
            icon: Icons.people_alt_rounded,
            color: const Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatMiniCard(
            context,
            title: 'الحسابات النشطة',
            count: controller.activeUsersCount,
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatMiniCard(
            context,
            title: 'معطلة / مجمدة',
            count: controller.inactiveUsersCount,
            icon: Icons.pause_circle_outline_rounded,
            color: const Color(0xFFC62828),
          ),
        ),
      ],
    );
  }

  Widget _buildStatMiniCard(
    BuildContext context, {
    required String title,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      borderColor: color.withValues(alpha: 0.25),
      borderWidth: 1.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, UsersManagementController controller) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.primaryMedium),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (val) => controller.searchQuery.value = val,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: 'البحث بالاسم، اسم المستخدم، أو رقم الهاتف...',
                hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : Colors.grey.shade400),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Obx(() => controller.searchQuery.value.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () => controller.searchQuery.value = '',
                )
              : const SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildRoleFilterChips(UsersManagementController controller) {
    final roles = [
      {'label': 'الكل', 'role': null, 'color': AppColors.primaryDark},
      {'label': 'أخصائي جودة', 'role': UserRole.qualitySpecialist, 'color': const Color(0xFF007791)},
      {'label': 'مدير جودة', 'role': UserRole.qualityManager, 'color': const Color(0xFF2E7D32)},
      {'label': 'مدير مصنع', 'role': UserRole.factoryManager, 'color': const Color(0xFF6A1B9A)},
      {'label': 'مدير عام', 'role': UserRole.generalManager, 'color': const Color(0xFF0D47A1)},
      {'label': 'مسؤول نظام', 'role': UserRole.admin, 'color': const Color(0xFF37474F)},
    ];

    return Obx(() {
      final selected = controller.selectedRoleFilter.value;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: roles.map((r) {
            final role = r['role'] as UserRole?;
            final label = r['label'] as String;
            final color = r['color'] as Color;
            final isSelected = selected == role;

            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                selected: isSelected,
                label: Text(label),
                labelStyle: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : color,
                ),
                backgroundColor: color.withValues(alpha: 0.06),
                selectedColor: color,
                checkmarkColor: Colors.white,
                side: BorderSide(color: isSelected ? color : color.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (_) => controller.selectedRoleFilter.value = role,
              ),
            );
          }).toList(),
        ),
      );
    });
  }

  Widget _buildUserCard(
    BuildContext context,
    UsersManagementController controller,
    UserModel user,
  ) {
    final roleColor = user.avatarColor != null ? Color(user.avatarColor!) : UserModel.defaultColorForRole(user.role);
    final roleIcon = UserModel.defaultIconForRole(user.role);
    final roleTitle = user.displayRoleTitle;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderColor: user.isActive ? roleColor.withValues(alpha: 0.25) : Colors.red.shade200,
        borderWidth: 1.2,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // أفتار المستخدم الملون
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (user.avatarColor != null ? Color(user.avatarColor!) : roleColor).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (user.avatarColor != null ? Color(user.avatarColor!) : roleColor).withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        roleIcon,
                        color: user.avatarColor != null ? Color(user.avatarColor!) : roleColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // تفاصيل المستخدم
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                user.fullName,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: user.isActive ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink) : (Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : Colors.grey.shade600),
                                  decoration: user.isActive ? null : TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            // شارة الدور الوظيفي
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(roleIcon, size: 12, color: roleColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    roleTitle,
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: roleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '@${user.username} • ${user.jobTitle ?? ""}',
                                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // شارة المصنع
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: user.branchId == null
                                    ? const Color(0xFF6A1B9A).withValues(alpha: 0.1)
                                    : (user.branchId == 1
                                        ? const Color(0xFF003853).withValues(alpha: 0.1)
                                        : const Color(0xFF007791).withValues(alpha: 0.1)),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.factory_rounded,
                                    size: 11,
                                    color: user.branchId == null
                                        ? const Color(0xFF6A1B9A)
                                        : (user.branchId == 1 ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853)) : const Color(0xFF007791)),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    user.branchId == null
                                        ? 'كلا المصنعين'
                                        : (user.branchId == 1 ? 'مصنع أرتل' : 'مصنع سنحان'),
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: user.branchId == null
                                          ? const Color(0xFF6A1B9A)
                                          : (user.branchId == 1 ? (Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimaryLight : const Color(0xFF003853)) : const Color(0xFF007791)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        if (user.phone != null && user.phone!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_iphone_rounded, size: 13, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  user.phone!,
                                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.grey.shade700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // شريط معلومات الحساب السفلية والإجراءات
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade50.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  // الشارات (التوقيع)
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (user.id != null)
                            FutureBuilder<bool>(
                              future: UserSignatureService.instance.hasCustomSignature(user.id!),
                              builder: (context, snapshot) {
                                final hasCustom = snapshot.data == true;
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: hasCustom
                                        ? const Color(0xFF0D47A1).withValues(alpha: 0.08)
                                        : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: hasCustom
                                          ? const Color(0xFF0D47A1).withValues(alpha: 0.25)
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.draw_rounded,
                                        size: 11.5,
                                        color: hasCustom ? const Color(0xFF0D47A1) : Colors.grey.shade500,
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        hasCustom ? 'توقيع معتمد' : 'توقيع تلقائي',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 10,
                                          fontWeight: hasCustom ? FontWeight.bold : FontWeight.normal,
                                          color: hasCustom ? const Color(0xFF0D47A1) : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 4),

                  // حالة التفعيل / التعطيل
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.isActive ? 'نشط' : 'معطل',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: user.isActive ? const Color(0xFF2E7D32) : Colors.red.shade700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      SizedBox(
                        width: 36,
                        height: 22,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: Switch(
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            value: user.isActive,
                            activeThumbColor: const Color(0xFF2E7D32),
                            onChanged: (_) => controller.toggleUserStatus(user),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // زر الخيارات الإضافية
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded, size: 20, color: Colors.grey),
                      onSelected: (action) {
                        if (action == 'edit') {
                          _showUserDialog(context, controller, existingUser: user);
                        } else if (action == 'security') {
                          _showSecurityDialog(context, controller, user);
                        } else if (action == 'delete') {
                          _confirmDelete(context, controller, user);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 18, color: AppColors.primaryMedium),
                              SizedBox(width: 8),
                              Text('تعديل البيانات', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'security',
                          child: Row(
                            children: [
                              Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFF6A1B9A)),
                              SizedBox(width: 8),
                              Text('تغيير كلمة المرور', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                              SizedBox(width: 8),
                              Text('حذف المستخدم', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.redAccent)),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: AppEmptyState(
          icon: Icons.person_search_rounded,
          title: 'لا يوجد مستخدمين مطابقين للبحث',
          message: 'جرّب تغيير كلمات البحث أو تصفية الدور الوظيفي',
        ),
      ),
    );
  }

  void _showUserDialog(
    BuildContext context,
    UsersManagementController controller, {
    UserModel? existingUser,
  }) async {
    final isEdit = existingUser != null;
    if (!context.mounted) return;

    final nameCtrl = TextEditingController(text: existingUser?.fullName ?? '');
    final userCtrl = TextEditingController(text: existingUser?.username ?? '');
    final jobCtrl = TextEditingController(text: existingUser?.jobTitle ?? '');
    final phoneCtrl = TextEditingController(text: existingUser?.phone ?? '');
    final emailCtrl = TextEditingController(text: existingUser?.email ?? '');
    final passCtrl = TextEditingController(text: isEdit ? '' : '123456');
    final isRestricted = UserSessionService.to.isBranchRestricted;
    final userBranchId = UserSessionService.to.assignedBranchId;
    var isActive = existingUser?.isActive ?? true;
    var selectedBranchId = isRestricted ? userBranchId : existingUser?.branchId;

    final rolesList = controller.availableRoles.isNotEmpty
        ? controller.availableRoles.toList()
        : RoleModel.defaultSystemRoles;

    RoleModel selectedRoleModel = rolesList.firstWhere(
      (r) {
        if (existingUser?.customRoleTitle != null) {
          return r.title == existingUser!.customRoleTitle;
        }
        return r.code == UserModel.roleToString(existingUser?.role ?? UserRole.qualitySpecialist).toLowerCase() ||
               r.title == UserModel.roleLabel(existingUser?.role ?? UserRole.qualitySpecialist);
      },
      orElse: () => rolesList.first,
    );

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            actionsOverflowButtonSpacing: 8,
            title: Row(
              children: [
                Icon(
                  isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                  color: AppColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isEdit ? 'تعديل بيانات المستخدم' : 'إضافة مستخدم جديد',
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // الاسم الكامل
                      TextFormField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل *',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال الاسم الكامل' : null,
                      ),
                      const SizedBox(height: 12),

                      // اسم المستخدم
                      TextFormField(
                        controller: userCtrl,
                        decoration: const InputDecoration(
                          labelText: 'اسم المستخدم للدخول (Username) *',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى إدخال اسم المستخدم' : null,
                      ),
                      const SizedBox(height: 12),

                      // الدور والصلاحية (يدعم الأدوار المخصصة والنظامية)
                      DropdownButtonFormField<RoleModel>(
                        initialValue: selectedRoleModel,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'الدور والصلاحية *',
                          prefixIcon: Icon(Icons.security_rounded),
                        ),
                        items: rolesList.map((r) {
                          final c = Color(r.color);
                          return DropdownMenuItem(
                            value: r,
                            child: Row(
                              children: [
                                Icon(r.iconData, size: 18, color: c),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    r.title,
                                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (!r.isSystem) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'مخصص',
                                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 9.5, color: Colors.green.shade800),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              selectedRoleModel = val;
                              if (jobCtrl.text.isEmpty || jobCtrl.text == existingUser?.jobTitle) {
                                jobCtrl.text = val.title;
                              }
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // المصنع / مقر العمل
                      DropdownButtonFormField<int?>(
                        initialValue: selectedBranchId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'المصنع / مقر العمل *',
                          prefixIcon: const Icon(Icons.factory_rounded),
                          helperText: isRestricted ? 'تم قفل المصنع تلقائياً بحسب صلاحيات حسابك' : null,
                          helperStyle: TextStyle(fontFamily: 'Tajawal', color: Colors.purple.shade700, fontSize: 11),
                        ),
                        items: isRestricted
                            ? [
                                DropdownMenuItem<int?>(
                                  value: userBranchId,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.water_drop_rounded, size: 18, color: Color(0xFF003853)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          userBranchId == 1
                                              ? 'مصنع أرتل (المصنع الرئيسي)'
                                              : 'مصنع سنحان (المصنع الثاني)',
                                          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ]
                            : const [
                                DropdownMenuItem<int?>(
                                  value: null,
                                  child: Row(
                                    children: [
                                      Icon(Icons.domain_rounded, size: 18, color: Color(0xFF6A1B9A)),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'كلا المصنعين (إدارة عامة وإشراف شامل)',
                                          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF6A1B9A)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 1,
                                  child: Row(
                                    children: [
                                      Icon(Icons.water_drop_rounded, size: 18, color: Color(0xFF003853)),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'مصنع أرتل (المصنع الرئيسي)',
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Color(0xFF003853)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem<int?>(
                                  value: 2,
                                  child: Row(
                                    children: [
                                      Icon(Icons.water_drop_rounded, size: 18, color: Color(0xFF007791)),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'مصنع سنحان (المصنع الثاني)',
                                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Color(0xFF007791)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                        onChanged: isRestricted
                            ? null
                            : (val) {
                                setState(() {
                                  selectedBranchId = val;
                                });
                              },
                      ),
                      const SizedBox(height: 12),

                      // المسمى الوظيفي
                      TextFormField(
                        controller: jobCtrl,
                        decoration: const InputDecoration(
                          labelText: 'المسمى الوظيفي',
                          prefixIcon: Icon(Icons.work_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // رقم الجوال
                      TextFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم الجوال',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // البريد الإلكتروني
                      TextFormField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // كلمة المرور
                      TextFormField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: isEdit ? 'كلمة المرور (اتركها فارغة للإبقاء على الحالية)' : 'كلمة المرور *',
                          prefixIcon: const Icon(Icons.lock_outline),
                        ),
                        validator: (v) {
                          if (!isEdit && (v == null || v.trim().isEmpty)) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),

                      // مفتاح التنشيط
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('الحساب نشط وجاهز للدخول', style: TextStyle(fontFamily: 'Tajawal', fontSize: 13)),
                        value: isActive,
                        activeThumbColor: const Color(0xFF2E7D32),
                        onChanged: (val) => setState(() => isActive = val),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    final ok = await controller.saveUser(
                      id: existingUser?.id,
                      fullName: nameCtrl.text,
                      username: userCtrl.text,
                      role: UserModel.stringToRole(selectedRoleModel.code),
                      branchId: selectedBranchId,
                      customRoleTitle: selectedRoleModel.isSystem ? null : selectedRoleModel.title,
                      avatarColor: selectedRoleModel.color,
                      email: emailCtrl.text,
                      phone: phoneCtrl.text,
                      jobTitle: jobCtrl.text,
                      password: passCtrl.text,
                      isActive: isActive,
                    );
                    if (ok && ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(isEdit ? 'حفظ التعديلات' : 'إضافة المستخدم', style: const TextStyle(fontFamily: 'Tajawal')),
              ),
            ],
          ),
        ),
      ),
    );
  }





  void _showSecurityDialog(
    BuildContext context,
    UsersManagementController controller,
    UserModel user,
  ) {
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          actionsOverflowButtonSpacing: 8,
          title: Row(
            children: [
              const Icon(Icons.lock_reset_rounded, color: Color(0xFF6A1B9A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'أمان حساب: ${user.fullName}',
                  style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
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
                decoration: const InputDecoration(
                  labelText: 'كلمة مرور جديدة (اتركها فارغة للتخطي)',
                  prefixIcon: Icon(Icons.password_rounded),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () async {
                final ok = await controller.changeUserPassword(
                  user.id!,
                  newPassword: passCtrl.text,
                );
                if (ok && ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('تحديث الأمان', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    UsersManagementController controller,
    UserModel user,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          actionsOverflowButtonSpacing: 8,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Expanded(
                child: Text('حذف المستخدم', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف حساب "${user.fullName}"؟\nملاحظة: يفضل دائماً تعطيل الحساب بدلاً من حذفه للحفاظ على سجلات الفحص والاعتمادات السابقة.',
            style: const TextStyle(fontFamily: 'Tajawal', height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                controller.deleteUser(user);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }
}
