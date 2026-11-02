import 'package:flutter/foundation.dart';
import '../models/factory_compliance_models.dart';
import 'database_helper.dart';
import 'dashboard_sync_service.dart';

class FactoryReportsComplianceService {
  FactoryReportsComplianceService._internal();
  static final FactoryReportsComplianceService instance =
      FactoryReportsComplianceService._internal();

  /// تحليل التزام مصنع محدد بالتقارير والفحوصات في تاريخ معين
  Future<FactoryDailyComplianceReport> getFactoryDailyCompliance({
    required DateTime date,
    required int branchId,
  }) async {
    try {
      // مزامنة أحدث الفحوصات المنفذة اليوم من السيرفر قبل الحساب
      await DashboardSyncService.instance.syncAllDashboardData(branchId: branchId);
      final db = await DatabaseHelper.instance.database;
      final dateStr =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      String branchName = branchId == 2 ? 'مصنع سنحان (الثاني)' : 'مصنع أرتل (الرئيسي)';

      // شرط الفرع للاستعلام
      String branchCondition(String tablePrefix) {
        if (branchId == 1) {
          return '($tablePrefix.branch_id = 1 OR $tablePrefix.branch_id IS NULL)';
        } else {
          return '$tablePrefix.branch_id = $branchId';
        }
      }

      final reportDetails = <ReportExecutionDetail>[];

      // -------------------------------------------------------------
      // 1. تقارير الجودة الأساسية: فحص المياه الخام
      // -------------------------------------------------------------
      final rawWaterSql = '''
        SELECT id, created_at, shift_id, shift_name, is_compliant, approval_status
        FROM WaterQualityLogs
        WHERE (report_category = 'RawWater' OR report_category = 'Raw Water')
          AND substr(created_at, 1, 10) = ?
          AND ${branchCondition('WaterQualityLogs')}
          AND (approval_status IS NULL OR approval_status != 'Draft')
        ORDER BY created_at ASC
      ''';
      final rawWaterRows = await db.rawQuery(rawWaterSql, [dateStr]);
      reportDetails.add(_buildExecutionDetailFromRows(
        reportKey: 'raw_water',
        reportName: 'فحص مياه الآبار والمياه الخام',
        departmentName: 'إدارة الجودة',
        sourceType: ReportSourceType.rawWater,
        rows: rawWaterRows,
      ));

      // -------------------------------------------------------------
      // 2. تقارير الجودة الأساسية: فحص المنتج النهائي ومياه التعبئة
      // -------------------------------------------------------------
      final finalProductSql = '''
        SELECT id, created_at, shift_id, shift_name, is_compliant, approval_status
        FROM WaterQualityLogs
        WHERE (report_category = 'FinalProduct' OR report_category = 'Final Product' OR report_category IS NULL OR report_category = '')
          AND substr(created_at, 1, 10) = ?
          AND ${branchCondition('WaterQualityLogs')}
          AND (approval_status IS NULL OR approval_status != 'Draft')
        ORDER BY created_at ASC
      ''';
      final finalProductRows = await db.rawQuery(finalProductSql, [dateStr]);
      reportDetails.add(_buildExecutionDetailFromRows(
        reportKey: 'final_product',
        reportName: 'فحص المنتج النهائي ومياه التعبئة',
        departmentName: 'إدارة الجودة',
        sourceType: ReportSourceType.finalProduct,
        rows: finalProductRows,
      ));

      // -------------------------------------------------------------
      // 3. تقارير سلامة الغذاء الأساسية: فحص النظافة العامة والشخصية
      // -------------------------------------------------------------
      final hygieneSql = '''
        SELECT id, created_at, supervisor_name, approval_status
        FROM HygieneReports
        WHERE substr(created_at, 1, 10) = ?
          AND ${branchCondition('HygieneReports')}
          AND (approval_status IS NULL OR approval_status != 'Draft')
        ORDER BY created_at ASC
      ''';
      final hygieneRows = await db.rawQuery(hygieneSql, [dateStr]);
      reportDetails.add(_buildExecutionDetailFromRows(
        reportKey: 'hygiene',
        reportName: 'فحص النظافة العامة والاشتراطات الصحية',
        departmentName: 'سلامة الغذاء',
        sourceType: ReportSourceType.hygiene,
        rows: hygieneRows,
      ));

      // -------------------------------------------------------------
      // 4. تقارير الجودة الأساسية: فحص المواد الأولية ومواد التعبئة
      // -------------------------------------------------------------
      final rawMaterialSql = '''
        SELECT id, created_at, inspector_name, quality_decision, approval_status
        FROM RawMaterialReports
        WHERE substr(created_at, 1, 10) = ?
          AND ${branchCondition('RawMaterialReports')}
          AND (approval_status IS NULL OR approval_status != 'Draft')
        ORDER BY created_at ASC
      ''';
      final rawMaterialRows = await db.rawQuery(rawMaterialSql, [dateStr]);
      reportDetails.add(_buildExecutionDetailFromRows(
        reportKey: 'raw_material',
        reportName: 'فحص المواد الأولية ومواد التعبئة',
        departmentName: 'إدارة الجودة',
        sourceType: ReportSourceType.rawMaterial,
        rows: rawMaterialRows,
      ));

      // -------------------------------------------------------------
      // 5. التقارير والنماذج الديناميكية المفعلة في النظام
      // -------------------------------------------------------------
      final dynamicTemplatesSql = '''
        SELECT dr.id, dr.name, dr.category_id, dc.name as category_name
        FROM dr_reports dr
        LEFT JOIN dr_categories dc ON dc.id = dr.category_id
        WHERE dr.is_active = 1
        ORDER BY dr.id ASC
      ''';
      final dynamicTemplates = await db.rawQuery(dynamicTemplatesSql);

      for (final template in dynamicTemplates) {
        final templateId = template['id'] as int;
        final templateName = template['name'] as String? ?? 'نموذج فحص مخصص';
        final categoryId = template['category_id'] as int? ?? 1;
        final departmentName = categoryId == 2 ? 'سلامة الغذاء' : 'إدارة الجودة';

        final recordsSql = '''
          SELECT id, created_at, shift_id, shift_name, status, approval_status
          FROM dr_records
          WHERE report_id = ?
            AND substr(created_at, 1, 10) = ?
            AND ${branchCondition('dr_records')}
            AND (approval_status IS NULL OR approval_status != 'Draft')
          ORDER BY created_at ASC
        ''';
        final recordsRows = await db.rawQuery(recordsSql, [templateId, dateStr]);

        reportDetails.add(_buildExecutionDetailFromRows(
          reportKey: 'dyn_$templateId',
          dynamicReportId: templateId,
          reportName: templateName,
          departmentName: departmentName,
          sourceType: ReportSourceType.dynamicReport,
          rows: recordsRows,
        ));
      }

      // -------------------------------------------------------------
      // تجميع النتائج وحساب الإحصائيات
      // -------------------------------------------------------------
      final executedList = reportDetails.where((r) => r.isExecuted).toList();
      final missedList = reportDetails.where((r) => !r.isExecuted).toList();

      final totalActive = reportDetails.length;
      final executedCount = executedList.length;
      final missedCount = missedList.length;
      final totalInspections = executedList.fold<int>(0, (sum, r) => sum + r.executionCount);

      final double complianceRate = totalActive > 0
          ? double.parse(((executedCount / totalActive) * 100).toStringAsFixed(1))
          : 100.0;

      return FactoryDailyComplianceReport(
        branchId: branchId,
        branchName: branchName,
        date: date,
        totalActiveReports: totalActive,
        executedReportsCount: executedCount,
        missedReportsCount: missedCount,
        totalInspectionsCount: totalInspections,
        complianceRate: complianceRate,
        executedReports: executedList,
        missedReports: missedList,
        allReports: reportDetails,
      );
    } catch (e, stack) {
      debugPrint('Error in getFactoryDailyCompliance: $e\n$stack');
      return FactoryDailyComplianceReport(
        branchId: branchId,
        branchName: branchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل',
        date: date,
        totalActiveReports: 0,
        executedReportsCount: 0,
        missedReportsCount: 0,
        totalInspectionsCount: 0,
        complianceRate: 0.0,
        executedReports: [],
        missedReports: [],
        allReports: [],
      );
    }
  }

  /// تحليل شامل لكافة المصانع في تاريخ محدد
  Future<FactoryComplianceKPISummary> getMultiFactoryDailyCompliance({
    required DateTime date,
    int? branchId,
  }) async {
    final branchReports = <FactoryDailyComplianceReport>[];

    if (branchId != null && branchId > 0) {
      final rep = await getFactoryDailyCompliance(date: date, branchId: branchId);
      branchReports.add(rep);
    } else {
      // جلب مصنع أرتل ومصنع سنحان
      final rep1 = await getFactoryDailyCompliance(date: date, branchId: 1);
      final rep2 = await getFactoryDailyCompliance(date: date, branchId: 2);
      branchReports.add(rep1);
      branchReports.add(rep2);
    }

    int totalActive = 0;
    int totalExecuted = 0;
    int totalMissed = 0;
    int totalInspections = 0;
    double sumRates = 0.0;

    for (final r in branchReports) {
      totalActive += r.totalActiveReports;
      totalExecuted += r.executedReportsCount;
      totalMissed += r.missedReportsCount;
      totalInspections += r.totalInspectionsCount;
      sumRates += r.complianceRate;
    }

    final double avgRate = branchReports.isNotEmpty
        ? double.parse((sumRates / branchReports.length).toStringAsFixed(1))
        : 100.0;

    return FactoryComplianceKPISummary(
      date: date,
      totalBranches: branchReports.length,
      overallComplianceRate: avgRate,
      totalActiveScheduled: totalActive,
      totalExecutedReports: totalExecuted,
      totalMissedReports: totalMissed,
      totalInspectionsCount: totalInspections,
      branchReports: branchReports,
    );
  }

  /// معالجة أسطر السجلات واستخراج إحصائيات التكرار والورديات
  ReportExecutionDetail _buildExecutionDetailFromRows({
    required String reportKey,
    int? dynamicReportId,
    required String reportName,
    required String departmentName,
    required ReportSourceType sourceType,
    required List<Map<String, dynamic>> rows,
  }) {
    if (rows.isEmpty) {
      return ReportExecutionDetail(
        reportKey: reportKey,
        dynamicReportId: dynamicReportId,
        reportName: reportName,
        departmentName: departmentName,
        sourceType: sourceType,
        isExecuted: false,
        executionCount: 0,
        shiftsCovered: const [],
        shiftIds: const {},
        lastExecutionTime: null,
        compliantCount: 0,
        nonCompliantCount: 0,
        pendingApprovalsCount: 0,
      );
    }

    final executionCount = rows.length;
    final shiftsSet = <String>{};
    final shiftIdsSet = <int>{};
    int compliant = 0;
    int nonCompliant = 0;
    int pending = 0;
    DateTime? latestTime;

    for (final row in rows) {
      // الوردية
      final shiftId = row['shift_id'] as int?;
      final shiftName = row['shift_name'] as String?;
      if (shiftId != null) {
        shiftIdsSet.add(shiftId);
        shiftsSet.add(shiftName ?? 'وردية $shiftId');
      } else if (shiftName != null && shiftName.trim().isNotEmpty) {
        shiftsSet.add(shiftName.trim());
      } else {
        shiftsSet.add('وردية تشغيلية');
      }

      // المطابقة
      final isComp = row['is_compliant'];
      final qualDec = row['quality_decision'] as String?;
      final recStatus = row['status'] as String?;

      if (isComp != null) {
        if (isComp == 1 || isComp == true) {
          compliant++;
        } else {
          nonCompliant++;
        }
      } else if (qualDec != null) {
        if (qualDec.toLowerCase().contains('reject') || qualDec.contains('مرفوض')) {
          nonCompliant++;
        } else {
          compliant++;
        }
      } else if (recStatus != null) {
        if (recStatus.toLowerCase().contains('reject') || recStatus.contains('مرفوض')) {
          nonCompliant++;
        } else {
          compliant++;
        }
      } else {
        compliant++;
      }

      // الاعتماد
      final status = (row['approval_status'] as String?) ?? '';
      if (status.contains('Pending') || status.contains('Submitted') || status.contains('UnderReview')) {
        pending++;
      }

      // التوقيت
      final createdStr = row['created_at'] as String?;
      if (createdStr != null) {
        final parsed = DateTime.tryParse(createdStr);
        if (parsed != null) {
          if (latestTime == null || parsed.isAfter(latestTime)) {
            latestTime = parsed;
          }
        }
      }
    }

    return ReportExecutionDetail(
      reportKey: reportKey,
      dynamicReportId: dynamicReportId,
      reportName: reportName,
      departmentName: departmentName,
      sourceType: sourceType,
      isExecuted: true,
      executionCount: executionCount,
      shiftsCovered: shiftsSet.toList(),
      shiftIds: shiftIdsSet,
      lastExecutionTime: latestTime,
      compliantCount: compliant,
      nonCompliantCount: nonCompliant,
      pendingApprovalsCount: pending,
    );
  }
}
