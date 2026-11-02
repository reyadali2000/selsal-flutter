import 'package:flutter/material.dart';

/// الوحدات الرئيسية في الشاشة الأم (التبويبات السفلية والدرج الجانبي)
enum HomeModule {
  dashboard('الرئيسية', Icons.dashboard_rounded, Color(0xFF0D47A1)),
  reports('التقارير', Icons.analytics_rounded, Color(0xFF007791)),
  quality('إدارة الجودة', Icons.verified_rounded, Color(0xFF2E7D32)),
  health('سلامة الغذاء', Icons.health_and_safety_rounded, Color(0xFFE65100)),
  shifts('الورديات', Icons.access_time_filled_rounded, Color(0xFF6A1B9A)),
  settings('الإعدادات', Icons.settings_rounded, Color(0xFF455A64));

  final String title;
  final IconData icon;
  final Color color;

  const HomeModule(this.title, this.icon, this.color);
}
