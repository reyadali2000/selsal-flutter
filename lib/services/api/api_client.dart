import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../sync/sync_queue.dart';

/// عميل الاتصال المركزي بالـ API (Central REST API Client)
/// يدير التوكن والعناوين والتحقق من الأخطاء لجميع طلبات الشبكة
class ApiClient extends GetxService {
  static ApiClient get to => Get.find<ApiClient>();




  late String _baseUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;

  @override
  Future<void> onInit() async {
    super.onInit();
    await _loadSettings();
  }

  /// تحميل الإعدادات والتوكن المحفوظ
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // الرابط الافتراضي للـ API (عبر شبكة الـ Wi-Fi المحلية للمصنع)
    const String defaultUrl = 'http://192.168.8.139:5000/api';
    var savedUrl = prefs.getString('api_base_url') ?? defaultUrl;
    _baseUrl = _normalizeApiUrl(savedUrl);
    _token = prefs.getString('jwt_token');
  }

  /// تنظيف الرابط والتأكد من إضافة /api مرة واحدة فقط في النهاية
  static String _normalizeApiUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    while (trimmed.endsWith('/api')) {
      trimmed = trimmed.substring(0, trimmed.length - 4);
      while (trimmed.endsWith('/')) {
        trimmed = trimmed.substring(0, trimmed.length - 1);
      }
    }
    return '$trimmed/api';
  }

  /// تحديث رابط السيرفر (مثلاً للربط عبر شبكة المصنع المحلية WiFi)
  Future<void> setBaseUrl(String newUrl) async {
    _baseUrl = _normalizeApiUrl(newUrl);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', _baseUrl);
  }

  /// حفظ التوكن في الذاكرة والجلسة
  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('jwt_token', token);
    } else {
      await prefs.remove('jwt_token');
    }
  }

  /// بناء ترويسات الطلب (Headers) متضمنة Bearer Token
  Map<String, String> _buildHeaders({Map<String, String>? extraHeaders}) {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Accept': 'application/json',
    };

    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// تنفيذ طلب GET
  Future<ApiResponse> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      var uri = Uri.parse('$_baseUrl$endpoint');
      if (queryParams != null && queryParams.isNotEmpty) {
        final stringParams = queryParams.map((k, v) => MapEntry(k, v?.toString() ?? ''));
        stringParams.removeWhere((k, v) => v.isEmpty);
        uri = uri.replace(queryParameters: stringParams);
      }

      final response = await http.get(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      return ApiResponse.error('تعذر الاتصال بخادم الـ API. تأكد من تشغيل السيرفر أو صحة الرابط.', isNetworkError: true);
    } on TimeoutException {
      return ApiResponse.error('انتهت مهلة الاتصال بالخادم. تحقق من اتصال الشبكة.', isNetworkError: true);
    } on http.ClientException catch (e) {
      return ApiResponse.error('خطأ في الاتصال بالشبكة: ${e.message}');
    } catch (e) {
      return ApiResponse.error('حدث خطأ غير متوقع: $e');
    }
  }

  /// تنفيذ طلب POST
  Future<ApiResponse> post(String endpoint, {dynamic body}) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final jsonBody = body != null ? jsonEncode(body) : null;
      final response = await http.post(uri, headers: _buildHeaders(), body: jsonBody).timeout(const Duration(seconds: 20));
      return _processResponse(response);
    } on SocketException {
      return ApiResponse.error('تعذر الاتصال بخادم الـ API. تأكد من تشغيل السيرفر.', isNetworkError: true);
    } on TimeoutException {
      return ApiResponse.error('انتهت مهلة الاتصال بالخادم. تحقق من اتصال الشبكة.', isNetworkError: true);
    } catch (e) {
      return ApiResponse.error('حدث خطأ أثناء إرسال البيانات: $e');
    }
  }

  /// تنفيذ طلب PUT
  Future<ApiResponse> put(String endpoint, {dynamic body, Map<String, dynamic>? queryParams}) async {
    try {
      final baseUri = Uri.parse('$_baseUrl$endpoint');
      final uri = queryParams != null && queryParams.isNotEmpty
          ? baseUri.replace(
              queryParameters: queryParams.map(
                (k, v) => MapEntry(k, v?.toString() ?? ''),
              )..removeWhere((k, v) => v.isEmpty),
            )
          : baseUri;
      final jsonBody = body != null ? jsonEncode(body) : null;
      final response = await http.put(uri, headers: _buildHeaders(), body: jsonBody).timeout(const Duration(seconds: 20));
      return _processResponse(response);
    } on SocketException {
      return ApiResponse.error('تعذر الاتصال بخادم الـ API.', isNetworkError: true);
    } on TimeoutException {
      return ApiResponse.error('انتهت مهلة الاتصال بالخادم. تحقق من اتصال الشبكة.', isNetworkError: true);
    } catch (e) {
      return ApiResponse.error('حدث خطأ أثناء التحديث: $e');
    }
  }

  /// تنفيذ طلب DELETE
  Future<ApiResponse> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$_baseUrl$endpoint');
      final response = await http.delete(uri, headers: _buildHeaders()).timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      return ApiResponse.error('تعذر الاتصال بخادم الـ API.', isNetworkError: true);
    } on TimeoutException {
      return ApiResponse.error('انتهت مهلة الاتصال بالخادم. تحقق من اتصال الشبكة.', isNetworkError: true);
    } catch (e) {
      return ApiResponse.error('حدث خطأ أثناء الحذف: $e');
    }
  }

  /// إعادة إرسال عملية محفوظة في طابور المزامنة (يستخدمها [SyncManager]).
  Future<ApiResponse> replay(String method, String endpoint, {dynamic body}) async {
    switch (method.toUpperCase()) {
      case 'POST':
        return await post(endpoint, body: body);
      case 'PUT':
        return await put(endpoint, body: body);
      case 'DELETE':
        return await delete(endpoint);
      default:
        return ApiResponse.error('HTTP method غير مدعوم في الطابور: $method');
    }
  }

  /// تنفيذ عملية كتابة مع تخزينها تلقائياً في طابور المزامنة (offline-first).
  ///
  /// عند نجاح العملية تُرجع استجابتها كما هي. وعند فشلها بسبب انقطاع
  /// الشبكة فقط (وليس خطأ منطق عمل من السيرفر) تُخزَّن في [SyncQueue]
  /// وتُرجع استجابة ناجحة مع رفع [ApiResponse.wasQueuedOffline] = true،
  /// كي تتابع الواجهة عملها بدل إظهار خطأ — وستُعاد العملية تلقائياً
  /// عند عودة الاتصال.
  Future<ApiResponse> writeQueued(
    String method,
    String endpoint, {
    dynamic body,
    String? entityType,
    int? entityId,
  }) async {
    final ApiResponse response = await replay(method, endpoint, body: body);

    if (response.isSuccess) return response;

    // فشل شبكي → خزّن في الطابور وعُد بنجاح "مؤجل"
    if (response.isNetworkError) {
      await SyncQueue.instance.enqueue(
        method: method,
        endpoint: endpoint,
        body: body,
        entityType: entityType,
        entityId: entityId,
      );
      return ApiResponse(
        statusCode: response.statusCode,
        isSuccess: true,
        message: 'تم الحفظ محلياً وسيتمت مزامنته تلقائياً عند عودة الاتصال',
        data: response.data,
        wasQueuedOffline: true,
      );
    }

    // خطأ من السيرفر (منطق عمل) → مرّره كما هو
    return response;
  }

  /// معالجة استجابة الـ HTTP وفك الترميز
  ApiResponse _processResponse(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      final bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;

      if (decoded is Map<String, dynamic>) {
        return ApiResponse(
          statusCode: response.statusCode,
          isSuccess: isSuccess && (decoded['success'] ?? true),
          message: decoded['message']?.toString() ?? (isSuccess ? 'تمت العملية بنجاح' : 'فشلت العملية'),
          data: decoded.containsKey('data') ? decoded['data'] : decoded,
          rawJson: decoded,
        );
      } else {
        return ApiResponse(
          statusCode: response.statusCode,
          isSuccess: isSuccess,
          message: isSuccess ? 'تمت العملية بنجاح' : 'فشلت العملية',
          data: decoded,
        );
      }
    } catch (e) {
      final bool isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      return ApiResponse(
        statusCode: response.statusCode,
        isSuccess: isSuccess,
        message: isSuccess ? 'نجحت العملية' : 'خطأ في استجابة الخادم (${response.statusCode})',
        data: response.body,
      );
    }
  }
}

/// كائن استجابة الـ API الموحد
class ApiResponse {
  final int statusCode;
  final bool isSuccess;
  final String message;
  final dynamic data;
  final Map<String, dynamic>? rawJson;

  /// هل فشل الطلب بسبب انقطاع/انتهاء مهلة الشبكة (قابل لإعادة الإرسال)؟
  final bool isNetworkError;

  /// هل تم تخزين العملية في طابور المزامنة بدل تنفيذها فوراً؟
  final bool wasQueuedOffline;

  ApiResponse({
    this.statusCode = 200,
    required this.isSuccess,
    required this.message,
    this.data,
    this.rawJson,
    this.isNetworkError = false,
    this.wasQueuedOffline = false,
  });

  factory ApiResponse.error(String message, {int statusCode = 500, bool isNetworkError = false}) {
    return ApiResponse(
      statusCode: statusCode,
      isSuccess: false,
      message: message,
      isNetworkError: isNetworkError,
    );
  }
}
