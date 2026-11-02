import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة إعداد البصمة (تفعيل/إلغاء تسجيل الدخول السريع بالبصمة)
class BiometricSettingsService {
  BiometricSettingsService._();
  static final BiometricSettingsService instance = BiometricSettingsService._();

  static const String _prefKey = 'biometric_login_enabled';

  /// هل البصمة مفعّلة من قبل المستخدم (اختياري)؟
  Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  /// تفعيل أو تعطيل البصمة
  Future<void> setEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}
