import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'api/water_quality_api_service.dart';
import 'api/raw_materials_api_service.dart';
import 'api/hygiene_api_service.dart';
import 'api/dynamic_reports_api_service.dart';
import 'api/master_data_api_service.dart';
import 'database_helper.dart';

/// خدمة مزامنة بيانات الداش بورد والفحوصات من السيرفر المركزي إلى SQLite المحلي
class DashboardSyncService {
  DashboardSyncService._internal();
  static final DashboardSyncService instance = DashboardSyncService._internal();

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// مزامنة شاملة وسريعة لكافة الفحوصات المركزية
  Future<void> syncAllDashboardData({int? branchId, bool force = false}) async {
    if (_isSyncing) return;
    if (!force && _lastSyncTime != null && DateTime.now().difference(_lastSyncTime!).inSeconds < 10) {
      return;
    }

    _isSyncing = true;
    try {
      final db = await DatabaseHelper.instance.database;

      await Future.wait([
        _syncTestParameters(db),
        _syncWaterQuality(db, branchId),
        _syncRawMaterials(db, branchId),
        _syncHygiene(db, branchId),
        _syncDynamicReports(db, branchId),
      ]);

      _lastSyncTime = DateTime.now();
    } catch (e, stack) {
      debugPrint('DashboardSyncService.syncAllDashboardData error: $e\n$stack');
    } finally {
      _isSyncing = false;
    }
  }

  /// 1. مزامنة معايير الفحص TestParameters
  Future<void> _syncTestParameters(Database db) async {
    try {
      if (!Get.isRegistered<MasterDataApiService>()) return;
      final existingCount = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM TestParameters'),
      ) ?? 0;

      // نجلب المعايير إذا كان الجدول فارغاً محلياً
      if (existingCount == 0) {
        final params = await MasterDataApiService.to.getTestParameters();
        if (params.isNotEmpty) {
          final batch = db.batch();
          for (final p in params) {
            final id = p['id'] is int ? p['id'] as int : int.tryParse(p['id'].toString()) ?? 0;
            if (id <= 0) continue;
            batch.insert('TestParameters', {
              'id': id,
              'category': p['category']?.toString(),
              'name_ar': p['nameAr'] ?? p['name_ar'] ?? p['name'] ?? '',
              'unit': p['unit']?.toString(),
              'input_type': p['inputType'] ?? p['input_type'] ?? 'numeric',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        }
      }
    } catch (e) {
      debugPrint('DashboardSyncService._syncTestParameters error: $e');
    }
  }

  /// 2. مزامنة فحوصات جودة المياه WaterQualityLogs ونتائجها
  Future<void> _syncWaterQuality(Database db, int? branchId) async {
    try {
      if (!Get.isRegistered<WaterQualityApiService>()) return;
      final logs = await WaterQualityApiService.to.getLogs(branchId: branchId);
      if (logs.isEmpty) return;

      final batch = db.batch();
      final List<int> recentLogIdsWithNoResults = [];

      for (final w in logs) {
        final id = w['id'] is int ? w['id'] as int : int.tryParse(w['id']?.toString() ?? '') ?? 0;
        if (id <= 0) continue;

        final isComp = (w['isCompliant'] == 1 || w['isCompliant'] == true || w['is_compliant'] == 1) ? 1 : 0;
        final bId = w['branchId'] ?? w['branch_id'] ?? 1;
        final bName = (w['branchName'] ?? w['branch_name'] ?? (bId == 2 ? 'مصنع سنحان' : 'مصنع أرتل')).toString();
        final sId = w['shiftId'] ?? w['shift_id'];
        final sName = w['shiftName'] ?? w['shift_name'];

        batch.insert('WaterQualityLogs', await _filterValidColumns(db, 'WaterQualityLogs', {
          'id': id,
          'branch_id': bId,
          'branch_name': bName,
          'shift_id': sId,
          'shift_name': sName,
          'created_by': w['createdBy'] ?? w['created_by'],
          'report_category': w['reportCategory'] ?? w['report_category'],
          'water_type': w['waterType'] ?? w['water_type'],
          'batch_number': w['batchNumber'] ?? w['batch_number'],
          'is_compliant': isComp,
          'general_notes': w['generalNotes'] ?? w['general_notes'],
          'created_at': w['createdAt'] ?? w['created_at'],
          'approval_status': w['approvalStatus'] ?? w['approval_status'],
          'approved_by': w['approvedBy'] ?? w['approved_by'],
          'approved_at': w['approvedAt'] ?? w['approved_at'],
          'rejection_reason': w['rejectionReason'] ?? w['rejection_reason'],
          'water_source': w['waterSource'] ?? w['water_source'],
          'well_number': w['wellNumber'] ?? w['well_number'],
          'sample_taker': w['sampleTaker'] ?? w['sample_taker'],
          'manager_notified': (w['managerNotified'] == 1 || w['managerNotified'] == true) ? 1 : 0,
          'source_suspended': (w['sourceSuspended'] == 1 || w['sourceSuspended'] == true) ? 1 : 0,
          'ncr_number': w['ncrNumber'] ?? w['ncr_number'],
          'qm_approved_by': w['qmApprovedBy'] ?? w['qm_approved_by'],
          'qm_approved_at': w['qmApprovedAt'] ?? w['qm_approved_at'],
          'gm_approved_by': w['gmApprovedBy'] ?? w['gm_approved_by'],
          'gm_approved_at': w['gmApprovedAt'] ?? w['gm_approved_at'],
          'rejected_by': w['rejectedBy'] ?? w['rejected_by'],
          'rejected_at': w['rejectedAt'] ?? w['rejected_at'],
          'product_name': w['productName'] ?? w['product_name'],
          'bottle_size': w['bottleSize'] ?? w['bottle_size'],
          'production_date': w['productionDate'] ?? w['production_date'],
          'sampling_time': w['samplingTime'] ?? w['sampling_time'],
          'sampling_location': w['samplingLocation'] ?? w['sampling_location'],
          'produced_quantity': w['producedQuantity'] ?? w['produced_quantity'],
          'is_isolated': (w['isIsolated'] == 1 || w['isIsolated'] == true) ? 1 : 0,
          'is_hold_issued': (w['isHoldIssued'] == 1 || w['isHoldIssued'] == true) ? 1 : 0,
          'is_reject_issued': (w['isRejectIssued'] == 1 || w['isRejectIssued'] == true) ? 1 : 0,
          'micro_results_pending': (w['microResultsPending'] == 1 || w['microResultsPending'] == true) ? 1 : 0,
          'micro_entered_by': w['microEnteredBy'] ?? w['micro_entered_by'],
          'micro_entered_at': w['microEnteredAt'] ?? w['micro_entered_at'],
          'stage1_qm_approved_by': w['stage1QmApprovedBy'] ?? w['stage1_qm_approved_by'],
          'stage1_qm_approved_at': w['stage1QmApprovedAt'] ?? w['stage1_qm_approved_at'],
          'stage1_gm_approved_by': w['stage1GmApprovedBy'] ?? w['stage1_gm_approved_by'],
          'stage1_gm_approved_at': w['stage1GmApprovedAt'] ?? w['stage1_gm_approved_at'],
          'micro_qm_approved_by': w['microQmApprovedBy'] ?? w['micro_qm_approved_by'],
          'micro_qm_approved_at': w['microQmApprovedAt'] ?? w['micro_qm_approved_at'],
          'micro_gm_approved_by': w['microGmApprovedBy'] ?? w['micro_gm_approved_by'],
          'micro_gm_approved_at': w['microGmApprovedAt'] ?? w['micro_gm_approved_at'],
          'rejection_category': w['rejectionCategory'] ?? w['rejection_category'],
          'severity_level': w['severityLevel'] ?? w['severity_level'],
          'rejection_notes': w['rejectionNotes'] ?? w['rejection_notes'],
          'affected_products': w['affectedProducts'] ?? w['affected_products'],
          'immediate_action': w['immediateAction'] ?? w['immediate_action'],
          'corrective_action': w['correctiveAction'] ?? w['corrective_action'],
          'corrective_owner': w['correctiveOwner'] ?? w['corrective_owner'],
          'corrective_due_date': w['correctiveDueDate'] ?? w['corrective_due_date'],
          'gm_decision': w['gmDecision'] ?? w['gm_decision'],
          'gm_decision_by': w['gmDecisionBy'] ?? w['gm_decision_by'],
          'gm_decision_at': w['gmDecisionAt'] ?? w['gm_decision_at'],
          'gm_decision_notes': w['gmDecisionNotes'] ?? w['gm_decision_notes'],
          'micro_rejection_reason': w['microRejectionReason'] ?? w['micro_rejection_reason'],
          'micro_rejected_by': w['microRejectedBy'] ?? w['micro_rejected_by'],
          'micro_rejected_at': w['microRejectedAt'] ?? w['micro_rejected_at'],
          'micro_rejection_action': w['microRejectionAction'] ?? w['micro_rejection_action'],
        }), conflictAlgorithm: ConflictAlgorithm.replace);

        recentLogIdsWithNoResults.add(id);
      }
      await batch.commit(noResult: true);

      // جلب نتائج القياسات (TDS, pH, Micro, etc.) لآخر 5 سجلات لتغذية رادار المؤشرات
      final topLogsToFetch = recentLogIdsWithNoResults.take(5).toList();
      for (final logId in topLogsToFetch) {
        final existingResults = await db.rawQuery(
          'SELECT COUNT(*) as cnt FROM WaterQualityResults WHERE log_id = ?',
          [logId],
        );
        final cnt = Sqflite.firstIntValue(existingResults) ?? 0;
        final logRow = await db.query(
          'WaterQualityLogs',
          columns: ['micro_entered_at'],
          where: 'id = ?',
          whereArgs: [logId],
          limit: 1,
        );
        final hasMicroUpdate = logRow.isNotEmpty &&
            logRow.first['micro_entered_at'] != null &&
            logRow.first['micro_entered_at'].toString().isNotEmpty;

        if (cnt == 0 || hasMicroUpdate) {
          final details = await WaterQualityApiService.to.getLogById(logId);
          if (details != null && details['results'] is List) {
            final resList = details['results'] as List;
            if (resList.length != cnt) {
              await db.delete('WaterQualityResults', where: 'log_id = ?', whereArgs: [logId]);
              final rBatch = db.batch();
              for (final r in resList) {
                final pId = r['parameterId'] ?? r['parameter_id'] ?? 0;
                final numVal = r['numericResult'] ?? r['numeric_result'];
                final txtVal = r['textResult'] ?? r['text_result'];
                final comp = (r['isCompliant'] == 1 || r['isCompliant'] == true || r['is_compliant'] == 1) ? 1 : 0;
                rBatch.insert('WaterQualityResults', {
                  'log_id': logId,
                  'parameter_id': pId,
                  'numeric_result': numVal is num ? numVal.toDouble() : double.tryParse(numVal?.toString() ?? ''),
                  'text_result': txtVal?.toString(),
                  'is_compliant': comp,
                  'notes': r['notes']?.toString(),
                }, conflictAlgorithm: ConflictAlgorithm.replace);
              }
              await rBatch.commit(noResult: true);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('DashboardSyncService._syncWaterQuality error: $e');
    }
  }

  /// 3. مزامنة تقارير فحص المواد الأولية RawMaterialReports
  Future<void> _syncRawMaterials(Database db, int? branchId) async {
    try {
      if (!Get.isRegistered<RawMaterialsApiService>()) return;
      final reports = await RawMaterialsApiService.to.getReports(branchId: branchId);
      if (reports.isEmpty) return;

      final batch = db.batch();
      for (final r in reports) {
        final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id']?.toString() ?? '') ?? 0;
        if (id <= 0) continue;

        batch.insert('RawMaterialReports', await _filterValidColumns(db, 'RawMaterialReports', {
          'id': id,
          'category_key': r['category_key'] ?? r['categoryKey'] ?? 'General',
          'annex_code': r['annex_code'] ?? r['annexCode'] ?? '',
          'annex_title': r['annex_title'] ?? r['annexTitle'] ?? '',
          'created_at': r['created_at'] ?? r['createdAt'] ?? '',
          'date_str': r['date_str'] ?? r['dateStr'] ?? '',
          'time_str': r['time_str'] ?? r['timeStr'] ?? '',
          'supplier_name': r['supplier_name'] ?? r['supplierName'] ?? '',
          'po_number': r['po_number'] ?? r['poNumber'] ?? '',
          'material_name': r['material_name'] ?? r['materialName'] ?? '',
          'receipt_number': r['receipt_number'] ?? r['receiptNumber'] ?? '',
          'received_quantity': r['received_quantity'] ?? r['receivedQuantity'] ?? '',
          'inspected_quantity': r['inspected_quantity'] ?? r['inspectedQuantity'] ?? '',
          'inspector_name': r['inspector_name'] ?? r['inspectorName'] ?? '',
          'batch_number': r['batch_number'] ?? r['batchNumber'] ?? '',
          'quality_decision': r['quality_decision'] ?? r['qualityDecision'] ?? 'مقبول',
          'action_hold': (r['action_hold'] == 1 || r['actionHold'] == 1 || r['actionHold'] == true) ? 1 : 0,
          'action_reject': (r['action_reject'] == 1 || r['actionReject'] == 1 || r['actionReject'] == true) ? 1 : 0,
          'action_return_to_supplier': (r['action_return_to_supplier'] == 1 || r['actionReturnToSupplier'] == 1 || r['actionReturnToSupplier'] == true) ? 1 : 0,
          'action_ncr': (r['action_ncr'] == 1 || r['actionNcr'] == 1 || r['actionNcr'] == true) ? 1 : 0,
          'ncr_number': r['ncr_number'] ?? r['ncrNumber'],
          'general_notes': r['general_notes'] ?? r['generalNotes'],
          'annex_notes': r['annex_notes'] ?? r['annexNotes'],
          'approval_status': r['approval_status'] ?? r['approvalStatus'] ?? 'Approved',
          'qm_approved_by': r['qm_approved_by'] ?? r['qmApprovedBy'],
          'qm_approved_at': r['qm_approved_at'] ?? r['qmApprovedAt'],
          'gm_approved_by': r['gm_approved_by'] ?? r['gmApprovedBy'],
          'gm_approved_at': r['gm_approved_at'] ?? r['gmApprovedAt'],
          'lab_responsible_name': r['lab_responsible_name'] ?? r['labResponsibleName'],
          'lab_responsible_at': r['lab_responsible_at'] ?? r['labResponsibleAt'],
          'rejected_by': r['rejected_by'] ?? r['rejectedBy'],
          'rejected_at': r['rejected_at'] ?? r['rejectedAt'],
          'rejection_reason': r['rejection_reason'] ?? r['rejectionReason'],
          'rejection_category': r['rejection_category'] ?? r['rejectionCategory'],
          'severity_level': r['severity_level'] ?? r['severityLevel'],
          'rejection_notes': r['rejection_notes'] ?? r['rejectionNotes'],
          'affected_products': r['affected_products'] ?? r['affectedProducts'],
          'immediate_action': r['immediate_action'] ?? r['immediateAction'],
          'corrective_action': r['corrective_action'] ?? r['correctiveAction'],
          'corrective_owner': r['corrective_owner'] ?? r['correctiveOwner'],
          'corrective_due_date': r['corrective_due_date'] ?? r['correctiveDueDate'],
          'gm_decision': r['gm_decision'] ?? r['gmDecision'],
          'gm_decision_by': r['gm_decision_by'] ?? r['gmDecisionBy'],
          'gm_decision_at': r['gm_decision_at'] ?? r['gmDecisionAt'],
          'gm_decision_notes': r['gm_decision_notes'] ?? r['gmDecisionNotes'],
          'accepted_quantity': r['accepted_quantity'] ?? r['acceptedQuantity'],
          'rejected_quantity': r['rejected_quantity'] ?? r['rejectedQuantity'],
          'branch_id': r['branch_id'] ?? r['branchId'] ?? 1,
          'branch_name': r['branch_name'] ?? r['branchName'] ?? 'مصنع أرتل',
        }), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('DashboardSyncService._syncRawMaterials error: $e');
    }
  }

  /// 4. مزامنة تقارير النظافة العامة والاشتراطات HygieneReports
  Future<void> _syncHygiene(Database db, int? branchId) async {
    try {
      if (!Get.isRegistered<HygieneApiService>()) return;
      final reports = await HygieneApiService.to.getReports(branchId: branchId);
      if (reports.isEmpty) return;

      final batch = db.batch();
      for (final r in reports) {
        final id = r['id'] is int ? r['id'] as int : int.tryParse(r['id']?.toString() ?? '') ?? 0;
        if (id <= 0) continue;

        final bId = r['branch_id'] ?? r['branchId'] ?? 1;
        final bName = (r['branch_name'] ?? r['branchName'] ?? (bId == 2 ? 'مصنع سنحان' : 'مصنع أرتل')).toString();
        final sId = r['shift_id'] ?? r['shiftId'] ?? 1;
        final sName = (r['shift_name'] ?? r['shiftName'] ?? 'وردية أولى (صباحية)').toString();

        batch.insert('HygieneReports', await _filterValidColumns(db, 'HygieneReports', {
          'id': id,
          'created_at': r['created_at'] ?? r['createdAt'] ?? '',
          'supervisor_name': r['supervisor_name'] ?? r['supervisorName'] ?? '',
          'employee_count': r['employee_count'] ?? r['employeeCount'] ?? 0,
          'approval_status': r['approval_status'] ?? r['approvalStatus'] ?? 'Approved',
          'rejection_reason': r['rejection_reason'] ?? r['rejectionReason'],
          'rejected_by': r['rejected_by'] ?? r['rejectedBy'],
          'rejected_at': r['rejected_at'] ?? r['rejectedAt'],
          'qm_approved_by': r['qm_approved_by'] ?? r['qmApprovedBy'],
          'qm_approved_at': r['qm_approved_at'] ?? r['qmApprovedAt'],
          'gm_approved_by': r['gm_approved_by'] ?? r['gmApprovedBy'],
          'gm_approved_at': r['gm_approved_at'] ?? r['gmApprovedAt'],
          'branch_id': bId,
          'branch_name': bName,
          'shift_id': sId,
          'shift_name': sName,
          'rejection_category': r['rejection_category'] ?? r['rejectionCategory'],
          'severity_level': r['severity_level'] ?? r['severityLevel'],
          'rejection_notes': r['rejection_notes'] ?? r['rejectionNotes'],
          'affected_products': r['affected_products'] ?? r['affectedProducts'],
          'immediate_action': r['immediate_action'] ?? r['immediateAction'],
          'corrective_action': r['corrective_action'] ?? r['correctiveAction'],
          'corrective_owner': r['corrective_owner'] ?? r['correctiveOwner'],
          'corrective_due_date': r['corrective_due_date'] ?? r['correctiveDueDate'],
          'gm_decision': r['gm_decision'] ?? r['gmDecision'],
          'gm_decision_by': r['gm_decision_by'] ?? r['gmDecisionBy'],
          'gm_decision_at': r['gm_decision_at'] ?? r['gmDecisionAt'],
          'gm_decision_notes': r['gm_decision_notes'] ?? r['gmDecisionNotes'],
        }), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('DashboardSyncService._syncHygiene error: $e');
    }
  }

  /// 5. مزامنة قوالب وسجلات النماذج الديناميكية
  Future<void> _syncDynamicReports(Database db, int? branchId) async {
    try {
      if (!Get.isRegistered<DynamicReportsApiService>()) return;

      // أ) تصنيفات وقوالب النماذج
      final templates = await DynamicReportsApiService.to.getTemplates();
      if (templates.isNotEmpty) {
        final batch = db.batch();
        for (final t in templates) {
          batch.insert('dr_reports', await _filterValidColumns(db, 'dr_reports', {
            'id': t.id,
            'category_id': t.categoryId,
            'name': t.name,
            'description': t.description,
            'icon': t.icon,
            'sort_order': t.sortOrder,
            'is_active': t.isActive ? 1 : 0,
            'approval_type': t.approvalType,
            'orientation': t.orientation,
            'doc_number': t.docNumber,
            'version_number': t.versionNumber,
            'issue_date': t.issueDate,
            'header_config_json': t.headerConfigJson,
            'created_at': t.createdAt?.toIso8601String(),
            'updated_at': t.updatedAt?.toIso8601String(),
          }), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }

      // ب) سجلات النماذج (مع الحفاظ على data_json المحلي إذا لم يرجعه السيرفر لسجلات قديمة)
      final records = await DynamicReportsApiService.to.getRecords(branchId: branchId);
      if (records.isNotEmpty) {
        final localRows = await db.rawQuery(
          'SELECT id, data_json, shift_id, qs_approved_by, qs_approved_at FROM dr_records',
        );
        final Map<int, Map<String, dynamic>> localById = {
          for (final row in localRows)
            if (row['id'] is int) row['id'] as int: row,
        };

        final batch = db.batch();
        for (final rec in records) {
          final existing = rec.id != null ? localById[rec.id!] : null;
          batch.insert('dr_records', await _filterValidColumns(db, 'dr_records', {
            'id': rec.id,
            'report_id': rec.reportId,
            'report_version_id': rec.reportVersionId,
            'created_by': rec.createdBy,
            'created_at': rec.createdAt?.toIso8601String(),
            'updated_at': rec.updatedAt?.toIso8601String(),
            'status': rec.status,
            'approval_status': rec.approvalStatus,
            'qs_approved_by': rec.qsApprovedBy ?? existing?['qs_approved_by'],
            'qs_approved_at': rec.qsApprovedAt?.toIso8601String() ?? existing?['qs_approved_at'],
            'qm_approved_by': rec.qmApprovedBy,
            'qm_approved_at': rec.qmApprovedAt?.toIso8601String(),
            'gm_approved_by': rec.gmApprovedBy,
            'gm_approved_at': rec.gmApprovedAt?.toIso8601String(),
            'rejection_reason': rec.rejectionReason,
            'rejected_by': rec.rejectedBy,
            'rejected_at': rec.rejectedAt?.toIso8601String(),
            'branch_id': rec.branchId,
            'branch_name': rec.branchName,
            'shift_id': existing?['shift_id'],
            'shift_name': rec.shiftName,
            'is_compliant': rec.isCompliant == null ? 1 : (rec.isCompliant! ? 1 : 0),
            'summary_notes': rec.summaryNotes,
            'data_json': (rec.dataJson != null && rec.dataJson!.isNotEmpty)
                ? rec.dataJson
                : existing?['data_json'],
            'rejection_category': rec.rejectionCategory,
            'severity_level': rec.severityLevel,
            'rejection_notes': rec.rejectionNotes,
            'affected_products': rec.affectedProducts,
            'immediate_action': rec.immediateAction,
            'corrective_action': rec.correctiveAction,
            'corrective_owner': rec.correctiveOwner,
            'corrective_due_date': rec.correctiveDueDate?.toIso8601String(),
            'gm_decision': rec.gmDecision,
            'gm_decision_by': rec.gmDecisionBy,
            'gm_decision_at': rec.gmDecisionAt?.toIso8601String(),
            'gm_decision_notes': rec.gmDecisionNotes,
          }), conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      }
    } catch (e) {
      debugPrint('DashboardSyncService._syncDynamicReports error: $e');
    }
  }

  final Map<String, Set<String>> _tableColumnsCache = {};

  Future<Map<String, dynamic>> _filterValidColumns(Database db, String tableName, Map<String, dynamic> data) async {
    if (!_tableColumnsCache.containsKey(tableName)) {
      final info = await db.rawQuery("PRAGMA table_info('$tableName')");
      _tableColumnsCache[tableName] = info.map((r) => r['name'].toString()).toSet();
    }
    final cols = _tableColumnsCache[tableName]!;
    return Map.fromEntries(data.entries.where((e) => cols.contains(e.key)));
  }

}
