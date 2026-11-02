class WorkerShiftStats {
  final int shiftId;
  final String shiftName;
  final int count;

  const WorkerShiftStats({
    required this.shiftId,
    required this.shiftName,
    required this.count,
  });

  Map<String, dynamic> toMap() => {
        'shift_id': shiftId,
        'shift_name': shiftName,
        'count': count,
      };
}

class WorkerDailyAttendanceRecord {
  final DateTime date;
  final int shiftId;
  final String shiftName;
  final int reportId;
  final int totalCriteria;
  final int compliantCriteria;
  final int nonCompliantCriteria;
  final double complianceScore;
  final List<String> violationNotes;
  final bool isFullCompliant;

  const WorkerDailyAttendanceRecord({
    required this.date,
    required this.shiftId,
    required this.shiftName,
    required this.reportId,
    required this.totalCriteria,
    required this.compliantCriteria,
    required this.nonCompliantCriteria,
    required this.complianceScore,
    required this.violationNotes,
    required this.isFullCompliant,
  });
}

class WorkerMonthlyCommitment {
  final int workerId;
  final String fullName;
  final String jobTitle;
  final int branchId;
  final String branchName;
  final bool isActive;
  final int year;
  final int month;
  final int daysPresent;
  final int targetWorkingDays;
  final double attendanceRate;
  final Map<int, int> shiftCounts;
  final double avgHygieneScore;
  final int totalViolations;
  final double compositeCommitmentScore;
  final List<WorkerDailyAttendanceRecord> dailyRecords;
  int rank;

  WorkerMonthlyCommitment({
    required this.workerId,
    required this.fullName,
    required this.jobTitle,
    required this.branchId,
    required this.branchName,
    required this.isActive,
    required this.year,
    required this.month,
    required this.daysPresent,
    required this.targetWorkingDays,
    required this.attendanceRate,
    required this.shiftCounts,
    required this.avgHygieneScore,
    required this.totalViolations,
    required this.compositeCommitmentScore,
    required this.dailyRecords,
    this.rank = 0,
  });

  int get shift1Count => shiftCounts[1] ?? 0;
  int get shift2Count => shiftCounts[2] ?? 0;
  int get shift3Count => shiftCounts[3] ?? 0;

  String get commitmentGrade {
    if (compositeCommitmentScore >= 95) return 'ممتاز مرتفع ⭐⭐⭐';
    if (compositeCommitmentScore >= 85) return 'ممتاز ⭐⭐';
    if (compositeCommitmentScore >= 75) return 'جيد جداً ⭐';
    if (compositeCommitmentScore >= 60) return 'جيد';
    return 'بحاجة لمتابعة ⚠️';
  }
}

class WorkersCommitmentKPISummary {
  final int totalRegisteredWorkers;
  final int totalAttendedWorkers;
  final double avgAttendanceRate;
  final double avgHygieneScore;
  final int totalShiftsCovered;
  final int targetWorkingDays;

  const WorkersCommitmentKPISummary({
    required this.totalRegisteredWorkers,
    required this.totalAttendedWorkers,
    required this.avgAttendanceRate,
    required this.avgHygieneScore,
    required this.totalShiftsCovered,
    required this.targetWorkingDays,
  });
}
