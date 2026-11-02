import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/branch_model.dart';
import 'api/master_data_api_service.dart';
import 'database_helper.dart';

/// خدمة إدارة المصانع والورديات
class FactoryShiftsService {
  FactoryShiftsService._internal();
  static final FactoryShiftsService instance = FactoryShiftsService._internal();

  /// جلب كافة المصانع / الفروع النشطة
  Future<List<BranchModel>> getAllBranches() async {
    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        final raw = await MasterDataApiService.to.getBranches();
        if (raw.isNotEmpty) {
          return raw.map((b) => BranchModel.fromMap(b)).toList();
        }
      }
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        'Branches',
        where: 'is_active = 1',
        orderBy: 'id ASC',
      );
      return maps.map((m) => BranchModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error in getAllBranches: $e');
      return [];
    }
  }

  /// جلب مصنع عبر المعرف ID
  Future<BranchModel?> getBranchById(int id) async {
    try {
      final all = await getAllBranches();
      return all.firstWhereOrNull((b) => b.id == id);
    } catch (e) {
      debugPrint('Error in getBranchById: $e');
    }
    return null;
  }

  /// جلب ورديات مصنع معين
  Future<List<ShiftModel>> getShiftsForBranch(int branchId, {bool activeOnly = false}) async {
    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        final shifts = await MasterDataApiService.to.getShifts(branchId: branchId);
        if (shifts.isNotEmpty) {
          final list = shifts.map((s) => ShiftModel.fromMap(s)).toList();
          return activeOnly ? list.where((s) => s.isActive).toList() : list;
        }
      }
    } catch (e) {
      debugPrint('Error in getShiftsForBranch API: $e');
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final whereClause = activeOnly ? 'branch_id = ? AND is_active = 1' : 'branch_id = ?';
      final maps = await db.query(
        'Shifts',
        where: whereClause,
        whereArgs: [branchId],
        orderBy: 'start_time ASC',
      );
      return maps.map((m) => ShiftModel.fromMap(m)).toList();
    } catch (e) {
      debugPrint('Error in getShiftsForBranch local: $e');
      return [];
    }
  }

  /// التعرف التلقائي على الوردية الجارية حالياً في مصنع ما وفق ساعة الهاتف
  Future<ShiftModel?> getActiveShiftNow(int branchId, [DateTime? now]) async {
    try {
      final shifts = await getShiftsForBranch(branchId, activeOnly: true);
      final current = now ?? DateTime.now();
      for (final s in shifts) {
        if (s.isCurrentlyActive(current)) {
          return s;
        }
      }
      // إذا لم يتطابق، أعد أول وردية نشطة كـ fallback
      if (shifts.isNotEmpty) return shifts.first;
    } catch (e) {
      debugPrint('Error in getActiveShiftNow: $e');
    }
    return null;
  }

  /// إضافة وردية جديدة
  Future<int> createShift(ShiftModel shift) async {
    int localId = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      localId = await db.insert('Shifts', shift.toMap());
    } catch (e) {
      debugPrint('Local createShift error: $e');
    }

    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        final payload = shift.toMap();
        payload.remove('id');
        await MasterDataApiService.to.saveShift(payload);
      }
    } catch (e) {
      debugPrint('API createShift error: $e');
    }
    return localId;
  }

  /// تعديل بيانات وردية
  Future<int> updateShift(ShiftModel shift) async {
    if (shift.id == null) return 0;
    int res = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      res = await db.update(
        'Shifts',
        shift.toMap(),
        where: 'id = ?',
        whereArgs: [shift.id],
      );
    } catch (e) {
      debugPrint('Local updateShift error: $e');
    }

    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        await MasterDataApiService.to.saveShift(shift.toMap());
      }
    } catch (e) {
      debugPrint('API updateShift error: $e');
    }
    return res;
  }

  /// تفعيل أو تعطيل وردية
  Future<int> toggleShiftActive(int id, bool isActive) async {
    int res = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      res = await db.update(
        'Shifts',
        {'is_active': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      debugPrint('Local toggleShiftActive error: $e');
    }

    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        await MasterDataApiService.to.toggleShiftStatus(id, isActive);
      }
    } catch (e) {
      debugPrint('API toggleShiftStatus error: $e');
    }
    return res;
  }

  /// حذف وردية
  Future<int> deleteShift(int id) async {
    int res = 0;
    try {
      final db = await DatabaseHelper.instance.database;
      res = await db.delete('Shifts', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      debugPrint('Local deleteShift error: $e');
    }

    try {
      if (Get.isRegistered<MasterDataApiService>()) {
        final ok = await MasterDataApiService.to.deleteShift(id);
        if (!ok) {
          throw Exception('فشل حذف الوردية من الخادم');
        }
      }
    } catch (e) {
      debugPrint('API deleteShift error: $e');
      rethrow;
    }
    return res;
  }

  /// تحديث اسم الموسم لجميع ورديات مصنع معين (مثل: التبديل إلى "توقيت شهر رمضان" أو "التوقيت الشتوي")
  Future<int> updateSeasonForBranch(int branchId, String newSeasonName) async {
    final db = await DatabaseHelper.instance.database;
    return await db.update(
      'Shifts',
      {'season_name': newSeasonName.trim()},
      where: 'branch_id = ?',
      whereArgs: [branchId],
    );
  }
}
