import '../models/dynamic_report_models.dart';
import 'calculated_field_helper.dart';

class DynamicValidationHelper {
  static String? validate(DynamicReportField field, String? value) {
    // الحقل المحسوب يُشتق تلقائياً ولا يُدخل يدوياً، فلا يُتحقق منه هنا
    // حقل التعليمات نص توجيهي ثابت للقراءة فقط، فلا يُتحقق منه أيضاً
    if (field.fieldType == 'calculated' || field.fieldType == 'instructions') {
      return null;
    }

    if (field.isRequired && (value == null || value.trim().isEmpty)) {
      return 'هذا الحقل مطلوب';
    }

    if (value == null || value.trim().isEmpty) {
      return null; // Empty and not required
    }

    final type = field.fieldType.toLowerCase().trim();
    if (type == 'number' || type == 'int' || type == 'integer' || type == 'decimal' || type == 'float' || type == 'double') {
      final numValue = double.tryParse(value);
      if (numValue == null) {
        return type.contains('dec') || type.contains('float') || type.contains('double') ? 'يجب إدخال قيمة رقمية صحيحة أو عشرية' : 'يجب إدخال رقم صحيح';
      }

      if (field.minValue != null && numValue < field.minValue!) {
        return 'يجب أن لا يقل عن ${field.minValue}';
      }

      if (field.maxValue != null && numValue > field.maxValue!) {
        return 'يجب أن لا يزيد عن ${field.maxValue}';
      }
    }

    // التحقق من حدود التقييم (تُخزَّن في validationJson)
    if (field.fieldType == 'rating') {
      final bounds = CalculatedFieldHelper.ratingBounds(field);
      final numValue = int.tryParse(value);
      if (numValue == null) {
        return 'قيمة التقييم غير صالحة';
      }
      if (numValue < bounds.min || numValue > bounds.max) {
        return 'يجب أن يكون التقييم بين ${bounds.min} و ${bounds.max}';
      }
    }

    // Advanced JSON validation can be added here parsing field.validationJson
    return null;
  }
}
