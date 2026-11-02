import 'package:get/get.dart';
import 'api_client.dart';

/// خدمة فحص المواد الأولية عبر API (Raw Materials API Service)
class RawMaterialsApiService extends GetxService {
  static RawMaterialsApiService get to => Get.find<RawMaterialsApiService>();

  final ApiClient _client = ApiClient.to;

  /// جلب تقارير فحص المواد الأولية
  Future<List<Map<String, dynamic>>> getReports({int? branchId}) async {
    final response = await _client.get('/RawMaterials/reports', queryParams: {'branchId': branchId});
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب تفاصيل تقرير مادة أولية مع الفحص العام والتخصصي
  Future<Map<String, dynamic>?> getReportDetails(int id) async {
    final response = await _client.get('/RawMaterials/reports/$id');
    if (response.isSuccess && response.data is Map) {
      return Map<String, dynamic>.from(response.data);
    }
    return null;
  }

  /// تحديث حالة الاعتماد والرفض لتقرير المواد الأولية (يدعم الأوفلاين والمزامنة التلقائية)
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
    };
    final response = await _client.writeQueued(
      'PUT',
      '/RawMaterials/reports/$id/status',
      body: body,
      entityType: 'raw_material_status',
      entityId: id,
    );
    return response.isSuccess;
  }

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
      );

  /// حفظ أو رفع تقرير فحص مواد أولية (يدعم العمل أوفلاين والمزامنة التلقائية)
  Future<int?> saveReport(Map<String, dynamic> report, List<Map<String, dynamic>> items) async {
    final body = {
      'report': report,
      'items': items,
    };
    final response = await _client.writeQueued(
      'POST',
      '/RawMaterials/reports',
      body: body,
      entityType: 'raw_material_report',
      entityId: report['id'] is int ? report['id'] as int : null,
    );
    if (response.isSuccess) {
      if (response.wasQueuedOffline) {
        return (report['id'] is int && (report['id'] as int) > 0) ? report['id'] as int : null;
      }
      if (response.data is int) return response.data as int;
      if (response.data is Map && response.data['id'] != null) {
        final idVal = response.data['id'];
        if (idVal is int) return idVal;
        if (idVal is String) return int.tryParse(idVal);
      }
      if (response.data is String) return int.tryParse(response.data.toString());
      return (report['id'] is int && (report['id'] as int) > 0) ? report['id'] as int : null;
    }
    return null;
  }

  /// الاسم البديل المتوافق لـ saveReport
  Future<int?> saveTest(Map<String, dynamic> report, List<Map<String, dynamic>> items) =>
      saveReport(report, items);

  /// حذف تقرير فحص مواد أولية (يدعم طابور المزامنة دون اتصال)
  Future<bool> deleteReport(int id) async {
    final response = await _client.writeQueued(
      'DELETE',
      '/RawMaterials/reports/$id',
      entityType: 'raw_material_report',
      entityId: id,
    );
    return response.isSuccess;
  }
}
