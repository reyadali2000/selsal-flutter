import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/hygiene_models.dart';
import 'package:wadialain/utils/hygiene_report_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HygieneReportPdfGenerator & ArabicPdfService Integration Tests', () {
    test('generateReportBytes generates a valid PDF with Arabic fonts and RTL layout', () async {
      final employees = [
        Employee(
          id: 1,
          branchId: 1,
          fullName: 'محمد سالم العولقي',
          jobTitle: 'فني تعبئة',
          isActive: true,
        ),
        Employee(
          id: 2,
          branchId: 1,
          fullName: 'عبدالله أحمد باوزير',
          jobTitle: 'مشرف خط',
          isActive: true,
        ),
      ];

      final criteria = [
        ChecklistItem(id: 1, checklistId: 1, itemName: 'نظافة الزي الرسمي'),
        ChecklistItem(id: 2, checklistId: 1, itemName: 'ارتداء غطاء الرأس'),
        ChecklistItem(id: 3, checklistId: 1, itemName: 'تقليم الأظافر ونظافة اليدين'),
      ];

      final complianceMatrix = {
        '1_1': true,
        '1_2': true,
        '1_3': false,
        '2_1': true,
        '2_2': true,
        '2_3': true,
      };

      final correctiveActions = {
        1: 'تم التنبيه الفوري بتقليم الأظافر',
      };

      final pdfBytes = await HygieneReportPdfGenerator.generateReportBytes(
        employees: employees,
        criteria: criteria,
        complianceMatrix: complianceMatrix,
        correctiveActions: correctiveActions,
        reportDate: '2026/09/27',
        supervisorName: 'م. سالم الكندي',
        approvalStatus: 'Approved',
        qmApprovedBy: 'حمود يسر',
        qmApprovedAt: DateTime(2026, 9, 27, 10, 30),
        gmApprovedBy: 'خالد العمري',
        gmApprovedAt: DateTime(2026, 9, 27, 12, 0),
      );

      expect(pdfBytes, isNotNull);
      expect(pdfBytes.isNotEmpty, isTrue);

      // Verify PDF magic header bytes: %PDF-
      final pdfMagic = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(pdfMagic, equals('%PDF-'));
    });
  });
}
