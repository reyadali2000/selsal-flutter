import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import '../models/hygiene_models.dart';
import '../models/worker_commitment_models.dart';
import 'api/hygiene_api_service.dart';
import 'api/master_data_api_service.dart';
import 'database_helper.dart';

class DailyWorkersCommitmentService {
  DailyWorkersCommitmentService._internal();
  static final DailyWorkersCommitmentService instance =
      DailyWorkersCommitmentService._internal();

  /// مزامنة تقارير النظافة وسجلات حضور العمالة من السيرفر إلى SQLite المحلي
  Future<void> syncFromApi({int? branchId}) async {
    try {
      final db = await DatabaseHelper.instance.database;

      // 1. مزامنة العمالة اليومية من السيرفر
      if (Get.isRegistered<MasterDataApiService>()) {
        try {
          final rawWorkers = await MasterDataApiService.to.getDailyWorkers(
            branchId: branchId,
            includeInactive: true,
          );
          if (rawWorkers.isNotEmpty) {
            final batch = db.batch();
            for (final w in rawWorkers) {
              final id = w['id'] is int ? w['id'] as int : int.tryParse(w['id'].toString()) ?? 0;
              final name = (w['full_name'] ?? w['fullName'] ?? '').toString().trim();
              final nKey = DailyWorker.normalizeName(name);
              final job = (w['job_title'] ?? w['jobTitle'] ?? 'عامل بالأجر اليومي').toString();
              final bId = w['branch_id'] ?? w['branchId'] ?? 1;
              final isAct = (w['is_active'] == 1 || w['is_active'] == true || w['isActive'] == true) ? 1 : 0;
              if (id > 0 && name.isNotEmpty) {
                batch.insert('DailyWorkers', {
                  'id': id,
                  'full_name': name,
                  'name_key': nKey,
                  'job_title': job,
                  'branch_id': bId,
                  'is_active': isAct,
                }, conflictAlgorithm: ConflictAlgorithm.replace);

                batch.insert('Employees', {
                  'id': id,
                  'full_name': name,
                  'job_title': job,
                  'branch_id': bId,
                  'is_active': isAct,
                }, conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
            await batch.commit(noResult: true);
          }
        } catch (e) {
          debugPrint('DailyWorkersCommitmentService: error syncing workers: $e');
        }
      }

      // 2. مزامنة تقارير النظافة وسجلات الفحص من السيرفر
      if (Get.isRegistered<HygieneApiService>()) {
        try {
          final reports = await HygieneApiService.to.getReports(branchId: branchId);
          for (final r in reports) {
            final rId = r['id'] is int ? r['id'] as int : int.tryParse(r['id'].toString()) ?? 0;
            if (rId <= 0) continue;

            final status = r['approval_status'] ?? r['approvalStatus'] ?? 'Approved';
            final createdAt = (r['created_at'] ?? r['createdAt'] ?? '').toString();
            final sup = (r['supervisor_name'] ?? r['supervisorName'] ?? '').toString();
            final empCount = r['employee_count'] ?? r['employeeCount'] ?? 0;
            final bId = r['branch_id'] ?? r['branchId'] ?? 1;
            final bName = (r['branch_name'] ?? r['branchName'] ?? (bId == 2 ? 'مصنع سنحان' : 'مصنع أرتل')).toString();
            final sId = r['shift_id'] ?? r['shiftId'] ?? 1;
            final sName = (r['shift_name'] ?? r['shiftName'] ?? 'وردية أولى (صباحية)').toString();

            await db.insert('HygieneReports', {
              'id': rId,
              'created_at': createdAt,
              'supervisor_name': sup,
              'employee_count': empCount,
              'approval_status': status,
              'branch_id': bId,
              'branch_name': bName,
              'shift_id': sId,
              'shift_name': sName,
              'rejection_reason': r['rejection_reason'] ?? r['rejectionReason'],
            }, conflictAlgorithm: ConflictAlgorithm.replace);

            // جلب تفاصيل التقرير إن لم تكن مسجلة محلياً
            final existingLogs = await db.rawQuery('SELECT COUNT(*) as cnt FROM HygieneLogs WHERE report_id = ?', [rId]);
            final logsCount = (existingLogs.firstOrNull?['cnt'] as int?) ?? 0;

            if (logsCount == 0) {
              final detailsData = await HygieneApiService.to.getReportDetails(rId);
              if (detailsData != null) {
                final emps = detailsData['employees'] as List? ?? detailsData['logs'] as List? ?? [];
                final details = detailsData['details'] as List? ?? [];

                final batch = db.batch();
                final empLogIdMap = <int, int>{};

                for (final e in emps) {
                  final logId = e['log_id'] ?? e['id'] ?? 0;
                  final empId = e['employee_id'] ?? 0;
                  if (empId > 0) {
                    final effectiveLogId = logId > 0 ? (logId is int ? logId : int.tryParse(logId.toString()) ?? (rId * 1000 + (empId is int ? empId : 1))) : (rId * 1000 + (empId is int ? empId : 1));
                    final effectiveEmpId = empId is int ? empId : int.tryParse(empId.toString()) ?? 1;
                    empLogIdMap[effectiveEmpId] = effectiveLogId;
                    batch.insert('HygieneLogs', {
                      'id': effectiveLogId,
                      'report_id': rId,
                      'branch_id': bId,
                      'shift_id': sId,
                      'shift_name': sName,
                      'checklist_id': 1,
                      'employee_id': effectiveEmpId,
                      'created_at': createdAt,
                      'approval_status': status,
                    }, conflictAlgorithm: ConflictAlgorithm.replace);
                  }
                }

                for (final d in details) {
                  final empIdRaw = d['employee_id'];
                  final empId = empIdRaw is int ? empIdRaw : int.tryParse(empIdRaw?.toString() ?? '') ?? 0;
                  final logId = d['hygiene_log_id'] ?? empLogIdMap[empId] ?? (rId * 1000 + empId);
                  final itemId = d['checklist_item_id'] ?? 0;
                  final isComp = (d['is_compliant'] == 1 || d['is_compliant'] == true || d['isCompliant'] == true) ? 1 : 0;
                  final notes = d['notes']?.toString();

                  batch.insert('HygieneLogDetails', {
                    if (d['id'] != null) 'id': d['id'],
                    'hygiene_log_id': logId,
                    'checklist_item_id': itemId,
                    'is_compliant': isComp,
                    'notes': notes,
                  }, conflictAlgorithm: ConflictAlgorithm.replace);
                }
                await batch.commit(noResult: true);
              }
            }
          }
        } catch (e) {
          debugPrint('DailyWorkersCommitmentService: error syncing reports: $e');
        }
      }
    } catch (e) {
      debugPrint('DailyWorkersCommitmentService.syncFromApi failed: $e');
    }
  }

  /// حساب واستخراج التقرير الشامل لالتزام الععمال والورديات لشهر وسنة محددين
  Future<List<WorkerMonthlyCommitment>> getMonthlyCommitmentReport({
    required int year,
    required int month,
    int? branchId,
    int? shiftFilterId,
  }) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final monthStr = '$year-${month.toString().padLeft(2, '0')}';

      // 1. حساب عدد أيام العمل المستهدفة (أيام التفتيش المسجلة في الفرع خلال الشهر)
      String targetDaysSql = '''
        SELECT COUNT(DISTINCT substr(created_at, 1, 10)) as working_days 
        FROM HygieneReports 
        WHERE approval_status != 'Draft' 
          AND substr(created_at, 1, 7) = ?
      ''';
      List<dynamic> targetDaysArgs = [monthStr];
      if (branchId != null && branchId > 0) {
        if (branchId == 1) {
          targetDaysSql += ' AND (branch_id = 1 OR branch_id IS NULL)';
        } else {
          targetDaysSql += ' AND branch_id = ?';
          targetDaysArgs.add(branchId);
        }
      }

      final targetDaysResult = await db.rawQuery(targetDaysSql, targetDaysArgs);
      int targetWorkingDays =
          (targetDaysResult.firstOrNull?['working_days'] as int?) ?? 0;

      // 2. جلب كافة سجلات التفتيش للشهر
      String logsSql = '''
        SELECT 
          hl.id AS log_id,
          hl.report_id,
          hl.branch_id,
          hl.shift_id,
          COALESCE(hl.shift_name, hr.shift_name, 'وردية أولى (صباحية)') AS shift_name,
          hl.employee_id,
          hr.created_at,
          hr.branch_name
        FROM HygieneLogs hl
        INNER JOIN HygieneReports hr ON hr.id = hl.report_id
        WHERE hr.approval_status != 'Draft'
          AND substr(hr.created_at, 1, 7) = ?
      ''';
      List<dynamic> logsArgs = [monthStr];
      if (branchId != null && branchId > 0) {
        if (branchId == 1) {
          logsSql += ' AND (hr.branch_id = 1 OR hr.branch_id IS NULL)';
        } else {
          logsSql += ' AND hr.branch_id = ?';
          logsArgs.add(branchId);
        }
      }
      logsSql += ' ORDER BY hr.created_at ASC';

      final logsRows = await db.rawQuery(logsSql, logsArgs);

      // 3. جلب تفاصيل تقييم بنود النظافة للشهر
      String detailsSql = '''
        SELECT 
          hld.hygiene_log_id,
          hld.checklist_item_id,
          hld.is_compliant,
          hld.notes,
          ci.item_name
        FROM HygieneLogDetails hld
        INNER JOIN HygieneLogs hl ON hl.id = hld.hygiene_log_id
        INNER JOIN HygieneReports hr ON hr.id = hl.report_id
        LEFT JOIN ChecklistItems ci ON ci.id = hld.checklist_item_id
        WHERE hr.approval_status != 'Draft'
          AND substr(hr.created_at, 1, 7) = ?
      ''';
      List<dynamic> detailsArgs = [monthStr];
      if (branchId != null && branchId > 0) {
        if (branchId == 1) {
          detailsSql += ' AND (hr.branch_id = 1 OR hr.branch_id IS NULL)';
        } else {
          detailsSql += ' AND hr.branch_id = ?';
          detailsArgs.add(branchId);
        }
      }

      final detailsRows = await db.rawQuery(detailsSql, detailsArgs);

      // تجميع تفاصيل البنود حسب hygiene_log_id
      final detailsByLogId = <int, List<Map<String, dynamic>>>{};
      for (final d in detailsRows) {
        final logId = d['hygiene_log_id'] as int;
        detailsByLogId.putIfAbsent(logId, () => []).add(d);
      }

      // 4. جلب جميع العمال المسجلين في النظام
      String workersSql = 'SELECT id, full_name, job_title, branch_id, is_active FROM DailyWorkers';
      List<dynamic> workersArgs = [];
      if (branchId != null && branchId > 0) {
        if (branchId == 1) {
          workersSql += ' WHERE (branch_id = 1 OR branch_id IS NULL)';
        } else {
          workersSql += ' WHERE branch_id = ?';
          workersArgs.add(branchId);
        }
      }
      workersSql += ' ORDER BY full_name ASC';
      final workersRows = await db.rawQuery(workersSql, workersArgs);

      // خريطة العمال
      final workersMap = <int, Map<String, dynamic>>{};
      for (final w in workersRows) {
        final id = w['id'] as int;
        workersMap[id] = w;
      }

      // تجميع سجلات الحضور حسب معرّف العامل (employee_id)
      final logsByWorker = <int, List<Map<String, dynamic>>>{};
      for (final log in logsRows) {
        final empId = log['employee_id'] as int?;
        if (empId != null) {
          logsByWorker.putIfAbsent(empId, () => []).add(log);
        }
      }

      // إذا كانت أيام التفتيش 0، نحدد الحد الأقصى لأيام حضور أي عامل
      int maxAttended = 0;
      for (final entries in logsByWorker.values) {
        final distinctDates = <String>{};
        for (final e in entries) {
          final createdAt = e['created_at'] as String?;
          if (createdAt != null && createdAt.length >= 10) {
            distinctDates.add(createdAt.substring(0, 10));
          }
        }
        if (distinctDates.length > maxAttended) {
          maxAttended = distinctDates.length;
        }
      }
      if (targetWorkingDays == 0) {
        targetWorkingDays = maxAttended > 0 ? maxAttended : 1;
      }

      // بناء كائنات التقييم الشهري
      final resultList = <WorkerMonthlyCommitment>[];

      // نمر على كل عامل مسجل أو عامل حضر في سجلات النظافة
      final allWorkerIds = <int>{...workersMap.keys, ...logsByWorker.keys};

      for (final workerId in allWorkerIds) {
        final workerData = workersMap[workerId];
        final workerLogs = logsByWorker[workerId] ?? [];

        // تصفية حسب الوردية إذا تم تحديدها
        if (shiftFilterId != null && shiftFilterId > 0) {
          final hasShiftLog = workerLogs.any((l) => (l['shift_id'] as int? ?? 1) == shiftFilterId);
          if (!hasShiftLog) continue;
        }

        // إذا لم يكن للعامل حضور وكان هناك فلتر وردية محدد نتجاهله
        if (workerLogs.isEmpty && shiftFilterId != null && shiftFilterId > 0) {
          continue;
        }

        final fullName = workerData != null
            ? (workerData['full_name'] as String? ?? 'عامل $workerId')
            : 'عامل $workerId';
        final jobTitle = workerData != null
            ? (workerData['job_title'] as String? ?? 'عامل بالأجر اليومي')
            : 'عامل بالأجر اليومي';
        final wBranchId = workerData != null
            ? (workerData['branch_id'] as int? ?? (branchId ?? 1))
            : (branchId ?? 1);
        final branchName = wBranchId == 2 ? 'مصنع سنحان' : 'مصنع أرتل';
        final isActive = workerData != null
            ? ((workerData['is_active'] as int?) ?? 1) == 1
            : true;

        // تجميع الأيام والورديات والتقييمات
        final distinctDatesMap = <String, Map<String, dynamic>>{};
        final shiftCounts = <int, int>{1: 0, 2: 0, 3: 0};
        final dailyRecords = <WorkerDailyAttendanceRecord>[];

        int totalEvaluatedItems = 0;
        int totalCompliantItems = 0;
        int totalViolations = 0;

        for (final log in workerLogs) {
          final logId = log['log_id'] as int;
          final createdAt = log['created_at'] as String;
          final dateKey = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;
          final shiftId = (log['shift_id'] as int?) ?? 1;
          final shiftName = (log['shift_name'] as String?) ?? 'وردية أولى (صباحية)';
          final reportId = (log['report_id'] as int?) ?? 0;

          // احتساب الوردية في الأيام الفريدة
          if (!distinctDatesMap.containsKey(dateKey)) {
            distinctDatesMap[dateKey] = log;
            shiftCounts[shiftId] = (shiftCounts[shiftId] ?? 0) + 1;
          }

          // تقييم بنود النظافة لهذا السجل
          final itemDetails = detailsByLogId[logId] ?? [];
          int logTotalCriteria = itemDetails.length;
          int logCompliantCount = 0;
          int logViolationsCount = 0;
          final violationNotes = <String>[];

          for (final item in itemDetails) {
            final isComp = (item['is_compliant'] as int?) == 1;
            final itemName = item['item_name'] as String? ?? 'بند النظافة';
            final note = item['notes'] as String?;

            totalEvaluatedItems++;
            if (isComp) {
              totalCompliantItems++;
              logCompliantCount++;
            } else {
              totalViolations++;
              logViolationsCount++;
              final text = note != null && note.trim().isNotEmpty
                  ? '$itemName: $note'
                  : itemName;
              violationNotes.add(text);
            }
          }

          final double logScore = logTotalCriteria > 0
              ? (logCompliantCount / logTotalCriteria * 100)
              : 100.0;

          final record = WorkerDailyAttendanceRecord(
            date: DateTime.tryParse(createdAt) ?? DateTime(year, month, 1),
            shiftId: shiftId,
            shiftName: shiftName,
            reportId: reportId,
            totalCriteria: logTotalCriteria,
            compliantCriteria: logCompliantCount,
            nonCompliantCriteria: logViolationsCount,
            complianceScore: logScore,
            violationNotes: violationNotes,
            isFullCompliant: logViolationsCount == 0,
          );
          dailyRecords.add(record);
        }

        final daysPresent = distinctDatesMap.length;
        final double attendanceRate = targetWorkingDays > 0
            ? ((daysPresent / targetWorkingDays) * 100).clamp(0.0, 100.0)
            : 0.0;

        final double avgHygieneScore = totalEvaluatedItems > 0
            ? ((totalCompliantItems / totalEvaluatedItems) * 100).clamp(0.0, 100.0)
            : (daysPresent > 0 ? 100.0 : 0.0);

        // مؤشر الالتزام المركب: 50% حضور + 50% نظافة
        final double compositeScore = daysPresent > 0
            ? ((attendanceRate * 0.5) + (avgHygieneScore * 0.5))
            : 0.0;

        // ترتيب السجلات اليومية تصاعدياً حسب التاريخ
        dailyRecords.sort((a, b) => a.date.compareTo(b.date));

        resultList.add(WorkerMonthlyCommitment(
          workerId: workerId,
          fullName: fullName,
          jobTitle: jobTitle,
          branchId: wBranchId,
          branchName: branchName,
          isActive: isActive,
          year: year,
          month: month,
          daysPresent: daysPresent,
          targetWorkingDays: targetWorkingDays,
          attendanceRate: double.parse(attendanceRate.toStringAsFixed(1)),
          shiftCounts: shiftCounts,
          avgHygieneScore: double.parse(avgHygieneScore.toStringAsFixed(1)),
          totalViolations: totalViolations,
          compositeCommitmentScore: double.parse(compositeScore.toStringAsFixed(1)),
          dailyRecords: dailyRecords,
        ));
      }

      // 5. الترتيب التنازلي وتحديد المراكز (Ranks)
      resultList.sort((a, b) {
        int cmp = b.compositeCommitmentScore.compareTo(a.compositeCommitmentScore);
        if (cmp != 0) return cmp;
        int cmpDays = b.daysPresent.compareTo(a.daysPresent);
        if (cmpDays != 0) return cmpDays;
        return b.avgHygieneScore.compareTo(a.avgHygieneScore);
      });

      for (int i = 0; i < resultList.length; i++) {
        resultList[i].rank = i + 1;
      }

      return resultList;
    } catch (e, stack) {
      debugPrint('Error in getMonthlyCommitmentReport: $e\n$stack');
      return [];
    }
  }

  /// حساب ملخص مؤشرات الأداء الرئيسية (KPIs)
  Future<WorkersCommitmentKPISummary> getKPISummary({
    required int year,
    required int month,
    int? branchId,
  }) async {
    final list = await getMonthlyCommitmentReport(
      year: year,
      month: month,
      branchId: branchId,
    );

    if (list.isEmpty) {
      return const WorkersCommitmentKPISummary(
        totalRegisteredWorkers: 0,
        totalAttendedWorkers: 0,
        avgAttendanceRate: 0.0,
        avgHygieneScore: 0.0,
        totalShiftsCovered: 0,
        targetWorkingDays: 0,
      );
    }

    final totalRegistered = list.length;
    final attendedList = list.where((w) => w.daysPresent > 0).toList();
    final totalAttended = attendedList.length;

    double sumAttendance = 0.0;
    double sumHygiene = 0.0;
    int totalShifts = 0;

    for (final w in attendedList) {
      sumAttendance += w.attendanceRate;
      sumHygiene += w.avgHygieneScore;
      totalShifts += (w.shift1Count + w.shift2Count + w.shift3Count);
    }

    final avgAttendance = totalAttended > 0 ? (sumAttendance / totalAttended) : 0.0;
    final avgHygiene = totalAttended > 0 ? (sumHygiene / totalAttended) : 0.0;
    final targetDays = list.first.targetWorkingDays;

    return WorkersCommitmentKPISummary(
      totalRegisteredWorkers: totalRegistered,
      totalAttendedWorkers: totalAttended,
      avgAttendanceRate: double.parse(avgAttendance.toStringAsFixed(1)),
      avgHygieneScore: double.parse(avgHygiene.toStringAsFixed(1)),
      totalShiftsCovered: totalShifts,
      targetWorkingDays: targetDays,
    );
  }
}
