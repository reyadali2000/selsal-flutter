import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import '../models/hygiene_models.dart';
import 'api/master_data_api_service.dart';
import 'database_helper.dart';

/// خدمة إدارة سجل العمالة اليومية
class WorkerDatabaseService {
  WorkerDatabaseService._internal();
  static final WorkerDatabaseService instance = WorkerDatabaseService._internal();

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// بناء جملة WHERE لفلترة الفرع مع التوافق مع السجلات القديمة
  String _branchWhere(int? branchId, {String alias = ''}) {
    if (branchId == null || branchId <= 0) return '';
    final prefix = alias.isEmpty ? '' : '$alias.';
    if (branchId == 1) {
      return "(${prefix}branch_id = 1 OR ${prefix}branch_id IS NULL)";
    }
    return "${prefix}branch_id = $branchId";
  }

  /// جلب كافة العمال، مع إمكانية الفلترة بالفرع وتضمين المتوقفين.
  Future<List<DailyWorker>> getAllWorkers({
    int? branchId,
    bool includeInactive = false,
    String searchQuery = '',
  }) async {
    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        final raw = await MasterDataApiService.to.getDailyWorkers(
          branchId: branchId,
          includeInactive: includeInactive,
        );
        var list = raw.map((w) => DailyWorker.fromMap(w)).toList();
        if (!includeInactive) list = list.where((w) => w.isActive).toList();
        if (searchQuery.trim().isNotEmpty) {
          final q = searchQuery.trim().toLowerCase();
          list = list.where((w) => w.fullName.toLowerCase().contains(q) || w.nameKey.contains(q)).toList();
        }
        return list;
      }

      final db = await _db;
      await DatabaseHelper.instance.ensureDailyWorkersTable();

      final where = <String>[];
      final args = <dynamic>[];

      final branchClause = _branchWhere(branchId);
      if (branchClause.isNotEmpty) where.add(branchClause);
      if (!includeInactive) where.add('is_active = 1');

      final cleanSearch = searchQuery.trim();
      if (cleanSearch.isNotEmpty) {
        where.add('(full_name LIKE ? OR name_key LIKE ?)');
        args.add('%$cleanSearch%');
        args.add('%${DailyWorker.normalizeName(cleanSearch)}%');
      }

      final maps = await db.query(
        'DailyWorkers',
        where: where.isNotEmpty ? where.join(' AND ') : null,
        whereArgs: args.isNotEmpty ? args : null,
        orderBy: 'is_active DESC, full_name ASC',
      );
      return maps.map((m) => DailyWorker.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error in getAllWorkers: $e');
      return [];
    }
  }

  /// البحث عن عمال للاقتراحات التلقائية أثناء كتابة الاسم في فحص النظافة.
  /// يطابق بداية الاسم المطبَّع أولاً (الأكثر صلة)، ثم يحتويه، ويحدّ النتائج.
  Future<List<DailyWorker>> searchWorkers(
    String query, {
    int? branchId,
    int limit = 8,
  }) async {
    try {
      final clean = DailyWorker.normalizeName(query);
      if (clean.isEmpty) return [];

      if (Get.isRegistered<MasterDataApiService>()) {
        final all = await getAllWorkers(branchId: branchId, includeInactive: false);
        return all
            .where((w) => w.nameKey.contains(clean) || w.fullName.toLowerCase().contains(query.toLowerCase()))
            .take(limit)
            .toList();
      }

      final db = await _db;
      await DatabaseHelper.instance.ensureDailyWorkersTable();

      final branchClause = _branchWhere(branchId);
      final branchWhere = branchClause.isNotEmpty ? 'AND $branchClause' : '';

      // مطابقة البداية أولاً (الأولوية الأعلى) ثم الاحتواء — بترتيب واحد
      final maps = await db.rawQuery('''
        SELECT * FROM DailyWorkers
        WHERE is_active = 1
          AND (name_key LIKE ? OR name_key LIKE ?)
          $branchWhere
        ORDER BY
          CASE WHEN name_key LIKE ? THEN 0 ELSE 1 END,
          full_name ASC
        LIMIT ?
      ''', [
        '$clean%',
        '%$clean%',
        '$clean%',
        limit,
      ]);

      return maps.map((m) => DailyWorker.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error in searchWorkers: $e');
      return [];
    }
  }

  /// التحقق من وجود عامل بنفس الاسم المطبَّع داخل الفرع.
  Future<DailyWorker?> findByName(String fullName, {required int branchId}) async {
    try {
      final clean = DailyWorker.normalizeName(fullName);
      if (clean.isEmpty) return null;

      if (Get.isRegistered<MasterDataApiService>()) {
        final raw = await MasterDataApiService.to.getDailyWorkers(branchId: branchId, includeInactive: true);
        for (final m in raw) {
          final w = DailyWorker.fromMap(m);
          if (w.nameKey == clean) return w;
        }
        return null;
      }

      final db = await _db;
      await DatabaseHelper.instance.ensureDailyWorkersTable();

      final branchClause = _branchWhere(branchId);
      final branchWhere = branchClause.isNotEmpty ? 'AND $branchClause' : '';

      final maps = await db.rawQuery('''
        SELECT * FROM DailyWorkers
        WHERE name_key = ? $branchWhere
        LIMIT 1
      ''', [clean]);

      if (maps.isEmpty) return null;
      return DailyWorker.fromMap(maps.first);
    } catch (e) {
      debugPrint('Error in findByName: $e');
      return null;
    }
  }

  /// حفظ عامل (إضافة أو تعديل). يُعيد المعرّف، أو null عند فشل العملية.
  /// يمنع تكرار الاسم داخل الفرع الواحد عبر قيد UNIQUE على name_key.
  Future<int?> saveWorker(DailyWorker worker) async {
    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        final payload = {
          'id': worker.id ?? 0,
          'branchId': worker.branchId,
          'fullName': worker.fullName.trim(),
          'nameKey': DailyWorker.normalizeName(worker.fullName),
          'jobTitle': worker.jobTitle.trim(),
          'isActive': worker.isActive,
        };
        final apiOk = await MasterDataApiService.to.saveDailyWorker(payload);
        if (apiOk) {
          try {
            final db = await _db;
            await DatabaseHelper.instance.ensureDailyWorkersTable();
            final map = worker.toMap();
            map['name_key'] = DailyWorker.normalizeName(worker.fullName);
            if (worker.id == null) {
              map.remove('id');
              await db.insert('DailyWorkers', map);
            } else {
              await db.update('DailyWorkers', map, where: 'id = ?', whereArgs: [worker.id]);
            }
          } catch (_) {}
          return worker.id ?? 1;
        }
      }

      final db = await _db;
      await DatabaseHelper.instance.ensureDailyWorkersTable();

      final map = worker.toMap();
      map['name_key'] = DailyWorker.normalizeName(worker.fullName);

      if (worker.id == null) {
        map.remove('id');
        return await db.insert('DailyWorkers', map);
      }
      await db.update(
        'DailyWorkers',
        map,
        where: 'id = ?',
        whereArgs: [worker.id],
      );
      return worker.id;
    } catch (e) {
      debugPrint('Error in saveWorker: $e');
      return null;
    }
  }

  /// تبديل حالة تفعيل العامل (إيقاف/تفعيل) دون حذفه لضمان سلامة المراجع.
  Future<void> toggleWorkerStatus(int workerId, bool isActive) async {
    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        await MasterDataApiService.to.toggleDailyWorkerStatus(workerId, isActive);
      }
      final db = await _db;
      await db.update(
        'DailyWorkers',
        {'is_active': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [workerId],
      );
    } catch (e) {
      debugPrint('Error in toggleWorkerStatus: $e');
    }
  }

  /// حذف عامل نهائياً. يجب التأكد من عدم وجود تقارير مرتبطة به قبل الحذف.
  Future<void> deleteWorker(int workerId) async {
    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        await MasterDataApiService.to.deleteDailyWorker(workerId);
      }
      final db = await _db;
      await db.delete(
        'DailyWorkers',
        where: 'id = ?',
        whereArgs: [workerId],
      );
    } catch (e) {
      debugPrint('Error in deleteWorker: $e');
    }
  }

  /// عدد التقارير المرتبطة بالعامل (للتحقق قبل الحذف).
  Future<int> countLinkedReports(int workerId) async {
    try {
      final db = await _db;
      final result = await db.rawQuery('''
        SELECT COUNT(*) AS cnt
        FROM HygieneLogs
        WHERE employee_id = ?
      ''', [workerId]);
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      debugPrint('Error in countLinkedReports: $e');
      return 0;
    }
  }
}
