import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/role_model.dart';

void main() {
  group('Dynamic report permission split', () {
    test('new permission codes are distinct', () {
      expect(SystemPermissions.fillQualityDynamicReports,
          isNot(equals(SystemPermissions.fillFoodSafetyDynamicReports)));
      expect(SystemPermissions.all.any((p) => p.code == SystemPermissions.fillQualityDynamicReports), isTrue);
      expect(SystemPermissions.all.any((p) => p.code == SystemPermissions.fillFoodSafetyDynamicReports), isTrue);
    });

    test('category permission mapping is correct', () {
      expect(SystemPermissions.dynamicFillPermissionForCategory(1),
          SystemPermissions.fillQualityDynamicReports);
      expect(SystemPermissions.dynamicFillPermissionForCategory(2),
          SystemPermissions.fillFoodSafetyDynamicReports);
      expect(SystemPermissions.dynamicFillPermissionForCategory(null),
          SystemPermissions.fillQualityDynamicReports);
    });

    test('quality manager no longer holds food safety permissions', () {
      final qm = RoleModel.defaultSystemRoles.firstWhere((r) => r.code == 'quality_manager');
      expect(qm.permissions, isNot(contains(SystemPermissions.fillHealthReports)));
      expect(qm.permissions, isNot(contains(SystemPermissions.viewHealthReports)));
      expect(qm.permissions, contains(SystemPermissions.fillQualityDynamicReports));
      expect(qm.permissions, isNot(contains(SystemPermissions.fillFoodSafetyDynamicReports)));
    });

    test('food safety engineer only fills food safety dynamic reports', () {
      final fse = RoleModel.defaultSystemRoles.firstWhere((r) => r.code == 'food_safety_engineer');
      expect(fse.permissions, contains(SystemPermissions.fillFoodSafetyDynamicReports));
      expect(fse.permissions, isNot(contains(SystemPermissions.fillQualityDynamicReports)));
      expect(fse.permissions, contains(SystemPermissions.fillHealthReports));
      expect(fse.permissions, contains(SystemPermissions.viewHealthReports));
      expect(fse.permissions, isNot(contains(SystemPermissions.createWaterReports)));
      expect(fse.permissions, isNot(contains(SystemPermissions.createRawMaterialReports)));
      expect(fse.permissions, isNot(contains(SystemPermissions.viewReports)));
    });

    test('quality specialist fills only quality dynamic reports', () {
      final qs = RoleModel.defaultSystemRoles.firstWhere((r) => r.code == 'quality_specialist');
      expect(qs.permissions, contains(SystemPermissions.fillQualityDynamicReports));
      expect(qs.permissions, isNot(contains(SystemPermissions.fillFoodSafetyDynamicReports)));
      expect(qs.permissions, isNot(contains(SystemPermissions.createHygieneReports)));
      expect(qs.permissions, isNot(contains(SystemPermissions.fillHealthReports)));
      expect(qs.permissions, isNot(contains(SystemPermissions.viewHealthReports)));
    });

    test('system-role cleanup removes previously cross-department grants', () {
      final quality = SystemPermissions.removeCrossDepartmentPermissionsForSystemRole(
        'quality_specialist',
        [SystemPermissions.createWaterReports, SystemPermissions.createHygieneReports],
      );
      final foodSafety = SystemPermissions.removeCrossDepartmentPermissionsForSystemRole(
        'food_safety_engineer',
        [SystemPermissions.createWaterReports, SystemPermissions.viewReports, SystemPermissions.viewHealthReports],
      );

      expect(quality, contains(SystemPermissions.createWaterReports));
      expect(quality, isNot(contains(SystemPermissions.createHygieneReports)));
      expect(foodSafety, contains(SystemPermissions.viewHealthReports));
      expect(foodSafety, isNot(contains(SystemPermissions.createWaterReports)));
      expect(foodSafety, isNot(contains(SystemPermissions.viewReports)));
    });

    test('legacy fill_dynamic_reports migrates to both new permissions', () {
      final migrated = SystemPermissions.migratePermissions([SystemPermissions.fillDynamicReports]);
      expect(migrated, contains(SystemPermissions.fillQualityDynamicReports));
      expect(migrated, contains(SystemPermissions.fillFoodSafetyDynamicReports));
    });

    test('admin and general manager keep all permissions', () {
      for (final code in ['admin', 'general_manager']) {
        final role = RoleModel.defaultSystemRoles.firstWhere((r) => r.code == code);
        expect(role.permissions.length, SystemPermissions.all.length);
      }
    });
  });
}
