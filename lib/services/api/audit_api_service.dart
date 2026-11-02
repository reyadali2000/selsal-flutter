import 'package:get/get.dart';
import 'api_client.dart';

/// خدمة سجل التدقيق والإشعارات والأرشيف عبر API (Audit & Notification API Service)
class AuditApiService extends GetxService {
  static AuditApiService get to => Get.find<AuditApiService>();

  final ApiClient _client = ApiClient.to;

  /// جلب سجل التدقيق والمراجعة
  Future<List<Map<String, dynamic>>> getAuditLogs({String? entityType, int? entityId}) async {
    final response = await _client.get('/Audit/logs', queryParams: {
      'entityType': entityType,
      'entityId': entityId,
    });
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب الإشعارات
  Future<List<Map<String, dynamic>>> getNotifications({String? targetRole, bool? isRead}) async {
    final response = await _client.get('/Audit/notifications', queryParams: {
      'targetRole': targetRole,
      'isRead': isRead,
    });
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// تحديد الإشعار كمقروء
  Future<bool> markNotificationRead(int id) async {
    final response = await _client.put('/Audit/notifications/$id/read');
    return response.isSuccess;
  }

  /// إنشاء إشعار جديد
  Future<bool> createNotification(Map<String, dynamic> notifData) async {
    final response = await _client.post('/Audit/notifications', body: notifData);
    return response.isSuccess;
  }

  /// جلب التقارير المؤرشفة
  Future<List<Map<String, dynamic>>> getArchivedReports({int? logId, String? logType}) async {
    final response = await _client.get('/Audit/archived-reports', queryParams: {
      'logId': logId,
      'logType': logType,
    });
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// أرشفة تقرير
  Future<bool> archiveReport(Map<String, dynamic> archiveData) async {
    final response = await _client.post('/Audit/archived-reports', body: archiveData);
    return response.isSuccess;
  }
}
