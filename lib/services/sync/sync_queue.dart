import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database_helper.dart';

/// طابور المزامنة المحلي (Outbox Pattern)
///
/// يخزّن عمليات الكتابة (POST / PUT / DELETE) التي فشلت بسبب انقطاع
/// الشبكة، ويعيد إرسالها تلقائياً عند عودة الاتصال عبر [SyncManager].
/// هذا يضمن عدم ضياع أي عملية كتابة يقوم بها المستخدم أثناء العمل offline.
class SyncQueue {
  SyncQueue._();
  static final SyncQueue instance = SyncQueue._();

  static const String table = 'sync_queue';

  Future<Database> get _db => DatabaseHelper.instance.database;

  /// إضافة عملية كتابة فاشلة إلى الطابور لتُعاد لاحقاً مع منع التكرار (Deduplication).
  Future<int> enqueue({
    required String method,
    required String endpoint,
    dynamic body,
    String? entityType,
    int? entityId,
  }) async {
    final now = DateTime.now().toIso8601String();
    final db = await _db;
    final bodyJson = body != null ? jsonEncode(body) : null;

    // فحص ما إذا كانت هناك عملية مطابقة في الطابور بحالة معلّقة أو قيد المعالجة
    // لمنع تدبيل الطلبات في حال الضغط المتكرر أثناء انقطاع الشبكة
    final existing = await db.query(
      table,
      where: "method = ? AND endpoint = ? AND status IN ('pending', 'processing')",
      whereArgs: [method.toUpperCase(), endpoint],
    );

    for (final row in existing) {
      final existingBody = row['body_json'] as String?;
      final existingEntityType = row['entity_type'] as String?;
      final existingEntityId = row['entity_id'] as int?;

      bool isMatch = false;
      if (entityType != null && entityId != null &&
          existingEntityType == entityType && existingEntityId == entityId) {
        isMatch = true;
      } else if (bodyJson != null && existingBody != null && bodyJson == existingBody) {
        isMatch = true;
      }

      if (isMatch) {
        final existingId = row['id'] as int;
        await db.update(
          table,
          {
            'body_json': bodyJson,
            'next_retry_at': now,
            'status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [existingId],
        );
        return existingId;
      }
    }

    return await db.insert(table, {
      'method': method.toUpperCase(),
      'endpoint': endpoint,
      'body_json': bodyJson,
      'entity_type': entityType,
      'entity_id': entityId,
      'status': 'pending',
      'attempts': 0,
      'last_error': null,
      'created_at': now,
      'next_retry_at': now,
    });
  }

  /// حجز وجلب العمليات المعلّقة الجاهزة للإرسال مع تعليمها فوراً كـ 'processing'
  /// داخل Transaction لمنع حدوث Race Condition وتكرار الإرسال المتزامن.
  Future<List<Map<String, dynamic>>> claimPending({int limit = 20}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();

    return await db.transaction((txn) async {
      final rows = await txn.query(
        table,
        where: "status = 'pending' AND next_retry_at <= ?",
        whereArgs: [now],
        orderBy: 'created_at ASC',
        limit: limit,
      );

      if (rows.isNotEmpty) {
        final ids = rows.map((r) => r['id'] as int).toList();
        final placeholders = List.filled(ids.length, '?').join(',');
        await txn.rawUpdate(
          "UPDATE $table SET status = 'processing' WHERE id IN ($placeholders)",
          ids,
        );
      }
      return rows;
    });
  }

  /// استعادة أي عمليات علقت كـ 'processing' عند بدء التطبيق
  Future<void> recoverStuckProcessing() async {
    try {
      final db = await _db;
      await db.update(
        table,
        {'status': 'pending'},
        where: "status = 'processing'",
      );
    } catch (_) {}
  }

  /// جلب العمليات المعلّقة الجاهزة للإرسال (للقراءة فقط).
  Future<List<Map<String, dynamic>>> getPending({int limit = 20}) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    return await db.query(
      table,
      where: "status = 'pending' AND next_retry_at <= ?",
      whereArgs: [now],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// عدد العمليات المعلّقة حالياً في الطابور.
  Future<int> pendingCount() async {
    final db = await _db;
    final result = await db.rawQuery("SELECT COUNT(*) AS cnt FROM $table WHERE status IN ('pending', 'processing')");
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// نجاح العملية → تُحذف من الطابور (لا حاجة لاحتفاظ بسجل منها).
  Future<void> markDone(int id) async {
    final db = await _db;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  /// فشل العملية → تُحفظ مع زيادة المحاولات وتأخير الإعادة (exponential backoff).
  /// بعد [maxAttempts] محاولات تُعلّم كـ 'failed' لتبقى للمراجعة اليدوية.
  Future<void> markFailed(int id, String error, {int maxAttempts = 5}) async {
    final db = await _db;
    final rows = await db.query(table, where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return;

    final attempts = (rows.first['attempts'] as int? ?? 0) + 1;

    if (attempts >= maxAttempts) {
      await db.update(
        table,
        {'status': 'failed', 'attempts': attempts, 'last_error': error},
        where: 'id = ?',
        whereArgs: [id],
      );
      return;
    }

    // backoff أُسّي: 2، 4، 8، 16 ثانية... (1 << attempts = 2^attempts)
    final delaySeconds = 1 << attempts;
    final nextRetry = DateTime.now().add(Duration(seconds: delaySeconds)).toIso8601String();

    await db.update(
      table,
      {
        'status': 'pending', // إعادة الحالة إلى pending لإعادة المحاولة لاحقاً
        'attempts': attempts,
        'last_error': error,
        'next_retry_at': nextRetry,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// تنظيف السجلات الفاشلة القديمة (أقدم من 30 يوماً) لمنع تضخّم الجدول.
  Future<void> purgeOldEntries() async {
    final db = await _db;
    final cutoff = DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    await db.delete(table, where: "status = 'failed' AND created_at < ?", whereArgs: [cutoff]);
  }
}
