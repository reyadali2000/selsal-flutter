import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/dynamic_report_models.dart';
import 'package:wadialain/utils/dynamic_validation_helper.dart';

DynamicReportField _field({
  required String fieldType,
  bool isRequired = false,
  String? defaultValue,
  String? validationJson,
}) {
  return DynamicReportField(
    id: 1,
    reportId: 1,
    sectionId: 1,
    fieldKey: 'f1',
    label: 'حقل',
    fieldType: fieldType,
    isRequired: isRequired,
    defaultValue: defaultValue,
    validationJson: validationJson,
  );
}

void main() {
  group('DynamicValidationHelper - حقل التعليمات', () {
    test('يتخطى التحقق دائماً (للقراءة فقط) حتى لو كان مطلوباً', () {
      final field = _field(fieldType: 'instructions', isRequired: true, defaultValue: 'نص تعليمات');
      expect(DynamicValidationHelper.validate(field, null), isNull);
      expect(DynamicValidationHelper.validate(field, ''), isNull);
    });
  });

  group('DynamicValidationHelper - حقل الملاحظة', () {
    test('مطلوب وفارغ يُرجع خطأ', () {
      final field = _field(fieldType: 'note', isRequired: true);
      expect(DynamicValidationHelper.validate(field, ''), 'هذا الحقل مطلوب');
      expect(DynamicValidationHelper.validate(field, null), 'هذا الحقل مطلوب');
    });

    test('غير مطلوب وفارغ يُرجع null', () {
      final field = _field(fieldType: 'note');
      expect(DynamicValidationHelper.validate(field, ''), isNull);
    });

    test('قيمة موجودة تُرجع null', () {
      final field = _field(fieldType: 'note', isRequired: true);
      expect(DynamicValidationHelper.validate(field, 'ملاحظة مهمة'), isNull);
    });
  });

  group('DynamicValidationHelper - حقل محسوب', () {
    test('يتخطى التحقق دائماً', () {
      final field = _field(fieldType: 'calculated', isRequired: true);
      expect(DynamicValidationHelper.validate(field, null), isNull);
      expect(DynamicValidationHelper.validate(field, ''), isNull);
    });
  });

  group('DynamicValidationHelper - حقل التقييم', () {
    test('داخل النطاق مقبول', () {
      final field = _field(fieldType: 'rating', validationJson: '{"min": 1, "max": 5}');
      expect(DynamicValidationHelper.validate(field, '3'), isNull);
      expect(DynamicValidationHelper.validate(field, '1'), isNull);
      expect(DynamicValidationHelper.validate(field, '5'), isNull);
    });

    test('خارج النطاق مرفوض', () {
      final field = _field(fieldType: 'rating', validationJson: '{"min": 1, "max": 5}');
      expect(DynamicValidationHelper.validate(field, '0'), isNotNull);
      expect(DynamicValidationHelper.validate(field, '6'), isNotNull);
    });

    test('قيمة غير رقمية مرفوضة', () {
      final field = _field(fieldType: 'rating', validationJson: '{"min": 1, "max": 5}');
      expect(DynamicValidationHelper.validate(field, 'abc'), isNotNull);
    });
  });

  group('defaultValue round-trip', () {
    test('حقل التعليمات يحفظ نصه في defaultValue', () {
      final field = _field(fieldType: 'instructions', defaultValue: 'تعليمات الاستخدام');
      expect(field.fieldType, 'instructions');
      expect(field.defaultValue, 'تعليمات الاستخدام');
      expect(field.toMap()['default_value'], 'تعليمات الاستخدام');
    });

    test('fromMap يسترجع defaultValue', () {
      final field = _field(fieldType: 'note', defaultValue: 'ملاحظة');
      final restored = DynamicReportField.fromMap(field.toMap());
      expect(restored.defaultValue, 'ملاحظة');
      expect(restored.fieldType, 'note');
    });
  });
}
