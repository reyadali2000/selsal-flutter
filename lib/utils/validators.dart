/// أدوات التحقق من صحة القراءات والبيانات
/// تُستخدم في الـ Controllers والـ Forms
class Validators {
  // ===== حدود معايير الجودة =====
  static const double phMin = 6.5;
  static const double phMax = 8.5;
  static const double tdsMax = 150.0;
  static const double ozoneMax = 0.5;
  static const double uvMin = 40.0;

  /// التحقق من صلاحية قراءة pH
  static bool isPhValid(double value) => value >= phMin && value <= phMax;

  /// التحقق من صلاحية قراءة TDS
  static bool isTdsValid(double value) => value <= tdsMax;

  /// التحقق من صلاحية قراءة الأوزون
  static bool isOzoneValid(double value) => value <= ozoneMax;

  /// التحقق من صلاحية قراءة UV
  static bool isUvValid(double value) => value >= uvMin;

  /// التحقق من أن النص غير فارغ
  static bool isNotEmpty(String? value) => value != null && value.trim().isNotEmpty;

  /// التحقق من أن النص رقم صالح
  static double? parseNumber(String text) => double.tryParse(text.trim());
}
