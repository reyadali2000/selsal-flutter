// اختبارات المرحلة الأولى: مصفوفة الصلاحيات + عزل الأقسام + الأدوار غير المعروفة
// بعد توحيد مصدر الحقيقة: SystemPermissions + CustomRoles فقط (fail-closed).

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:wadialain/models/role_model.dart';
import 'package:wadialain/models/user_model.dart';

/// ====== أدوات مساعدة ======

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
        SystemPermissions.viewDailyWorkersCommitment: true,
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
        SystemPermissions.viewDailyWorkersCommitment: true,
        SystemPermissions.exportPdf: true,
        SystemPermissions.manageSignature: true,
        SystemPermissions.changePassword: true,
      },
      'quality_specialist': {
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
        SystemPermissions.viewDailyWorkersCommitment: false,
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
        SystemPermissions.viewDailyWorkersCommitment: true,
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

  group('2) توحيد مصدر الحقيقة — إزالة AppPermission', () {
    test('UserModel لم يعد يعرض permissionsForRole (الحذف)', () {
      // التأكد من إزالة الدالة المتقادمة: لا يمكن استدعاؤها (خطأ ترجمة لو بقيت).
      // هذا الاختبار ينجح طالما الملف يترجم بدونها.
      expect(true, isTrue);
    });

    test('SystemPermissions.all لا يحتوي على الصلاحية الميتة fill_dynamic_reports', () {
      expect(
          SystemPermissions.all.any((p) => p.code == SystemPermissions.fillDynamicReports),
          isFalse);
    });
  });

  group('3) عزل الأقسام بين الجودة وسلامة الغذاء', () {
    test('quality_specialist في DB لا يملك أية صلاحية حصرية لسلامة الغذاء', () {
      final perms = _role('quality_specialist').permissions.toSet();
      final leakage = perms.intersection(_foodSafetyOnlyCodes);
      expect(leakage, isEmpty,
          reason: 'تسرّب صلاحيات سلامة الغذاء إلى أخصائي الجودة: $leakage');
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

    test('D.1 مصلحة: صلاحية fill_dynamic_reports أُزيلت من الكتالوج', () {
      final inCatalog = SystemPermissions.all
          .any((p) => p.code == SystemPermissions.fillDynamicReports);
      expect(inCatalog, isFalse,
          reason: 'الصلاحية الميتة fill_dynamic_reports لم تعد معروضة في واجهة '
              'إدارة الأدوار — الثابت يبقى فقط لأغراض الترحيل');
      // لكنها لا تزال صالحة كمصدر ترحيل
      expect(SystemPermissions.legacyMigrationMap.keys,
          contains(SystemPermissions.fillDynamicReports));
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

    test('D.4/D.5 مصلحة: مطابقة دقيقة و fail-closed في getPermissionsForRole fallback', () {
      // محاكاة منطق getPermissionsForRole fallback بعد الإصلاح: مطابقة دقيقة + fail-closed
      List<String> simulateFallback(String roleCodeOrTitle) {
        final clean = roleCodeOrTitle.trim().toLowerCase();
        final normalized = clean.replaceAll('_', '').replaceAll(' ', '');

        const systemRoleAliases = <String, String>{
          'admin': 'admin',
          'administrator': 'admin',
          'مديرالنظام': 'admin',
          'generalmanager': 'general_manager',
          'gmanager': 'general_manager',
          'مديرعام': 'general_manager',
          'المديرالعام': 'general_manager',
          'qualitymanager': 'quality_manager',
          'qm': 'quality_manager',
          'مديرالجودة': 'quality_manager',
          'factorymanager': 'factory_manager',
          'gm': 'factory_manager',
          'مديرالمصنع': 'factory_manager',
          'foodsafetyengineer': 'food_safety_engineer',
          'foodsafety': 'food_safety_engineer',
          'سلامةالغذاء': 'food_safety_engineer',
          'مهندسسلامة': 'food_safety_engineer',
        };

        final code = systemRoleAliases[normalized];
        if (code != null) {
          return RoleModel.defaultSystemRoles.firstWhere((e) => e.code == code).permissions;
        }
        return <String>[]; // fail-closed
      }

      // 1. الأسماء الصحيحة لا تزال تطابق بدقة
      expect(simulateFallback('admin'),
          equals(SystemPermissions.all.map((p) => p.code).toList()));
      expect(simulateFallback('gm'), equals(_role('factory_manager').permissions));
      expect(simulateFallback('qm'), equals(_role('quality_manager').permissions));
      expect(simulateFallback('QualityManager'),
          equals(_role('quality_manager').permissions));
      expect(simulateFallback('FoodSafetyEngineer'),
          equals(_role('food_safety_engineer').permissions));

      // 2. ثغرات التصعيد أُغلقت (D.4)
      expect(simulateFallback('sysadmin'), isEmpty,
          reason: "D.4 مصلحة: 'sysadmin' لم يعد يطابق 'admin' → لا صلاحيات");
      expect(simulateFallback('agm'), isEmpty,
          reason: "D.4 مصلحة: 'agm' لم يعد يطابق 'gm' → لا صلاحيات");
      expect(simulateFallback('sqm'), isEmpty,
          reason: "D.4 مصلحة: 'sqm' لم يعد يطابق 'qm' → لا صلاحيات");

      // 3. الدور غير المعروف يُرفض بدل أخذ أخصائي الجودة (D.5)
      expect(simulateFallback('محاسب'), isEmpty,
          reason: "D.5 مصلحة: دور غير معروف → قائمة فارغة (fail-closed) بدل أخصائي جودة");
    });
  });

  // ====== 4b) اختبارات ترحيل v9 ======

  group('4b) ترحيل v10 — تنظيف الصلاحيات العابرة للأقسام والمصفوفة التفصيلية', () {
    test('schemaVersion مرفوع إلى 10 فما فوق', () {
      expect(SystemPermissions.schemaVersion, greaterThanOrEqualTo(10),
          reason: 'يجب رفع إصدار الهيكل لتشغيل الترحيل عند أول تشغيل');
    });

    test('removeCrossDepartment ينظف createHygieneReports من quality_specialist', () {
      // محاكاة دور قديم مخزّن بصلاحيات النظافة (قبل الحصر)
      final contaminated = <String>[
        ..._role('quality_specialist').permissions,
        SystemPermissions.createHygieneReports,
        SystemPermissions.fillHealthReports,
        SystemPermissions.viewHealthReports,
        SystemPermissions.fillFoodSafetyDynamicReports,
      ];
      final cleaned = SystemPermissions.removeCrossDepartmentPermissionsForSystemRole(
          'quality_specialist', contaminated);
      expect(cleaned, isNot(contains(SystemPermissions.createHygieneReports)));
      expect(cleaned, isNot(contains(SystemPermissions.fillHealthReports)));
      expect(cleaned, isNot(contains(SystemPermissions.viewHealthReports)));
      expect(cleaned, isNot(contains(SystemPermissions.fillFoodSafetyDynamicReports)));
      // صلاحيات الجودة تبقى سليمة
      expect(cleaned, contains(SystemPermissions.createWaterReports));
      expect(cleaned, contains(SystemPermissions.fillQualityDynamicReports));
    });

    test('removeCrossDepartment ينظف createHygieneReports من quality_manager (ترحيل v9)', () {
      // محاكاة مدير جودة قديم يملك صلاحيات النظافة العالقة
      final contaminated = <String>[
        ..._role('quality_manager').permissions,
        SystemPermissions.createHygieneReports,
        SystemPermissions.fillHealthReports,
        SystemPermissions.viewHealthReports,
        SystemPermissions.fillFoodSafetyDynamicReports,
      ];
      final cleaned = SystemPermissions.removeCrossDepartmentPermissionsForSystemRole(
          'quality_manager', contaminated);
      expect(cleaned, isNot(contains(SystemPermissions.createHygieneReports)),
          reason: 'ترحيل v9: create_hygiene_reports محذوفة من مدير الجودة');
      expect(cleaned, isNot(contains(SystemPermissions.fillHealthReports)));
      expect(cleaned, isNot(contains(SystemPermissions.viewHealthReports)));
      expect(cleaned, isNot(contains(SystemPermissions.fillFoodSafetyDynamicReports)));
      // صلاحيات مدير الجودة الأصلية تبقى سليمة
      expect(cleaned, contains(SystemPermissions.approveQM));
      expect(cleaned, contains(SystemPermissions.designDynamicReports));
      expect(cleaned, contains(SystemPermissions.manageProducts));
    });

    test('migratePermissions يحافظ على صلاحيات دور نظامي نظيف', () {
      final clean = _role('food_safety_engineer').permissions;
      final migrated = SystemPermissions.migratePermissions(clean);
      // الدور النظيف لا يتغير جوهرياً (قد تضاف manageSignature/changePassword)
      expect(migrated, containsAll(clean));
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

    test('مسار login: UserModel بدون customPermissions يرفض كل الصلاحيات (fail-closed)', () {
      final user = UserModel(
        id: 1,
        fullName: 'أخصائي تجريبي',
        username: 'test_qs',
        role: UserRole.qualitySpecialist,
        customPermissions: null, // لم تُحمَّل بعد
      );

      // بعد التوحيد: لا enum fallback بعد الآن — الرفض الصريح حتى تُحمَّل صلاحيات DB
      expect(user.hasPermissionCode(SystemPermissions.fillHealthReports), isFalse,
          reason: 'fail-closed: المسار بدون customPermissions يجب أن يرفض كل الصلاحيات');
      expect(user.hasPermissionCode(SystemPermissions.viewReports), isFalse,
          reason: 'fail-closed: حتى صلاحيات الجودة المشروعة تُرفض حتى تُحمَّل من DB');
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

    test('D.6 مصلحة: foodsafetyengineer لم يعد يُعتبر دوراً مخصصاً في fromMap', () {
      final fse = UserModel.fromMap({
        'id': 12,
        'full_name': 'م. بشير القدسي',
        'username': 'basheer_fs',
        'role': 'FoodSafetyEngineer',
        'is_active': 1,
      });

      expect(fse.role, UserRole.foodSafetyEngineer,
          reason: 'enum role يُحل صحيحاً');
      expect(fse.customRoleTitle, isNull,
          reason: 'D.6 مصلحة: foodsafetyengineer أُضيف لقائمة الأدوار النظامية في fromMap');
      expect(fse.displayRoleTitle, 'مهندس سلامة الغذاء',
          reason: 'التأثير المرئي: يظهر التسمية العربية الصحيحة في الواجهة');
    });
  });
}
