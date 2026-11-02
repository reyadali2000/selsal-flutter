import 'package:get/get.dart';
import 'api_client.dart';

/// خدمة الإشعارات السحابية عبر API (Notifications API Service)
class NotificationsApiService extends GetxService {
  static NotificationsApiService get to => Get.find<NotificationsApiService>();

  final ApiClient _client = ApiClient.to;

  /// جلب الإشعارات
  Future<List<Map<String, dynamic>>> getNotifications({String? role, int? branchId}) async {
    final response = await _client.get('/Notifications', queryParams: {
      'targetRole': role,
      'role': role,
      'branchId': branchId,
    });
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب عدد الإشعارات غير المقروءة
  Future<int> getUnreadCount({String? role, int? branchId}) async {
    final response = await _client.get('/Notifications/unread-count', queryParams: {
      'targetRole': role,
      'role': role,
      'branchId': branchId,
    });
    if (response.isSuccess && response.data is num) {
      return (response.data as num).toInt();
    }
    return 0;
  }

  /// إنشاء إشعار جديد (يدعم طابور المزامنة دون اتصال)
  Future<int?> createNotification({
    required String title,
    required String body,
    int? reportId,
    String? reportCategory,
    String? targetRole,
    int? branchId,
  }) async {
    final payload = {
      'title': title,
      'body': body,
      'reportId': reportId,
      'reportCategory': reportCategory,
      'targetRole': targetRole,
      'branchId': branchId,
    };
    final response = await _client.writeQueued(
      'POST',
      '/Notifications',
      body: payload,
      entityType: 'notification',
      entityId: reportId,
    );
    if (response.isSuccess && response.data is num) {
      return (response.data as num).toInt();
    }
    return null;
  }

  /// تمييز الإشعار كمقروء (يدعم طابور المزامنة دون اتصال)
  Future<bool> markAsRead(int id) async {
    final response = await _client.writeQueued(
      'PUT',
      '/Notifications/$id/read',
      entityType: 'notification_read',
      entityId: id,
    );
    return response.isSuccess;
  }

  /// تمييز كافة الإشعارات كمقروءة (يدعم طابور المزامنة دون اتصال)
  Future<bool> markAllAsRead({String? role, int? branchId}) async {
    final queryParams = <String>[];
    if (role != null && role.isNotEmpty) {
      queryParams.add('targetRole=${Uri.encodeComponent(role)}');
      queryParams.add('role=${Uri.encodeComponent(role)}');
    }
    if (branchId != null) {
      queryParams.add('branchId=$branchId');
    }
    final queryString = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';
    final response = await _client.writeQueued(
      'PUT',
      '/Notifications/read-all$queryString',
      entityType: 'notification_read_all',
    );
    return response.isSuccess;
  }

  /// حذف إشعار (يدعم طابور المزامنة دون اتصال)
  Future<bool> deleteNotification(int id) async {
    final response = await _client.writeQueued(
      'DELETE',
      '/Notifications/$id',
      entityType: 'notification',
      entityId: id,
    );
    return response.isSuccess;
  }
}
