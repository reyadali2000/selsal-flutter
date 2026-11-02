import 'package:get/get.dart';
import 'api_client.dart';
import '../../models/user_model.dart';
import '../../models/role_model.dart';

/// خدمة المصادقة السحابية عبر API (Auth API Service)
class AuthApiService extends GetxService {
  static AuthApiService get to => Get.find<AuthApiService>();

  final ApiClient _client = ApiClient.to;

  /// تسجيل الدخول واستلام الـ JWT Token وبيانات المستخدم
  Future<AuthApiResult> login(String username, String password) async {
    final response = await _client.post('/Auth/login', body: {
      'username': username,
      'password': password,
    });

    if (!response.isSuccess) {
      return AuthApiResult(
        isSuccess: false,
        message: response.message,
      );
    }

    final raw = response.rawJson ?? {};
    final String? token = raw['token'] ?? (raw['data'] is Map ? raw['data']['token'] : null);
    final userMap = raw['user'] ?? (raw['data'] is Map ? raw['data']['user'] : null);
    final List<dynamic>? permsRaw = raw['permissions'] ?? (raw['data'] is Map ? raw['data']['permissions'] : null);

    final List<String> permissions = permsRaw?.map((e) => e.toString()).toList() ?? [];

    if (token != null) {
      await _client.setToken(token);
    }

    UserModel? user;
    if (userMap is Map<String, dynamic>) {
      user = UserModel.fromMap(userMap, permissions: permissions);
    }

    return AuthApiResult(
      isSuccess: true,
      message: response.message,
      token: token,
      user: user,
      permissions: permissions,
    );
  }

  /// جلب بيانات المستخدم النشط حالياً
  Future<UserModel?> getCurrentUser() async {
    final response = await _client.get('/Auth/me');
    if (response.isSuccess && response.data is Map<String, dynamic>) {
      return UserModel.fromMap(response.data);
    }
    return null;
  }

  /// تغيير كلمة المرور
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    final response = await _client.post('/Auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    return response.isSuccess;
  }

  /// جلب التوقيع الرقمي للمستخدم
  Future<String?> getSignature() async {
    final response = await _client.get('/Auth/signature');
    if (response.isSuccess && response.data is Map) {
      return response.data['signatureData']?.toString();
    }
    return null;
  }

  /// حفظ التوقيع الرقمي (يدعم طابور المزامنة التلقائية دون اتصال)
  Future<bool> saveSignature(
    String signatureData, {
    String signatureType = 'drawn_png',
    String? signatureHash,
    int? userId,
  }) async {
    final response = await _client.writeQueued(
      'POST',
      '/Auth/signature',
      body: {
        'userId': userId,
        'signatureData': signatureData,
        'signatureType': signatureType,
        if (signatureHash != null) 'signatureHash': signatureHash,
      },
      entityType: 'user_signature',
      entityId: userId,
    );
    return response.isSuccess;
  }

  /// جلب التوقيع الرقمي لمستخدم محدد (لمزامنة وعرض التوقيعات عبر مختلف الأجهزة)
  Future<String?> getUserSignature(int userId) async {
    final response = await _client.get('/Auth/users/$userId/signature');
    if (response.isSuccess && response.data is Map) {
      return response.data['signatureData']?.toString();
    }
    return null;
  }

  /// حذف التوقيع الرقمي للمستخدم الحالي (استعادة التوقيع الافتراضي للنظام - يدعم المزامنة)
  Future<bool> deleteSignature({int? userId}) async {
    final endpoint = (userId != null && userId > 0) ? '/Auth/signature?userId=$userId' : '/Auth/signature';
    final response = await _client.writeQueued(
      'DELETE',
      endpoint,
      entityType: 'user_signature',
      entityId: userId,
    );
    return response.isSuccess;
  }

  /// جلب جميع المستخدمين (لإدارة المستخدمين)
  Future<List<UserModel>> getAllUsers() async {
    final response = await _client.get('/Auth/users');
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((m) => UserModel.fromMap(m as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// حفظ أو إنشاء مستخدم جديد عبر السيرفر
  Future<bool> saveUser(Map<String, dynamic> userData) async {
    final response = await _client.post('/Auth/users', body: userData);
    return response.isSuccess;
  }

  /// تفعيل أو تعطيل حساب مستخدم
  Future<bool> toggleUserStatus(int userId, bool isActive) async {
    final response = await _client.put('/Auth/users/$userId/toggle-active', body: {'isActive': isActive});
    return response.isSuccess;
  }

  /// جلب جميع الأدوار المخصصة والصلاحيات
  Future<List<RoleModel>> getAllRoles() async {
    final response = await _client.get('/Auth/roles');
    if (response.isSuccess && response.data is List) {
      return (response.data as List).map((m) => RoleModel.fromMap(m as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// حفظ دور مخصص وصلاحياته
  Future<bool> saveRole(Map<String, dynamic> roleData) async {
    final response = await _client.post('/Auth/roles', body: roleData);
    return response.isSuccess;
  }

  /// حذف دور مخصص من السيرفر
  Future<bool> deleteRole(int roleId) async {
    final response = await _client.delete('/Auth/roles/$roleId');
    return response.isSuccess;
  }

  /// جلب صلاحيات دور معين مباشرة
  Future<List<String>> getPermissionsForRole(String roleKey) async {
    try {
      final roles = await getAllRoles();
      final cleanKey = roleKey.trim().toLowerCase();
      final normKey = cleanKey.replaceAll('_', '').replaceAll(' ', '');
      final target = roles.firstWhereOrNull((r) {
        final rCode = r.code.trim().toLowerCase();
        final rCodeNorm = rCode.replaceAll('_', '').replaceAll(' ', '');
        final rTitle = r.title.trim().toLowerCase();
        final rTitleNorm = rTitle.replaceAll('_', '').replaceAll(' ', '');
        return rCode == cleanKey || rTitle == cleanKey || rCodeNorm == normKey || rTitleNorm == normKey;
      });
      return target?.permissions ?? [];
    } catch (_) {
      return [];
    }
  }
}

/// نتيجة عملية المصادقة عبر API
class AuthApiResult {
  final bool isSuccess;
  final String message;
  final String? token;
  final UserModel? user;
  final List<String> permissions;

  AuthApiResult({
    required this.isSuccess,
    required this.message,
    this.token,
    this.user,
    this.permissions = const [],
  });
}
