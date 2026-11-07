import 'package:get/get.dart';
import 'api_client.dart';

/// خدمة النظافة والاشتراطات الصحية عبر API (Hygiene API Service)
class HygieneApiService extends GetxService {
  static HygieneApiService get to => Get.find<HygieneApiService>();

  final ApiClient _client = ApiClient.to;

  /// جلب تقارير النظافة
  Future<List<Map<String, dynamic>>> getReports({int? branchId}) async {
    final response = await _client.get('/Hygiene/reports', queryParams: {'branchId': branchId});
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب تفاصيل تقرير نظافة مع سجلات الفحص
  Future<Map<String, dynamic>?> getReportDetails(int id) async {
    final response = await _client.get('/Hygiene/reports/$id');
    if (response.isSuccess && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// تحديث حالة تقرير النظافة مع استرجاع كائن الاستجابة الكامل [ApiResponse]
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
    int? rejectionCount,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (rejectionCategory != null) 'rejectionCategory': rejectionCategory,
      if (severityLevel != null) 'severityLevel': severityLevel,
      if (rejectionNotes != null) 'rejectionNotes': rejectionNotes,
      if (affectedProducts != null) 'affectedProducts': affectedProducts,
      if (immediateAction != null) 'immediateAction': immediateAction,
      if (correctiveAction != null) 'correctiveAction': correctiveAction,
      if (correctiveOwner != null) 'correctiveOwner': correctiveOwner,
      if (correctiveDueDate != null) 'correctiveDueDate': correctiveDueDate,
      if (gmDecision != null) 'gmDecision': gmDecision,
      if (gmDecisionBy != null) 'gmDecisionBy': gmDecisionBy,
      if (gmDecisionNotes != null) 'gmDecisionNotes': gmDecisionNotes,
      if (rejectionCount != null) 'rejectionCount': rejectionCount,
    };
    return await _client.writeQueued(
      'PUT',
      '/Hygiene/reports/$id/status',
      body: body,
      entityType: 'hygiene_status',
      entityId: id,
    );
  }

  /// تحديث حالة تقرير النظافة (اعتماد / رفض - يدعم الأوفلاين والمزامنة التلقائية)
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
    int? rejectionCount,
  }) async {
    final body = <String, dynamic>{
      'status': status,
      if (approvedBy != null) 'approvedBy': approvedBy,
      if (rejectionReason != null) 'rejectionReason': rejectionReason,
      if (rejectionCategory != null) 'rejectionCategory': rejectionCategory,
      if (severityLevel != null) 'severityLevel': severityLevel,
      if (rejectionNotes != null) 'rejectionNotes': rejectionNotes,
      if (affectedProducts != null) 'affectedProducts': affectedProducts,
      if (immediateAction != null) 'immediateAction': immediateAction,
      if (correctiveAction != null) 'correctiveAction': correctiveAction,
      if (correctiveOwner != null) 'correctiveOwner': correctiveOwner,
      if (correctiveDueDate != null) 'correctiveDueDate': correctiveDueDate,
      if (gmDecision != null) 'gmDecision': gmDecision,
      if (gmDecisionBy != null) 'gmDecisionBy': gmDecisionBy,
      if (gmDecisionNotes != null) 'gmDecisionNotes': gmDecisionNotes,
      if (rejectionCount != null) 'rejectionCount': rejectionCount,
    };
    final response = await _client.writeQueued(
      'PUT',
      '/Hygiene/reports/$id/status',
      body: body,
      entityType: 'hygiene_status',
      entityId: id,
    );
    return response.isSuccess;
  }

  /// الاسم المتوافق لتحديث الاعتماد مع استرجاع ApiResponse
  Future<ApiResponse> updateApprovalWithResponse(
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
    int? rejectionCount,
  }) =>
      updateStatusWithResponse(
        id,
        status,
        approvedBy: approvedBy,
        rejectionReason: rejectionReason,
        rejectionCategory: rejectionCategory,
        severityLevel: severityLevel,
        rejectionNotes: rejectionNotes,
        affectedProducts: affectedProducts,
        immediateAction: immediateAction,
        correctiveAction: correctiveAction,
        correctiveOwner: correctiveOwner,
        correctiveDueDate: correctiveDueDate,
        gmDecision: gmDecision,
        gmDecisionBy: gmDecisionBy,
        gmDecisionNotes: gmDecisionNotes,
        rejectionCount: rejectionCount,
      );

  /// الاسم المتوافق لتحديث الاعتماد
  Future<bool> updateApproval(
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
    int? rejectionCount,
  }) =>
      updateStatus(
        id,
        status,
        approvedBy: approvedBy,
        rejectionReason: rejectionReason,
        rejectionCategory: rejectionCategory,
        severityLevel: severityLevel,
        rejectionNotes: rejectionNotes,
        affectedProducts: affectedProducts,
        immediateAction: immediateAction,
        correctiveAction: correctiveAction,
        correctiveOwner: correctiveOwner,
        correctiveDueDate: correctiveDueDate,
        gmDecision: gmDecision,
        gmDecisionBy: gmDecisionBy,
        gmDecisionNotes: gmDecisionNotes,
        rejectionCount: rejectionCount,
      );

  /// حذف تقرير النظافة (يدعم طابور المزامنة دون اتصال)
  Future<bool> deleteReport(int id) async {
    final response = await _client.writeQueued(
      'DELETE',
      '/Hygiene/reports/$id',
      entityType: 'hygiene_report',
      entityId: id,
    );
    return response.isSuccess;
  }

  /// جلب قوائم التدقيق والاشتراطات
  Future<List<Map<String, dynamic>>> getChecklists() async {
    final response = await _client.get('/Hygiene/checklists');
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// حفظ تقرير نظافة جديد (يدعم العمل أوفلاين والمزامنة التلقائية)
  Future<int?> saveReport(Map<String, dynamic> reportData) async {
    final response = await _client.writeQueued(
      'POST',
      '/Hygiene/reports',
      body: reportData,
      entityType: 'hygiene_report',
      entityId: reportData['id'] is int ? reportData['id'] as int : null,
    );
    if (response.isSuccess) {
      if (response.wasQueuedOffline) {
        return (reportData['id'] is int && (reportData['id'] as int) > 0) ? reportData['id'] as int : null;
      }
      if (response.data is int) return response.data as int;
      if (response.data is Map && response.data['id'] != null) {
        final idVal = response.data['id'];
        if (idVal is int) return idVal;
        if (idVal is String) return int.tryParse(idVal);
      }
      if (response.data is String) return int.tryParse(response.data.toString());
      return (reportData['id'] is int && (reportData['id'] as int) > 0) ? reportData['id'] as int : null;
    }
    return null;
  }
}
