import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:get/get.dart';
import 'api/auth_api_service.dart';
import 'database_helper.dart';
import 'user_database_service.dart';
import 'user_session_service.dart';

/// خدمة إدارة وتوليد التوقيعات المرئية المعتمدة
/// تتيح تخزين التوقيعات، وتوليد توقيعات تجريبية/افتراضية عالية الدقة بخلفية شفافة،
/// وتجميد لقطات التوقيع وقت الاعتماد مع بصمة SHA-256 لمنع التلاعب
class UserSignatureService {
  static final UserSignatureService instance = UserSignatureService._init();
  UserSignatureService._init();

  final Map<Object, Uint8List> _signatureCache = {};
  final Set<int> _syncedUsersInSession = {};

  /// مسح الذاكرة المؤقتة للتواقيع لفرض جلب أحدث التواقيع المحدثة من قاعدة البيانات
  void clearCache() {
    _signatureCache.clear();
    _syncedUsersInSession.clear();
  }

  /// توليد بصمة SHA-256 من مصفوفة بايتات
  String computeHash(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// توليد بصمة للتقرير وبياناته لحظة الاعتماد (Tamper-evidence Document Hash)
  String computeDocumentHash({
    required int recordId,
    required String? reportName,
    required Map<String, dynamic>? dataJson,
    required String actionAt,
    String? actionType,
    String? actionBy,
    int? actorUserId,
  }) {
    final payload = jsonEncode({
      'record_id': recordId,
      'report_name': reportName,
      'data_snapshot': dataJson,
      'action_at': actionAt,
      if (actionType != null) 'action_type': actionType,
      if (actionBy != null) 'action_by': actionBy,
      if (actorUserId != null) 'actor_user_id': actorUserId,
    });
    return sha256.convert(utf8.encode(payload)).toString();
  }

  /// توليد توقيع افتراضي رسمي معتمد بخلفية شفافة وانسيابية تامة
  Future<Uint8List> generateDefaultTransparentSignature({
    required String signerName,
    required String signerPosition,
    double width = 360,
    double height = 140,
    Color inkColor = const Color(0xFF003853),
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    final cleanName = signerName
        .replaceAll('(منفذ الفحص)', '')
        .replaceAll('(مدير الجودة)', '')
        .replaceAll('(مدير المصنع)', '')
        .replaceAll('(المفتش)', '')
        .trim();

    // خلفية شفافة تماماً بدون رسم أي لون أرضي (Transparent Background)
    final path = Path();
    final randomSeed = (cleanName.isNotEmpty ? cleanName.codeUnits.reduce((a, b) => a + b) : 42);

    final linePaint = Paint()
      ..color = inkColor.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // خطوط التوقيع اليدوي الحركية (Handwritten Spline Simulation)
    final startY = height * 0.52;
    path.moveTo(width * 0.12, startY);

    for (int i = 1; i <= 6; i++) {
      final t = i / 6.0;
      final x = width * (0.12 + t * 0.62);
      final yOffset = ((randomSeed * (i * 13 + 7)) % 40) - 20.0;
      final cpX = x - width * 0.05;
      final cpY = startY + yOffset * 1.5;
      path.quadraticBezierTo(cpX, cpY, x, startY + yOffset * 0.6);
    }

    // لفة توقيع منحنية إضافية تمنح التوقيع طابعاً رسمياً
    path.cubicTo(
      width * 0.78,
      height * 0.20,
      width * 0.85,
      height * 0.82,
      width * 0.62,
      height * 0.72,
    );
    path.quadraticBezierTo(width * 0.40, height * 0.65, width * 0.88, height * 0.68);

    canvas.drawPath(path, linePaint);

    // خط أفقي تحتي مائل خفيف تحت التوقيع
    final underlinePaint = Paint()
      ..color = inkColor.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    final underlinePath = Path();
    underlinePath.moveTo(width * 0.10, height * 0.75);
    underlinePath.quadraticBezierTo(width * 0.50, height * 0.79, width * 0.85, height * 0.74);
    canvas.drawPath(underlinePath, underlinePaint);

    // كتابة الاسم والمسمى بخط ناعم أنيق أسفل التوقيع
    final textPainter = TextPainter(
      text: TextSpan(
        text: cleanName,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: inkColor.withValues(alpha: 0.90),
        ),
      ),
      textDirection: TextDirection.rtl,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(width * 0.5 - textPainter.width / 2, height * 0.68));

    final picture = recorder.endRecording();
    final img = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// استرجاع توقيع المستخدم من قاعدة البيانات أو توليد توقيع افتراضي معتمد
  /// يدعم تمرير userId أو البحث التلقائي باسم المستخدم / منفذ الفحص / دوره الوظيفي
  Future<Uint8List> getSignatureBytesForUser({
    int? userId,
    required String userName,
    String userPosition = 'أخصائي الجودة / منفذ الفحص',
    bool forceRefresh = false,
  }) async {
    final cleanName = userName
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
    String effectiveName = cleanName.isNotEmpty ? cleanName : userName.trim();

    // تجريد الألقاب والبادئات لضمان مطابقة الاسم الفعلي في قاعدة البيانات
    final strippedOfTitles = effectiveName
        .replaceAll(RegExp(r'^(دكتور|د\.?|أستاذ|أ\.?|مهندس|م\.?|المهندس|الدكتور|الأستاذ)\s+', caseSensitive: false), '')
        .trim();

    const usernameMap = {
      'basheer_fs': 'م. بشير القدسي',
      'salah': 'م. صلاح الجابري',
      'osama': 'م. أسامة الشجاع',
      'mohammed_r': 'م. محمد الرجامي',
      'amjad_fs': 'م. أمجد الخدشي',
      'ali': 'علي محمد',
      'sam': 'د/سام',
      'mohm': 'محمد احمد',
      'qm': 'أ. حمود يسر',
      'nabil': 'نبيل مراد',
      'gm2': 'أ. محمد الحاج',
      'gm': 'د. خالد العمري',
      'gmanager': 'أ. مازن الجلال',
      'admin': 'مسؤول النظام (المدير التقني)',
    };
    if (usernameMap.containsKey(effectiveName.toLowerCase())) {
      effectiveName = usernameMap[effectiveName.toLowerCase()]!;
    } else if (usernameMap.containsKey(strippedOfTitles.toLowerCase())) {
      effectiveName = usernameMap[strippedOfTitles.toLowerCase()]!;
    }

    // التحقق مما إذا كان الاسم مجرد مسمى وظيفي عام وليس اسماً شخصياً
    final isGenericRole = effectiveName == 'مدير الجودة' ||
        effectiveName == 'مدير المصنع' ||
        effectiveName == 'مشرف الجودة' ||
        effectiveName == 'مفتش الجودة' ||
        effectiveName == 'أخصائي الجودة' ||
        effectiveName == 'منفذ الفحص';

    if (!forceRefresh) {
      if (userId != null && userId > 0 && _signatureCache.containsKey(userId)) {
        return _signatureCache[userId]!;
      }
      if (!isGenericRole && effectiveName.isNotEmpty && _signatureCache.containsKey(effectiveName)) {
        return _signatureCache[effectiveName]!;
      }
    }

    int? effectiveUserId = (userId != null && userId > 0) ? userId : null;

    try {
      final db = await DatabaseHelper.instance.database;

      // إذا لم يتم تمرير معرف المستخدم، نبحث عنه بذكاء في الجلسة وجدول المستخدمين
      if (effectiveUserId == null && effectiveName.isNotEmpty) {
        // 1. فحص المستخدم الحالي النشط في الجلسة أولاً
        try {
          if (Get.isRegistered<UserSessionService>()) {
            final sessionUser = UserSessionService.to.currentUser.value;
            if (sessionUser != null && sessionUser.id != null && sessionUser.id! > 0) {
              final sFullName = sessionUser.fullName.trim();
              final sUsername = sessionUser.username.trim();
              if (sFullName == effectiveName ||
                  sFullName == strippedOfTitles ||
                  sUsername.toLowerCase() == effectiveName.toLowerCase() ||
                  sUsername.toLowerCase() == strippedOfTitles.toLowerCase() ||
                  sFullName.contains(strippedOfTitles) ||
                  strippedOfTitles.contains(sFullName)) {
                effectiveUserId = sessionUser.id;
              }
            }
          }
        } catch (_) {}

        // 2. البحث بالاسم الكامل (مع اللقب أو مجرداً) أو اسم المستخدم في جدول Users
        if (effectiveUserId == null) {
          final userRows = await db.query(
            'Users',
            columns: ['id', 'full_name', 'job_title', 'role'],
            where: 'full_name LIKE ? OR full_name LIKE ? OR username = ? OR username = ?',
            whereArgs: ['%$effectiveName%', '%$strippedOfTitles%', effectiveName, strippedOfTitles],
            limit: 1,
          );
          if (userRows.isNotEmpty) {
            effectiveUserId = userRows.first['id'] as int?;
            final dbFullName = userRows.first['full_name'] as String?;
            if (dbFullName != null && dbFullName.trim().isNotEmpty) {
              effectiveName = dbFullName.trim();
            }
          }
        }

        // 3. مطابقة الأدوار الوظيفية العامة (مثل "مفتش الجودة" أو "مدير الجودة" أو "مدير المصنع")
        if (effectiveUserId == null) {
          final textToSearch = '$userName $userPosition $cleanName';
          String? targetRole;
          if (textToSearch.contains('مفتش') ||
              textToSearch.contains('أخصائي') ||
              textToSearch.contains('منفذ') ||
              textToSearch.contains('فاحص')) {
            targetRole = 'qualityspecialist';
          } else if (textToSearch.contains('مدير الجودة')) {
            targetRole = 'qualitymanager';
          } else if (textToSearch.contains('مدير المصنع') || textToSearch.contains('مدير مصنع')) {
            targetRole = 'factorymanager';
          }

          if (targetRole != null) {
            // نفضل أولاً المستخدم الذي يملك توقيعاً مخصصاً محفوظاً ونشطاً في user_signatures
            final rawSql = '''
              SELECT u.id 
              FROM Users u
              LEFT JOIN user_signatures s ON u.id = s.user_id AND s.is_active = 1
              WHERE (LOWER(u.role) = ? OR LOWER(u.role) LIKE ? OR u.job_title LIKE ?) AND u.is_active = 1
              ORDER BY (CASE WHEN s.id IS NOT NULL THEN 0 ELSE 1 END), u.id ASC
              LIMIT 1
            ''';
            final roleRows = await db.rawQuery(rawSql, [targetRole, '%$targetRole%', '%$cleanName%']);
            if (roleRows.isNotEmpty) {
              effectiveUserId = roleRows.first['id'] as int?;
            }
          }
        }
      }

      // البحث عن التوقيع المخصص (محلياً أولاً، ثم من السيرفر ليتزامن عبر الأجهزة)
      if (effectiveUserId != null) {
        final customBytes = await getCustomUserSignatureBytes(effectiveUserId);
        if (customBytes != null) {
          _signatureCache[effectiveUserId] = customBytes;
          if (!isGenericRole && effectiveName.isNotEmpty) _signatureCache[effectiveName] = customBytes;
          return customBytes;
        }
      }
    } catch (e) {
      debugPrint('Error loading signature from DB: $e');
    }

    // إذا لم يسبق للمستخدم حفظ توقيع يدوي، نولد له توقيعاً انسيابياً شفافاً رسمياً
    final generated = await generateDefaultTransparentSignature(
      signerName: effectiveName,
      signerPosition: userPosition,
    );
    if (effectiveUserId != null) {
      _signatureCache[effectiveUserId] = generated;
    }
    if (!isGenericRole && effectiveName.isNotEmpty) {
      _signatureCache[effectiveName] = generated;
    }
    return generated;
  }

  /// حفظ أو تحديث توقيع يدوي لمستخدم
  ///
  /// يُحفظ التوقيع محلياً (SQLite) ثم يُرفع إلى السيرفر (SQL Server) ليظهر
  /// على جميع الأجهزة. يُرجِع `true` عند نجاح المزامنة مع السيرفر، و`false`
  /// إذا حُفظ محلياً فقط (السيرفر غير متاح).
  /// ملاحظة: التوقيع يُدخله المستخدم لنفسه فقط من شاشة الإعدادات.
  Future<bool> saveUserSignature({
    required int userId,
    required Uint8List pngBytes,
    String signatureType = 'drawn_png',
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final base64Str = base64Encode(pngBytes);
    final hash = computeHash(pngBytes);

    // إلغاء تفعيل أي توقيعات قديمة للمستخدم
    await db.update(
      'user_signatures',
      {'is_active': 0, 'updated_at': now},
      where: 'user_id = ?',
      whereArgs: [userId],
    );

    // ضمان وجود صف للمستخدم في الجدول المحلي Users قبل الإدراج، لتفادي خرق قيد
    // المفتاح الأجنبي (FOREIGN KEY) في حال عدم مزامنة المستخدم محلياً بعد
    await _ensureLocalUserRow(userId);

    // إدراج التوقيع الجديد
    await db.insert('user_signatures', {
      'user_id': userId,
      'signature_type': signatureType,
      'signature_data': base64Str,
      'signature_hash': hash,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    // مسح الذاكرة المؤقتة بالكامل لضمان تحديث التوقيع الجديد فوراً في كافة الواجهات والتقارير
    _signatureCache.clear();
    _signatureCache[userId] = pngBytes;

    final savedRows = await db.query(
      'user_signatures',
      columns: ['id'],
      where: 'user_id = ? AND is_active = 1',
      whereArgs: [userId],
      orderBy: 'id DESC',
      limit: 1,
    );
    if (savedRows.isEmpty) {
      throw Exception('Signature was not stored for user id $userId');
    }

    // مزامنة التوقيع مع السيرفر (SQL Server) ليظهر على جميع الأجهزة.
    // endpoint التوقيع يعمل مع المستخدم المسجّل دخوله حالياً فقط، لذلك يُرفع
    // التوقيع حصراً عند مطابقته للمستخدم الحالي (إدخال التوقيع من الإعدادات).
    return await _uploadSignatureToServer(
      userId: userId,
      base64Str: base64Str,
      signatureType: signatureType,
    );
  }

  /// التأكد من وجود صف للمستخدم في الجدول المحلي Users قبل كتابة أي سجل مرتبط به،
  /// لمنع خرق قيد المفتاح الأجنبي (FOREIGN KEY) عند تأخر مزامنة المستخدم محلياً.
  Future<void> _ensureLocalUserRow(int userId) async {
    try {
      final sessionUser = UserSessionService.to.currentUser.value;
      if (sessionUser != null && sessionUser.id == userId) {
        await UserDatabaseService.instance.upsertServerUser(sessionUser);
        return;
      }
      await UserDatabaseService.instance.ensurePlaceholderUser(userId);
    } catch (e) {
      debugPrint('Error ensuring local user row for signature: $e');
    }
  }

  /// رفع توقيع المستخدم الحالي إلى السيرفر وإرجاع نتيجة المزامنة (يدعم طابور المزامنة أوفلاين)
  Future<bool> _uploadSignatureToServer({
    required int userId,
    required String base64Str,
    required String signatureType,
  }) async {
    try {
      if (!Get.isRegistered<AuthApiService>() || !Get.isRegistered<UserSessionService>()) {
        return false;
      }
      final sessionUserId = UserSessionService.to.currentUser.value?.id;
      if (sessionUserId == null || sessionUserId <= 0 || sessionUserId != userId) {
        // التوقيع لمستخدم آخر — غير مسموح برفعه (قاصر على المستخدم نفسه)
        return false;
      }
      return await AuthApiService.to.saveSignature(
        base64Str,
        signatureType: signatureType,
        signatureHash: computeHash(base64Decode(base64Str.contains(',') ? base64Str.split(',').last : base64Str)),
        userId: userId,
      );
    } catch (e) {
      debugPrint('Failed to upload signature to server: $e');
      return false;
    }
  }

  /// مزامنة توقيع المستخدم من السيرفر وحفظه في SQLite والذاكرة المؤقتة
  Future<void> syncUserSignatureFromServer(int userId) async {
    try {
      if (userId <= 0 || !Get.isRegistered<AuthApiService>()) return;
      final sigData = await AuthApiService.to.getUserSignature(userId);
      if (sigData != null && sigData.isNotEmpty) {
        final clean = sigData.contains(',') ? sigData.split(',').last : sigData;
        final bytes = base64Decode(clean);
        final hash = computeHash(bytes);
        final db = await DatabaseHelper.instance.database;
        final now = DateTime.now().toIso8601String();

        await _ensureLocalUserRow(userId);

        final existing = await db.query(
          'user_signatures',
          columns: ['id'],
          where: 'user_id = ? AND is_active = 1',
          whereArgs: [userId],
          limit: 1,
        );

        if (existing.isEmpty) {
          await db.insert('user_signatures', {
            'user_id': userId,
            'signature_type': 'drawn_png',
            'signature_data': clean,
            'signature_hash': hash,
            'is_active': 1,
            'created_at': now,
            'updated_at': now,
          });
        } else {
          await db.update(
            'user_signatures',
            {
              'signature_data': clean,
              'signature_hash': hash,
              'is_active': 1,
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [existing.first['id']],
          );
        }

        _signatureCache[userId] = bytes;
      }
    } catch (e) {
      debugPrint('Error syncing user signature from server: $e');
    }
  }

  /// جلب التوقيع المخصص المحفوظ للمستخدم فقط إن وُجد (دون توليد افتراضي)
  ///
  /// للمستخدمين الآخرين: يتحقق من السيرفر أولاً مرة واحدة في الجلسة لضمان جلب أحدث
  /// توقيع محدّث عبر الأجهزة، ثم يحدّث SQLite المحلي، ويعود إلى SQLite المحلي عند انقطاع الاتصال.
  Future<Uint8List?> getCustomUserSignatureBytes(int userId) async {
    if (_signatureCache.containsKey(userId)) {
      return _signatureCache[userId];
    }

    final sessionUserId = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to.currentUser.value?.id
        : null;
    final bool isOtherUserUnsynced = sessionUserId != userId && !_syncedUsersInSession.contains(userId);

    // 1. إذا كان التوقيع لمستخدم آخر ولم يُزامَن في هذه الجلسة بعد، نتحقق من السيرفر أولاً لمنع الكاش القديم
    if (isOtherUserUnsynced && Get.isRegistered<AuthApiService>()) {
      try {
        final sigData = await AuthApiService.to.getUserSignature(userId);
        _syncedUsersInSession.add(userId);
        if (sigData != null && sigData.isNotEmpty) {
          final clean = sigData.contains(',') ? sigData.split(',').last : sigData;
          final bytes = base64Decode(clean);
          _signatureCache[userId] = bytes;
          await _cacheServerSignatureLocally(userId, clean, bytes);
          return bytes;
        }
      } catch (e) {
        debugPrint('Server signature check skipped (offline/error): $e');
      }
    }

    // 2. البحث في قاعدة البيانات المحلية SQLite
    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query(
        'user_signatures',
        where: 'user_id = ? AND is_active = 1',
        whereArgs: [userId],
        orderBy: 'id DESC',
        limit: 1,
      );

      if (rows.isNotEmpty) {
        final dataStr = rows.first['signature_data'] as String;
        final clean = dataStr.contains(',') ? dataStr.split(',').last : dataStr;
        final bytes = base64Decode(clean);
        _signatureCache[userId] = bytes;
        return bytes;
      }
    } catch (e) {
      debugPrint('Error loading custom signature from DB: $e');
    }

    // 3. إن لم يوجد التوقيع محلياً، يُطلَب من السيرفر (مزامنة تنازلية)
    if (!_syncedUsersInSession.contains(userId) && Get.isRegistered<AuthApiService>()) {
      try {
        final sigData = await AuthApiService.to.getUserSignature(userId);
        _syncedUsersInSession.add(userId);
        if (sigData != null && sigData.isNotEmpty) {
          final clean = sigData.contains(',') ? sigData.split(',').last : sigData;
          final bytes = base64Decode(clean);
          _signatureCache[userId] = bytes;
          await _cacheServerSignatureLocally(userId, clean, bytes);
          return bytes;
        }
      } catch (e) {
        debugPrint('Failed to fetch signature from server: $e');
      }
    }
    return null;
  }

  /// تحديث التوقيع المحفوظ في SQLite المحلي بنسخة السيرفر الحديثة
  Future<void> _cacheServerSignatureLocally(int userId, String cleanBase64, Uint8List bytes) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      final hash = computeHash(bytes);
      await _ensureLocalUserRow(userId);
      await db.update(
        'user_signatures',
        {'is_active': 0, 'updated_at': now},
        where: 'user_id = ?',
        whereArgs: [userId],
      );
      await db.insert('user_signatures', {
        'user_id': userId,
        'signature_type': 'drawn_png',
        'signature_data': cleanBase64,
        'signature_hash': hash,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      });
    } catch (e) {
      debugPrint('Error caching signature to local SQLite: $e');
    }
  }

  /// التحقق مما إذا كان المستخدم يملك توقيعاً مخصصاً محفوظاً
  Future<bool> hasCustomSignature(int userId) async {
    final bytes = await getCustomUserSignatureBytes(userId);
    return bytes != null;
  }

  /// حذف أو استعادة التوقيع الافتراضي للمستخدم
  Future<void> deleteUserSignature(int userId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().toIso8601String();
      await db.update(
        'user_signatures',
        {'is_active': 0, 'updated_at': now},
        where: 'user_id = ?',
        whereArgs: [userId],
      );

      // مزامنة الاستعادة مع السيرفر ليعود التوقيع الافتراضي على جميع الأجهزة (يدعم طابور المزامنة)
      try {
        if (Get.isRegistered<AuthApiService>() && Get.isRegistered<UserSessionService>()) {
          final sessionUserId = UserSessionService.to.currentUser.value?.id;
          if (sessionUserId != null && sessionUserId == userId) {
            await AuthApiService.to.deleteSignature(userId: userId);
          }
        }
      } catch (e) {
        debugPrint('Failed to delete signature from server: $e');
      }

      clearCache();
    } catch (e) {
      debugPrint('Error deleting user signature: $e');
    }
  }

  /// فحص وتحجيم أي صورة توقيع مرفوعة إلى أبعاد قياسية (أقصى 600×240) بصيغة PNG شفافة
  Future<Uint8List?> _normalizeSignaturePngBytes(Uint8List rawBytes) async {
    try {
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;

      const int maxWidth = 600;
      const int maxHeight = 240;

      if (srcImage.width <= maxWidth && srcImage.height <= maxHeight) {
        final byteData = await srcImage.toByteData(format: ui.ImageByteFormat.png);
        return byteData?.buffer.asUint8List() ?? rawBytes;
      }

      final double scaleX = maxWidth / srcImage.width;
      final double scaleY = maxHeight / srcImage.height;
      final double scale = scaleX < scaleY ? scaleX : scaleY;
      final int targetW = (srcImage.width * scale).round().clamp(1, maxWidth);
      final int targetH = (srcImage.height * scale).round().clamp(1, maxHeight);

      final resizedCodec = await ui.instantiateImageCodec(
        rawBytes,
        targetWidth: targetW,
        targetHeight: targetH,
      );
      final resizedFrame = await resizedCodec.getNextFrame();
      final byteData = await resizedFrame.image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List() ?? rawBytes;
    } catch (e) {
      debugPrint('Invalid or corrupt signature image file: $e');
      return null;
    }
  }

  /// رفع صورة توقيع بصيغة PNG من ملفات الجهاز (معزولة الخلفية)
  Future<Uint8List?> pickSignaturePngFromDevice() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? rawBytes;
        if (file.bytes != null) {
          rawBytes = file.bytes!;
        } else if (file.path != null) {
          rawBytes = await File(file.path!).readAsBytes();
        }
        if (rawBytes != null) {
          return await _normalizeSignaturePngBytes(rawBytes);
        }
      }
    } catch (e) {
      debugPrint('Error picking PNG signature via FilePicker: $e');
    }
    return null;
  }

  /// اختيار صورة التوقيع من معرض الصور بالجهاز
  Future<Uint8List?> pickSignatureImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 400,
      );
      if (picked != null) {
        final rawBytes = await picked.readAsBytes();
        return await _normalizeSignaturePngBytes(rawBytes);
      }
    } catch (e) {
      debugPrint('Error picking signature via ImagePicker: $e');
    }
    return null;
  }
}
