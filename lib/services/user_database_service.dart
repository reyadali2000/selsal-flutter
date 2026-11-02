import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user_model.dart';
import '../utils/password_hasher.dart';
import 'database_helper.dart';

class UserDatabaseService {
  UserDatabaseService._internal();
  static final UserDatabaseService instance = UserDatabaseService._internal();

  Future<Database> get _db async => await DatabaseHelper.instance.database;

  /// تسجيل الدخول بالتحقق من اسم المستخدم أو البريد وكلمة المرور المشفرة
  Future<UserModel?> authenticate(String usernameOrEmail, String password) async {
    final db = await _db;
    final cleanInput = usernameOrEmail.trim().toLowerCase();
    final cleanPass = password.trim();

    final res = await db.query(
      'Users',
      where: '(LOWER(username) = ? OR LOWER(email) = ?) AND is_active = 1',
      whereArgs: [cleanInput, cleanInput],
      limit: 1,
    );

    if (res.isEmpty) {
      debugPrint("Authentication failed: User '$cleanInput' not found or inactive.");
      return null;
    }

    final userMap = res.first;
    final storedHash = userMap['password_hash']?.toString() ?? '';

    // التحقق من كلمة المرور المشفرة (القيمة المخزنة يجب أن تكون هاشاً)
    if (!PasswordHasher.verify(cleanPass, storedHash)) {
      debugPrint("Authentication failed: Password mismatch for user '$cleanInput'.");
      return null;
    }

    // تحديث تاريخ آخر تسجيل دخول
    try {
      await db.update(
        'Users',
        {'last_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [userMap['id']],
      );
    } catch (_) {}

    return UserModel.fromMap(userMap);
  }

  /// تسجيل الدخول بالتحقق من اسم المستخدم أو البريد وكلمة المرور المشفرة
  /// (مسار PIN القديم مُلغى — الدخول بكلمة المرور فقط)

  /// جلب كافة المستخدمين المسجلين في النظام (مع إمكانية تصفية الفرع)
  Future<List<UserModel>> getAllUsers({UserRole? roleFilter, bool? activeOnly, int? branchId}) async {
    final db = await _db;
    String? whereClause;
    List<dynamic>? whereArgs;

    final List<String> conditions = [];
    final List<dynamic> args = [];

    if (roleFilter != null) {
      conditions.add('role = ?');
      args.add(UserModel.roleToString(roleFilter));
    }

    if (activeOnly == true) {
      conditions.add('is_active = 1');
    }

    if (branchId != null && branchId > 0) {
      conditions.add('branch_id = ?');
      args.add(branchId);
    }

    if (conditions.isNotEmpty) {
      whereClause = conditions.join(' AND ');
      whereArgs = args;
    }

    final res = await db.query(
      'Users',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'id ASC',
    );

    return res.map((e) => UserModel.fromMap(e)).toList();
  }

  /// جلب مستخدم بواسطة الرقم التعريفي
  Future<UserModel?> getUserById(int id) async {
    final db = await _db;
    final res = await db.query('Users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (res.isEmpty) return null;
    return UserModel.fromMap(res.first);
  }

  /// جلب مستخدم بواسطة اسم المستخدم
  Future<UserModel?> getUserByUsername(String username) async {
    final db = await _db;
    final res = await db.query(
      'Users',
      where: 'LOWER(username) = ?',
      whereArgs: [username.trim().toLowerCase()],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return UserModel.fromMap(res.first);
  }

  /// إضافة مستخدم جديد إلى النظام (كلمة المرور تُخزَّن مشفرة)
  Future<int> createUser(UserModel user) async {
    final db = await _db;
    final map = user.toMap();
    map.remove('id'); // SQLite generates ID automatically
    // custom_permissions خاص بالسيرفر ولا يوجد عمود مماثل في الجدول المحلي
    map.remove('custom_permissions');
    // تشفير كلمة المرور قبل التخزين إن لم تكن مشفرة بالفعل
    final rawPass = map['password_hash']?.toString() ?? '';
    if (rawPass.isNotEmpty && !PasswordHasher.looksLikeHash(rawPass)) {
      map['password_hash'] = PasswordHasher.hash(rawPass);
    }
    return await db.insert('Users', map);
  }

  /// مزامنة مستخدم قادم من السيرفر (SQL Server) إلى قاعدة البيانات المحلية (SQLite).
  ///
  /// المستخدمون يُدارون مركزياً على السيرفر وتأتي ملفاتهم بمعرّفات السيرفر، بينما
  /// تحتوي الجداول المحلية (user_signatures و report_approvals و audit_logs ...)
  /// على قيود مفاتيح أجنبية تشير إلى Users(id). هذه الدالة تُدرج/تُحدّث المستخدم
  /// محلياً **مع الحفاظ على معرّف السيرفر** لتبقى تلك القيود صالحة ولا تنتهك
  /// (FOREIGN KEY constraint failed) عند حفظ التوقيع أو سجلات الاعتماد.
  Future<void> upsertServerUser(UserModel user) async {
    if (user.id == null || user.id! <= 0) return;

    final db = await _db;
    final map = user.toMap();

    // custom_permissions خاص بالسيرفر ولا يوجد عمود مماثل في الجدول المحلي
    map.remove('custom_permissions');

    // التأكد من وجود الفرع محلياً قبل ربطه تفادياً لخرق قيد المفتاح الأجنبي
    final branchId = map['branch_id'];
    if (branchId != null) {
      final branchRow = await db.query('Branches', columns: ['id'], where: 'id = ?', whereArgs: [branchId]);
      if (branchRow.isEmpty) {
        map['branch_id'] = null;
      }
    }

    final username = (map['username'] ?? '').toString().trim().toLowerCase();
    if (username.isEmpty) {
      map['username'] = 'user_${user.id}';
    }

    // تحديث الصف إن وُجد محلياً بنفس معرّف السيرفر
    final existing = await db.query('Users', columns: ['id'], where: 'id = ?', whereArgs: [user.id]);
    if (existing.isNotEmpty) {
      await db.update('Users', map, where: 'id = ?', whereArgs: [user.id]);
      return;
    }

    // إزالة أي نسخة محلية قديمة بنفس اسم المستخدم (بمعرّف مختلف) لتفادي تعارض UNIQUE
    await db.delete('Users', where: 'LOWER(username) = ?', whereArgs: [username]);

    await db.insert('Users', map);
  }

  /// إدراج صف مستخدم أدنى (Placeholder) إن لم يكن موجوداً محلياً،
  /// لإرضاء قيود المفاتيح الأجنبية في الجداول المحلية عند غياب بيانات المستخدم الكاملة.
  Future<void> ensurePlaceholderUser(int userId) async {
    if (userId <= 0) return;

    final db = await _db;
    final existing = await db.query('Users', columns: ['id'], where: 'id = ?', whereArgs: [userId]);
    if (existing.isNotEmpty) return;

    final username = 'user_$userId';
    await db.delete('Users', where: 'LOWER(username) = ?', whereArgs: [username]);

    await db.insert('Users', {
      'id': userId,
      'username': username,
      'full_name': 'مستخدم $userId',
      'role': 'QualitySpecialist',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// تعديل بيانات مستخدم حالي
  Future<int> updateUser(UserModel user) async {
    if (user.id == null) return -1;
    final db = await _db;
    final map = user.toMap();
    return await db.update('Users', map, where: 'id = ?', whereArgs: [user.id]);
  }

  /// تفعيل أو تعطيل حساب المستخدم (Toggle Active)
  Future<int> toggleUserStatus(int userId, bool isActive) async {
    final db = await _db;
    return await db.update(
      'Users',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// تغيير كلمة المرور للمستخدم (تُخزَّن مشفرة)
  Future<int> changePassword(int userId, String newPassword) async {
    final db = await _db;
    final plain = newPassword.trim();
    return await db.update(
      'Users',
      {'password_hash': PasswordHasher.hash(plain)},
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  /// حذف مستخدم
  Future<int> deleteUser(int userId) async {
    final db = await _db;
    // التأكد من عدم حذف آخر أدمن
    final admins = await getAllUsers(roleFilter: UserRole.admin, activeOnly: true);
    if (admins.length <= 1 && admins.any((u) => u.id == userId)) {
      throw Exception('لا يمكن حذف مسؤول النظام الوحيد النشط.');
    }
    return await db.delete('Users', where: 'id = ?', whereArgs: [userId]);
  }

  /// التحقق من اسم المستخدم إن كان محجوزاً
  Future<bool> isUsernameTaken(String username, {int? excludeUserId}) async {
    final db = await _db;
    final clean = username.trim().toLowerCase();
    String where = 'LOWER(username) = ?';
    List<dynamic> args = [clean];
    if (excludeUserId != null) {
      where += ' AND id != ?';
      args.add(excludeUserId);
    }
    final res = await db.query('Users', columns: ['id'], where: where, whereArgs: args);
    return res.isNotEmpty;
  }
}
