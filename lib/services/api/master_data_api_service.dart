import 'package:get/get.dart';
import 'api_client.dart';

/// خدمة البيانات الأساسية (Master Data API Service)
class MasterDataApiService extends GetxService {
  static MasterDataApiService get to => Get.find<MasterDataApiService>();

  final ApiClient _client = ApiClient.to;

  /// جلب الفروع والمصانع
  Future<List<Map<String, dynamic>>> getBranches() async {
    final response = await _client.get('/MasterData/branches');
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب الورديات
  Future<List<Map<String, dynamic>>> getShifts({int? branchId}) async {
    final response = await _client.get('/MasterData/shifts', queryParams: {'branchId': branchId});
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// حفظ أو إضافة وردية جديدة (يدعم طابور المزامنة دون اتصال)
  Future<bool> saveShift(Map<String, dynamic> shift) async {
    final response = await _client.writeQueued(
      'POST',
      '/MasterData/shifts',
      body: shift,
      entityType: 'shift',
      entityId: shift['id'] is int ? shift['id'] as int : null,
    );
    return response.isSuccess;
  }

  /// تبديل حالة تفعيل وردية (يدعم طابور المزامنة دون اتصال)
  Future<bool> toggleShiftStatus(int shiftId, bool isActive) async {
    final response = await _client.writeQueued(
      'PUT',
      '/MasterData/shifts/$shiftId/toggle-active',
      body: {'isActive': isActive},
      entityType: 'shift_status',
      entityId: shiftId,
    );
    return response.isSuccess;
  }

  /// حذف وردية (يدعم طابور المزامنة دون اتصال)
  Future<bool> deleteShift(int shiftId) async {
    final response = await _client.writeQueued(
      'DELETE',
      '/MasterData/shifts/$shiftId',
      entityType: 'shift',
      entityId: shiftId,
    );
    return response.isSuccess;
  }

  /// جلب المنتجات والعبوات
  /// [includeInactive] = true لجلب العبوات غير النشطة أيضاً (تستخدمها شاشة الإدارة)
  Future<List<Map<String, dynamic>>> getProducts({int? branchId, bool includeInactive = false}) async {
    final response = await _client.get('/MasterData/products', queryParams: {
      'branchId': branchId,
      'includeInactive': includeInactive,
    });
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// حفظ أو إضافة عبوة جديدة (يدعم طابور المزامنة دون اتصال)
  Future<bool> saveProduct(Map<String, dynamic> product) async {
    final response = await _client.writeQueued(
      'POST',
      '/MasterData/products',
      body: product,
      entityType: 'product',
      entityId: product['id'] is int ? product['id'] as int : null,
    );
    return response.isSuccess;
  }

  /// تبديل حالة تفعيل عبوة (تفعيل/تعطيل) (يدعم طابور المزامنة دون اتصال)
  Future<bool> toggleProductStatus(int productId, bool isActive) async {
    final response = await _client.writeQueued(
      'PUT',
      '/MasterData/products/$productId/toggle-active',
      body: {'isActive': isActive},
      entityType: 'product_status',
      entityId: productId,
    );
    return response.isSuccess;
  }

  /// حذف عبوة نهائياً مع مواصفاتها القياسية المرتبطة بها (يدعم طابور المزامنة دون اتصال)
  Future<bool> deleteProduct(int productId) async {
    final response = await _client.writeQueued(
      'DELETE',
      '/MasterData/products/$productId',
      entityType: 'product',
      entityId: productId,
    );
    return response.isSuccess;
  }

  /// جلب عناصر ومعايير الفحص (Test Parameters)
  Future<List<Map<String, dynamic>>> getTestParameters() async {
    final response = await _client.get('/MasterData/test-parameters');
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب المواصفات القياسية للجودة
  Future<List<Map<String, dynamic>>> getQualityStandards({int? productId, String? waterType}) async {
    final response = await _client.get('/MasterData/quality-standards', queryParams: {
      'productId': productId,
      'waterType': waterType,
    });
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب الأقسام الإدارية
  Future<List<Map<String, dynamic>>> getDepartments({int? branchId}) async {
    final response = await _client.get('/MasterData/departments', queryParams: {'branchId': branchId});
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب المناصب والوظائف
  Future<List<Map<String, dynamic>>> getPositions({int? departmentId}) async {
    final response = await _client.get('/MasterData/positions', queryParams: {'departmentId': departmentId});
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// جلب العمالة اليومية
  Future<List<Map<String, dynamic>>> getDailyWorkers({int? branchId, bool includeInactive = false}) async {
    final response = await _client.get('/MasterData/daily-workers', queryParams: {
      'branchId': branchId,
      'includeInactive': includeInactive,
    });
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }

  /// حفظ أو إضافة عامل يومي جديد (يدعم طابور المزامنة دون اتصال)
  Future<bool> saveDailyWorker(Map<String, dynamic> worker) async {
    final response = await _client.writeQueued(
      'POST',
      '/MasterData/daily-workers',
      body: worker,
      entityType: 'daily_worker',
      entityId: worker['id'] is int ? worker['id'] as int : null,
    );
    return response.isSuccess;
  }

  /// تبديل حالة تفعيل عامل يومي (يدعم طابور المزامنة دون اتصال)
  Future<bool> toggleDailyWorkerStatus(int workerId, bool isActive) async {
    final response = await _client.writeQueued(
      'PUT',
      '/MasterData/daily-workers/$workerId/toggle-active',
      body: {'isActive': isActive},
      entityType: 'daily_worker_status',
      entityId: workerId,
    );
    return response.isSuccess;
  }

  /// حذف عامل يومي (يدعم طابور المزامنة دون اتصال)
  Future<bool> deleteDailyWorker(int workerId) async {
    final response = await _client.writeQueued(
      'DELETE',
      '/MasterData/daily-workers/$workerId',
      entityType: 'daily_worker',
      entityId: workerId,
    );
    return response.isSuccess;
  }

  /// جلب الموظفين الدائمين
  Future<List<Map<String, dynamic>>> getEmployees({int? branchId}) async {
    final response = await _client.get('/MasterData/employees', queryParams: {'branchId': branchId});
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((e) => Map<String, dynamic>.from(e)).toList();
    }
    return [];
  }
}
