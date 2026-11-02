import 'package:flutter/material.dart';

/// الأدوار الوظيفية المعتمدة في مصنع المياه
enum UserRole {
  admin,                // مسؤول النظام التقني
  generalManager,       // المدير العام (أعلى سلطة، صلاحيات كاملة)
  qualitySpecialist,    // أخصائي الجودة / منفذ الفحص
  qualitySupervisor,    // مشرف الجودة (QS)
  qualityManager,       // مدير الجودة
  factoryManager,       // مدير المصنع
  foodSafetyEngineer,   // مهندس سلامة الغذاء
}

/// نموذج بيانات المستخدم
class UserModel {
  final int? id;
  final int? branchId;
  final String fullName;
  final String username;
  final UserRole role;
  final String? customRoleTitle;
  final List<String>? customPermissions;
  final String? email;
  final String? passwordHash;
  final String? phone;
  final String? jobTitle;
  final bool isActive;
  final int? avatarColor;
  final DateTime? createdAt;
  final DateTime? lastLogin;

  UserModel({
    this.id,
    this.branchId,
    required this.fullName,
    required this.username,
    required this.role,
    this.customRoleTitle,
    this.customPermissions,
    this.email,
    this.passwordHash,
    this.phone,
    this.jobTitle,
    this.isActive = true,
    this.avatarColor,
    this.createdAt,
    this.lastLogin,
  });

  String get displayRoleTitle => customRoleTitle ?? roleLabel(role);

  Color get roleBadgeColor {
    if (avatarColor != null) return Color(avatarColor!);
    return defaultColorForRole(role);
  }

  IconData get roleIcon => defaultIconForRole(role);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'branch_id': branchId,
      'full_name': fullName,
      'username': username.toLowerCase().trim(),
      'role': customRoleTitle ?? roleToString(role),
      'custom_permissions': customPermissions,
      'email': email?.trim(),
      'password_hash': passwordHash,
      'phone': phone?.trim(),
      'job_title': jobTitle?.trim() ?? (customRoleTitle ?? defaultJobTitleForRole(role)),
      'is_active': isActive ? 1 : 0,
      'avatar_color': avatarColor ?? defaultColorForRole(role).toARGB32(),
      'created_at': createdAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, {List<String>? permissions}) {
    final rawRole = (map['role'] ?? '').toString();
    final role = stringToRole(rawRole);
    final normalized = rawRole.toLowerCase().replaceAll('_', '').replaceAll(' ', '');
    final isCustom = rawRole.isNotEmpty && !['admin', 'generalmanager', 'qualitymanager', 'factorymanager', 'qualityspecialist', 'qualitysupervisor', 'foodsafetyengineer', 'qm', 'qs', 'gm', 'gmanager'].contains(normalized);

    final fullNameRaw = map['full_name'] ?? map['fullName'] ?? map['name'];
    final fullNameVal = fullNameRaw?.toString().trim() ?? '';
    
    final usernameRaw = map['username'] ?? map['userName'];
    final usernameVal = usernameRaw?.toString().trim() ?? (map['email'] != null ? map['email'].toString().split('@').first : (map['id'] != null ? 'user_${map['id']}' : ''));
    
    final branchIdRaw = map['branch_id'] ?? map['branchId'];
    final branchIdVal = branchIdRaw != null ? (branchIdRaw is int ? branchIdRaw : int.tryParse(branchIdRaw.toString())) : null;

    final jobTitleRaw = map['job_title'] ?? map['jobTitle'];
    final jobTitleVal = jobTitleRaw?.toString().trim() ?? (isCustom ? rawRole : defaultJobTitleForRole(role));

    final isActiveRaw = map['is_active'] ?? map['isActive'];
    final isActiveVal = isActiveRaw == 1 || isActiveRaw == true || isActiveRaw == '1' || isActiveRaw == 'true' || isActiveRaw == null;

    final avatarColorRaw = map['avatar_color'] ?? map['avatarColor'];
    final avatarColorVal = avatarColorRaw != null ? (avatarColorRaw as num).toInt() : null;

    final permsRaw = permissions ?? map['custom_permissions'] ?? map['customPermissions'] ?? map['permissions'];
    List<String>? parsedPermissions;
    if (permsRaw is List) {
      parsedPermissions = permsRaw.map((e) => e.toString()).toList();
    }

    final createdAtRaw = map['created_at'] ?? map['createdAt'];
    final lastLoginRaw = map['last_login'] ?? map['lastLogin'];

    return UserModel(
      id: map['id'] != null ? (map['id'] is int ? map['id'] : int.tryParse(map['id'].toString())) : null,
      branchId: branchIdVal,
      fullName: fullNameVal.isNotEmpty ? fullNameVal : (usernameVal.isNotEmpty ? usernameVal : 'مستخدم'),
      username: usernameVal,
      role: role,
      customRoleTitle: isCustom ? rawRole : null,
      customPermissions: parsedPermissions,
      email: map['email']?.toString(),
      passwordHash: (map['password_hash'] ?? map['passwordHash'])?.toString(),
      phone: map['phone']?.toString(),
      jobTitle: jobTitleVal,
      isActive: isActiveVal,
      avatarColor: avatarColorVal,
      createdAt: createdAtRaw != null ? DateTime.tryParse(createdAtRaw.toString()) : null,
      lastLogin: lastLoginRaw != null ? DateTime.tryParse(lastLoginRaw.toString()) : null,
    );
  }

  UserModel copyWith({
    int? id,
    int? branchId,
    String? fullName,
    String? username,
    UserRole? role,
    String? customRoleTitle,
    List<String>? customPermissions,
    String? email,
    String? passwordHash,
    String? phone,
    String? jobTitle,
    bool? isActive,
    int? avatarColor,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return UserModel(
      id: id ?? this.id,
      branchId: branchId ?? this.branchId,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      role: role ?? this.role,
      customRoleTitle: customRoleTitle ?? this.customRoleTitle,
      customPermissions: customPermissions ?? this.customPermissions,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      phone: phone ?? this.phone,
      jobTitle: jobTitle ?? this.jobTitle,
      isActive: isActive ?? this.isActive,
      avatarColor: avatarColor ?? this.avatarColor,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }

  /// التحقق مما إذا كان المستخدم يملك صلاحية معينة (بكود نصي)
  ///
  /// مصدر الحقيقة الوحيد بعد التوحيد: `customPermissions` المُحمَّلة من جدول
  /// الأدوار (CustomRoles) وقت تسجيل الدخول/استعادة الجلسة.
  ///
  /// عند غياب `customPermissions` (مستخدم جُلب مباشرة من DB قبل تحميل صلاحياته)
  /// نرجع `false` صراحةً (fail-closed) بدل الرجوع لمصفوفة Enum متقادمة كانت
  /// تمنح صلاحيات متعارضة مع ما هو مخزّن في قاعدة البيانات.
  bool hasPermissionCode(String permCode) {
    if (!isActive) return false;
    if (role == UserRole.admin || role == UserRole.generalManager) return true;
    if (customPermissions != null) {
      return customPermissions!.contains(permCode);
    }
    // fail-closed: الصلاحيات تُحمَّل دائماً من CustomRoles في مسارات الجلسة.
    return false;
  }

  static String roleToString(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.generalManager:
        return 'GeneralManager';
      case UserRole.qualityManager:
        return 'QualityManager';
      case UserRole.factoryManager:
        return 'FactoryManager';
      case UserRole.qualitySpecialist:
        return 'QualitySpecialist';
      case UserRole.qualitySupervisor:
        return 'QualitySupervisor';
      case UserRole.foodSafetyEngineer:
        return 'FoodSafetyEngineer';
    }
  }

  static UserRole stringToRole(String? raw) {
    if (raw == null) return UserRole.qualitySpecialist;
    final r = raw.trim().toLowerCase();
    final normalized = r.replaceAll(RegExp(r'[_\s-]+'), '');
    if (r == 'admin' || r == 'administrator' || r.contains('مدير النظام')) {
      return UserRole.admin;
    }
    if (normalized == 'generalmanager' || normalized == 'gmanager' || normalized == 'general' || r.contains('مدير عام') || r.contains('المدير العام')) {
      return UserRole.generalManager;
    }
    if (normalized == 'qualitymanager' || r == 'qm' || r.contains('مدير الجودة')) {
      return UserRole.qualityManager;
    }
    if (normalized == 'factorymanager' || r == 'gm' || r.contains('مدير المصنع')) {
      return UserRole.factoryManager;
    }
    if (normalized == 'foodsafetyengineer' || normalized == 'foodsafety' || r == 'fse' || r.contains('سلامة الغذاء') || r.contains('مهندس سلامة')) {
      return UserRole.foodSafetyEngineer;
    }
    if (normalized == 'qualitysupervisor' || r == 'qs' || r.contains('مشرف الجودة')) {
      return UserRole.qualitySupervisor;
    }
    return UserRole.qualitySpecialist;
  }

  static String roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'مسؤول النظام (المدير التقني)';
      case UserRole.generalManager:
        return 'المدير العام';
      case UserRole.qualityManager:
        return 'مدير الجودة';
      case UserRole.factoryManager:
        return 'مدير المصنع';
      case UserRole.qualitySpecialist:
        return 'أخصائي الجودة / منفذ الفحص';
      case UserRole.qualitySupervisor:
        return 'مشرف الجودة';
      case UserRole.foodSafetyEngineer:
        return 'مهندس سلامة الغذاء';
    }
  }

  static String defaultJobTitleForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'مدير تقنية المعلومات والنظام';
      case UserRole.generalManager:
        return 'المدير العام';
      case UserRole.qualityManager:
        return 'مدير توكيد ورقابة الجودة';
      case UserRole.factoryManager:
        return 'المدير العام لمصنع المياه';
      case UserRole.qualitySpecialist:
        return 'أخصائي فحص ومطابقة جودة';
      case UserRole.qualitySupervisor:
        return 'مشرف الجودة والرقابة';
      case UserRole.foodSafetyEngineer:
        return 'مهندس سلامة الغذاء';
    }
  }

  static Color defaultColorForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return const Color(0xFF37474F); // Blue Grey
      case UserRole.generalManager:
        return const Color(0xFF0D47A1); // Deep Blue
      case UserRole.qualityManager:
        return const Color(0xFF2E7D32); // Green
      case UserRole.factoryManager:
        return const Color(0xFF6A1B9A); // Purple
      case UserRole.qualitySpecialist:
        return const Color(0xFF007791); // Deep Teal / Blue
      case UserRole.qualitySupervisor:
        return const Color(0xFF00897B); // Teal
      case UserRole.foodSafetyEngineer:
        return const Color(0xFFE65100); // Deep Orange
    }
  }

  static IconData defaultIconForRole(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      case UserRole.generalManager:
        return Icons.supervisor_account_rounded;
      case UserRole.qualityManager:
        return Icons.verified_user_rounded;
      case UserRole.factoryManager:
        return Icons.business_center_rounded;
      case UserRole.qualitySpecialist:
        return Icons.science_rounded;
      case UserRole.qualitySupervisor:
        return Icons.policy_rounded;
      case UserRole.foodSafetyEngineer:
        return Icons.health_and_safety_rounded;
    }
  }
}
