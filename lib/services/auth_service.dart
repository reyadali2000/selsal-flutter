/// خدمة المصادقة (Authentication Service)
/// تعزل منطق تسجيل الدخول عن واجهة المستخدم
/// يمكن ترقيتها لاحقاً لاستخدام Firebase أو API خارجي
class AuthService {
  // بيانات الدخول المؤقتة — سيتم استبدالها لاحقاً بخدمة حقيقية
  static const String _defaultUsername = 'admin';
  static const String _defaultPassword = '123456';

  /// التحقق من بيانات تسجيل الدخول
  /// يُرجع `null` عند النجاح، أو رسالة خطأ عند الفشل
  static AuthResult login(String username, String password) {
    String? usernameError;
    String? passwordError;

    if (username.isEmpty) {
      usernameError = 'يرجى إدخال اسم المستخدم';
    } else if (username != _defaultUsername) {
      usernameError = 'اسم المستخدم غير صحيح';
    }

    if (password.isEmpty) {
      passwordError = 'يرجى إدخال كلمة المرور';
    } else if (password != _defaultPassword) {
      passwordError = 'كلمة المرور غير صحيحة';
    }

    return AuthResult(
      isSuccess: usernameError == null && passwordError == null,
      usernameError: usernameError,
      passwordError: passwordError,
    );
  }
}

/// نتيجة عملية تسجيل الدخول
class AuthResult {
  final bool isSuccess;
  final String? usernameError;
  final String? passwordError;

  const AuthResult({
    required this.isSuccess,
    this.usernameError,
    this.passwordError,
  });
}
