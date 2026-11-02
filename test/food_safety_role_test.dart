import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/user_model.dart';
import 'package:wadialain/models/role_model.dart';

void main() {
  group('FoodSafetyEngineer role', () {
    test('enum exists and is distinct from other roles', () {
      expect(UserRole.values.contains(UserRole.foodSafetyEngineer), isTrue);
      expect(UserRole.foodSafetyEngineer, isNot(equals(UserRole.qualitySpecialist)));
    });

    test('roleToString and stringToRole round-trip', () {
      expect(UserModel.roleToString(UserRole.foodSafetyEngineer), 'FoodSafetyEngineer');
      expect(UserModel.stringToRole('FoodSafetyEngineer'), UserRole.foodSafetyEngineer);
      expect(UserModel.stringToRole('food_safety_engineer'), UserRole.foodSafetyEngineer);
      expect(UserModel.stringToRole('مهندس سلامة الغذاء'), UserRole.foodSafetyEngineer);
      expect(UserModel.stringToRole('سلامة الغذاء'), UserRole.foodSafetyEngineer);
    });

    test('has health/food-safety permissions but not approvals', () {
      final role = RoleModel.defaultSystemRoles.firstWhere(
        (r) => r.code == 'food_safety_engineer',
        orElse: () => fail('food_safety_engineer role not found'),
      );
      expect(role.permissions, contains(SystemPermissions.fillHealthReports));
      expect(role.permissions, contains(SystemPermissions.viewHealthReports));
      expect(role.permissions, contains(SystemPermissions.createHygieneReports));
      expect(role.permissions, contains(SystemPermissions.exportPdf));
      expect(role.permissions, isNot(contains(SystemPermissions.approveQM)));
      expect(role.permissions, isNot(contains(SystemPermissions.approveGM)));
      expect(role.permissions, isNot(contains(SystemPermissions.manageUsers)));
    });

    test('labels, icon and color are defined', () {
      expect(UserModel.roleLabel(UserRole.foodSafetyEngineer), 'مهندس سلامة الغذاء');
      expect(UserModel.defaultJobTitleForRole(UserRole.foodSafetyEngineer), 'مهندس سلامة الغذاء');
      expect(UserModel.defaultColorForRole(UserRole.foodSafetyEngineer), isNotNull);
      expect(UserModel.defaultIconForRole(UserRole.foodSafetyEngineer), isNotNull);
    });

    test('default system role is registered with correct permissions', () {
      final role = RoleModel.defaultSystemRoles.firstWhere(
        (r) => r.code == 'food_safety_engineer',
        orElse: () => fail('food_safety_engineer role not found'),
      );
      expect(role.isSystem, isTrue);
      expect(role.title, 'مهندس سلامة الغذاء');
      expect(role.permissions, contains(SystemPermissions.fillHealthReports));
      expect(role.permissions, contains(SystemPermissions.viewHealthReports));
      expect(role.permissions, contains(SystemPermissions.createHygieneReports));
      expect(role.permissions, isNot(contains(SystemPermissions.approveGM)));
      expect(role.permissions, isNot(contains(SystemPermissions.manageUsers)));
    });

    test('old quality-specialist food safety users are replaced by dedicated role', () {
      // الدور الجديد يحمل صلاحيات سلامة الغذاء دون صلاحيات الاعتماد
      final role = RoleModel.defaultSystemRoles.firstWhere(
        (r) => r.code == 'food_safety_engineer',
      );
      expect(role.permissions, contains(SystemPermissions.fillHealthReports));
      expect(role.permissions, contains(SystemPermissions.viewHealthReports));
      expect(role.permissions, isNot(contains(SystemPermissions.approveQM)));
      expect(role.permissions, isNot(contains(SystemPermissions.approveGM)));
    });
  });
}
