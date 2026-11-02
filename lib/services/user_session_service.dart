import 'dart:convert';
import 'realtime_notification_client.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/role_model.dart';
import '../constants/app_modules.dart';
import 'notification_service.dart';
import 'api/auth_api_service.dart';
import 'roles_database_service.dart';
import 'user_database_service.dart';
import 'user_signature_service.dart';
import '../routes/app_routes.dart';

export '../models/user_model.dart' show UserRole, UserModel;

class UserSessionService extends GetxService {
  static UserSessionService get to => Get.find<UserSessionService>();

  // كائن المستخدم النشط
  final Rx<UserModel?> currentUser = Rx<UserModel?>(null);

  // الدور واسم المستخدم المتوافق مع شاشات التطبيق الحالية
  final currentRole = UserRole.qualitySpecialist.obs;
  final currentUserName = 'صلاح الجابري (مهندس الجودة)'.obs;
  final isLoggedIn = false.obs;

  // ─── فلتر المصنع للأدوار العليا ───────────────────────────────────────────
  // null = عرض الكل، 1 = مصنع أرتل، 2 = مصنع سنحان
  final Rx<int?> activeBranchFilter = Rx<int?>(null);

  /// قائمة المصانع المتاحة في النظام
  static const List<Map<String, dynamic>> availableBranches = [
    {'id': 1, 'name': 'مصنع أرتل'},
    {'id': 2, 'name': 'مصنع سنحان'},
  ];

  /// تغيير فلتر المصنع النشط (للأدوار العليا فقط)
  void setActiveBranchFilter(int? branchId) {
    activeBranchFilter.value = branchId;
  }

  /// الفلتر الفعلي المُستخدم في الاستعلامات:
  /// - المستخدم المقيد بفرع → فرعه المحدد دائماً
  /// - الأدوار العليا → ما اختاره المستخدم (null = الكل)
  int? get effectiveBranchFilter {
    if (isBranchRestricted) return assignedBranchId;
    return activeBranchFilter.value;
  }

  /// هل يمكن للمستخدم الحالي استخدام فلتر المصنع
  bool get canFilterByBranch =>
      isAdmin || isGeneralManager ||
      (isQualityManager && !isBranchRestricted);
  // ──────────────────────────────────────────────────────────────────────────

  final Map<UserRole, String> defaultNames = {
    UserRole.admin: 'مسؤول النظام (المدير التقني)',
    UserRole.generalManager: 'أ. مازن الجلال',
    UserRole.qualitySpecialist: 'صلاح الجابري',
    UserRole.qualitySupervisor: 'مشرف الجودة',
    UserRole.qualityManager: 'أ. حمود يسر',
    UserRole.factoryManager: 'خالد العمري',
    UserRole.foodSafetyEngineer: 'مهندس سلامة الغذاء',
  };

  final Map<UserRole, String> roleLabels = {
    UserRole.admin: 'مسؤول النظام (المدير التقني)',
    UserRole.generalManager: 'المدير العام',
    UserRole.qualitySpecialist: 'منفذ الفحص / أخصائي الجودة',
    UserRole.qualitySupervisor: 'مشرف الجودة والرقابة',
    UserRole.qualityManager: 'مدير الجودة',
    UserRole.factoryManager: 'مدير المصنع',
    UserRole.foodSafetyEngineer: 'مهندس سلامة الغذاء',
  };

  final Map<UserRole, IconData> roleIcons = {
    UserRole.admin: Icons.admin_panel_settings_rounded,
    UserRole.generalManager: Icons.supervisor_account_rounded,
    UserRole.qualitySpecialist: Icons.science_outlined,
    UserRole.qualitySupervisor: Icons.policy_outlined,
    UserRole.qualityManager: Icons.verified_user_outlined,
    UserRole.factoryManager: Icons.business_outlined,
    UserRole.foodSafetyEngineer: Icons.health_and_safety_outlined,
  };

  final Map<UserRole, Color> roleColors = {
    UserRole.admin: const Color(0xFF37474F),             // Blue Grey
    UserRole.generalManager: const Color(0xFF0D47A1),    // Deep Blue
    UserRole.qualitySpecialist: const Color(0xFF007791), // Teal/Blue
    UserRole.qualitySupervisor: const Color(0xFF00897B), // Teal
    UserRole.qualityManager: const Color(0xFF2E7D32),    // Green
    UserRole.factoryManager: const Color(0xFF6A1B9A),    // Purple/Indigo
    UserRole.foodSafetyEngineer: const Color(0xFFE65100), // Deep Orange
  };

  @override
  void onInit() {
    super.onInit();
    _initSession();
  }

  Future<void> _initSession() async {
    await restoreSession();
    if (currentUser.value == null || (currentUser.value?.customPermissions == null || currentUser.value!.customPermissions!.isEmpty)) {
      await refreshPermissions();
    }
  }

  /// تسجيل دخول وتثبيت جلسة المستخدم
  Future<void> login(UserModel user) async {
    currentUser.value = user;
    currentRole.value = user.role;
    currentUserName.value = user.fullName;
    isLoggedIn.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_user_id', user.id ?? -1);
    await prefs.setString('active_username', user.username);
    await prefs.setString('active_role', user.customRoleTitle ?? UserModel.roleToString(user.role));
    await prefs.setString('active_fullname', user.fullName);
    await prefs.setString('active_user_json', jsonEncode(user.toMap()));
    await prefs.setBool('hasLoggedInBefore', true);

    // عكس المستخدم الحالي على قاعدة البيانات المحلية (SQLite) مع الحفاظ على معرّف
    // السيرفر الخاص به، لضمان سلامة قيود المفاتيح الأجنبية في الجداول المحلية
    // (user_signatures و report_approvals و audit_logs ...) عند حفظ التوقيع وغيره.
    try {
      await UserDatabaseService.instance.upsertServerUser(user);
      if (user.id != null && user.id! > 0) {
        UserSignatureService.instance.syncUserSignatureFromServer(user.id!);
      }
    } catch (e) {
      debugPrint('Error mirroring logged-in user to local DB: $e');
    }

    if (Get.isRegistered<NotificationService>()) {
      NotificationService.to.loadNotifications();
    }
    if (Get.isRegistered<RealtimeNotificationClient>()) {
      RealtimeNotificationClient.to.refreshConnection();
    }
  }

  /// تسجيل الخروج
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_user_id');
    await prefs.remove('active_username');
    await prefs.remove('active_role');
    await prefs.remove('active_fullname');
    await prefs.remove('active_user_json');

    currentUser.value = null;
    isLoggedIn.value = false;
    currentRole.value = UserRole.qualitySpecialist;
    currentUserName.value = 'صلاح الجابري (مهندس الجودة)';
    activeBranchFilter.value = null; // إعادة ضبط فلتر المصنع

    if (Get.isRegistered<RealtimeNotificationClient>()) {
      RealtimeNotificationClient.to.disconnect();
    }
    if (Get.isRegistered<NotificationService>()) {
      NotificationService.to.clearOnLogout();
    }

    Get.offAllNamed(AppRoutes.login);
  }

  /// استعادة الجلسة السابقة تلقائياً
  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJsonStr = prefs.getString('active_user_json');
      if (userJsonStr != null && userJsonStr.isNotEmpty) {
        final Map<String, dynamic> userMap = jsonDecode(userJsonStr);
        final user = UserModel.fromMap(userMap);
        if (user.isActive) {
          currentUser.value = user;
          currentRole.value = user.role;
          currentUserName.value = user.fullName;
          isLoggedIn.value = true;
          if (Get.isRegistered<RealtimeNotificationClient>()) {
            RealtimeNotificationClient.to.refreshConnection();
          }
          if (Get.isRegistered<NotificationService>()) {
            NotificationService.to.loadNotifications();
          }
          if (user.customPermissions == null || user.customPermissions!.isEmpty) {
            await refreshPermissions();
          }

          // عكس المستخدم المُستعاد على قاعدة البيانات المحلية بنفس معرّف السيرفر
          try {
            await UserDatabaseService.instance.upsertServerUser(user);
            if (user.id != null && user.id! > 0) {
              UserSignatureService.instance.syncUserSignatureFromServer(user.id!);
            }
          } catch (e) {
            debugPrint('Error mirroring restored user to local DB: $e');
          }
          return;
        }
      }

      final userId = prefs.getInt('active_user_id');
      if (userId != null && userId > 0) {
        if (Get.isRegistered<AuthApiService>()) {
          final users = await AuthApiService.to.getAllUsers();
          final user = users.firstWhereOrNull((u) => u.id == userId);
          if (user != null && user.isActive) {
            await login(user);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint("Session restore error: $e");
    }
  }

  /// تحديث الصلاحيات فورياً للجلسة الحالية
  Future<void> refreshPermissions() async {
    final user = currentUser.value;
    final role = currentRole.value;

    if (Get.isRegistered<AuthApiService>()) {
      try {
        final roles = await AuthApiService.to.getAllRoles();
        final roleKey = user?.customRoleTitle ?? UserModel.roleToString(role);
        final matchedRole = roles.firstWhereOrNull((r) => matchRole(r, roleKey));
        final perms = matchedRole?.permissions ?? user?.customPermissions ?? [];

        if (user != null) {
          currentUser.value = user.copyWith(customPermissions: perms);
        } else {
          currentUser.value = UserModel(
            id: -1,
            fullName: currentUserName.value,
            username: UserModel.roleToString(role).toLowerCase(),
            role: role,
            customPermissions: perms,
          );
        }
        currentUser.refresh();
        return;
      } catch (_) {}
    }

    if (user == null) {
      currentUser.value = UserModel(
        id: -1,
        fullName: currentUserName.value,
        username: UserModel.roleToString(role).toLowerCase(),
        role: role,
        customPermissions: [],
      );
      currentUser.refresh();
    }
  }

  /// مطابقة ذكية لاسم الدور أو كوده مع التعامل مع الشرطات والمسافات
  static bool matchRole(RoleModel r, String roleKey) {
    final cleanKey = roleKey.trim().toLowerCase();
    final normKey = cleanKey.replaceAll('_', '').replaceAll(' ', '');
    final rCode = r.code.trim().toLowerCase();
    final rCodeNorm = rCode.replaceAll('_', '').replaceAll(' ', '');
    final rTitle = r.title.trim().toLowerCase();
    final rTitleNorm = rTitle.replaceAll('_', '').replaceAll(' ', '');
    return rCode == cleanKey || rTitle == cleanKey || rCodeNorm == normKey || rTitleNorm == normKey;
  }

  /// تبديل الدور السريع (للمعاينة والمشرفين)
  void switchRole(UserRole role, {String? customName, int? branchId}) async {
    currentRole.value = role;
    currentUserName.value = customName ?? defaultNames[role] ?? '';
    final roleStr = UserModel.roleToString(role);

    List<String> perms = [];
    if (Get.isRegistered<AuthApiService>()) {
      try {
        final roles = await AuthApiService.to.getAllRoles();
        final matchedRole = roles.firstWhereOrNull((r) => matchRole(r, roleStr));
        perms = matchedRole?.permissions ?? [];
      } catch (_) {}
    }

    currentUser.value = UserModel(
      id: -1,
      branchId: branchId,
      fullName: currentUserName.value,
      username: roleStr.toLowerCase(),
      role: role,
      customPermissions: perms,
    );
    currentUser.refresh();

    // تحديث الإشعارات فورياً للدور الجديد
    if (Get.isRegistered<NotificationService>()) {
      NotificationService.to.loadNotifications();
    }
    if (Get.isRegistered<RealtimeNotificationClient>()) {
      RealtimeNotificationClient.to.refreshConnection();
    }

    Get.snackbar(
      'تم تغيير الدور النشط',
      'أنت تعمل الآن بصلاحية: ${roleLabels[role]} (${currentUserName.value})',
      snackPosition: SnackPosition.TOP,
      backgroundColor: roleColors[role] ?? Colors.blueGrey,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      icon: Icon(roleIcons[role], color: Colors.white),
    );
  }

  /// التبديل المباشر لمستخدم معين (مع الفرع والصلاحيات الكاملة)
  Future<void> switchToUser(UserModel user) async {
    final roleKey = user.customRoleTitle ?? UserModel.roleToString(user.role);
    List<String> perms = [];
    if (Get.isRegistered<AuthApiService>()) {
      try {
        perms = await AuthApiService.to.getPermissionsForRole(roleKey);
      } catch (_) {}
    }
    if (perms.isEmpty) {
      try {
        perms = await RolesDatabaseService.instance.getPermissionsForRole(roleKey);
      } catch (_) {}
    }
    final fullUser = user.copyWith(customPermissions: perms);

    currentUser.value = fullUser;
    currentRole.value = fullUser.role;
    currentUserName.value = fullUser.fullName;
    isLoggedIn.value = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_user_id', user.id ?? -1);
    await prefs.setString('active_username', user.username);
    await prefs.setString('active_role', user.customRoleTitle ?? UserModel.roleToString(user.role));
    await prefs.setString('active_fullname', user.fullName);

    if (Get.isRegistered<NotificationService>()) {
      NotificationService.to.loadNotifications();
    }
    if (Get.isRegistered<RealtimeNotificationClient>()) {
      RealtimeNotificationClient.to.refreshConnection();
    }

    Get.snackbar(
      'تم تبديل المستخدم بنجاح',
      'الحساب النشط الآن: ${fullUser.fullName}',
      snackPosition: SnackPosition.TOP,
      backgroundColor: fullUser.roleBadgeColor,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      icon: Icon(fullUser.roleIcon, color: Colors.white),
    );
  }

  /// صلاحية تعبئة تقرير ديناميكي حسب فئته (1=الجودة، 2=سلامة الغذاء)
  bool canFillDynamicInCategory(int? categoryId) {
    if (isAdmin) return true;
    if (categoryId != null && !isDepartmentEnabled(categoryId)) return false;
    return hasPermissionCode(SystemPermissions.dynamicFillPermissionForCategory(categoryId)) || hasPermissionCode(SystemPermissions.fillDynamicReports);
  }

  /// يسمح بقراءة السجلات الديناميكية داخل القسم نفسه فقط.
  bool canViewDynamicInCategory(int? categoryId) {
    if (isAdmin || isGeneralManager || isFactoryManager) return true;
    if (categoryId != null && !isDepartmentEnabled(categoryId)) return false;
    if (categoryId == 1 && isQualityManager) return true;
    if (canFillDynamicInCategory(categoryId)) return true;
    return categoryId == 2 ? canViewHealthReports : canViewReports;
  }

  // --- التحقق من الصلاحيات التفصيلية للأقسام والتقارير ---
  bool isDepartmentEnabled(int categoryId) {
    if (isAdmin || isGeneralManager || isFactoryManager) return true;
    if (categoryId == 1 && isQualityManager) return true;
    final code = categoryId == 2 ? SystemPermissions.deptFoodSafety : SystemPermissions.deptQuality;
    return hasPermissionCode(code);
  }

  // 1. تقرير فحص المواد الخام
  bool get canFillRawMaterial => isDepartmentEnabled(1) && canFillReport('rpt_raw_material');
  bool get canViewRawMaterial => isDepartmentEnabled(1) && canViewReport('rpt_raw_material');
  bool get canPrintRawMaterial => isDepartmentEnabled(1) && canPrintReport('rpt_raw_material');

  // 2. تقرير الإنتاج النهائي
  bool get canFillFinalProduct => isDepartmentEnabled(1) && canFillReport('rpt_final_product');
  bool get canViewFinalProduct => isDepartmentEnabled(1) && canViewReport('rpt_final_product');
  bool get canPrintFinalProduct => isDepartmentEnabled(1) && canPrintReport('rpt_final_product');

  // 3. تقرير فحص المياه الخام
  bool get canFillRawWater => isDepartmentEnabled(1) && canFillReport('rpt_raw_water');
  bool get canViewRawWater => isDepartmentEnabled(1) && canViewReport('rpt_raw_water');
  bool get canPrintRawWater => isDepartmentEnabled(1) && canPrintReport('rpt_raw_water');

  // 4. تقرير النظافة والتعقيم
  bool get canFillHygiene => isDepartmentEnabled(2) && canFillReport('rpt_hygiene');
  bool get canViewHygiene => isDepartmentEnabled(2) && canViewReport('rpt_hygiene');
  bool get canPrintHygiene => isDepartmentEnabled(2) && canPrintReport('rpt_hygiene');

  // 5. التقارير الديناميكية
  bool canFillDynamicReport(int? reportId, int? categoryId) {
    if (isAdmin || isGeneralManager) return true;
    if (reportId == null) return false;
    final catId = categoryId ?? 1;

    // 1. التحقق من وجود صلاحية محددة ومباشرة لهذا التقرير (الأسبقية للصلاحية الصريحة)
    if (hasPermissionCode(SystemPermissions.fillDynamicReportCode(reportId))) return true;

    // 2. التحقق من تفعيل القسم إذا لم تكن هناك صلاحية مباشرة للتقرير
    if (!isDepartmentEnabled(catId)) return false;

    // 3. إذا كان للمستخدم أي صلاحية مخصصة لأي تقرير ديناميكي، نمنع الصلاحية العامة الشاملة ونكتفي بما حُدد له فقط
    if (hasAnySpecificDynamicReportPermission) {
      return false;
    }

    // 4. التوافق مع الأدوار العامة التي لم تُخصص لها تقارير محددة
    return hasPermissionCode(SystemPermissions.dynamicFillPermissionForCategory(categoryId)) ||
        hasPermissionCode(SystemPermissions.fillDynamicReports);
  }

  bool canViewDynamicReport(int? reportId, int? categoryId) {
    if (isAdmin || isGeneralManager || isFactoryManager) return true;
    if (reportId == null) return false;
    final catId = categoryId ?? 1;
    if (catId == 1 && isQualityManager) return true;

    // 1. إذا كان يملك صلاحية صريحة لتعبئة التقرير أو استعراضه أو تفعيله بالتحديد
    if (hasPermissionCode(SystemPermissions.viewDynamicReportCode(reportId))) return true;
    if (hasPermissionCode(SystemPermissions.enabledDynamicReportCode(reportId))) return true;
    if (canFillDynamicReport(reportId, categoryId)) return true;

    // 2. التحقق من تفعيل القسم إذا لم تكن هناك صلاحية مباشرة للتقرير
    if (!isDepartmentEnabled(catId)) return false;

    // 3. إذا كان لديه صلاحيات مخصصة لتقارير ديناميكية محددة ولم تشمل هذا التقرير، نمنع ظهوره
    if (hasAnySpecificDynamicReportViewPermission || hasAnySpecificDynamicReportPermission) {
      return false;
    }

    // 4. الصلاحيات العامة في حال عدم وجود أي تخصيص
    return false;
  }

  bool canPrintDynamicReport(int? reportId, int? categoryId) {
    if (isAdmin || isGeneralManager || isFactoryManager) return true;
    if (reportId == null) return false;
    final catId = categoryId ?? 1;
    if (catId == 1 && isQualityManager) return true;

    if (hasPermissionCode(SystemPermissions.printDynamicReportCode(reportId))) return true;

    if (!isDepartmentEnabled(catId)) return false;

    if (hasAnySpecificDynamicReportPrintPermission) {
      return false;
    }

    return canExportPdf;
  }

  // دوال عامة للمطابقة والتحقق
  bool canFillReport(String reportKey) {
    if (isAdmin || isGeneralManager) return true;
    if (hasPermissionCode('fill_$reportKey')) return true;
    if (reportKey == 'rpt_final_product' || reportKey == 'rpt_raw_water') {
      return hasPermissionCode(SystemPermissions.createWaterReports);
    }
    if (reportKey == 'rpt_raw_material') {
      return hasPermissionCode(SystemPermissions.createRawMaterialReports);
    }
    if (reportKey == 'rpt_hygiene') {
      return hasPermissionCode(SystemPermissions.createHygieneReports) || hasPermissionCode(SystemPermissions.fillHealthReports);
    }
    return false;
  }

  bool canViewReport(String reportKey) {
    if (isAdmin || isGeneralManager || isFactoryManager) return true;
    if (canFillReport(reportKey)) return true;
    if (hasPermissionCode('view_$reportKey')) return true;
    if (reportKey == 'rpt_hygiene') return canViewHealthReports || isQualityManager;
    return canViewReports || isQualityManager;
  }

  bool canPrintReport(String reportKey) {
    if (isAdmin || isGeneralManager || isFactoryManager || isQualityManager) return true;
    if (hasPermissionCode('print_$reportKey')) return true;
    return canExportPdf;
  }

  /// التحقق من امتلاك صلاحية محددة بكود الصلاحية
  bool hasPermissionCode(String permCode) {
    if (currentUser.value != null) {
      return currentUser.value!.hasPermissionCode(permCode);
    }
    // في غياب جلسة نشطة تُطبَّق نفس قاعدة الإدارة العليا الموحّدة في النموذج
    // (مسؤول النظام + المدير العام) لتفادي الازدواجية بين طبقتي التحقق.
    return isGeneralManager;
  }

  // Getters مساعدة للأدوار الأساسية
  bool get isAdmin => currentRole.value == UserRole.admin;
  bool get isGeneralManager => currentRole.value == UserRole.generalManager || isAdmin;
  bool get isQualityManager => currentRole.value == UserRole.qualityManager || isAdmin;
  bool get isQualitySupervisor => currentRole.value == UserRole.qualitySupervisor || isAdmin;
  bool get isFactoryManager => currentRole.value == UserRole.factoryManager || isAdmin;
  bool get isQualitySpecialist => currentRole.value == UserRole.qualitySpecialist || isAdmin;
  bool get isFoodSafetyEngineer => currentRole.value == UserRole.foodSafetyEngineer || isAdmin;

  // Multi-Branch Access & Isolation Getters
  int? get assignedBranchId => currentUser.value?.branchId;
  bool get isBranchRestricted => assignedBranchId != null && assignedBranchId! > 0 && !isAdmin && !isGeneralManager;
  String get assignedBranchName {
    if (assignedBranchId == 1) return 'مصنع أرتل';
    if (assignedBranchId == 2) return 'مصنع سنحان';
    return 'كافة المصانع';
  }

  /// التحقق من صلاحية استعراض تقرير أو بيانات تتبع لفرع معين
  bool canViewBranchData(int? dataBranchId) {
    if (isAdmin || isGeneralManager) return true;
    if (!isBranchRestricted) return true; // مدير الجودة العام غير المقيد
    // السجلات التي ليس لها فرع محدد (NULL أو 0) تتبع مصنع أرتل الافتراضي (الفرع 1)
    final effectiveDataBranch = (dataBranchId == null || dataBranchId == 0) ? 1 : dataBranchId;
    return assignedBranchId == effectiveDataBranch;
  }

  /// التحقق من صلاحية اعتماد أو رفض تقرير يتبع لفرع معين
  bool canApproveBranchData(int? dataBranchId) {
    if (isAdmin || isGeneralManager) return true;
    // مدير الجودة العام غير المقيد بفرع يعتمد كافة المصانع
    if (isQualityManager && (assignedBranchId == null || assignedBranchId == 0)) {
      return true;
    }
    // مدير المصنع المقيد بفرع: مسموح له فقط بمصنعه
    if (isBranchRestricted) {
      final effectiveDataBranch = (dataBranchId == null || dataBranchId == 0) ? 1 : dataBranchId;
      return assignedBranchId == effectiveDataBranch;
    }
    return true;
  }

  // الصلاحيات الدقيقة: تعتمد حصراً على مصفوفة الصلاحيات المحددة للدور في قاعدة البيانات أو الإدارة العليا
  bool get canCreateWaterReports => isAdmin || hasPermissionCode(SystemPermissions.createWaterReports);
  bool get canCreateRawMaterialReports => isAdmin || hasPermissionCode(SystemPermissions.createRawMaterialReports);
  bool get canCreateHygieneReports => isAdmin || hasPermissionCode(SystemPermissions.createHygieneReports);
  bool get canFillDynamicReports =>
      isAdmin || hasPermissionCode(SystemPermissions.fillDynamicReports) || canFillQualityDynamicReports || canFillFoodSafetyDynamicReports || hasAnySpecificDynamicReportPermission;
      
  bool get hasAnySpecificDynamicReportPermission {
    final permissions = currentUser.value?.customPermissions ?? [];
    return permissions.any((p) => p.startsWith('fill_dyn_rpt_'));
  }
  bool get canFillQualityDynamicReports =>
      isAdmin || hasPermissionCode(SystemPermissions.fillQualityDynamicReports);
  bool get canFillFoodSafetyDynamicReports =>
      isAdmin || hasPermissionCode(SystemPermissions.fillFoodSafetyDynamicReports);
  bool get canEditReports => isAdmin || hasPermissionCode(SystemPermissions.editReports);
  bool get canDeleteReports => isAdmin || hasPermissionCode(SystemPermissions.deleteReports);
  bool get canViewReports => isAdmin || isFactoryManager || isQualityManager || isGeneralManager || hasPermissionCode(SystemPermissions.viewReports) || hasAnySpecificDynamicReportViewPermission;
  
  bool get hasAnySpecificDynamicReportViewPermission {
    final permissions = currentUser.value?.customPermissions ?? [];
    return permissions.any((p) => p.startsWith('view_dyn_rpt_'));
  }

  bool get canApproveQSupervisor => isAdmin || hasPermissionCode(SystemPermissions.approveQSupervisor);
  bool get canApproveQM => isAdmin || isQualityManager || hasPermissionCode(SystemPermissions.approveQM);
  bool get canApproveGM => isAdmin || isFactoryManager || isGeneralManager || hasPermissionCode(SystemPermissions.approveGM);
  bool get canRejectReports => isAdmin || isFactoryManager || isQualityManager || isGeneralManager || hasPermissionCode(SystemPermissions.rejectReports);

  bool get canDesignDynamicReports => isAdmin || hasPermissionCode(SystemPermissions.designDynamicReports);
  bool get canFillHealthReports => isAdmin || hasPermissionCode(SystemPermissions.fillHealthReports);
  bool get canViewHealthReports => isAdmin || isFactoryManager || isGeneralManager || hasPermissionCode(SystemPermissions.viewHealthReports);
  bool get canViewShifts => isAdmin || hasPermissionCode(SystemPermissions.viewShifts);
  bool get canManageShifts => isAdmin || hasPermissionCode(SystemPermissions.manageShifts);
  bool get canManageUsers => isAdmin || hasPermissionCode(SystemPermissions.manageUsers);
  bool get canManageRoles => isAdmin || hasPermissionCode(SystemPermissions.manageRoles);
  bool get canManageSettings => isAdmin || hasPermissionCode(SystemPermissions.manageSettings);
  bool get canManageProducts => isAdmin || hasPermissionCode(SystemPermissions.manageProducts);
  bool get canManageDailyWorkers =>
      isAdmin || hasPermissionCode(SystemPermissions.manageDailyWorkers);
  bool get canViewDailyWorkersCommitment =>
      isAdmin || hasPermissionCode(SystemPermissions.viewDailyWorkersCommitment);
  bool get canViewFactoryComplianceReport =>
      isAdmin || hasPermissionCode(SystemPermissions.viewFactoryComplianceReport);
  bool get canExportPdf => isAdmin || hasPermissionCode(SystemPermissions.exportPdf) || hasAnySpecificDynamicReportPrintPermission;
  
  bool get hasAnySpecificDynamicReportPrintPermission {
    final permissions = currentUser.value?.customPermissions ?? [];
    return permissions.any((p) => p.startsWith('print_dyn_rpt_'));
  }
  bool get canManageSignature => isAdmin || hasPermissionCode(SystemPermissions.manageSignature);
  bool get canChangePassword => isAdmin || hasPermissionCode(SystemPermissions.changePassword);

  /// صلاحية الدخول لوحدة رئيسية (تبويب سفلي) — كل وحدة لها صلاحيتها الخاصة
  bool canAccessModule(HomeModule module) {
    switch (module) {
      case HomeModule.dashboard:
        return true; // لوحة التحكم متاحة لجميع المستخدمين النشطين
      case HomeModule.reports:
        return canViewReports || canViewHealthReports || canCreateWaterReports ||
            canCreateRawMaterialReports || canCreateHygieneReports ||
            canFillDynamicReports || isFactoryManager || isQualityManager;
      case HomeModule.quality:
        // قسم الجودة فقط لمن يملك صلاحيات الجودة صراحةً — صلاحية تعبئة
        // النماذج الديناميكية لسلامة الغذاء لا تفتح هذا القسم.
        return canCreateWaterReports ||
            canCreateRawMaterialReports ||
            canFillQualityDynamicReports || isFactoryManager || isQualityManager;
      case HomeModule.health:
        return canFillHealthReports || canCreateHygieneReports || canFillFoodSafetyDynamicReports || isFactoryManager;
      case HomeModule.shifts:
        return canViewShifts || canManageShifts || isFactoryManager;
      case HomeModule.settings:
        return true; // الإعدادات متاحة للجميع (الأقسام الإدارية تُخفى داخلياً)
    }
  }

  String get roleKey => currentUser.value?.customRoleTitle ?? UserModel.roleToString(currentRole.value);
  String get roleTitle => currentUser.value?.displayRoleTitle ?? (roleLabels[currentRole.value] ?? '');
  IconData get roleIcon => roleIcons[currentRole.value] ?? Icons.person;
  Color get roleColor => currentUser.value?.avatarColor != null ? Color(currentUser.value!.avatarColor!) : (roleColors[currentRole.value] ?? Colors.blue);
}
