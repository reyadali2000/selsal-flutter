import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/factory_compliance_models.dart';
import 'package:wadialain/models/role_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Factory Daily Reports Compliance Models & Logic Tests', () {
    test('ReportExecutionDetail properties and compliance calculation', () {
      final executedDetail = ReportExecutionDetail(
        reportKey: 'raw_water',
        reportName: 'فحص مياه الآبار والمياه الخام',
        departmentName: 'إدارة الجودة',
        sourceType: ReportSourceType.rawWater,
        isExecuted: true,
        executionCount: 3,
        shiftsCovered: ['الوردية الأولى (صباحية)', 'الوردية الثانية (مسائية)'],
        shiftIds: {1, 2},
        lastExecutionTime: DateTime(2026, 10, 5, 14, 30),
        compliantCount: 3,
        nonCompliantCount: 0,
      );

      expect(executedDetail.isExecuted, true);
      expect(executedDetail.executionCount, 3);
      expect(executedDetail.shiftsCovered.length, 2);
      expect(executedDetail.complianceRate, 100.0);
      expect(executedDetail.sourceType.label, 'فحص مياه خام');

      final missedDetail = ReportExecutionDetail(
        reportKey: 'raw_material',
        reportName: 'فحص المواد الأولية ومواد التعبئة',
        departmentName: 'إدارة الجودة',
        sourceType: ReportSourceType.rawMaterial,
        isExecuted: false,
        executionCount: 0,
        shiftsCovered: const [],
        shiftIds: const {},
      );

      expect(missedDetail.isExecuted, false);
      expect(missedDetail.executionCount, 0);
      expect(missedDetail.shiftsCovered, isEmpty);
    });

    test('FactoryDailyComplianceReport calculates rate, grade and status correctly', () {
      final executed1 = ReportExecutionDetail(
        reportKey: 'raw_water',
        reportName: 'فحص مياه الآبار',
        departmentName: 'إدارة الجودة',
        sourceType: ReportSourceType.rawWater,
        isExecuted: true,
        executionCount: 2,
      );
      final executed2 = ReportExecutionDetail(
        reportKey: 'final_product',
        reportName: 'فحص المنتج النهائي',
        departmentName: 'إدارة الجودة',
        sourceType: ReportSourceType.finalProduct,
        isExecuted: true,
        executionCount: 4,
      );
      final missed1 = ReportExecutionDetail(
        reportKey: 'hygiene',
        reportName: 'فحص النظافة العامة والاشتراطات',
        departmentName: 'سلامة الغذاء',
        sourceType: ReportSourceType.hygiene,
        isExecuted: false,
        executionCount: 0,
      );

      final report = FactoryDailyComplianceReport(
        branchId: 1,
        branchName: 'مصنع أرتل',
        date: DateTime(2026, 10, 5),
        totalActiveReports: 3,
        executedReportsCount: 2,
        missedReportsCount: 1,
        totalInspectionsCount: 6,
        complianceRate: 66.7,
        executedReports: [executed1, executed2],
        missedReports: [missed1],
        allReports: [executed1, executed2, missed1],
      );

      expect(report.totalActiveReports, 3);
      expect(report.executedReportsCount, 2);
      expect(report.missedReportsCount, 1);
      expect(report.totalInspectionsCount, 6);
      expect(report.complianceRate, 66.7);
      expect(report.complianceGrade, contains('متوسط'));
      expect(report.executedReports.length, 2);
      expect(report.missedReports.length, 1);
    });

    test('Security Permission viewFactoryComplianceReport is properly defined and assigned', () {
      expect(
        SystemPermissions.all.any((p) => p.code == SystemPermissions.viewFactoryComplianceReport),
        true,
      );

      final rolesMap = {for (var r in RoleModel.defaultSystemRoles) r.code: r.permissions};

      expect(rolesMap['admin']?.contains(SystemPermissions.viewFactoryComplianceReport), true);
      expect(rolesMap['general_manager']?.contains(SystemPermissions.viewFactoryComplianceReport), true);
      expect(rolesMap['factory_manager']?.contains(SystemPermissions.viewFactoryComplianceReport), true);
      expect(rolesMap['quality_manager']?.contains(SystemPermissions.viewFactoryComplianceReport), true);
      expect(rolesMap['food_safety_engineer']?.contains(SystemPermissions.viewFactoryComplianceReport), true);
      // Operational role quality_specialist does NOT have it
      expect(rolesMap['quality_specialist']?.contains(SystemPermissions.viewFactoryComplianceReport), false);
    });
  });
}
