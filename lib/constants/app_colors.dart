import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryDarkest = Color(0xFF021024);
  static const Color primaryDark = Color(0xFF052659);
  static const Color primary = primaryDark;
  static const Color primaryMedium = Color(0xFF5483B3);
  static const Color primaryLight = Color(0xFF7DA0CA);
  static const Color primaryLightest = Color(0xFFC1E8FF);

  // Neutral tones shared by all screens, to keep content calm and readable.
  static const Color canvas = Color(0xFFF4F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF142B4A);
  static const Color muted = Color(0xFF64748B);
  static const Color success = Color(0xFF118A68);
  static const Color border = Color(0xFFE2EAF3);

  // ===== البديل الداكن للألوان المحايدة والأساسية (الثيم الداكن المطور) =====
  static const Color darkCanvas = Color(0xFF090E17); // خلفية التطبيق الليلية الملكية
  static const Color darkSurface = Color(0xFF131D2E); // البطاقات والأسطح المرتفعة
  static const Color darkSurfaceElevated = Color(0xFF1A273D); // الحاويات والحقول فوق البطاقات
  static const Color darkInk = Color(0xFFF8FAFC); // النص الأساسي شديد الوضوح والنقاء
  static const Color darkMuted = Color(0xFF94A3B8); // النص الثانوي عالي المقروئية
  static const Color darkBorder = Color(0xFF23354E); // الحدود الأنيقة الواضحة

  // ألوان أزرار وأيقونات الوضع الليلي المتناسقة والمضيئة
  static const Color darkPrimary = Color(0xFF0EA5E9); // أزرق سماوي مضيء وعالي التباين
  static const Color darkPrimaryLight = Color(0xFF38BDF8); // أزرق سماوي فاتح للنصوص والأيقونات
  static const Color darkPrimaryDark = Color(0xFF0284C7); // أزرق سماوي داكن للخلفيات
  static const Color darkSuccess = Color(0xFF10B981); // أخضر زمردي واضح
  static const Color darkSuccessLight = Color(0xFF34D399); // أخضر فاتح
  static const Color darkWarning = Color(0xFFF59E0B); // برتقالي تحذيري مضيء
  static const Color darkWarningLight = Color(0xFFFBBF24); // أصفر تحذيري
  static const Color darkDanger = Color(0xFFEF4444); // أحمر واضح وساطع
  static const Color darkDangerLight = Color(0xFFF87171); // أحمر فاتح

  // ===== دوال مساعدة لجلب اللون المتناسق مع وضع الشاشة الحالي =====
  static Color inkOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkInk : ink;
  }

  static Color mutedOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkMuted : muted;
  }

  static Color surfaceOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkSurface : surface;
  }

  static Color borderOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkBorder : border;
  }

  static Color primaryOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkPrimary : primaryDark;
  }

  static Color primaryLightOf(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? darkPrimaryLight : primaryLight;
  }
}
