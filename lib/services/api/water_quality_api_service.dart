import 'package:get/get.dart';
import 'api_client.dart';

/// خدمة فحوصات وجودة المياه عبر API (Water Quality API Service)
class WaterQualityApiService extends GetxService {
  static WaterQualityApiService get to => Get.find<WaterQualityApiService>();

  final ApiClient _client = ApiClient.to;

  /// جلب سجلات فحص المياه مع الفلاتر
  Future<List<Map<String, dynamic>>> getLogs({
    int? branchId,
    String? category,
    String? fromDate,
    String? toDate,
  }) async {
    final response = await _client.get('/WaterQuality/logs', queryParams: {
      'branchId': branchId,
      'category': category,
      'fromDate': fromDate,
      'toDate': toDate,
    });

    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب تفاصيل تقرير فحص المياه مع نتائجه
  Future<Map<String, dynamic>?> getLogById(int id) async {
    final response = await _client.get('/WaterQuality/logs/$id');
    if (response.isSuccess && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// حفظ أو تحديث تقرير فحص المياه ونتائجه (يدعم العمل أوفلاين والمزامنة التلقائية)
  Future<int?> saveLog(Map<String, dynamic> log, List<Map<String, dynamic>> results) async {
    final body = {
      'log': log,
      'results': results,
    };
    final response = await _client.writeQueued(
      'POST',
      '/WaterQuality/logs',
      body: body,
      entityType: 'water_quality_log',
      entityId: log['id'] is int ? log['id'] as int : null,
    );

    if (response.isSuccess) {
      if (response.wasQueuedOffline) {
        return (log['id'] is int && (log['id'] as int) > 0) ? log['id'] as int : null;
      }
      if (response.data is int) return response.data as int;
      if (response.data is Map && response.data['id'] != null) {
        final idVal = response.data['id'];
        if (idVal is int) return idVal;
        if (idVal is String) return int.tryParse(idVal);
      }
      if (response.data is String) return int.tryParse(response.data.toString());
      return (log['id'] is int && (log['id'] as int) > 0) ? log['id'] as int : null;
    }
    return null;
  }

  /// تحديث حالة الاعتماد أو الرفض مع استرجاع كائن الاستجابة الكامل [ApiResponse]
  Future<ApiResponse> updateStatusWithResponse(
    int id,
    String status, {
    String? approvedBy,
    String? rejectionReason,
    String? rejectionCategory,
    String? severityLevel,
    String? rejectionNotes,
    String? affectedProducts,
    String? immediateAction,
    String? correctiveAction,
    String? correctiveOwner,
    String? correctiveDueDate,
    String? gmDecision,
    String? gmDecisionBy,
    String? gmDecisionNotes,
    String? microRejectionReason,
    String? microRejectedBy,
    String? microRejectionAction,
    int? rejectionCount,
  }) async {
    return await _client.writeQueued(
      'PUT',
      '/WaterQuality/logs/$id/status',
      body: {
        'status': status,
        'approvedBy': approvedBy,
        'rejectionReason': rejectionReason,
        if (rejectionCategory != null) 'rejectionCategory': rejectionCategory,
        if (severityLevel != null) 'severityLevel': severityLevel,
        if (rejectionNotes != null) 'rejectionNotes': rejectionNotes,
        if (affectedProducts != null) 'affectedProducts': affectedProducts,
        if (immediateAction != null) 'immediateAction': immediateAction,
        'correctiveAction': correctiveAction,
        'correctiveOwner': correctiveOwner,
        'correctiveDueDate': correctiveDueDate,
        'gmDecision': gmDecision,
        'gmDecisionBy': gmDecisionBy,
        'gmDecisionNotes': gmDecisionNotes,
        if (rejectionCount != null) 'rejectionCount': rejectionCount,
        if (microRejectionReason != null) 'microRejectionReason': microRejectionReason,
        if (microRejectedBy != null) 'microRejectedBy': microRejectedBy,
        if (microRejectionAction != null) 'microRejectionAction': microRejectionAction,
      },
      entityType: 'water_quality_status',
      entityId: id,
    );
  }

  /// تحديث حالة الاعتماد أو الرفض أو الإجراء التصحيحي (يدعم العمل أوفلاين والمزامنة التلقائية)
  Future<bool> updateStatus(
    int id,
    String status, {
    String? approvedBy,
    String? rejectionReason,
    String? rejectionCategory,
    String? severityLevel,
    String? rejectionNotes,
    String? affectedProducts,
    String? immediateAction,
    String? correctiveAction,
    String? correctiveOwner,
    String? correctiveDueDate,
    String? gmDecision,
    String? gmDecisionBy,
    String? gmDecisionNotes,
    String? microRejectionReason,
    String? microRejectedBy,
    String? microRejectionAction,
    int? rejectionCount,
  }) async {
    final response = await _client.writeQueued(
      'PUT',
      '/WaterQuality/logs/$id/status',
      body: {
        'status': status,
        'approvedBy': approvedBy,
        'rejectionReason': rejectionReason,
        if (rejectionCategory != null) 'rejectionCategory': rejectionCategory,
        if (severityLevel != null) 'severityLevel': severityLevel,
        if (rejectionNotes != null) 'rejectionNotes': rejectionNotes,
        if (affectedProducts != null) 'affectedProducts': affectedProducts,
        if (immediateAction != null) 'immediateAction': immediateAction,
        'correctiveAction': correctiveAction,
        'correctiveOwner': correctiveOwner,
        'correctiveDueDate': correctiveDueDate,
        'gmDecision': gmDecision,
        'gmDecisionBy': gmDecisionBy,
        'gmDecisionNotes': gmDecisionNotes,
        if (rejectionCount != null) 'rejectionCount': rejectionCount,
        if (microRejectionReason != null) 'microRejectionReason': microRejectionReason,
        if (microRejectedBy != null) 'microRejectedBy': microRejectedBy,
        if (microRejectionAction != null) 'microRejectionAction': microRejectionAction,
      },
      entityType: 'water_quality_status',
      entityId: id,
    );
    return response.isSuccess;
  }

  /// حفظ نتائج الفحص الميكروبيولوجي (يدعم طابور المزامنة دون اتصال)
  Future<bool> saveMicroResults(int id, List<Map<String, dynamic>> results, {String? enteredBy}) async {
    final response = await _client.writeQueued(
      'POST',
      '/WaterQuality/logs/$id/micro',
      body: {
        'enteredBy': enteredBy,
        'results': results,
      },
      entityType: 'water_quality_micro',
      entityId: id,
    );
    return response.isSuccess;
  }

  /// حذف تقرير فحص مياه (يدعم طابور المزامنة دون اتصال)
  Future<bool> deleteLog(int id) async {
    final response = await _client.writeQueued(
      'DELETE',
      '/WaterQuality/logs/$id',
      entityType: 'water_quality_log',
      entityId: id,
    );
    return response.isSuccess;
  }

  /// جلب التقارير اليومية الملخصة للمياه
  Future<List<Map<String, dynamic>>> getDailyReports() async {
    final response = await _client.get('/WaterQuality/daily-reports');
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// حفظ تقرير مياه يومي (يدعم طابور المزامنة دون اتصال)
  Future<bool> saveDailyReport(Map<String, dynamic> reportData) async {
    final response = await _client.writeQueued(
      'POST',
      '/WaterQuality/daily-reports',
      body: reportData,
      entityType: 'water_quality_daily_report',
    );
    return response.isSuccess;
  }
}
