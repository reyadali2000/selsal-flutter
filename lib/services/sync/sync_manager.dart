import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../dashboard_sync_service.dart';
import 'sync_queue.dart';

/// مدير المزامنة المركزي (Sync Manager)
///
/// يوفّر طبقة "المزامنة اللحظية" بين التطبيق وخادم الـ API (الذي يتصل
/// بـ SQL Server) عبر ثلاث مسؤوليات:
///
/// 1. **مراقبة الاتصال**: تتبّع حالة الشبكة (online/offline) بشكل تفاعلي.
/// 2. **التحديث الدوري للقراءة (polling)**: يستدعي دورياً دوال التحديث
///    المسجّلة من الشاشات النشطة كل [pollInterval] — مما يجعل الواجهة
///    تتحدث فوراً عند تغيّر البيانات على السيرفر (المزامنة اللحظية).
/// 3. **طرد طابور الكتابة (outbox)**: إعادة إرسال عمليات الكتابة
///    المعلّقة تلقائياً عند عودة الاتصال.
///
/// كما يدير العلامات المائية (watermarks) لكل وحدة لدعم المزامنة
/// التزايدية (delta sync) عند توفّرها لاحقاً في الـ API.
class SyncManager extends GetxService {
  bool _isFlushingOutbox = false;
  Timer? _connectivityDebounceTimer;
  static SyncManager get to => Get.find<SyncManager>();

  // ===== حالة تفاعلية للاستخدام في الواجهة =====
  final isOnline = true.obs;
  final isSyncing = false.obs;
  final pendingCount = 0.obs;
  final lastSyncAt = Rx<DateTime?>(null);

  /// فترة التحديث الدوري. يمكن جعلها قابلة للتعديل من الإعدادات لاحقاً.
  static const Duration pollInterval = Duration(seconds: 60);

  final Connectivity _connectivity = Connectivity();
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  /// دوال التحديث المسجّلة من الشاشات/الـ controllers.
  /// المفتاح معرّف فريد لكل شاشة (مثل 'dynamic_record_12').
  final Map<String, Future<void> Function()> _refreshers = {};
  bool _refreshInProgress = false;

  @override
  void onInit() {
    super.onInit();
    SyncQueue.instance.recoverStuckProcessing();
    _initConnectivity();
    _startPolling();
    _restoreLastSyncAt();
  }

  /// تسجيل دالة تحديث شاشة/وحدة لتُستدعى دورياً عند توفّر الاتصال.
  /// استخدم [unregisterRefresher] عند إغلاق الشاشة لتجنّب التسريبات.
  void registerRefresher(String key, Future<void> Function() refresher) {
    _refreshers[key] = refresher;
  }

  void unregisterRefresher(String key) {
    _refreshers.remove(key);
  }

  // ===== العلامات المائية (watermarks) للمزامنة التزايدية =====

  /// حفظ علامة زمنية لآخر مزامنة ناجحة لوحدة معينة (لدعم delta sync).
  Future<void> setModuleWatermark(String module, DateTime ts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_watermark_$module', ts.toIso8601String());
  }

  Future<DateTime?> getModuleWatermark(String module) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sync_watermark_$module');
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  // ===== مراقبة الاتصال =====

  Future<void> _initConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _applyConnectivity(result);
    } catch (e) {
      debugPrint('SyncManager: تعذّر قراءة حالة الاتصال الأولية: $e');
    }

    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) {
      final wasOnline = isOnline.value;
      _applyConnectivity(result);
      // عند عودة الاتصال فقط → طرد الطابور وتحديث كل شيء فوراً
      if (!wasOnline && isOnline.value) {
        onConnectivityRestored();
      }
    });
  }

  void _applyConnectivity(List<ConnectivityResult> result) {
    isOnline.value = result.any((r) => r != ConnectivityResult.none);
  }

  /// تُستدعى عند عودة الشبكة: تطرد طابور الكتابة ثم تحدّث الشاشات.
  /// تُستدعى عند عودة الشبكة: طرد الطابور وتحديث الشاشات مع Debounce لمنع التكرار
  void onConnectivityRestored() {
    _connectivityDebounceTimer?.cancel();
    _connectivityDebounceTimer = Timer(const Duration(milliseconds: 1500), () async {
      await flushOutbox();
      await refreshAll();
    });
  }

  // ===== التحديث الدوري (المزامنة اللحظية للقراءة) =====

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => _tick());
  }

  Future<void> _tick() async {
    if (!isOnline.value || _refreshInProgress) return;

    // 1) تحديث الشاشات النشطة
    await refreshAll();

    // 2) طرد طابور الكتابة إن وُجدت عمليات معلّقة فعلياً
    //    (نقرأ العدد من قاعدة البيانات لأن writeQueued قد يضيف
    //     عناصر دون تحديث العداد التفاعلي مباشرة)
    final actualPending = await SyncQueue.instance.pendingCount();
    if (actualPending > 0) {
      pendingCount.value = actualPending;
      await flushOutbox();
    }
  }

  /// يستدعي دوال التحديث المسجّلة بالتوازي مع عزل الأخطاء عن بعضها.
  Future<void> refreshAll() async {
    if (_refreshInProgress || _refreshers.isEmpty) return;

    _refreshInProgress = true;
    isSyncing.value = true;
    try {
      await Future.wait(
        _refreshers.values.map((fn) => fn().catchError((Object e) {
              debugPrint('SyncManager: خطأ أثناء التحديث الدوري: $e');
            })),
      );
      lastSyncAt.value = DateTime.now();
      await _persistLastSyncAt();
    } finally {
      isSyncing.value = false;
      _refreshInProgress = false;
    }
  }

  // ===== طرد طابور الكتابة (outbox flush) =====

  Future<void> flushOutbox() async {
    if (_isFlushingOutbox) return;
    _isFlushingOutbox = true;
    try {
      final pending = await SyncQueue.instance.claimPending(limit: 20);
      if (pending.isEmpty) {
        pendingCount.value = await SyncQueue.instance.pendingCount();
        return;
      }

      isSyncing.value = true;
      bool anySucceeded = false;
      for (final row in pending) {
        final id = row['id'] as int;
        final method = row['method'] as String;
        final endpoint = row['endpoint'] as String;
        final bodyJson = row['body_json'] as String?;

        dynamic body;
        if (bodyJson != null && bodyJson.isNotEmpty) {
          try {
            body = jsonDecode(bodyJson);
          } catch (_) {}
        }

        final response = await ApiClient.to.replay(method, endpoint, body: body);
        if (response.isSuccess) {
          anySucceeded = true;
          await SyncQueue.instance.markDone(id);
        } else {
          await SyncQueue.instance.markFailed(id, response.message);
        }
      }

      if (anySucceeded) {
        await DashboardSyncService.instance.syncAllDashboardData(force: true);
      }

      // تنظيف دوري لمنع تضخّم الجدول
      await SyncQueue.instance.purgeOldEntries();
    } catch (e) {
      debugPrint('SyncManager: خطأ أثناء طرد طابور المزامنة: $e');
    } finally {
      pendingCount.value = await SyncQueue.instance.pendingCount();
      isSyncing.value = false;
      _isFlushingOutbox = false;
    }
  }

  // ===== حفظ/استعادة وقت آخر مزامنة =====

  Future<void> _persistLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sync_last_sync_at', DateTime.now().toIso8601String());
  }

  Future<void> _restoreLastSyncAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('sync_last_sync_at');
    if (raw != null) lastSyncAt.value = DateTime.tryParse(raw);
  }

  @override
  void onClose() {
    _timer?.cancel();
    _connectivitySub?.cancel();
    _connectivityDebounceTimer?.cancel();
    super.onClose();
  }
}
