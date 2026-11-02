import '../routes/app_routes.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../models/notification_model.dart';
import 'api/api_client.dart';
import 'notification_service.dart';
import '../controllers/dashboard_controller.dart';
import '../views/factory_reports_compliance_view.dart';
import 'user_session_service.dart';

/// عميل الإشعارات اللحظية عبر WebSocket
/// يتصل بالخادم ويستقبل التنبيهات المنبثقة فور رفع أو اعتماد أي تقرير
class RealtimeNotificationClient extends GetxService {
  static RealtimeNotificationClient get to => Get.find<RealtimeNotificationClient>();

  WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _isDisposed = false;
  final RxBool isConnected = false.obs;

  @override
  void onInit() {
    super.onInit();
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    if (session != null && session.isLoggedIn.value) {
      connect();
    }
  }

  @override
  void onClose() {
    _isDisposed = true;
    _cleanup();
    super.onClose();
  }

  void _cleanup() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
    isConnected.value = false;
  }

  void disconnect() {
    _cleanup();
  }

  /// إعادة الاتصال بالدور الجديد عند تبديل المستخدم أو الدور
  void refreshConnection() {
    _cleanup();
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    if (session != null && session.isLoggedIn.value) {
      connect();
    }
  }

  Future<void> connect() async {
    if (_isDisposed) return;
    final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
    if (session == null || !session.isLoggedIn.value) {
      debugPrint('[RealtimeNotifications] Skipped connection: user is not logged in.');
      return;
    }
    if (_socket != null && _socket!.readyState == WebSocket.open) return;

    try {
      if (!Get.isRegistered<ApiClient>()) return;

      String base = ApiClient.to.baseUrl;
      if (base.endsWith('/api')) {
        base = base.substring(0, base.length - 4);
      }
      while (base.endsWith('/')) {
        base = base.substring(0, base.length - 1);
      }
      if (base.startsWith('https://')) {
        base = 'wss://${base.substring(8)}';
      } else if (base.startsWith('http://')) {
        base = 'ws://${base.substring(7)}';
      } else if (!base.startsWith('ws://') && !base.startsWith('wss://')) {
        base = 'ws://$base';
      }

      final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
      final role = session?.roleKey ?? 'All';
      final branchId = session?.assignedBranchId ?? 0;
      final username = session?.currentUserName.value ?? '';

      final wsUri = Uri.parse('$base/ws/notifications').replace(queryParameters: {
        'role': role,
        'branchId': branchId.toString(),
        'username': username,
      });

      debugPrint('[RealtimeNotifications] Connecting to $wsUri ...');
      _socket = await WebSocket.connect(wsUri.toString()).timeout(const Duration(seconds: 10));
      isConnected.value = true;
      debugPrint('[RealtimeNotifications] Connected successfully to Realtime Notification Hub!');

      _socket!.listen(
        (data) {
          _handleMessage(data);
        },
        onError: (err) {
          debugPrint('[RealtimeNotifications] WebSocket error: $err');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[RealtimeNotifications] WebSocket closed by server.');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      // Keepalive ping كل 25 ثانية
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
        if (_socket != null && _socket!.readyState == WebSocket.open) {
          try {
            _socket!.add(jsonEncode({'type': 'PING'}));
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('[RealtimeNotifications] Connection failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    isConnected.value = false;
    _pingTimer?.cancel();
    _socket = null;
    if (_isDisposed) return;
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (!_isDisposed) {
        final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
        if (session != null && session.isLoggedIn.value) {
          connect();
        }
      }
    });
  }

  void _handleMessage(dynamic data) {
    try {
      final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
      if (session == null || !session.isLoggedIn.value || Get.currentRoute == AppRoutes.login) {
        return;
      }
      final jsonMap = jsonDecode(data.toString()) as Map<String, dynamic>;
      final type = jsonMap['type']?.toString();
      if (type == 'NEW_NOTIFICATION') {
        final rawNotif = jsonMap['data'] as Map<String, dynamic>;
        final notif = AppNotification.fromJson(rawNotif);
        if (Get.isRegistered<NotificationService>()) {
          NotificationService.to.handleIncomingRealtimeNotification(notif);
        }

        // تحديث لحظي للداش بورد وشاشة التزام المصانع بالبيانات الجديدة تلقائياً
        if (Get.isRegistered<DashboardController>()) {
          Get.find<DashboardController>().loadStats(silent: true);
        }
        if (Get.isRegistered<FactoryReportsComplianceController>()) {
          Get.find<FactoryReportsComplianceController>().loadReportData();
        }
      }
    } catch (e) {
      debugPrint('[RealtimeNotifications] Error handling message: $e');
    }
  }
}
