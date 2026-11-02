import 'package:flutter/material.dart';

/// نوع مصدر التقرير (أساسي قياسي أم نموذج ديناميكي مخصص)
enum ReportSourceType {
  rawWater,
  finalProduct,
  hygiene,
  rawMaterial,
  dynamicReport,
}

extension ReportSourceTypeHelper on ReportSourceType {
  String get label {
    switch (this) {
      case ReportSourceType.rawWater:
        return 'فحص مياه خام';
      case ReportSourceType.finalProduct:
        return 'فحص منتج نهائي';
      case ReportSourceType.hygiene:
        return 'نظافة وهايجين';
      case ReportSourceType.rawMaterial:
        return 'مواد خام وتعبئة';
      case ReportSourceType.dynamicReport:
        return 'نموذج مخصص';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportSourceType.rawWater:
        return Icons.water_drop_rounded;
      case ReportSourceType.finalProduct:
        return Icons.local_drink_rounded;
      case ReportSourceType.hygiene:
        return Icons.cleaning_services_rounded;
      case ReportSourceType.rawMaterial:
        return Icons.inventory_2_rounded;
      case ReportSourceType.dynamicReport:
        return Icons.dashboard_customize_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ReportSourceType.rawWater:
        return const Color(0xFF0288D1);
      case ReportSourceType.finalProduct:
        return const Color(0xFF2E7D32);
      case ReportSourceType.hygiene:
        return const Color(0xFF00897B);
      case ReportSourceType.rawMaterial:
        return const Color(0xFF6D4C41);
      case ReportSourceType.dynamicReport:
        return const Color(0xFF6A1B9A);
    }
  }
}

/// تفاصيل تنفيذ تقرير/فحص محدد في يوم معين
class ReportExecutionDetail {
  final String reportKey; // مفتاح فريد للتقرير (مثلاً 'raw_water' أو 'dyn_12')
  final int? dynamicReportId;
  final String reportName;
  final String departmentName; // إدارة الجودة / سلامة الغذاء
  final ReportSourceType sourceType;
  final bool isExecuted; // هل قام المصنع بهذا الفحص اليوم؟
  final int executionCount; // كم مرة أُنشئ هذا التقرير اليوم
  final List<String> shiftsCovered; // الورديات المغطاة: ['الأولى', 'الثانية']
  final Set<int> shiftIds;
  final DateTime? lastExecutionTime;
  final int compliantCount;
  final int nonCompliantCount;
  final int pendingApprovalsCount;
  final String? notes;

  const ReportExecutionDetail({
    required this.reportKey,
    this.dynamicReportId,
    required this.reportName,
    required this.departmentName,
    required this.sourceType,
    required this.isExecuted,
    required this.executionCount,
    this.shiftsCovered = const [],
    this.shiftIds = const {},
    this.lastExecutionTime,
    this.compliantCount = 0,
    this.nonCompliantCount = 0,
    this.pendingApprovalsCount = 0,
    this.notes,
  });

  /// حالة الامتثال للفحص
  double get complianceRate => (executionCount > 0 && (compliantCount + nonCompliantCount) > 0)
      ? ((compliantCount / (compliantCount + nonCompliantCount)) * 100)
      : 100.0;

  Map<String, dynamic> toMap() {
    return {
      'reportKey': reportKey,
      'dynamicReportId': dynamicReportId,
      'reportName': reportName,
      'departmentName': departmentName,
      'sourceType': sourceType.name,
      'isExecuted': isExecuted ? 1 : 0,
      'executionCount': executionCount,
      'shiftsCovered': shiftsCovered,
      'shiftIds': shiftIds.toList(),
      'lastExecutionTime': lastExecutionTime?.toIso8601String(),
      'compliantCount': compliantCount,
      'nonCompliantCount': nonCompliantCount,
      'pendingApprovalsCount': pendingApprovalsCount,
      'notes': notes,
    };
  }

  factory ReportExecutionDetail.fromMap(Map<String, dynamic> map) {
    return ReportExecutionDetail(
      reportKey: map['reportKey'] ?? '',
      dynamicReportId: map['dynamicReportId'],
      reportName: map['reportName'] ?? '',
      departmentName: map['departmentName'] ?? '',
      sourceType: ReportSourceType.values.firstWhere(
        (e) => e.name == map['sourceType'],
        orElse: () => ReportSourceType.dynamicReport,
      ),
      isExecuted: (map['isExecuted'] as int? ?? 0) == 1,
      executionCount: (map['executionCount'] as int?) ?? 0,
      shiftsCovered: List<String>.from(map['shiftsCovered'] ?? []),
      shiftIds: Set<int>.from(map['shiftIds'] ?? []),
      lastExecutionTime: map['lastExecutionTime'] != null
          ? DateTime.tryParse(map['lastExecutionTime'])
          : null,
      compliantCount: (map['compliantCount'] as int?) ?? 0,
      nonCompliantCount: (map['nonCompliantCount'] as int?) ?? 0,
      pendingApprovalsCount: (map['pendingApprovalsCount'] as int?) ?? 0,
      notes: map['notes'],
    );
  }
}

/// تقرير التزام المصنع اليومي بكافة الفحوصات والتقارير
class FactoryDailyComplianceReport {
  final int branchId;
  final String branchName;
  final DateTime date;
  final int totalActiveReports; // إجمالي التقارير المقررة والمفعلة بالنظام
  final int executedReportsCount; // عدد التقارير التي تم تنفيذها اليوم (مرة أو أكثر)
  final int missedReportsCount; // عدد التقارير المتخلفة التي لم تنفذ نهائياً
  final int totalInspectionsCount; // إجمالي عدد السجلات/الفحوصات المنشأة اليوم
  final double complianceRate; // نسبة التزام المصنع بالتقارير (%)
  final List<ReportExecutionDetail> executedReports;
  final List<ReportExecutionDetail> missedReports;
  final List<ReportExecutionDetail> allReports;

  const FactoryDailyComplianceReport({
    required this.branchId,
    required this.branchName,
    required this.date,
    required this.totalActiveReports,
    required this.executedReportsCount,
    required this.missedReportsCount,
    required this.totalInspectionsCount,
    required this.complianceRate,
    required this.executedReports,
    required this.missedReports,
    required this.allReports,
  });

  /// تقييم الالتزام (ممتاز / جيد / متوسط / منخفض)
  String get complianceGrade {
    if (complianceRate >= 95) return 'التزام ممتاز';
    if (complianceRate >= 80) return 'التزام جيد جداً';
    if (complianceRate >= 65) return 'التزام متوسط';
    return 'التزام منخفض يتطلب متابعة';
  }

  Color get complianceColor {
    if (complianceRate >= 90) return const Color(0xFF2E7D32);
    if (complianceRate >= 75) return const Color(0xFF007791);
    if (complianceRate >= 60) return const Color(0xFFE65100);
    return const Color(0xFFC62828);
  }
}

/// ملخص مؤشرات أداء الالتزام للمصنعين
class FactoryComplianceKPISummary {
  final DateTime date;
  final int totalBranches;
  final double overallComplianceRate;
  final int totalActiveScheduled;
  final int totalExecutedReports;
  final int totalMissedReports;
  final int totalInspectionsCount;
  final List<FactoryDailyComplianceReport> branchReports;

  const FactoryComplianceKPISummary({
    required this.date,
    required this.totalBranches,
    required this.overallComplianceRate,
    required this.totalActiveScheduled,
    required this.totalExecutedReports,
    required this.totalMissedReports,
    required this.totalInspectionsCount,
    required this.branchReports,
  });
}
