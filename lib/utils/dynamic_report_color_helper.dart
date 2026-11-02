import 'package:flutter/material.dart';
import '../models/dynamic_report_models.dart';

/// مساعِد تحديد ألوان التقارير الديناميكية لضمان تميّز كل تقرير بلون راقٍ ومتناسق
/// بحسب الأيقونة المختارة أو المعرّف، بما يحقق تناغماً مع خصائص كل قسم.
class DynamicReportColorHelper {
  DynamicReportColorHelper._();

  /// لوحة ألوان تنفيذية متناغمة عالية التباين
  static const List<Color> curatedPalette = [
    Color(0xFF0288D1), // أزرق سماوي فخم (مياه ومعالجة)
    Color(0xFF6A1B9A), // بنفسجي ملكي (مختبرات وتحاليل)
    Color(0xFFE65100), // برتقالي داكن / كهرماني (جودة واعتماد)
    Color(0xFF00897B), // تيل بترولي (تفتيش ورقابة)
    Color(0xFF1565C0), // كحلي إداري (تدقيق ومهام)
    Color(0xFFD84315), // قرمزي ناري (تصنيع وتشغيل)
    Color(0xFF2E7D32), // أخضر غابي (سلامة وبيئة)
    Color(0xFFC2185B), // وردي توتي راقٍ (تقييم وقياس)
    Color(0xFF0097A7), // سيان عميق (فلاتر ومحطات)
    Color(0xFF455A64), // رمادي أزرق (معايير وضوابط)
    Color(0xFF5E35B1), // إنديجو بنفسجي
    Color(0xFF00695C), // أخضر داكن (مواد خام)
  ];

  /// خارطة الألوان الدلالية المرتبطة بالأيقونات
  static const Map<String, Color> _iconColors = {
    'water_drop': Color(0xFF0288D1),
    'water': Color(0xFF0288D1),
    'science': Color(0xFF6A1B9A),
    'lab': Color(0xFF6A1B9A),
    'verified': Color(0xFFE65100),
    'quality': Color(0xFFE65100),
    'fact_check': Color(0xFF00897B),
    'checklist': Color(0xFF00897B),
    'assignment': Color(0xFF1565C0),
    'task': Color(0xFF1565C0),
    'inventory_2': Color(0xFF00695C),
    'inventory': Color(0xFF00695C),
    'clean_hands': Color(0xFF00796B),
    'sanitizer': Color(0xFF00796B),
    'hygiene': Color(0xFF00796B),
    'health_and_safety': Color(0xFF2E7D32),
    'shield': Color(0xFF2E7D32),
    'precision_manufacturing': Color(0xFFD84315),
    'factory': Color(0xFFD84315),
    'biotech': Color(0xFF8E24AA),
    'filter_alt': Color(0xFF0097A7),
    'filter': Color(0xFF0097A7),
    'table_chart': Color(0xFF283593),
    'rule': Color(0xFF455A64),
    'assessment': Color(0xFFC2185B),
    'description': Color(0xFF3F51B5),
  };

  /// استخراج اللون الخاص بالتقرير الديناميكي
  static Color getColor(DynamicReport report) {
    return getColorByKey(report.icon, report.id, report.name);
  }

  /// استخراج اللون باستخدام مفتاح الأيقونة والمعرف واسم التقرير
  static Color getColorByKey(String? iconKey, [int? reportId, String? reportName]) {
    if (iconKey != null && iconKey.contains('|')) {
      // دعم تخصيص لون صريح عبر النمط "icon_key|#HEX"
      final parts = iconKey.split('|');
      if (parts.length > 1) {
        final hexStr = parts[1].replaceAll('#', '').trim();
        if (hexStr.length == 6 || hexStr.length == 8) {
          try {
            final val = int.parse(hexStr.length == 6 ? 'FF$hexStr' : hexStr, radix: 16);
            return Color(val);
          } catch (_) {}
        }
      }
      iconKey = parts.first.trim();
    }

    final cleanKey = iconKey?.trim().toLowerCase();
    if (cleanKey != null && cleanKey.isNotEmpty && cleanKey != 'description') {
      final color = _iconColors[cleanKey];
      if (color != null) return color;
    }

    // إذا كانت الأيقونة عامة أو غير مسجلة، نوزع من الباليتة المتناغمة بالاعتماد على المعرف أو الاسم
    if (reportId != null && reportId > 0) {
      return curatedPalette[reportId % curatedPalette.length];
    }

    if (reportName != null && reportName.isNotEmpty) {
      final code = reportName.hashCode.abs();
      return curatedPalette[code % curatedPalette.length];
    }

    return _iconColors['description'] ?? const Color(0xFF3F51B5);
  }
}
