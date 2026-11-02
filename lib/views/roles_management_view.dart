import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/role_model.dart';
import '../models/dynamic_report_models.dart';
import '../services/api/auth_api_service.dart';
import '../services/api/dynamic_reports_api_service.dart';
import '../services/roles_database_service.dart';
import '../services/user_session_service.dart';
import '../widgets/ds/ds.dart';

class RolesManagementController extends GetxController {
  final isLoading = true.obs;
  final roles = <RoleModel>[].obs;
  final dynamicReports = <DynamicReport>[].obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadRoles();
  }

  Future<void> loadRoles() async {
    isLoading.value = true;
    try {
      if (Get.isRegistered<AuthApiService>()) {
        final list = await AuthApiService.to.getAllRoles();
        if (list.isNotEmpty) {
          roles.value = list;
        } else {
          final dbList = await RolesDatabaseService.instance.getAllRoles();
          roles.value = dbList;
        }
      } else {
        final list = await RolesDatabaseService.instance.getAllRoles();
        roles.value = list;
      }

      try {
        if (Get.isRegistered<DynamicReportsApiService>()) {
          dynamicReports.value = await DynamicReportsApiService.to.getTemplates();
        }
      } catch (_) {
        dynamicReports.value = [];
      }
    } catch (e) {
      Get.snackbar('خطأ', 'فشل تحميل قائمة الأدوار: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  List<RoleModel> get filteredRoles {
    final q = searchQuery.value.trim().toLowerCase();
    if (q.isEmpty) return roles;
    return roles.where((r) {
      return r.title.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q) ||
          (r.description ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int get totalRolesCount => roles.length;
  int get systemRolesCount => roles.where((r) => r.isSystem).length;
  int get customRolesCount => roles.where((r) => !r.isSystem).length;

  /// إجمالي عدد الصلاحيات المتاحة في النظام بالكامل بشكل ديناميكي (الثابتة + صلاحيات كل تقرير ديناميكي)
  int get totalAvailablePermissionsCount =>
      SystemPermissions.calculateTotalPermissionsCount(dynamicReports.length);

  Future<bool> saveRole({
    int? id,
    required String title,
    String? description,
    required int color,
    required String iconName,
    required List<String> permissions,
    bool isSystem = false,
  }) async {
    try {
      if (title.trim().isEmpty) {
        Get.snackbar('تنبيه', 'يرجى إدخال اسم الدور الوظيفي',
            backgroundColor: Colors.amber.shade900, colorText: Colors.white);
        return false;
      }

      if (permissions.isEmpty) {
        Get.snackbar('تنبيه', 'يجب تحديد صلاحية واحدة على الأقل لهذا الدور',
            backgroundColor: Colors.amber.shade900, colorText: Colors.white);
        return false;
      }

      final generatedCode = id == null
          ? 'custom_${DateTime.now().millisecondsSinceEpoch}'
          : roles.firstWhere((r) => r.id == id).code;

      final role = RoleModel(
        id: id,
        code: generatedCode,
        title: title.trim(),
        description: description?.trim(),
        color: color,
        iconName: iconName,
        permissions: permissions,
        isSystem: isSystem,
      );

      // حفظ على خادم SQL Server أولاً عبر AuthApiService
      if (Get.isRegistered<AuthApiService>()) {
        await AuthApiService.to.saveRole(role.toMap());
      }
      // مزامنة محلية لضمان استمرارية العمل دون انقطاع
      try {
        if (id == null) {
          await RolesDatabaseService.instance.createRole(role);
        } else {
          await RolesDatabaseService.instance.updateRole(role);
        }
      } catch (_) {}

      await loadRoles();

      // تحديث صلاحيات الجلسة النشطة فوراً إذا كانت تتبع هذا الدور
      try {
        if (Get.isRegistered<UserSessionService>()) {
          await UserSessionService.to.refreshPermissions();
        }
      } catch (_) {}

      Get.snackbar(
        'تم بنجاح',
        id == null ? 'تم حفظ الدور "$title" في السيرفر بنجاح' : 'تم تحديث صلاحيات الدور "$title" في السيرفر بنجاح',
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
      Get.snackbar('خطأ', 'فشل حفظ الدور: $e',
          backgroundColor: Colors.redAccent, colorText: Colors.white);
      return false;
    }
  }

  Future<void> deleteRole(RoleModel role) async {
    try {
      if (Get.isRegistered<AuthApiService>() && role.id != null) {
        await AuthApiService.to.deleteRole(role.id!);
      }
      if (role.id != null) {
        try {
          await RolesDatabaseService.instance.deleteRole(role.id!);
        } catch (_) {}
      }
      await loadRoles();
      Get.snackbar(
        'تم الحذف',
        'تم حذف الدور الوظيفي "${role.title}" بنجاح',
        backgroundColor: Colors.blueGrey,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
      );
    } catch (e) {
      Get.snackbar(
        'تعذر الحذف',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  /// استعادة صلاحيات دور نظامي إلى الإعدادات الافتراضية للنظام
  Future<void> resetSystemRole(RoleModel role) async {
    try {
      await RolesDatabaseService.instance.resetSystemRole(role.id!);
      await loadRoles();

      try {
        if (Get.isRegistered<UserSessionService>()) {
          await UserSessionService.to.refreshPermissions();
        }
      } catch (_) {}

      Get.snackbar(
        'تمت الاستعادة',
        'تمت استعادة صلاحيات الدور "${role.title}" إلى الإعدادات الافتراضية',
        backgroundColor: const Color(0xFF0D47A1),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
        icon: const Icon(Icons.restart_alt_rounded, color: Colors.white),
      );
    } catch (e) {
      Get.snackbar(
        'تعذرت الاستعادة',
        e.toString().replaceAll('Exception: ', ''),
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(12),
      );
    }
  }
}

class RolesManagementView extends StatelessWidget {
  const RolesManagementView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RolesManagementController());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? theme.scaffoldBackgroundColor : Colors.grey.shade50,
        appBar: AppBar(
          title: const Text(
            'إدارة الأدوار والصلاحيات المخصصة',
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
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'تحديث',
              onPressed: controller.loadRoles,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showRoleDialog(context, controller),
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_moderator_rounded),
          label: const Text(
            'إنشاء دور جديد',
            style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
          ),
        ),
        body: Obx(() {
          if (controller.isLoading.value) {
            return const AppLoading(message: 'جاري تحميل الأدوار والصلاحيات...');
          }

          final list = controller.filteredRoles;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. بطاقات الإحصائيات المتجاوبة
                    _buildStatsOverview(context, controller),
                    const SizedBox(height: 16),

                    // 2. شريط البحث
                    _buildSearchBar(context, controller),
                    const SizedBox(height: 16),

                    // 3. قائمة الأدوار
                    if (list.isEmpty)
                      _buildEmptyState(context)
                    else
                      ...list.map((r) => _buildRoleCard(context, controller, r)),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStatsOverview(BuildContext context, RolesManagementController controller) {
    return Row(
      children: [
        Expanded(
          child: _buildStatMiniCard(
            context,
            title: 'إجمالي الأدوار',
            count: controller.totalRolesCount,
            icon: Icons.shield_rounded,
            color: const Color(0xFF0D47A1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatMiniCard(
            context,
            title: 'أدوار النظام',
            count: controller.systemRolesCount,
            icon: Icons.verified_user_rounded,
            color: const Color(0xFF37474F),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildStatMiniCard(
            context,
            title: 'أدوار مخصصة',
            count: controller.customRolesCount,
            icon: Icons.auto_awesome_rounded,
            color: const Color(0xFF2E7D32),
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
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, RolesManagementController controller) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: TextField(
        onChanged: (v) => controller.searchQuery.value = v,
        decoration: InputDecoration(
          hintText: 'بحث في مسميات الأدوار والصلاحيات...',
          hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.grey.shade500),
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryDark),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context,
    RolesManagementController controller,
    RoleModel role,
  ) {
    final roleColor = Color(role.color);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderColor: roleColor.withValues(alpha: 0.25),
        borderWidth: 1.2,
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // أيقونة الدور ولونه
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: roleColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Icon(role.iconData, color: roleColor, size: 24),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // اسم الدور والوصف
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                role.title,
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? (role.isSystem ? const Color(0xFF1E2B3E) : const Color(0xFF0C2B18))
                                    : (role.isSystem ? Colors.blueGrey.shade50 : Colors.green.shade50),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? (role.isSystem ? const Color(0xFF334155) : const Color(0xFF10B981).withValues(alpha: 0.4))
                                      : (role.isSystem ? Colors.blueGrey.shade200 : Colors.green.shade200),
                                ),
                              ),
                              child: Text(
                                role.isSystem ? 'أساسي' : 'مخصص',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? (role.isSystem ? const Color(0xFF94A3B8) : const Color(0xFF34D399))
                                      : (role.isSystem ? Colors.blueGrey.shade800 : Colors.green.shade800),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          role.description ?? 'دور وظيفي مخصص في مصنع المياه',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12,
                            color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkMuted : Colors.grey.shade600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // شريط إحصائية الصلاحيات والإجراءات
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 15, color: roleColor),
                  const SizedBox(width: 6),
                  Obx(() => Text(
                    '${role.permissions.toSet().length} من إجمالي ${controller.totalAvailablePermissionsCount} صلاحية',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  )),
                  const Spacer(),
                  // زر تعديل الصلاحيات (متاح لكل الأدوار بما فيها الأساسية)
                  TextButton.icon(
                    onPressed: () => _showRoleDialog(context, controller, existingRole: role),
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text(
                      'تعديل',
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  // زر استعادة الصلاحيات الافتراضية (للأدوار الأساسية فقط)
                  if (role.isSystem)
                    IconButton(
                      icon: const Icon(Icons.restart_alt_rounded, size: 17, color: Color(0xFF0D47A1)),
                      tooltip: 'استعادة الصلاحيات الافتراضية',
                      onPressed: () => _confirmResetRole(context, controller, role),
                    ),
                  // زر حذف الدور (إن لم يكن نظامياً)
                  if (!role.isSystem)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                      tooltip: 'حذف الدور',
                      onPressed: () => _confirmDeleteRole(context, controller, role),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: AppEmptyState(
          icon: Icons.security_outlined,
          title: 'لا توجد أدوار تطابق البحث',
          message: 'يمكنك إنشاء دور وظيفي مخصص جديد عبر الزر بالأسفل',
        ),
      ),
    );
  }

  void _showRoleDialog(
    BuildContext context,
    RolesManagementController controller, {
    RoleModel? existingRole,
  }) async {
    final isEdit = existingRole != null;
    final isSystemRole = existingRole?.isSystem == true;

    // جلب التقارير الديناميكية الحالية لتضمينها تلقائياً في مصفوفة الصلاحيات
    List<DynamicReport> dynamicReports = [];
    try {
      dynamicReports = await DynamicReportsApiService.to.getTemplates();
      controller.dynamicReports.value = dynamicReports;
    } catch (_) {}

    if (!context.mounted) return;

    final titleCtrl = TextEditingController(text: existingRole?.title ?? '');
    final descCtrl = TextEditingController(text: existingRole?.description ?? '');

    var selectedColor = existingRole?.color ?? const Color(0xFF007791).toARGB32();
    var selectedIcon = existingRole?.iconName ?? 'security';
    final selectedPermissions = <String>{...(existingRole?.permissions ?? [])};

    final colorsPalette = [
      const Color(0xFF0D47A1), // Deep Blue
      const Color(0xFF007791), // Teal
      const Color(0xFF2E7D32), // Green
      const Color(0xFF6A1B9A), // Purple
      const Color(0xFFC62828), // Red
      const Color(0xFFE65100), // Orange
      const Color(0xFF37474F), // Blue Grey
      const Color(0xFF4A148C), // Violet
    ];

    final iconOptions = [
      {'name': 'security', 'icon': Icons.security_rounded},
      {'name': 'science', 'icon': Icons.science_rounded},
      {'name': 'verified', 'icon': Icons.verified_user_rounded},
      {'name': 'water', 'icon': Icons.water_drop_rounded},
      {'name': 'supervisor', 'icon': Icons.supervisor_account_rounded},
      {'name': 'work', 'icon': Icons.engineering_rounded},
      {'name': 'business', 'icon': Icons.business_center_rounded},
      {'name': 'admin', 'icon': Icons.admin_panel_settings_rounded},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final size = MediaQuery.of(ctx).size;
          final dialogWidth = size.width > 950
              ? 900.0
              : (size.width > 650 ? size.width * 0.90 : size.width * 0.96);

          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              actionsOverflowButtonSpacing: 8,
              titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_note_rounded : Icons.add_moderator_rounded,
                      color: AppColors.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'تعديل الدور: ${existingRole.title}' : 'إنشاء دور وظيفي جديد',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'تخصيص مصفوفة صلاحيات الفحوصات والتقارير والأقسام بدقة',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 11.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: dialogWidth,
                height: size.height * 0.82,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // تنبيه عند تعديل دور أساسي في النظام
                      if (isSystemRole)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'هذا دور أساسي في النظام. تعديل صلاحياته ينعكس فوراً على كل المستخدمين المسندين إليه.',
                                  style: TextStyle(
                                    fontFamily: 'Tajawal',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade900,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      // 1. مسمى الدور الوظيفي
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'مسمى الدور الوظيفي * (مثال: فني مختبر)',
                          prefixIcon: Icon(Icons.badge_rounded),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. وصف مهام الدور
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: 'وصف مهام ومسؤوليات الدور',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. اختيار اللون والأيقونة
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // اللون
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'لون الشارة المميز:',
                                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: colorsPalette.map((c) {
                                    final isSelected = selectedColor == c.toARGB32();
                                    return GestureDetector(
                                      onTap: () => setState(() => selectedColor = c.toARGB32()),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: c,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isSelected ? Colors.black87 : Colors.transparent,
                                            width: 2.5,
                                          ),
                                          boxShadow: isSelected
                                              ? [BoxShadow(color: c.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1)]
                                              : null,
                                        ),
                                        child: isSelected
                                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                                            : null,
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          // الأيقونة
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'أيقونة الدور:',
                                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: iconOptions.map((item) {
                                    final name = item['name'] as String;
                                    final icon = item['icon'] as IconData;
                                    final isSelected = selectedIcon == name;
                                    return GestureDetector(
                                      onTap: () => setState(() => selectedIcon = name),
                                      child: Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Color(selectedColor).withValues(alpha: 0.15)
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? Color(selectedColor) : Colors.transparent,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          size: 18,
                                          color: isSelected ? Color(selectedColor) : Colors.grey.shade600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 4. رأس مصفوفة الصلاحيات مع أزرار التحكم السريع
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'مصفوفة صلاحيات الفحوصات والتقارير:',
                                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13.5),
                                ),
                                Text(
                                  'تم تحديد ${selectedPermissions.length} من إجمالي ${controller.totalAvailablePermissionsCount} صلاحية',
                                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade700),
                                ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                final isAllSelected = selectedPermissions.length >= controller.totalAvailablePermissionsCount;

                                if (isAllSelected) {
                                  selectedPermissions.clear();
                                } else {
                                  selectedPermissions.addAll(SystemPermissions.all.map((p) => p.code));
                                  selectedPermissions.add(SystemPermissions.deptQuality);
                                  selectedPermissions.add(SystemPermissions.deptFoodSafety);
                                  selectedPermissions.addAll([
                                    SystemPermissions.fillRawMaterial,
                                    SystemPermissions.viewRawMaterial,
                                    SystemPermissions.printRawMaterial,
                                    SystemPermissions.enabledRawMaterial,
                                    SystemPermissions.fillFinalProduct,
                                    SystemPermissions.viewFinalProduct,
                                    SystemPermissions.printFinalProduct,
                                    SystemPermissions.enabledFinalProduct,
                                    SystemPermissions.fillRawWater,
                                    SystemPermissions.viewRawWater,
                                    SystemPermissions.printRawWater,
                                    SystemPermissions.enabledRawWater,
                                    SystemPermissions.fillHygiene,
                                    SystemPermissions.viewHygiene,
                                    SystemPermissions.printHygiene,
                                    SystemPermissions.enabledHygiene,
                                  ]);
                                  for (final r in dynamicReports) {
                                    if (r.id != null) {
                                      selectedPermissions.add(SystemPermissions.fillDynamicReportCode(r.id!));
                                      selectedPermissions.add(SystemPermissions.viewDynamicReportCode(r.id!));
                                      selectedPermissions.add(SystemPermissions.printDynamicReportCode(r.id!));
                                      selectedPermissions.add(SystemPermissions.enabledDynamicReportCode(r.id!));
                                    }
                                  }
                                }
                              });
                            },
                            icon: const Icon(Icons.select_all_rounded, size: 16),
                            label: Text(
                              selectedPermissions.isNotEmpty ? 'إلغاء الكل' : 'تحديد الكل',
                              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 5. جدول مصفوفة الصلاحيات المتجاوب (Matching Design)
                      _buildReportsPermissionsMatrix(
                        context: ctx,
                        selectedPermissions: selectedPermissions,
                        dynamicReports: dynamicReports,
                        setState: setState,
                        selectedColor: selectedColor,
                      ),
                      const SizedBox(height: 16),

                      // 6. الصلاحيات الإدارية الأخرى (سلسلة الاعتماد، العمليات، النظام)
                      _buildOtherPermissionsSection(
                        context: ctx,
                        selectedPermissions: selectedPermissions,
                        setState: setState,
                        selectedColor: selectedColor,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء', style: TextStyle(fontFamily: 'Tajawal')),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    // مزامنة الأكواد التوافقية العريضة لضمان عدم حدوث أي تعارضات مع دوال الفحص العامة
                    final finalPermissions = <String>{...selectedPermissions};

                    // 1. إزالة جميع الصلاحيات الشاملة والضمنية أولاً لتنظيفها
                    finalPermissions.remove(SystemPermissions.createWaterReports);
                    finalPermissions.remove(SystemPermissions.createRawMaterialReports);
                    finalPermissions.remove(SystemPermissions.createHygieneReports);
                    finalPermissions.remove(SystemPermissions.fillHealthReports);
                    finalPermissions.remove(SystemPermissions.viewReports);
                    finalPermissions.remove(SystemPermissions.viewHealthReports);
                    finalPermissions.remove(SystemPermissions.exportPdf);

                    // إزالة صلاحيات التقارير الديناميكية الشاملة القديمة دائماً (لأننا نعتمد الآن على الصلاحيات المخصصة لكل تقرير)
                    finalPermissions.remove(SystemPermissions.fillDynamicReports);
                    finalPermissions.remove(SystemPermissions.fillQualityDynamicReports);
                    finalPermissions.remove(SystemPermissions.fillFoodSafetyDynamicReports);

                    // 2. إعادة إضافة الصلاحيات الضمنية فقط بناءً على الصلاحيات المحددة فعلياً في الواجهة
                    // إذا كان هناك أي فحص مياه مفعل للتعبئة
                    if (finalPermissions.contains(SystemPermissions.fillRawWater) ||
                        finalPermissions.contains(SystemPermissions.fillFinalProduct)) {
                      finalPermissions.add(SystemPermissions.createWaterReports);
                    }
                    if (finalPermissions.contains(SystemPermissions.fillRawMaterial)) {
                      finalPermissions.add(SystemPermissions.createRawMaterialReports);
                    }
                    if (finalPermissions.contains(SystemPermissions.fillHygiene)) {
                      finalPermissions.add(SystemPermissions.createHygieneReports);
                      finalPermissions.add(SystemPermissions.fillHealthReports);
                    }
                    if (finalPermissions.contains(SystemPermissions.viewRawMaterial) ||
                        finalPermissions.contains(SystemPermissions.viewFinalProduct) ||
                        finalPermissions.contains(SystemPermissions.viewRawWater)) {
                      finalPermissions.add(SystemPermissions.viewReports);
                    }
                    if (finalPermissions.contains(SystemPermissions.viewHygiene)) {
                      finalPermissions.add(SystemPermissions.viewHealthReports);
                    }
                    if (finalPermissions.any((p) => p.startsWith('print_rpt_') || p.startsWith('print_dyn_rpt_'))) {
                      finalPermissions.add(SystemPermissions.exportPdf);
                    }

                    final ok = await controller.saveRole(
                      id: existingRole?.id,
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      color: selectedColor,
                      iconName: selectedIcon,
                      permissions: finalPermissions.toList(),
                      isSystem: existingRole?.isSystem ?? false,
                    );
                    if (ok && ctx.mounted) {
                      Navigator.pop(ctx);
                    }
                  },
                  icon: const Icon(Icons.check_rounded, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimary : AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  label: Text(
                    isEdit ? 'حفظ التعديلات' : 'إنشاء الدور',
                    style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// مصفوفة صلاحيات التقارير المتجاوبة والمرنة
  Widget _buildReportsPermissionsMatrix({
    required BuildContext context,
    required Set<String> selectedPermissions,
    required List<DynamicReport> dynamicReports,
    required StateSetter setState,
    required int selectedColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // تصفية التقارير الديناميكية حسب فئاتها:
    // Category 1: إدارة الجودة (Quality Management)
    final qualityDynReports = dynamicReports.where((r) => r.categoryId == 1 || r.categoryId == null).toList();
    // Category 2: سلامة الغذاء (Food Safety)
    final foodSafetyDynReports = dynamicReports.where((r) => r.categoryId == 2).toList();

    // جميع أكواد صلاحيات تقارير الجودة
    final allQualityCodes = <String>[
      SystemPermissions.fillRawMaterial,
      SystemPermissions.viewRawMaterial,
      SystemPermissions.printRawMaterial,
      SystemPermissions.enabledRawMaterial,
      SystemPermissions.fillFinalProduct,
      SystemPermissions.viewFinalProduct,
      SystemPermissions.printFinalProduct,
      SystemPermissions.enabledFinalProduct,
      SystemPermissions.fillRawWater,
      SystemPermissions.viewRawWater,
      SystemPermissions.printRawWater,
      SystemPermissions.enabledRawWater,
      for (final r in qualityDynReports) ...[
        SystemPermissions.fillDynamicReportCode(r.id!),
        SystemPermissions.viewDynamicReportCode(r.id!),
        SystemPermissions.printDynamicReportCode(r.id!),
        SystemPermissions.enabledDynamicReportCode(r.id!),
      ],
    ];

    // جميع أكواد صلاحيات تقارير سلامة الغذاء
    final allFoodSafetyCodes = <String>[
      SystemPermissions.fillHygiene,
      SystemPermissions.viewHygiene,
      SystemPermissions.printHygiene,
      SystemPermissions.enabledHygiene,
      for (final r in foodSafetyDynReports) ...[
        SystemPermissions.fillDynamicReportCode(r.id!),
        SystemPermissions.viewDynamicReportCode(r.id!),
        SystemPermissions.printDynamicReportCode(r.id!),
        SystemPermissions.enabledDynamicReportCode(r.id!),
      ],
    ];

    final isQualityDeptActive = selectedPermissions.contains(SystemPermissions.deptQuality);
    final isFoodSafetyDeptActive = selectedPermissions.contains(SystemPermissions.deptFoodSafety);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double minTableWidth = 580.0;
          final double tableWidth = constraints.maxWidth.isFinite && constraints.maxWidth > minTableWidth
              ? constraints.maxWidth
              : minTableWidth;

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: tableWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // 1. رأس الجدول (Table Header Bar)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF263238),
                ),
                child: Row(
                  children: [
                    // القسم / الوحدة
                    const Expanded(
                      flex: 5,
                      child: Row(
                        children: [
                          Icon(Icons.dashboard_outlined, size: 16, color: Colors.white70),
                          SizedBox(width: 6),
                          Text(
                            'القسم / الوحدة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // الطباعة
                    SizedBox(
                      width: 65,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.print_outlined, size: 15, color: Colors.white70),
                            SizedBox(width: 4),
                            Text(
                              'الطباعة',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 11.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // تقارير (عرض / تعبئة)
                    SizedBox(
                      width: 140,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'تقارير',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: const [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.visibility_outlined, size: 13, color: Colors.white70),
                                  SizedBox(width: 2),
                                  Text(
                                    'عرض',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.edit_note_rounded, size: 14, color: Colors.white70),
                                  SizedBox(width: 2),
                                  Text(
                                    'تعبئة',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 11,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // تفعيل القسم
                    SizedBox(
                      width: 75,
                      child: Center(
                        child: Text(
                          'تفعيل القسم',
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 2. راية قسم تقارير الجودة (Green Banner)
              _buildDepartmentBanner(
                title: 'تقارير الجودة',
                icon: Icons.folder_open_rounded,
                bgColor: isDark ? const Color(0xFF1B382B) : const Color(0xFFE8F5E9),
                textColor: isDark ? const Color(0xFF81C784) : const Color(0xFF1B5E20),
                iconColor: isDark ? const Color(0xFF81C784) : const Color(0xFF2E7D32),
                isActive: isQualityDeptActive,
                onToggle: (val) {
                  setState(() {
                    if (val) {
                      selectedPermissions.add(SystemPermissions.deptQuality);
                    } else {
                      selectedPermissions.remove(SystemPermissions.deptQuality);
                      for (final c in allQualityCodes) {
                        selectedPermissions.remove(c);
                      }
                    }
                  });
                },
              ),

              // صفوف تقارير الجودة الثابتة
              _buildReportMatrixRow(
                title: 'تقارير المواد الخام',
                icon: Icons.inventory_2_outlined,
                deptCode: SystemPermissions.deptQuality,
                fillCode: SystemPermissions.fillRawMaterial,
                viewCode: SystemPermissions.viewRawMaterial,
                printCode: SystemPermissions.printRawMaterial,
                enabledCode: SystemPermissions.enabledRawMaterial,
                selectedPermissions: selectedPermissions,
                setState: setState,
                selectedColor: selectedColor,
                isDark: isDark,
              ),
              _buildReportMatrixRow(
                title: 'تقارير المنتج النهائي',
                icon: Icons.verified_outlined,
                deptCode: SystemPermissions.deptQuality,
                fillCode: SystemPermissions.fillFinalProduct,
                viewCode: SystemPermissions.viewFinalProduct,
                printCode: SystemPermissions.printFinalProduct,
                enabledCode: SystemPermissions.enabledFinalProduct,
                selectedPermissions: selectedPermissions,
                setState: setState,
                selectedColor: selectedColor,
                isDark: isDark,
              ),
              _buildReportMatrixRow(
                title: 'تقارير المياه الخام',
                icon: Icons.water_drop_outlined,
                deptCode: SystemPermissions.deptQuality,
                fillCode: SystemPermissions.fillRawWater,
                viewCode: SystemPermissions.viewRawWater,
                printCode: SystemPermissions.printRawWater,
                enabledCode: SystemPermissions.enabledRawWater,
                selectedPermissions: selectedPermissions,
                setState: setState,
                selectedColor: selectedColor,
                isDark: isDark,
              ),

              // صفوف تقارير الجودة الديناميكية (إن وجدت)
              for (final rpt in qualityDynReports)
                _buildReportMatrixRow(
                  title: rpt.name,
                  icon: Icons.assignment_outlined,
                  deptCode: SystemPermissions.deptQuality,
                  fillCode: SystemPermissions.fillDynamicReportCode(rpt.id!),
                  viewCode: SystemPermissions.viewDynamicReportCode(rpt.id!),
                  printCode: SystemPermissions.printDynamicReportCode(rpt.id!),
                  enabledCode: SystemPermissions.enabledDynamicReportCode(rpt.id!),
                  selectedPermissions: selectedPermissions,
                  setState: setState,
                  selectedColor: selectedColor,
                  isDark: isDark,
                  isDynamic: true,
                ),

              // 3. راية قسم سلامة الغذاء والصحة (Teal Banner)
              _buildDepartmentBanner(
                title: 'سلامة الغذاء والصحة',
                icon: Icons.folder_open_rounded,
                bgColor: isDark ? const Color(0xFF103632) : const Color(0xFFE0F2F1),
                textColor: isDark ? const Color(0xFF4DB6AC) : const Color(0xFF004D40),
                iconColor: isDark ? const Color(0xFF4DB6AC) : const Color(0xFF00796B),
                isActive: isFoodSafetyDeptActive,
                onToggle: (val) {
                  setState(() {
                    if (val) {
                      selectedPermissions.add(SystemPermissions.deptFoodSafety);
                    } else {
                      selectedPermissions.remove(SystemPermissions.deptFoodSafety);
                      for (final c in allFoodSafetyCodes) {
                        selectedPermissions.remove(c);
                      }
                    }
                  });
                },
              ),

              // صفوف تقارير سلامة الغذاء الثابتة
              _buildReportMatrixRow(
                title: 'تقارير النظافة والاشتراطات الصحية',
                icon: Icons.cleaning_services_outlined,
                deptCode: SystemPermissions.deptFoodSafety,
                fillCode: SystemPermissions.fillHygiene,
                viewCode: SystemPermissions.viewHygiene,
                printCode: SystemPermissions.printHygiene,
                enabledCode: SystemPermissions.enabledHygiene,
                selectedPermissions: selectedPermissions,
                setState: setState,
                selectedColor: selectedColor,
                isDark: isDark,
              ),

              // صفوف تقارير سلامة الغذاء الديناميكية (إن وجدت)
              for (final rpt in foodSafetyDynReports)
                _buildReportMatrixRow(
                  title: rpt.name,
                  icon: Icons.assignment_outlined,
                  deptCode: SystemPermissions.deptFoodSafety,
                  fillCode: SystemPermissions.fillDynamicReportCode(rpt.id!),
                  viewCode: SystemPermissions.viewDynamicReportCode(rpt.id!),
                  printCode: SystemPermissions.printDynamicReportCode(rpt.id!),
                  enabledCode: SystemPermissions.enabledDynamicReportCode(rpt.id!),
                  selectedPermissions: selectedPermissions,
                  setState: setState,
                  selectedColor: selectedColor,
                  isDark: isDark,
                  isDynamic: true,
                ),
            ],
          ),
        ),
      );
    },
  ),
);
  }

  /// راية القسم الرئيسية (Master Department Banner)
  Widget _buildDepartmentBanner({
    required String title,
    required IconData icon,
    required Color bgColor,
    required Color textColor,
    required Color iconColor,
    required bool isActive,
    required ValueChanged<bool> onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: iconColor.withValues(alpha: 0.25), width: 1),
        ),
      ),
      child: Row(
        children: [
          // الأيقونة واسم القسم
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Icon(icon, size: 20, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 65), // فراغ عمود الطباعة
          const SizedBox(width: 8),
          const SizedBox(width: 140), // فراغ عمود التقارير
          const SizedBox(width: 8),
          // مفتاح تفعيل القسم العام
          SizedBox(
            width: 75,
            child: Center(
              child: Transform.scale(
                scale: 0.85,
                child: Switch.adaptive(
                  value: isActive,
                  activeTrackColor: iconColor,
                  onChanged: onToggle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// صف التقرير في مصفوفة الصلاحيات
  Widget _buildReportMatrixRow({
    required String title,
    required IconData icon,
    required String deptCode,
    required String fillCode,
    required String viewCode,
    required String printCode,
    required String enabledCode,
    required Set<String> selectedPermissions,
    required StateSetter setState,
    required int selectedColor,
    required bool isDark,
    bool isDynamic = false,
  }) {
    final isDeptActive = selectedPermissions.contains(deptCode);
    final isRowActive = isDeptActive &&
        (selectedPermissions.contains(enabledCode) ||
            selectedPermissions.contains(fillCode) ||
            selectedPermissions.contains(viewCode) ||
            selectedPermissions.contains(printCode));

    final hasFill = isDeptActive && selectedPermissions.contains(fillCode);
    final hasView = isDeptActive && selectedPermissions.contains(viewCode);
    final hasPrint = isDeptActive && selectedPermissions.contains(printCode);

    final activeColor = Color(selectedColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isRowActive
            ? (isDark ? Colors.grey.shade800.withValues(alpha: 0.35) : const Color(0xFFF8FAFC))
            : (isDark ? Colors.grey.shade900 : Colors.white),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // أيقونة وعنوان التقرير
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isRowActive ? activeColor : Colors.grey.shade500,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: isRowActive ? FontWeight.bold : FontWeight.w500,
                            fontSize: 12.5,
                            color: isRowActive
                                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                : (isDark ? Colors.grey.shade400 : Colors.grey.shade700),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isDynamic) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue.shade200, width: 0.8),
                          ),
                          child: Text(
                            'ديناميكي',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // خيار الطباعة
          SizedBox(
            width: 65,
            child: Center(
              child: Checkbox(
                value: hasPrint,
                activeColor: activeColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: isDeptActive
                    ? (val) {
                        setState(() {
                          if (val == true) {
                            selectedPermissions.add(deptCode);
                            selectedPermissions.add(enabledCode);
                            selectedPermissions.add(printCode);
                          } else {
                            selectedPermissions.remove(printCode);
                            if (!selectedPermissions.contains(viewCode) && !selectedPermissions.contains(fillCode)) {
                              selectedPermissions.remove(enabledCode);
                            }
                          }
                        });
                      }
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // خيارات التقارير (عرض / تعبئة)
          SizedBox(
            width: 140,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // مربع اختيار العرض
                Checkbox(
                  value: hasView,
                  activeColor: activeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: isDeptActive
                      ? (val) {
                          setState(() {
                            if (val == true) {
                              selectedPermissions.add(deptCode);
                              selectedPermissions.add(enabledCode);
                              selectedPermissions.add(viewCode);
                            } else {
                              selectedPermissions.remove(viewCode);
                              selectedPermissions.remove(fillCode);
                              if (!selectedPermissions.contains(printCode)) {
                                selectedPermissions.remove(enabledCode);
                              }
                            }
                          });
                        }
                      : null,
                ),
                // مربع اختيار التعبئة
                Checkbox(
                  value: hasFill,
                  activeColor: activeColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  onChanged: isDeptActive
                      ? (val) {
                          setState(() {
                            if (val == true) {
                              selectedPermissions.add(deptCode);
                              selectedPermissions.add(enabledCode);
                              selectedPermissions.add(viewCode); // التعبئة تفترض وتمنح العرض تلقائياً
                              selectedPermissions.add(fillCode);
                            } else {
                              selectedPermissions.remove(fillCode);
                            }
                          });
                        }
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // مفتاح تفعيل الصف/التقرير
          SizedBox(
            width: 75,
            child: Center(
              child: Transform.scale(
                scale: 0.78,
                child: Switch.adaptive(
                  value: isRowActive,
                  activeTrackColor: activeColor,
                  onChanged: isDeptActive
                      ? (val) {
                          setState(() {
                            if (val) {
                              selectedPermissions.add(deptCode);
                              selectedPermissions.add(enabledCode);
                              selectedPermissions.add(viewCode); // تفعيل العرض افتراضياً
                            } else {
                              selectedPermissions.remove(enabledCode);
                              selectedPermissions.remove(fillCode);
                              selectedPermissions.remove(viewCode);
                              selectedPermissions.remove(printCode);
                            }
                          });
                        }
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// بطاقات الصلاحيات العامة الأخرى (اعتماد، ورديات، إدارة نظام)
  Widget _buildOtherPermissionsSection({
    required BuildContext context,
    required Set<String> selectedPermissions,
    required StateSetter setState,
    required int selectedColor,
  }) {
    final otherCategories = [
      {
        'title': 'سلسلة الاعتماد والتوقيع',
        'icon': Icons.verified_user_rounded,
        'color': const Color(0xFF0D47A1),
        'permissions': [
          SystemPermissions.approveQSupervisor,
          SystemPermissions.approveQM,
          SystemPermissions.approveGM,
          SystemPermissions.rejectReports,
          SystemPermissions.editReports,
          SystemPermissions.deleteReports,
        ],
      },
      {
        'title': 'مصمم وقوالب التقارير الديناميكية',
        'icon': Icons.dashboard_customize_rounded,
        'color': const Color(0xFF6A1B9A),
        'permissions': [
          SystemPermissions.designDynamicReports,
        ],
      },
      {
        'title': 'العمليات والورديات وإدارة المنتجات والعمالة والالتزام',
        'icon': Icons.business_center_rounded,
        'color': const Color(0xFFE65100),
        'permissions': [
          SystemPermissions.viewShifts,
          SystemPermissions.manageShifts,
          SystemPermissions.manageProducts,
          SystemPermissions.manageDailyWorkers,
          SystemPermissions.viewDailyWorkersCommitment,
          SystemPermissions.viewFactoryComplianceReport,
        ],
      },
      {
        'title': 'إدارة النظام والأمان والإعدادات',
        'icon': Icons.admin_panel_settings_rounded,
        'color': const Color(0xFF37474F),
        'permissions': [
          SystemPermissions.manageUsers,
          SystemPermissions.manageRoles,
          SystemPermissions.manageSettings,
          SystemPermissions.manageSignature,
          SystemPermissions.changePassword,
        ],
      },
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 18, color: AppColors.primaryDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'صلاحيات النظام والاعتماد والإدارة العامة:',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        ...otherCategories.map((cat) {
          final catTitle = cat['title'] as String;
          final catIcon = cat['icon'] as IconData;
          final catColor = cat['color'] as Color;
          final codes = cat['permissions'] as List<String>;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isDark ? Colors.grey.shade900 : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    color: isDark
                        ? catColor.withValues(alpha: 0.15)
                        : catColor.withValues(alpha: 0.08),
                    child: Row(
                      children: [
                        Icon(catIcon, size: 17, color: catColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            catTitle,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.bold,
                              fontSize: 12.5,
                              color: catColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...codes.map((code) {
                    final def = SystemPermissions.getDef(code);
                    if (def == null) return const SizedBox.shrink();
                    final isGranted = selectedPermissions.contains(code);

                    return CheckboxListTile(
                      dense: true,
                      value: isGranted,
                      activeColor: Color(selectedColor),
                      title: Text(
                        def.title,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontWeight: isGranted ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                      subtitle: Text(
                        def.description,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      secondary: Icon(
                        def.icon,
                        size: 18,
                        color: isGranted ? Color(selectedColor) : Colors.grey.shade500,
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedPermissions.add(code);
                          } else {
                            selectedPermissions.remove(code);
                          }
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _confirmResetRole(
    BuildContext context,
    RolesManagementController controller,
    RoleModel role,
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
              Icon(Icons.restart_alt_rounded, color: Color(0xFF0D47A1)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'استعادة الصلاحيات الافتراضية',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'سيتم استبدال كافة صلاحيات الدور "${role.title}" بالصلاحيات الافتراضية للنظام.\n'
            'أي تعديلات أجريتها على هذا الدور الأساسي ستُلغى.',
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
                controller.resetSystemRole(role);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('تأكيد الاستعادة', style: TextStyle(fontFamily: 'Tajawal')),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteRole(
    BuildContext context,
    RolesManagementController controller,
    RoleModel role,
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
                child: Text(
                  'حذف الدور الوظيفي',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'هل أنت متأكد من رغبتك في حذف الدور "${role.title}"؟\nلن يمكن حذفه إذا كان هناك أي مستخدمين مسندين لهذا الدور.',
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
                controller.deleteRole(role);
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

