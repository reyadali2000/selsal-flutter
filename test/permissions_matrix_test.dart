// اختبارات المرحلة الأولى: مصفوفة الصلاحيات + عزل الأقسام + الأدوار غير المعروفة
// الغرض: تجميد السلوك الحالي وكشف التعارضات بين مصدري الحقيقة (DB مقابل enum)
// ملاحظة: لا تفترض هذه الاختبارات أن الوضع الحالي صحيح — بل توثّقه كما هو.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

import 'package:wadialain/models/role_model.dart';
import 'package:wadialain/models/user_model.dart';

/// ====== أدوات مساعدة ======

/// تحويل AppPermission إلى كود نصي لغرض الاختبارات
String _appPermToCode(AppPermission perm) {
  switch (perm) {
    case AppPermission.createReports:
      return SystemPermissions.createWaterReports;
    case AppPermission.createRawMaterialReports:
      return SystemPermissions.createRawMaterialReports;
    case AppPermission.createHygieneReports:
      return SystemPermissions.createHygieneReports;
    case AppPermission.editDraftReports:
      return SystemPermissions.editReports;
    case AppPermission.deleteReports:
      return SystemPermissions.deleteReports;
    case AppPermission.viewReports:
      return SystemPermissions.viewReports;
    case AppPermission.approveQuality:
      return SystemPermissions.approveQM;
    case AppPermission.approveFactory:
      return SystemPermissions.approveGM;
    case AppPermission.rejectReport:
      return SystemPermissions.rejectReports;
    case AppPermission.manageDynamicReports:
      return SystemPermissions.designDynamicReports;
    case AppPermission.fillDynamicReports:
      return SystemPermissions.fillDynamicReports;
    case AppPermission.fillHealthReports:
      return SystemPermissions.fillHealthReports;
    case AppPermission.viewHealthReports:
      return SystemPermissions.viewHealthReports;
    case AppPermission.viewShifts:
      return SystemPermissions.viewShifts;
    case AppPermission.manageShifts:
      return SystemPermissions.manageShifts;
    case AppPermission.manageUsers:
      return SystemPermissions.manageUsers;
    case AppPermission.manageSettings:
      return SystemPermissions.manageSettings;
    case AppPermission.exportData:
      return SystemPermissions.exportPdf;
  }
}

/// المصفوفة المرجعية للصلاحيات (مأخوذة من RoleModel.defaultSystemRoles — مصدر DB)
Map<String, Set<String>> _expectedFromDefaultSystemRoles() {
  final map = <String, Set<String>>{};
  for (final role in RoleModel.defaultSystemRoles) {
    map[role.code] = role.permissions.toSet();
  }
  return map;
}

/// كل أكواد الصلاحيات المعروفة في الكتالوج
final Set<String> _allCatalogCodes =
    SystemPermissions.all.map((p) => p.code).toSet();

/// صلاحيات قسم الجودة (يجب ألا يملكها مهندس سلامة الغذاء)
const Set<String> _qualityOnlyCodes = {
  SystemPermissions.createWaterReports,
  SystemPermissions.fillQualityDynamicReports,
};

/// صلاحيات قسم سلامة الغذاء (يجب ألا يملكها أخصائي الجودة)
const Set<String> _foodSafetyOnlyCodes = {
  SystemPermissions.fillFoodSafetyDynamicReports,
  SystemPermissions.fillHealthReports,
  SystemPermissions.viewHealthReports,
  SystemPermissions.createHygieneReports,
};

RoleModel _role(String code) {
  return RoleModel.defaultSystemRoles.firstWhere(
    (r) => r.code == code,
    orElse: () => fail('الدور $code غير موجود في defaultSystemRoles'),
  );
}

/// ====== 1) مصفوفة الصلاحيات: دور × كل صلاحية ======

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('1) مصفوفة الصلاحيات — مصدر DB (defaultSystemRoles)', () {
    final expected = _expectedFromDefaultSystemRoles();

    test('admin يملك كل صلاحيات الكتالوج', () {
      final admin = _role('admin');
      expect(admin.permissions.toSet(), _allCatalogCodes,
          reason: 'admin يجب أن يملك كل صلاحيات SystemPermissions.all');
    });

    test('general_manager يملك كل صلاحيات الكتالوج', () {
      final gm = _role('general_manager');
      expect(gm.permissions.toSet(), _allCatalogCodes,
          reason: 'general_manager يجب أن يملك كل صلاحيات SystemPermissions.all');
    });

    test('كل صلاحية في المصفوفة تنتمي فعلاً للكتالوج', () {
      for (final entry in expected.entries) {
        for (final code in entry.value) {
          expect(_allCatalogCodes.contains(code), isTrue,
              reason: 'الدور ${entry.key} يحمل صلاحية "$code" غير موجودة في الكتالوج');
        }
      }
    });

    test('لا توجد صلاحية مكررة داخل أي دور', () {
      for (final role in RoleModel.defaultSystemRoles) {
        expect(role.permissions.length, role.permissions.toSet().length,
            reason: 'الدور ${role.code} يحتوي على صلاحيات مكررة');
      }
    });

    test('كل الأدوار الستة موجودة في defaultSystemRoles', () {
      final codes = RoleModel.defaultSystemRoles.map((r) => r.code).toSet();
      expect(codes, containsAll(<String>[
        'admin',
        'general_manager',
        'quality_manager',
        'factory_manager',
        'quality_specialist',
        'food_safety_engineer',
      ]));
    });

    // —— المصفوفة الكاملة: لكل دور، كل صلاحية، متوقع —— //
    final matrix = <String, Map<String, bool>>{
      'quality_manager': {
        SystemPermissions.createWaterReports: true,
        SystemPermissions.createRawMaterialReports: true,
        SystemPermissions.createHygieneReports: false,
        SystemPermissions.fillQualityDynamicReports: true,
        SystemPermissions.fillFoodSafetyDynamicReports: false,
        SystemPermissions.fillHealthReports: false,
        SystemPermissions.viewHealthReports: false,
        SystemPermissions.viewReports: true,
        SystemPermissions.editReports: true,
        SystemPermissions.deleteReports: false,
        SystemPermissions.approveQM: true,
        SystemPermissions.approveGM: false,
        SystemPermissions.rejectReports: true,
        SystemPermissions.designDynamicReports: true,
        SystemPermissions.viewShifts: true,
        SystemPermissions.manageShifts: false,
        SystemPermissions.manageUsers: false,
        SystemPermissions.manageRoles: false,
        SystemPermissions.manageSettings: false,
        SystemPermissions.manageProducts: true,
        SystemPermissions.manageDailyWorkers: true,
        SystemPermissions.exportPdf: true,
        SystemPermissions.manageSignature: true,
        SystemPermissions.changePassword: true,
      },
      'factory_manager': {
        SystemPermissions.createWaterReports: false,
        SystemPermissions.createRawMaterialReports: false,
        SystemPermissions.createHygieneReports: false,
        SystemPermissions.fillQualityDynamicReports: false,
        SystemPermissions.fillFoodSafetyDynamicReports: false,
        SystemPermissions.fillHealthReports: false,
        SystemPermissions.viewHealthReports: true,
        SystemPermissions.viewReports: true,
        SystemPermissions.editReports: false,
        SystemPermissions.deleteReports: false,
        SystemPermissions.approveQM: false,
        SystemPermissions.approveGM: true,
        SystemPermissions.rejectReports: true,
        SystemPermissions.designDynamicReports: false,
        SystemPermissions.viewShifts: true,
        SystemPermissions.manageShifts: false,
        SystemPermissions.manageUsers: false,
        SystemPermissions.manageRoles: false,
        SystemPermissions.manageSettings: false,
        SystemPermissions.manageProducts: false,
        SystemPermissions.manageDailyWorkers: true,
        SystemPermissions.exportPdf: true,
        SystemPermissions.manageSignature: true,
        SystemPermissions.changePassword: true,
      },
      'quality_specialist': {
        SystemPermissions.createWaterReports: true,
        SystemPermissions.createRawMaterialReports: true,
        SystemPermissions.createHygieneReports: true,
        SystemPermissions.fillQualityDynamicReports: true,
        SystemPermissions.fillFoodSafetyDynamicReports: false,
        SystemPermissions.fillHealthReports: false,
        SystemPermissions.viewHealthReports: false,
        SystemPermissions.viewReports: true,
        SystemPermissions.editReports: true,
        SystemPermissions.deleteReports: false,
        SystemPermissions.approveQM: false,
        SystemPermissions.approveGM: false,
        SystemPermissions.rejectReports: false,
        SystemPermissions.designDynamicReports: false,
        SystemPermissions.viewShifts: false,
        SystemPermissions.manageShifts: false,
        SystemPermissions.manageUsers: false,
        SystemPermissions.manageRoles: false,
        SystemPermissions.manageSettings: false,
        SystemPermissions.manageProducts: false,
        SystemPermissions.manageDailyWorkers: false,
        SystemPermissions.exportPdf: true,
        SystemPermissions.manageSignature: true,
        SystemPermissions.changePassword: true,
      },
      'food_safety_engineer': {
        SystemPermissions.createWaterReports: false,
        SystemPermissions.createRawMaterialReports: false,
        SystemPermissions.createHygieneReports: true,
        SystemPermissions.fillQualityDynamicReports: false,
        SystemPermissions.fillFoodSafetyDynamicReports: true,
        SystemPermissions.fillHealthReports: true,
        SystemPermissions.viewHealthReports: true,
        SystemPermissions.viewReports: false,
        SystemPermissions.editReports: true,
        SystemPermissions.deleteReports: false,
        SystemPermissions.approveQM: false,
        SystemPermissions.approveGM: false,
        SystemPermissions.rejectReports: false,
        SystemPermissions.designDynamicReports: false,
        SystemPermissions.viewShifts: false,
        SystemPermissions.manageShifts: false,
        SystemPermissions.manageUsers: false,
        SystemPermissions.manageRoles: false,
        SystemPermissions.manageSettings: false,
        SystemPermissions.manageProducts: false,
        SystemPermissions.manageDailyWorkers: false,
        SystemPermissions.exportPdf: true,
        SystemPermissions.manageSignature: true,
        SystemPermissions.changePassword: true,
      },
    };

    for (final entry in matrix.entries) {
      test('${entry.key}: مطابقة كاملة لمصفوفة الصلاحيات', () {
        final role = _role(entry.key);
        for (final perm in entry.value.entries) {
          final has = role.permissions.contains(perm.key);
          final expectedValue = perm.value;
          expect(has, expectedValue,
              reason:
                  'الدور ${entry.key}: صلاحية "${perm.key}" المتوقع ${expectedValue ? "موجودة" : "غير موجودة"} لكنها ${has ? "موجودة" : "غير موجودة"}');
        }
      });
    }
  });

  group('2) مصفوفة الصلاحيات — مصدر enum المتقادم (permissionsForRole)', () {
    test('كل صلاحيات enum لها مقابل في كتالوج SystemPermissions', () {
      for (final role in UserRole.values) {
        final enumPerms = UserModel.permissionsForRole(role);
        for (final p in enumPerms) {
          expect(_allCatalogCodes, contains(_appPermToCode(p)),
              reason: 'الدور ${UserModel.roleToString(role)}: صلاحية enum "$p" '
                  'أنتجت كوداً غير موجود في الكتالوج');
        }
      }
    });

    test('admin/general_manager في enum يملكان كل صلاحيات الـ enum', () {
      expect(UserModel.permissionsForRole(UserRole.admin).length,
          AppPermission.values.length);
      expect(UserModel.permissionsForRole(UserRole.generalManager).length,
          AppPermission.values.length);
    });

    test('تعارض: enum quality_specialist يمنح صلاحيات سلامة الغذاء', () {
      final dbPerms = _role('quality_specialist').permissions.toSet();
      final enumPerms = UserModel.permissionsForRole(UserRole.qualitySpecialist)
          .map((p) => _appPermToCode(p))
          .toSet();

      // توثيق التعارض الحي: enum يمنح fillHealthReports و viewHealthReports بينما DB يرفضهما
      expect(enumPerms.contains(SystemPermissions.fillHealthReports), isTrue);
      expect(dbPerms.contains(SystemPermissions.fillHealthReports), isFalse);
      expect(enumPerms.contains(SystemPermissions.viewHealthReports), isTrue);
      expect(dbPerms.contains(SystemPermissions.viewHealthReports), isFalse);
    });

    test('تعارض: enum food_safety_engineer يمنح صلاحيات الجودة', () {
      final dbPerms = _role('food_safety_engineer').permissions.toSet();
      final enumPerms = UserModel.permissionsForRole(UserRole.foodSafetyEngineer)
          .map((p) => _appPermToCode(p))
          .toSet();

      // توثيق التعارض الحي: enum يمنح createRawMaterialReports و viewReports بينما DB يرفضهما
      expect(enumPerms.contains(SystemPermissions.createRawMaterialReports), isTrue);
      expect(dbPerms.contains(SystemPermissions.createRawMaterialReports), isFalse);
      expect(enumPerms.contains(SystemPermissions.viewReports), isTrue);
      expect(dbPerms.contains(SystemPermissions.viewReports), isFalse);
    });
  });

  group('3) عزل الأقسام بين الجودة وسلامة الغذاء', () {
    test('quality_specialist في DB لا يملك أية صلاحية حصرية لسلامة الغذاء', () {
      final perms = _role('quality_specialist').permissions.toSet();
      // createHygieneReports مشتركة/تاريخية، لكن fillHealthReports و viewHealthReports و fillFoodSafetyDynamic حصرية
      expect(perms, isNot(contains(SystemPermissions.fillHealthReports)));
      expect(perms, isNot(contains(SystemPermissions.viewHealthReports)));
      expect(perms, isNot(contains(SystemPermissions.fillFoodSafetyDynamicReports)));
    });

    test('food_safety_engineer في DB لا يملك أية صلاحية حصرية للجودة', () {
      final perms = _role('food_safety_engineer').permissions.toSet();
      final leakage = perms.intersection(_qualityOnlyCodes);
      expect(leakage, isEmpty,
          reason: 'تسرّب صلاحيا�� الجودة إلى مهندس سلامة الغذاء: $leakage');
    });

    test('quality_manager لا يملك صلاحيات تعبئة سلامة الغذاء', () {
      final perms = _role('quality_manager').permissions.toSet();
      expect(perms, isNot(contains(SystemPermissions.fillFoodSafetyDynamicReports)));
      expect(perms, isNot(contains(SystemPermissions.fillHealthReports)));
      expect(perms, isNot(contains(SystemPermissions.viewHealthReports)));
    });

    test('dynamicFillPermissionForCategory يعيد الصلاحية الصحيحة حسب القسم', () {
      expect(SystemPermissions.dynamicFillPermissionForCategory(1),
          SystemPermissions.fillQualityDynamicReports);
      expect(SystemPermissions.dynamicFillPermissionForCategory(2),
          SystemPermissions.fillFoodSafetyDynamicReports);
      expect(SystemPermissions.dynamicFillPermissionForCategory(null),
          SystemPermissions.fillQualityDynamicReports);
    });

    test('canFillDynamicInCategory يعزل حسب القسم (مصدر الكتالوج)', () {
      final qPerms = _role('quality_specialist').permissions;
      final fPerms = _role('food_safety_engineer').permissions;

      expect(
          SystemPermissions.canFillDynamicInCategory(1, qPerms), isTrue,
          reason: 'أخصائي الجودة يستطيع تعبئة نماذج الجودة');
      expect(
          SystemPermissions.canFillDynamicInCategory(2, qPerms), isFalse,
          reason: 'أخصائي الجودة لا يستطيع تعبئة نماذج سلامة الغذاء');
      expect(
          SystemPermissions.canFillDynamicInCategory(2, fPerms), isTrue,
          reason: 'مهندس سلامة الغذاء يستطيع تعبئة نماذج سلامة الغذاء');
      expect(
          SystemPermissions.canFillDynamicInCategory(1, fPerms), isFalse,
          reason: 'مهندس سلامة الغذاء لا يستطيع تعبئة نماذج الجودة');
    });

    test('removeCrossDepartmentPermissionsForSystemRole ينظف التسرّبات', () {
      final contaminatedQs = <String>[
        ..._role('quality_specialist').permissions,
        SystemPermissions.fillHealthReports,
        SystemPermissions.viewHealthReports,
        SystemPermissions.fillFoodSafetyDynamicReports,
      ];
      final cleaned = SystemPermissions.removeCrossDepartmentPermissionsForSystemRole(
          'quality_specialist', contaminatedQs);
      expect(cleaned, isNot(contains(SystemPermissions.fillHealthReports)));
      expect(cleaned, isNot(contains(SystemPermissions.viewHealthReports)));
      expect(cleaned, isNot(contains(SystemPermissions.fillFoodSafetyDynamicReports)));
      expect(cleaned, contains(SystemPermissions.fillQualityDynamicReports));
    });

    test('removeCrossDepartment لا يمسح صلاحيات دور غير معروف (سلوك موثّق)', () {
      final custom = <String>[
        SystemPermissions.fillHealthReports,
        SystemPermissions.createWaterReports,
      ];
      final cleaned = SystemPermissions.removeCrossDepartmentPermissionsForSystemRole(
          'custom_role', custom);
      expect(cleaned.length, custom.length,
          reason: 'الأدوار المخصصة لا تُنظَّف — موثّق كقياس');
    });

    test('migratePermissions يفكك fill_dynamic_reports لكلا القسمين', () {
      final migrated =
          SystemPermissions.migratePermissions([SystemPermissions.fillDynamicReports]);
      expect(migrated, contains(SystemPermissions.fillQualityDynamicReports));
      expect(migrated, contains(SystemPermissions.fillFoodSafetyDynamicReports));
    });

    test('migratePermissions يسقط الأكواد غير الموجودة في الكتالوج', () {
      final migrated = SystemPermissions.migratePermissions(
          ['unknown_old_code', SystemPermissions.createWaterReports]);
      expect(migrated, isNot(contains('unknown_old_code')));
      expect(migrated, contains(SystemPermissions.createWaterReports));
    });

    test('migratePermissions يضيف manageSignature/changePassword للأدوار القديمة', () {
      final migrated =
          SystemPermissions.migratePermissions([SystemPermissions.createWaterReports]);
      expect(migrated, contains(SystemPermissions.manageSignature));
      expect(migrated, contains(SystemPermissions.changePassword));
    });

    test('صلاحية fill_dynamic_reports القديمة لا تزال معروضة في الكتالوج (D.1)', () {
      final inCatalog = SystemPermissions.all
          .any((p) => p.code == SystemPermissions.fillDynamicReports);
      expect(inCatalog, isTrue,
          reason: 'صلاحية ميتة (fill_dynamic_reports) لا تزال في SystemPermissions.all '
              'وتُعرَض في واجهة إدارة الأدوار');
    });
  });

  // ====== 4) اختبار حالات الأدوار غير المعروفة (agm, sysadmin, sqm, مخصص) ======

  group('4) حالات الأدوار غير المعروفة والمطابقة النصية (D.4/D.5)', () {
    test('stringToRole: agm و sqm و sysadmin تسقط للأخصائي الافتراضي', () {
      // stringToRole تستخدم == (مطابقة دقيقة) لـ 'gm' و 'qm' و 'admin'
      expect(UserModel.stringToRole('agm'), UserRole.qualitySpecialist,
          reason: "'agm' ليست 'gm' → تسقط للافتراضي");
      expect(UserModel.stringToRole('sqm'), UserRole.qualitySpecialist,
          reason: "'sqm' ليست 'qm' → تسقط للافتراضي");
      expect(UserModel.stringToRole('sysadmin'), UserRole.qualitySpecialist,
          reason: "'sysadmin' ليست 'admin' → تسقط للافتراضي");
      expect(UserModel.stringToRole('محاسب'), UserRole.qualitySpecialist,
          reason: "اسم مخصص غير معروف → يسقط للافتراضي");
    });

    test('stringToRole: المطابقة الدقيقة تنجح للأدوار الصحيحة فقط', () {
      expect(UserModel.stringToRole('admin'), UserRole.admin);
      expect(UserModel.stringToRole('gm'), UserRole.factoryManager);
      expect(UserModel.stringToRole('qm'), UserRole.qualityManager);
      expect(UserModel.stringToRole('gmanager'), UserRole.generalManager);
      expect(UserModel.stringToRole('QualityManager'), UserRole.qualityManager);
      expect(UserModel.stringToRole('FoodSafetyEngineer'), UserRole.foodSafetyEngineer);
    });

    test('توثيق سلوك normalized.contains في roles_database_service', () {
      // محاكاة منطق getPermissionsForRole fallback (الأسطر 213-228 من roles_database_service.dart)
      List<String> simulateFallback(String roleCodeOrTitle) {
        final clean = roleCodeOrTitle.trim().toLowerCase();
        final normalized = clean.replaceAll('_', '').replaceAll(' ', '');

        if (normalized.contains('admin') || normalized.contains('مديرالنظام')) {
          return SystemPermissions.all.map((p) => p.code).toList();
        } else if (normalized.contains('generalmanager') ||
            normalized.contains('gmanager') ||
            normalized.contains('مديرعام') ||
            normalized.contains('المديرالعام')) {
          return SystemPermissions.all.map((p) => p.code).toList();
        } else if (normalized.contains('qualitymanager') ||
            normalized.contains('qm') ||
            normalized.contains('مديرالجودة')) {
          return RoleModel.defaultSystemRoles
              .firstWhere((e) => e.code == 'quality_manager')
              .permissions;
        } else if (normalized.contains('factorymanager') ||
            normalized.contains('gm') ||
            normalized.contains('مديرالمصنع')) {
          return RoleModel.defaultSystemRoles
              .firstWhere((e) => e.code == 'factory_manager')
              .permissions;
        } else if (normalized.contains('foodsafetyengineer') ||
            normalized.contains('foodsafety') ||
            normalized.contains('سلامةالغذاء') ||
            normalized.contains('مهندسسلامة')) {
          return RoleModel.defaultSystemRoles
              .firstWhere((e) => e.code == 'food_safety_engineer')
              .permissions;
        }
        return RoleModel.defaultSystemRoles
            .firstWhere((e) => e.code == 'quality_specialist')
            .permissions;
      }

      // 1. sysadmin يحتوي 'admin' → يأخذ كامل الصلاحيات!
      final sysadminPerms = simulateFallback('sysadmin');
      expect(sysadminPerms.length, SystemPermissions.all.length,
          reason: "D.4: 'sysadmin' يحتوي 'admin' → أخذ كامل صلاحيات المدير");

      // 2. agm يحتوي 'gm' → يأخذ صلاحيات factory_manager!
      final agmPerms = simulateFallback('agm');
      final fmPerms = _role('factory_manager').permissions;
      expect(agmPerms, equals(fmPerms),
          reason: "D.4: 'agm' يحتوي 'gm' → أخذ صلاحيات مدير المصنع");

      // 3. sqm يحتوي 'qm' → يأخذ صلاحيات quality_manager!
      final sqmPerms = simulateFallback('sqm');
      final qmPerms = _role('quality_manager').permissions;
      expect(sqmPerms, equals(qmPerms),
          reason: "D.4: 'sqm' يحتوي 'qm' → أخذ صلاحيات مدير الجودة");

      // 4. محاسب (اسم مخصص غير مطابق) → يسقط لأخصائي الجودة (fail-open)!
      final accountantPerms = simulateFallback('محاسب');
      final qsPerms = _role('quality_specialist').permissions;
      expect(accountantPerms, equals(qsPerms),
          reason: "D.5: دور غير معروف 'محاسب' → أخذ صلاحيات أخصائي الجودة (fail-open)");

      // 5. تعارض بين stringToRole و fallback:
      // stringToRole('agm') = qualitySpecialist
      // simulateFallback('agm') = factory_manager permissions!
      expect(UserModel.stringToRole('agm'), UserRole.qualitySpecialist);
      expect(simulateFallback('agm'), isNot(equals(qsPerms)),
          reason: 'تعارض حقيقي: الـ enum يقول أخصائي جودة، والصلاحيات تُمنح كمدير مصنع!');
    });
  });

  // ====== 5) مسارات تحميل الصلاحيات (قاعدة البيانات + الجلسة) ======

  group('5) مسارات تحميل الصلاحيات — قاعدة البيانات والجلسة', () {
    late Database db;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE CustomRoles (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              code TEXT UNIQUE NOT NULL,
              title TEXT NOT NULL,
              description TEXT,
              color INTEGER,
              icon_name TEXT,
              permissions_json TEXT NOT NULL,
              is_system INTEGER DEFAULT 0,
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE Users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              branch_id INTEGER,
              full_name TEXT,
              username TEXT UNIQUE,
              role TEXT,
              email TEXT,
              password_hash TEXT,
              phone TEXT,
              job_title TEXT,
              is_active INTEGER DEFAULT 1,
              avatar_color INTEGER,
              created_at TEXT,
              last_login TEXT,
              FOREIGN KEY (branch_id) REFERENCES Branches(id)
            )
          ''');
          await db.execute('''
            CREATE TABLE Branches (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              code TEXT UNIQUE,
              location TEXT,
              is_active INTEGER DEFAULT 1
            )
          ''');
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('توثيق: جدول Users يخزّن role كنص ولا يوجد عمود role_id', () async {
      final cols = await db.rawQuery("PRAGMA table_info('Users')");
      final names = cols.map((c) => c['name'].toString()).toSet();
      expect(names.contains('role'), isTrue, reason: 'عمود role النصي موجود');
      expect(names.contains('role_id'), isFalse, reason: 'لا يوجد role_id في الهيكل الحالي');
    });

    test('مسار login: UserModel بدون customPermissions يسقط في enum fallback', () {
      final user = UserModel(
        id: 1,
        fullName: 'أخصائي تجريبي',
        username: 'test_qs',
        role: UserRole.qualitySpecialist,
        customPermissions: null, // لم تُحمَّل بعد
      );

      // هنا يظهر التعارض الحي: UserModel.hasPermissionCode يستخدم _appPermToCode + permissionsForRole
      // والـ enum يمنح fillHealthReports لأخصائي الجودة!
      expect(user.hasPermissionCode(SystemPermissions.fillHealthReports), isTrue,
          reason: 'تعارض موثّق: المسار بدون customPermissions يسقط في enum fallback '
              'ويمنح صلاحيات سلامة الغذاء لأخصائي الجودة!');
    });

    test('مسار login: بعد تحميل customPermissions تُحترم صلاحيات DB الحقيقية', () {
      final dbRole = _role('quality_specialist');
      final user = UserModel(
        id: 1,
        fullName: 'أخصائي تجريبي',
        username: 'test_qs',
        role: UserRole.qualitySpecialist,
        customPermissions: dbRole.permissions, // حُمّلت من DB
      );

      // الآن مع customPermissions: العزل يعمل بشكل سليم
      expect(user.hasPermissionCode(SystemPermissions.fillHealthReports), isFalse,
          reason: 'مع customPermissions: أخصائي الجودة لا يملك fillHealthReports');
      expect(user.hasPermissionCode(SystemPermissions.createWaterReports), isTrue);
    });

    test('admin/general_manager يتجاوزان دائماً بغض النظر عن customPermissions', () {
      final admin = UserModel(
        id: 1,
        fullName: 'أدمن',
        username: 'admin',
        role: UserRole.admin,
        customPermissions: null,
      );
      final gm = UserModel(
        id: 2,
        fullName: 'مدير عام',
        username: 'gm_user',
        role: UserRole.generalManager,
        customPermissions: null,
      );

      expect(admin.hasPermissionCode(SystemPermissions.manageUsers), isTrue);
      expect(gm.hasPermissionCode(SystemPermissions.manageUsers), isTrue);
    });

    test('المستخدم غير النشط تُرفض كل صلاحياته', () {
      final inactive = UserModel(
        id: 1,
        fullName: 'معطّل',
        username: 'inactive_admin',
        role: UserRole.admin,
        customPermissions: SystemPermissions.all.map((p) => p.code).toList(),
        isActive: false,
      );
      expect(inactive.hasPermissionCode(SystemPermissions.manageUsers), isFalse);
    });

    test('توثيق مشكلة D.3: إعادة تسمية دور مخصص تيتم المستخدمين في DB', () async {
      // 1. إنشاء دور مخصص
      await db.insert('CustomRoles', {
        'code': 'auditor',
        'title': 'مدقق جودة خارجي',
        'permissions_json': '["view_reports","export_pdf"]',
        'is_system': 0,
      });

      // 2. إنشاء مستخدم مرتبط بهذا الدور (يخزّن العنوان نصياً كما في users_management_view)
      await db.insert('Users', {
        'full_name': 'سعيد المدقق',
        'username': 'saeed',
        'role': 'مدقق جودة خارجي', // العنوان القديم
        'is_active': 1,
      });

      // 3. تعديل عنوان الدور في CustomRoles (محاكاة updateRole)
      await db.update(
        'CustomRoles',
        {'title': 'مدقق رقابة وتفتيش'},
        where: "code = 'auditor'",
      );

      // 4. قراءة المستخدم والتحقق من المطابقة:
      final userRow = (await db.query('Users', where: "username = 'saeed'")).first;
      final storedRole = userRow['role'].toString();

      // البحث في CustomRoles بالعنوان المخزّن (القديم)
      final match = await db.query(
        'CustomRoles',
        where: 'LOWER(title) = ? OR LOWER(code) = ?',
        whereArgs: [storedRole.toLowerCase(), storedRole.toLowerCase()],
      );

      expect(match, isEmpty,
          reason: "D.3 مؤكدة: إعادة تسمية عنوان الدور في CustomRoles جعل المستخدم 'saeed' "
              "يتيماً — لم يعد يطابق الدور بالاسم القديم ('مدقق جودة خارجي')");
    });

    test('توثيق مشكلة D.6: foodsafetyengineer يُعتبر دوراً مخصصاً في fromMap', () {
      final fse = UserModel.fromMap({
        'id': 12,
        'full_name': 'م. بشير القدسي',
        'username': 'basheer_fs',
        'role': 'FoodSafetyEngineer',
        'is_active': 1,
      });

      expect(fse.role, UserRole.foodSafetyEngineer,
          reason: 'enum role يُحل صحيحاً');
      expect(fse.customRoleTitle, isNotNull,
          reason: 'D.6 مؤكدة: foodsafetyengineer ناقص من قائمة الأدوار النظامية في fromMap '
              'فيُعتبر دوراً مخصصاً ويأخذ customRoleTitle');
      expect(fse.displayRoleTitle, 'FoodSafetyEngineer',
          reason: 'D.6 تأثير مرئي: يظهر الكود الإنجليزي في الواجهة بدل التسمية العربية');
    });
  });
}
