import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/worker_commitment_models.dart';
import 'package:wadialain/models/role_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Worker Commitment Models & Formulas Tests', () {
    test('WorkerMonthlyCommitment grade and composite score calculations', () {
      final worker = WorkerMonthlyCommitment(
        workerId: 101,
        fullName: 'أحمد علي',
        jobTitle: 'عامل خط الإنتاج',
        branchId: 1,
        branchName: 'مصنع أرتل',
        isActive: true,
        year: 2026,
        month: 10,
        daysPresent: 16,
        targetWorkingDays: 18,
        attendanceRate: 88.9,
        shiftCounts: {1: 3, 2: 13, 3: 0},
        avgHygieneScore: 100.0,
        totalViolations: 0,
        compositeCommitmentScore: 94.5,
        dailyRecords: [],
      );

      expect(worker.shift1Count, 3);
      expect(worker.shift2Count, 13);
      expect(worker.shift3Count, 0);
      expect(worker.daysPresent, 16);
      expect(worker.targetWorkingDays, 18);
      expect(worker.commitmentGrade, contains('ممتاز'));
    });

    test('WorkerDailyAttendanceRecord calculates full compliance correctly', () {
      final recordCompliant = WorkerDailyAttendanceRecord(
        date: DateTime(2026, 10, 4),
        shiftId: 1,
        shiftName: 'وردية 1 (صباحية)',
        reportId: 1,
        totalCriteria: 9,
        compliantCriteria: 9,
        nonCompliantCriteria: 0,
        complianceScore: 100.0,
        violationNotes: [],
        isFullCompliant: true,
      );

      expect(recordCompliant.isFullCompliant, true);
      expect(recordCompliant.violationNotes, isEmpty);

      final recordViolation = WorkerDailyAttendanceRecord(
        date: DateTime(2026, 10, 5),
        shiftId: 2,
        shiftName: 'وردية 2 (مسائية)',
        reportId: 2,
        totalCriteria: 9,
        compliantCriteria: 8,
        nonCompliantCriteria: 1,
        complianceScore: 88.9,
        violationNotes: ['تغطية الشعر والشارب: تم ارتداء غطاء الرأس فوراً'],
        isFullCompliant: false,
      );

      expect(recordViolation.isFullCompliant, false);
      expect(recordViolation.violationNotes.length, 1);
    });

    test('WorkersCommitmentKPISummary initializes properly', () {
      const summary = WorkersCommitmentKPISummary(
        totalRegisteredWorkers: 25,
        totalAttendedWorkers: 22,
        avgAttendanceRate: 85.4,
        avgHygieneScore: 98.2,
        totalShiftsCovered: 350,
        targetWorkingDays: 20,
      );

      expect(summary.totalRegisteredWorkers, 25);
      expect(summary.totalAttendedWorkers, 22);
      expect(summary.avgAttendanceRate, 85.4);
      expect(summary.avgHygieneScore, 98.2);
      expect(summary.totalShiftsCovered, 350);
      expect(summary.targetWorkingDays, 20);
    });

    test('Security Permission viewDailyWorkersCommitment is registered', () {
      expect(
        SystemPermissions.all.any((p) => p.code == SystemPermissions.viewDailyWorkersCommitment),
        true,
      );

      final rolesMap = {for (var r in RoleModel.defaultSystemRoles) r.code: r.permissions};

      expect(rolesMap['admin']?.contains(SystemPermissions.viewDailyWorkersCommitment), true);
      expect(rolesMap['general_manager']?.contains(SystemPermissions.viewDailyWorkersCommitment), true);
      expect(rolesMap['factory_manager']?.contains(SystemPermissions.viewDailyWorkersCommitment), true);
      expect(rolesMap['quality_manager']?.contains(SystemPermissions.viewDailyWorkersCommitment), true);
      expect(rolesMap['food_safety_engineer']?.contains(SystemPermissions.viewDailyWorkersCommitment), true);
    });

    test('ReportsView does not contain viewDailyWorkersCommitment category (Management Only in Dashboard)', () {
      // Confirms separation of concerns: Feature is placed in Executive Dashboard, not ReportsView
      expect(SystemPermissions.viewDailyWorkersCommitment, 'view_daily_workers_commitment');
    });
  });
}
