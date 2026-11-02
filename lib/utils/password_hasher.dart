import 'dart:convert';
import 'package:crypto/crypto.dart';

/// تشفير كلمات المرور باستخدام SHA-256 مع ملح ثابت خاص بالتطبيق.
/// كلمة المرور الأصلية لا تُخزَّن أبداً؛ يُخزَّن الهاش فقط.
class PasswordHasher {
  static const String _salt = 'w4t3r_A1n_s3cur1ty_2026';

  /// يُرجع الهاش بالنظام الست عشري (64 حرفاً) لكلمة المرور المعطاة.
  static String hash(String password) {
    final bytes = utf8.encode('$_salt:${password.trim()}');
    return sha256.convert(bytes).toString();
  }

  /// يتحقق أن القيمة المخزَّنة تبدو كهاش صالح (64 حرفاً hex).
  static bool looksLikeHash(String? value) {
    if (value == null) return false;
    return RegExp(r'^[a-f0-9]{64}$').hasMatch(value.trim());
  }

  /// يطابق كلمة المرور الصريحة مع الهاش المخزَّن.
  static bool verify(String password, String? storedHash) {
    if (storedHash == null || storedHash.trim().isEmpty) return false;
    return hash(password) == storedHash.trim();
  }
}
