import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:wadialain/models/dynamic_report_models.dart';

void main() {
  group('DynamicTableConfig - عمود التاريخ', () {
    test('حقل التاريخ يُسلسَل ويُسترجَل عبر JSON', () {
      final config = DynamicTableConfig(
        columns: [
          DynamicTableColumn(key: 'item', title: 'بند الفحص', type: 'label', widthRatio: 2.5),
          DynamicTableColumn(key: 'result', title: 'النتيجة', type: 'text', widthRatio: 1.5),
          DynamicTableColumn(key: 'inspection_date', title: 'تاريخ الفحص', type: 'date', widthRatio: 1.3),
        ],
        defaultRows: [
          {'item': 'سلامة العبوات', 'inspection_date': '21/09/2026'},
        ],
      );

      final jsonStr = config.toJsonString();
      final restored = DynamicTableConfig.fromJsonString(jsonStr);

      expect(restored, isNotNull);
      expect(restored!.columns.length, 3);
      expect(restored.columns[2].type, 'date');
      expect(restored.columns[2].key, 'inspection_date');
      expect(restored.columns[2].title, 'تاريخ الفحص');
      expect(restored.defaultRows.first['inspection_date'], '21/09/2026');
    });

    test('صيغة dd/MM/yyyy تُنتج فواصل شرطة مائلة', () {
      final dt = DateTime(2026, 9, 21);
      final formatted = DateFormat('dd/MM/yyyy').format(dt);
      expect(formatted, '21/09/2026');
      expect(formatted.contains('/'), isTrue);

      // استرجاع القيمة بنفس الصيغة
      final parsed = DateFormat('dd/MM/yyyy').parse(formatted);
      expect(parsed, dt);
    });

    test('الجدول يتعامل مع خلية التاريخ الفارغة', () {
      final config = DynamicTableConfig(
        columns: [
          DynamicTableColumn(key: 'd', title: 'تاريخ', type: 'date'),
        ],
        defaultRows: [
          {'d': ''},
          {},
        ],
      );
      final restored = DynamicTableConfig.fromJsonString(config.toJsonString());
      expect(restored?.defaultRows.first['d'], '');
      expect(restored?.defaultRows.last, isEmpty);
    });
  });

  group('DynamicTableConfig - عمود الوقت', () {
    test('صيغة HH:mm تُنتج فواصل النقطتين بنظام 24 ساعة', () {
      final dt = DateTime(2026, 9, 21, 14, 5);
      final formatted = DateFormat('HH:mm').format(dt);
      expect(formatted, '14:05');
      expect(formatted.contains(':'), isTrue);

      final parsed = DateFormat('HH:mm').parse('14:05');
      expect(parsed.hour, 14);
      expect(parsed.minute, 5);
    });

    test('عمود وقت يُسلسَل ويُسترجَل', () {
      final config = DynamicTableConfig(
        columns: [
          DynamicTableColumn(key: 'sample_time', title: 'وقت أخذ العينة', type: 'time'),
        ],
        defaultRows: [
          {'sample_time': '09:30'},
        ],
      );
      final restored = DynamicTableConfig.fromJsonString(config.toJsonString());
      expect(restored?.columns.first.type, 'time');
      expect(restored?.defaultRows.first['sample_time'], '09:30');
    });
  });

  group('DynamicTableConfig - عمود الرقم العشري', () {
    test('عمود عشري يُسلسَل ويُسترجَل ويحتفظ بالكسور', () {
      final config = DynamicTableConfig(
        columns: [
          DynamicTableColumn(key: 'ph', title: 'pH', type: 'decimal'),
          DynamicTableColumn(key: 'cl', title: 'الكلور mg/L', type: 'decimal'),
        ],
        defaultRows: [
          {'ph': '7.5', 'cl': '0.2'},
        ],
      );
      final restored = DynamicTableConfig.fromJsonString(config.toJsonString());
      expect(restored?.columns[0].type, 'decimal');
      expect(restored?.columns[1].type, 'decimal');
      expect(restored?.defaultRows.first['ph'], '7.5');
      expect(restored?.defaultRows.first['cl'], '0.2');
    });
  });
}
