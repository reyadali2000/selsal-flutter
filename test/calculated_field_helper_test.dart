import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/dynamic_report_models.dart';
import 'package:wadialain/utils/calculated_field_helper.dart';

DynamicReportField _calcField(String? validationJson) {
  return DynamicReportField(
    id: 1,
    reportId: 1,
    sectionId: 1,
    fieldKey: 'total',
    label: 'المجموع',
    fieldType: 'calculated',
    validationJson: validationJson,
  );
}

void main() {
  group('CalculatedFieldHelper.extractFormula', () {
    test('يستخرج الصيغة من validationJson', () {
      final field = _calcField('{"formula": "{a} * 2 + {b}"}');
      expect(CalculatedFieldHelper.extractFormula(field), '{a} * 2 + {b}');
    });

    test('يُرجع null للحقل غير المحسوب', () {
      final field = DynamicReportField(
        id: 2,
        reportId: 1,
        sectionId: 1,
        fieldKey: 'x',
        label: 'x',
        fieldType: 'number',
        validationJson: '{"formula": "1"}',
      );
      expect(CalculatedFieldHelper.extractFormula(field), isNull);
    });

    test('يُرجع null عند غياب validationJson', () {
      expect(CalculatedFieldHelper.extractFormula(_calcField(null)), isNull);
      expect(CalculatedFieldHelper.extractFormula(_calcField('')), isNull);
      expect(CalculatedFieldHelper.extractFormula(_calcField('{}')), isNull);
    });
  });

  group('CalculatedFieldHelper.ratingBounds', () {
    test('يقرأ الحدود من validationJson', () {
      final field = DynamicReportField(
        id: 3,
        reportId: 1,
        sectionId: 1,
        fieldKey: 'rate',
        label: 'تقييم',
        fieldType: 'rating',
        validationJson: '{"min": 0, "max": 10}',
      );
      final bounds = CalculatedFieldHelper.ratingBounds(field);
      expect(bounds.min, 0);
      expect(bounds.max, 10);
    });

    test('القيم الافتراضية 1..5 عند الغياب', () {
      final field = DynamicReportField(
        id: 4,
        reportId: 1,
        sectionId: 1,
        fieldKey: 'rate',
        label: 'تقييم',
        fieldType: 'rating',
      );
      final bounds = CalculatedFieldHelper.ratingBounds(field);
      expect(bounds.min, 1);
      expect(bounds.max, 5);
    });

    test('يصحح الحدود المقلوبة', () {
      final field = DynamicReportField(
        id: 5,
        reportId: 1,
        sectionId: 1,
        fieldKey: 'rate',
        label: 'تقييم',
        fieldType: 'rating',
        validationJson: '{"min": 5, "max": 1}',
      );
      final bounds = CalculatedFieldHelper.ratingBounds(field);
      expect(bounds.min, 5);
      expect(bounds.max, 6);
    });
  });

  group('CalculatedFieldHelper.evaluateFormula', () {
    test('جمع وبساطة', () {
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} + {b}', {'a': '3', 'b': '4'}),
        '7',
      );
    });

    test('ضرب وقسم وأولوية العمليات', () {
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} * 2 + {b}', {'a': '5', 'b': '3'}),
        '13',
      );
      expect(
        CalculatedFieldHelper.evaluateFormula('({a} + {b}) * 2', {'a': '5', 'b': '3'}),
        '16',
      );
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} / {b}', {'a': '10', 'b': '4'}),
        '2.5',
      );
    });

    test('الإشارة السالبة والأقواس المتداخلة', () {
      expect(
        CalculatedFieldHelper.evaluateFormula('-{a} + 10', {'a': '3'}),
        '7',
      );
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} * -2', {'a': '4'}),
        '-8',
      );
      expect(
        CalculatedFieldHelper.evaluateFormula('(({a} + 1) * ({b} - 1))', {'a': '2', 'b': '5'}),
        '12',
      );
    });

    test('الكسور العشرية والفاصلة كفاصل عشري', () {
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} * 1.5', {'a': '4'}),
        '6',
      );
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} + {b}', {'a': '1,5', 'b': '2,5'}),
        '4',
      );
    });

    test('يُرجع null عند نقص مدخل', () {
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} + {b}', {'a': '3'}),
        isNull,
      );
    });

    test('يُرجع null عند مدخل غير عددي', () {
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} + 1', {'a': 'abc'}),
        isNull,
      );
    });

    test('يُرجع null للصيغة الفارغة أو غير الصالحة', () {
      expect(CalculatedFieldHelper.evaluateFormula('', {}), isNull);
      expect(CalculatedFieldHelper.evaluateFormula('{a} +', {'a': '1'}), isNull);
      expect(CalculatedFieldHelper.evaluateFormula('{a} (', {'a': '1'}), isNull);
    });

    test('يُرجع null للقسمة على صفر', () {
      expect(
        CalculatedFieldHelper.evaluateFormula('{a} / 0', {'a': '5'}),
        isNull,
      );
    });

    test('يرفض الحروف والرموز الغريبة', () {
      expect(CalculatedFieldHelper.evaluateFormula('{a}; DROP', {'a': '1'}), isNull);
    });

    test('evaluateField يربط الاستخراج بالتقييم', () {
      final field = _calcField('{"formula": "{x} * {y}"}');
      expect(
        CalculatedFieldHelper.evaluateField(field, {'x': '6', 'y': '7'}),
        '42',
      );
      expect(CalculatedFieldHelper.evaluateField(field, {'x': '6'}), isNull);
    });
  });
}
