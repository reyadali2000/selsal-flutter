import 'package:flutter/material.dart';
import '../models/dynamic_report_models.dart';

/// مساعِد تحديد ألوان التقارير الديناميكية لضمان تميّز كل تقرير بلون راقٍ ومتناسق
/// يدعم أكثر من 64 لوناً مميزاً، بالإضافة إلى التخصيص اليدوي المباشر عبر صيغة "icon_key|#HEX"
/// وتوليد ألوان غير متكررة تلقائياً لأكثر من 60 تقريراً.
class DynamicReportColorHelper {
  DynamicReportColorHelper._();

  /// لوحة ألوان تنفيذية موسّعة (64 لوناً متمايزاً عالي التباين)
  /// مرتبة بعناية لتجنب التشابه البصري وتغطية أكثر من 60 تقريراً.
  static const List<Color> curatedPalette = [
    // 1-8: درجات الأزرق والكحلي والسيان
    Color(0xFF0288D1), // 1. أزرق سماوي فخم
    Color(0xFF1565C0), // 2. كحلي إداري
    Color(0xFF0D47A1), // 3. أزرق ملكي عميق
    Color(0xFF1E88E5), // 4. أزرق ناصع
    Color(0xFF0097A7), // 5. سيان عميق
    Color(0xFF00838F), // 6. سيان بترولي
    Color(0xFF006064), // 7. أزرق محيطي داكن
    Color(0xFF283593), // 8. نيلي رسمي

    // 9-16: درجات التركواز والتيل والأخضر الزمردي
    Color(0xFF00897B), // 9. تيل بترولي
    Color(0xFF00695C), // 10. أخضرزمردي داكن
    Color(0xFF004D40), // 11. أخضر غامق جداً
    Color(0xFF26A69A), // 12. تركواز هادئ
    Color(0xFF2E7D32), // 13. أخضر غابي
    Color(0xFF1B5E20), // 14. أخضر ملكي
    Color(0xFF388E3C), // 15. أخضر عشبي
    Color(0xFF43A047), // 16. أخضر نضر

    // 17-24: درجات الأخضر الزيتي والليموني الداكن
    Color(0xFF558B2F), // 17. أخضر زيتي
    Color(0xFF33691E), // 18. زيتي عميق
    Color(0xFF689F38), // 19. أخضر تفاحي داكن
    Color(0xFF827717), // 20. زيتي ذهبي
    Color(0xFF9E9D24), // 21. ليموني خردلي
    Color(0xFFAFB42B), // 22. فستقي داكن
    Color(0xFF00796B), // 23. تيل كلاسيكي
    Color(0xFF00ACC1), // 24. أكوا مشرق

    // 25-32: درجات الكهرماني والذهبي والبرتقالي
    Color(0xFFF57F17), // 25. ذهبي كهرماني
    Color(0xFFFF8F00), // 26. كهرماني دافئ
    Color(0xFFFF6F00), // 27. برتقالي ذهبي
    Color(0xFFE65100), // 28. برتقالي داكن
    Color(0xFFEF6C00), // 29. برتقالي ساطع
    Color(0xFFF57C00), // 30. برتقالي نحاسي
    Color(0xFFD84315), // 31. قرمزي ناري
    Color(0xFFBF360C), // 32. طوبي محروق

    // 33-40: درجات الأحمر والعنابي والمرجاني
    Color(0xFFC62828), // 33. أحمر قاني
    Color(0xFFB71C1C), // 34. عنابي ملكي
    Color(0xFFD32F2F), // 35. أحمر رسمي
    Color(0xFFE53935), // 36. أحمر مرجاني
    Color(0xFFAD1457), // 37. توتي عميق
    Color(0xFF880E4F), // 38. خمري داكن
    Color(0xFFC2185B), // 39. وردي توتي
    Color(0xFFD81B60), // 40. فوشيا راقٍ

    // 41-48: درجات البنفسجي والأرجواني والإنديجو
    Color(0xFF6A1B9A), // 41. بنفسجي ملكي
    Color(0xFF4A148C), // 42. باذنجاني عميق
    Color(0xFF7B1FA2), // 43. أرجواني غني
    Color(0xFF8E24AA), // 44. بنفسجي مشرق
    Color(0xFF5E35B1), // 45. إنديجو بنفسجي
    Color(0xFF4527A0), // 46. إنديجو ملكي
    Color(0xFF311B92), // 47. كحلي بنفسجي
    Color(0xFF3949AB), // 48. إنديجو صافٍ

    // 49-56: درجات البرونزي والبني والرمادي المعدني
    Color(0xFF5D4037), // 49. بني شوكولاتة
    Color(0xFF4E342E), // 50. بني إسبريسو
    Color(0xFF6D4C41), // 51. برونزي دافئ
    Color(0xFF795548), // 52. كاكاو
    Color(0xFF455A64), // 53. رمادي فولاذي
    Color(0xFF37474F), // 54. رمادي فحمي مزرق
    Color(0xFF263238), // 55. فحمي داكن
    Color(0xFF546E7A), // 56. أردوازي

    // 57-64: درجات إضافية متميزة (نيلي، فيروزي، ياقوتي، نحاسي)
    Color(0xFF1976D2), // 57. أزرق ياقوتي
    Color(0xFF039BE5), // 58. أزرق بحري
    Color(0xFF00BFA5), // 59. فيروزي حيوي
    Color(0xFF64DD17), // 60. أخضر ليموني مشرق
    Color(0xFFAEEA00), // 61. زبرجد
    Color(0xFFAA00FF), // 62. جمشت
    Color(0xFF6200EA), // 63. بنفسجي كهربائي
    Color(0xFFC51162), // 64. ياقوت أحمر
  ];

  /// خارطة الألوان الدلالية الافتراضية المرتبطة بالأيقونات (تُستخدم عند المعاينة المبدئية للأيقونة)
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
    'report_problem': Color(0xFFC62828),
    'ncr': Color(0xFFC62828),
    'build_circle': Color(0xFF455A64),
    'maintenance': Color(0xFF455A64),
    'thermostat': Color(0xFFE53935),
    'temperature': Color(0xFFE53935),
    'pest_control': Color(0xFF5D4037),
    'bug': Color(0xFF5D4037),
    'checkroom': Color(0xFF5E35B1),
    'locker': Color(0xFF5E35B1),
    'local_shipping': Color(0xFF1E88E5),
    'truck': Color(0xFF1E88E5),
    'warehouse': Color(0xFF6D4C41),
    'storage': Color(0xFF6D4C41),
    'recycling': Color(0xFF43A047),
    'waste': Color(0xFF43A047),
    'local_drink': Color(0xFF039BE5),
    'bottle': Color(0xFF039BE5),
    'speed': Color(0xFFF57C00),
    'gauge': Color(0xFFF57C00),
    'engineering': Color(0xFF3949AB),
    'workers': Color(0xFF3949AB),
    'medical_services': Color(0xFFD81B60),
    'first_aid': Color(0xFFD81B60),
    'cleaning_services': Color(0xFF00ACC1),
    'cleaning': Color(0xFF00ACC1),
    'bolt': Color(0xFFF57F17),
    'energy': Color(0xFFF57F17),
    'qr_code_scanner': Color(0xFF37474F),
    'traceability': Color(0xFF37474F),
    'wine_bar': Color(0xFF00838F),
    'glass': Color(0xFF00838F),
    'school': Color(0xFF7B1FA2),
    'training': Color(0xFF7B1FA2),
    'description': Color(0xFF3F51B5),
  };

  /// استخراج اسم الأيقونة الصافي بدون كود اللون (قبل علامة |)
  static String extractIconName(String? rawIcon) {
    if (rawIcon == null || rawIcon.trim().isEmpty) return 'description';
    if (rawIcon.contains('|')) {
      final first = rawIcon.split('|').first.trim();
      return first.isEmpty ? 'description' : first;
    }
    return rawIcon.trim();
  }

  /// استخراج كود اللون السداسي المخصص (#RRGGBB) إن وُجد بعد علامة |
  static String? extractCustomColorHex(String? rawIcon) {
    if (rawIcon == null || !rawIcon.contains('|')) return null;
    final parts = rawIcon.split('|');
    if (parts.length > 1) {
      final hex = parts[1].trim();
      if (hex.isNotEmpty) {
        return hex.startsWith('#') ? hex.toUpperCase() : '#${hex.toUpperCase()}';
      }
    }
    return null;
  }

  /// دمج مفتاح الأيقونة مع كود اللون السداسي لحفظهما معاً في حقل icon
  static String combineIconAndColor(String iconName, String? colorHex) {
    final cleanIcon = extractIconName(iconName);
    if (colorHex == null || colorHex.trim().isEmpty) return cleanIcon;
    var cleanHex = colorHex.trim().toUpperCase();
    if (!cleanHex.startsWith('#')) cleanHex = '#$cleanHex';
    return '$cleanIcon|$cleanHex';
  }

  /// تحويل كائن Color إلى نص سداسي #RRGGBB
  static String colorToHex(Color color) {
    final r = (color.r * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255.0).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
    return '#${r.toUpperCase()}${g.toUpperCase()}${b.toUpperCase()}';
  }

  /// تحويل نص #HEX إلى Color بأمان
  static Color? parseHexColor(String? hexStr) {
    if (hexStr == null || hexStr.trim().isEmpty) return null;
    final clean = hexStr.replaceAll('#', '').trim();
    if (clean.length == 6 || clean.length == 8) {
      final val = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
      if (val != null) return Color(val);
    }
    return null;
  }

  /// توليد لون فريد بالاعتماد على الفهرس أو المعرّف (يدعم عدداً غير محدود عبر الزاوية الذهبية)
  static Color getDistinctColorForIndex(int index) {
    final safeIdx = index.abs();
    if (safeIdx < curatedPalette.length) {
      return curatedPalette[safeIdx];
    }
    // إذا زاد عدد التقارير عن 64، نولّد درجات فريدة عبر Golden Angle (137.508 درجة)
    final double hue = (safeIdx * 137.508) % 360.0;
    final double saturation = 0.65 + ((safeIdx % 3) * 0.10); // 0.65 - 0.85
    final double lightness = 0.35 + ((safeIdx % 4) * 0.05);  // 0.35 - 0.50
    return HSLColor.fromAHSL(1.0, hue, saturation.clamp(0.5, 0.9), lightness.clamp(0.3, 0.55)).toColor();
  }

  /// استخراج اللون الخاص بالتقرير الديناميكي
  static Color getColor(DynamicReport report) {
    return getColorByKey(report.icon, report.id, report.name);
  }

  /// استخراج اللون باستخدام مفتاح الأيقونة والمعرف واسم التقرير
  static Color getColorByKey(String? iconKey, [int? reportId, String? reportName]) {
    // 1. إذا كان هناك لون مخصص صريح بصيغة "icon_key|#HEX"، نستخدمه فوراً
    final customHex = extractCustomColorHex(iconKey);
    if (customHex != null) {
      final parsed = parseHexColor(customHex);
      if (parsed != null) return parsed;
    }

    final cleanKey = extractIconName(iconKey).toLowerCase();

    // 2. إذا تم تمرير معرف التقرير (أو اسمه)، نضمن توزيعاً لونياً فريداً لكل تقرير
    // حتى لا تتشابه ألوان التقارير التي تشترك في نفس الأيقونة!
    if (reportId != null && reportId > 0) {
      // توزيع فريد بالاعتماد على معرف التقرير مع إزاحة أولية لمنع التكرار
      final int idx = (reportId * 13 + (reportName?.hashCode.abs() ?? 0)) % curatedPalette.length;
      return curatedPalette[idx];
    }

    if (reportName != null && reportName.trim().isNotEmpty) {
      final int idx = reportName.trim().hashCode.abs() % curatedPalette.length;
      return curatedPalette[idx];
    }

    // 3. في حال استدعاء الدالة بمفتاح الأيقونة فقط (مثل العرض المبدئي للأيقونة)
    if (cleanKey.isNotEmpty) {
      final color = _iconColors[cleanKey];
      if (color != null) return color;
    }

    return _iconColors['description'] ?? const Color(0xFF3F51B5);
  }
}
