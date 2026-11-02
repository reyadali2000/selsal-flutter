import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/role_model.dart';
import 'database_helper.dart';

class RolesDatabaseService {
  RolesDatabaseService._();
  static final RolesDatabaseService instance = RolesDatabaseService._();

  static const String _prefKey = 'roles_schema_version';

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// ترحيل صلاحيات الأدوار المخزنة عند ترقية هيكل الصلاحيات
  Future<void> _migrateRolesSchemaIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(_prefKey) ?? 1;

    if (current >= SystemPermissions.schemaVersion) return;

    final db = await _db;
    final rows = await db.query('CustomRoles');

    for (final row in rows) {
      final role = RoleModel.fromMap(row);
      var migrated = SystemPermissions.migratePermissions(role.permissions);
      if (role.isSystem) {
        final defaultRole = RoleModel.defaultSystemRoles.firstWhere(
          (d) => d.code == role.code,
          orElse: () => role,
        );
        for (final p in defaultRole.permissions) {
          if (!migrated.contains(p)) {
            migrated.add(p);
          }
        }
        migrated = SystemPermissions.removeCrossDepartmentPermissionsForSystemRole(
          role.code,
          migrated,
        );
      }
      if (migrated.length != role.permissions.length ||
          !migrated.every((c) => role.permissions.contains(c))) {
        await db.update(
          'CustomRoles',
          {'permissions_json': jsonEncode(migrated)},
          where: 'id = ?',
          whereArgs: [role.id],
        );
      }
    }

    await prefs.setInt(_prefKey, SystemPermissions.schemaVersion);
  }

  /// جلب كافة الأدوار (النظامية والمخصصة)
  Future<List<RoleModel>> getAllRoles() async {
    final db = await _db;
    final res = await db.query('CustomRoles', orderBy: 'is_system DESC, id ASC');
    if (res.isEmpty) {
      // إذا كان الجدول فارغاً نقوم بضخ الأدوار الافتراضية
      for (final r in RoleModel.defaultSystemRoles) {
        await db.insert('CustomRoles', r.toMap());
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefKey, SystemPermissions.schemaVersion);
      final fresh = await db.query('CustomRoles', orderBy: 'is_system DESC, id ASC');
      return fresh.map((e) => RoleModel.fromMap(e)).toList();
    }
    // ضمان وجود نسخة محدثة من الأدوار النظامية بعد التحديثات
    await _ensureSystemRolesFresh();
    await _migrateRolesSchemaIfNeeded();

    final finalRes = await db.query('CustomRoles', orderBy: 'is_system DESC, id ASC');
    return finalRes.map((e) => RoleModel.fromMap(e)).toList();
  }

  /// ضخ الأدوار النظامية المفقودة فقط — دون الكتابة فوق صلاحياتها
  /// حتى لا تُلغى تعديلات المسؤول عليها عند كل استدعاء.
  Future<void> _ensureSystemRolesFresh() async {
    final db = await _db;
    for (final def in RoleModel.defaultSystemRoles) {
      final existing = await getRoleByCode(def.code);
      if (existing == null) {
        await db.insert('CustomRoles', def.toMap());
      }
    }
  }

  /// استعادة صلاحيات دور نظامي إلى الإعدادات الافتراضية للنظام
  Future<void> resetSystemRole(int roleId) async {
    final db = await _db;
    final role = await getRoleById(roleId);
    if (role == null) {
      throw Exception('الدور الوظيفي غير موجود.');
    }
    if (!role.isSystem) {
      throw Exception('لا يمكن الاستعادة: هذا ليس دوراً نظامياً أساسياً.');
    }

    final def = RoleModel.defaultSystemRoles.firstWhere(
      (d) => d.code == role.code,
      orElse: () => role,
    );

    await db.update(
      'CustomRoles',
      {
        'permissions_json': jsonEncode(def.permissions),
        'title': def.title,
        'description': def.description,
      },
      where: 'id = ?',
      whereArgs: [roleId],
    );
  }

  /// جلب دور محدد بواسطة الكود الفريد
  Future<RoleModel?> getRoleByCode(String code) async {
    final db = await _db;
    final res = await db.query(
      'CustomRoles',
      where: 'LOWER(code) = ?',
      whereArgs: [code.trim().toLowerCase()],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return RoleModel.fromMap(res.first);
  }

  /// جلب دور محدد بواسطة المعرف
  Future<RoleModel?> getRoleById(int id) async {
    final db = await _db;
    final res = await db.query('CustomRoles', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    return RoleModel.fromMap(res.first);
  }

  /// فحص توفر كود الدور
  Future<bool> isRoleCodeTaken(String code, {int? excludeId}) async {
    final db = await _db;
    final cleanCode = code.trim().toLowerCase();
    String where = 'LOWER(code) = ?';
    List<dynamic> args = [cleanCode];

    if (excludeId != null) {
      where += ' AND id != ?';
      args.add(excludeId);
    }

    final res = await db.query('CustomRoles', where: where, whereArgs: args);
    return res.isNotEmpty;
  }

  /// إنشاء دور وظيفي مخصص جديد
  Future<int> createRole(RoleModel role) async {
    final db = await _db;
    final map = role.toMap();
    map.remove('id');
    return await db.insert('CustomRoles', map);
  }

  /// تحديث دور وظيفي مخصص
  Future<int> updateRole(RoleModel role) async {
    final db = await _db;
    final map = role.toMap();
    return await db.update(
      'CustomRoles',
      map,
      where: 'id = ?',
      whereArgs: [role.id],
    );
  }

  /// حذف دور مخصص (مع التحقق من عدم كونه دور نظامي أو مرتبط بمستخدمين)
  Future<void> deleteRole(int roleId) async {
    final db = await _db;
    final role = await getRoleById(roleId);
    if (role == null) {
      throw Exception('الدور الوظيفي غير موجود.');
    }

    if (role.isSystem) {
      throw Exception('لا يمكن حذف أدوار النظام الأساسية.');
    }

    // التحقق من عدم وجود مستخدمين مسندين لهذا الدور
    final usersWithRole = await db.rawQuery('''
      SELECT COUNT(*) as count FROM Users 
      WHERE LOWER(role) = ? OR LOWER(role) = ?
    ''', [role.code.toLowerCase(), role.title.toLowerCase()]);

    final count = Sqflite.firstIntValue(usersWithRole) ?? 0;
    if (count > 0) {
      throw Exception('لا يمكن حذف الدور "$role.title" لوجود $count مستخدم مرتبطين به حالياً.');
    }

    await db.delete('CustomRoles', where: 'id = ?', whereArgs: [roleId]);
  }

  /// جلب قائمة صلاحيات مستخدم بناءً على الدور المسند إليه
  Future<List<String>> getPermissionsForRole(String roleCodeOrTitle) async {
    final clean = roleCodeOrTitle.trim().toLowerCase();
    final normalized = clean.replaceAll('_', '').replaceAll(' ', '');

    // 1. بحث دقيق ومرن في جدول الأدوار (CustomRoles)
    final allRoles = await getAllRoles();
    for (final r in allRoles) {
      final rCode = r.code.trim().toLowerCase();
      final rCodeNorm = rCode.replaceAll('_', '').replaceAll(' ', '');
      final rTitle = r.title.trim().toLowerCase();
      final rTitleNorm = rTitle.replaceAll('_', '').replaceAll(' ', '');

      if (rCode == clean || rTitle == clean || rCodeNorm == normalized || rTitleNorm == normalized) {
        return r.permissions;
      }
    }

    // 2. توافق خلفي إذا لم يتم العثور عليه في جدول الأدوار
    //    مطابقة دقيقة فقط (لا contains) لتفادي التصعيد الصامت لأسماء الأدوار
    //    التي تحتوي على أسماء النظام جزئياً (مثل sysadmin/agm/sqm) — مشكلة D.4.
    const systemRoleAliases = <String, String>{
      'admin': 'admin',
      'administrator': 'admin',
      'مديرالنظام': 'admin',
      'generalmanager': 'general_manager',
      'gmanager': 'general_manager',
      'مديرعام': 'general_manager',
      'المديرالعام': 'general_manager',
      'qualitymanager': 'quality_manager',
      'qm': 'quality_manager',
      'مديرالجودة': 'quality_manager',
      'factorymanager': 'factory_manager',
      'gm': 'factory_manager',
      'مديرالمصنع': 'factory_manager',
      'foodsafetyengineer': 'food_safety_engineer',
      'foodsafety': 'food_safety_engineer',
      'سلامةالغذاء': 'food_safety_engineer',
      'مهندسسلامة': 'food_safety_engineer',
    };

    final code = systemRoleAliases[normalized];
    if (code != null) {
      final r = RoleModel.defaultSystemRoles.firstWhere(
        (e) => e.code == code,
        orElse: () => RoleModel.defaultSystemRoles.firstWhere((e) => e.code == 'quality_specialist'),
      );
      return r.permissions;
    }

    // 3. دور غير معروف — رفض صريح (fail-closed) بدل منح أخصائي الجودة — مشكلة D.5.
    //    المستخدم الذي دوره غير مسجّل في CustomRoles يُربط بدور صحيح من شاشة الإدارة.
    debugPrint('⚠️ الدور "$roleCodeOrTitle" غير مسجّل في CustomRoles '
        'وغير معروف في أسماء النظام — تم رفض كل الصلاحيات (fail-closed).');
    return <String>[];
  }
}
