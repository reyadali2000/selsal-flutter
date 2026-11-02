import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة الثيم (فاتح/داكن) — تحفظ تفضيل المستخدم وتستعيده عند الإقلاع
class ThemeService extends GetxService {
  static ThemeService get to => Get.find<ThemeService>();

  static const String _prefKey = 'is_dark_mode';

  /// الوضع النشط حالياً (يتغير تفاعلياً عبر Obx)
  final RxBool isDarkMode = false.obs;

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  @override
  void onInit() {
    super.onInit();
    ensureLoaded();
  }

  /// استرجاع التفضيل المحفوظ (يُستدعى عند الإقلاع)
  Future<void> ensureLoaded() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool(_prefKey) ?? false;
  }

  /// تبديل الوضع وحفظه
  Future<void> toggleTheme() async {
    isDarkMode.value = !isDarkMode.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, isDarkMode.value);
  }

  /// تفعيل وضع محدد
  Future<void> setDarkMode(bool enabled) async {
    isDarkMode.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }
}
