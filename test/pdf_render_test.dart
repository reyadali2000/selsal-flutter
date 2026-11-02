import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:wadialain/models/dynamic_report_models.dart';
import 'package:wadialain/utils/dynamic_report_pdf_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Test DynamicReportPdfGenerator.generate with 2 tables in 1 section', () async {
    final sec1 = DynamicReportSection(
      id: 10127,
      reportId: 1020,
      title: 'سجل المواد الكيميائية وأدوات ومعدات التنظيف والتطهير:',
      sortOrder: 1,
      fields: [
        DynamicReportField(
          id: 101172,
          reportId: 1020,
          sectionId: 10127,
          fieldKey: 'report_date',
          label: 'تاريخ التقرير',
          fieldType: 'date',
        ),
        DynamicReportField(
          id: 101173,
          reportId: 1020,
          sectionId: 10127,
          fieldKey: 'field_1792698373769_0',
          label: 'أولاً: قائمة المواد المستخدمة للتنظيف والتطهير',
          fieldType: 'table',
          optionsJson: '{"columns":[{"key":"col_0","title":"اسم المادة التجارية","type":"text","widthRatio":2.0},{"key":"col_1","title":"الاسم الكيميائي","type":"text","widthRatio":2.0},{"key":"col_2","title":"الغرض (تنظيف/تطهير)","type":"text","widthRatio":2.0},{"key":"col_3","title":"مناطق الاستخدام","type":"text","widthRatio":2.0},{"key":"col_4","title":"التركيز المعتمد","type":"text","widthRatio":2.0},{"key":"col_5","title":"طريقة التحضير","type":"text","widthRatio":2.0},{"key":"col_6","title":"مكان التخزين","type":"text","widthRatio":2.0},{"key":"col_7","title":"MSDS متوفر","type":"yes_no","options":["نعم","لا"],"widthRatio":1.1},{"key":"col_8","title":"اسم المورد","type":"text","widthRatio":2.0},{"key":"col_9","title":"حالة الأعتماد","type":"text","widthRatio":2.0},{"key":"col_10","title":"الملاحظات","type":"text","widthRatio":2.0}],"rowCount":3}',
        ),
        DynamicReportField(
          id: 101174,
          reportId: 1020,
          sectionId: 10127,
          fieldKey: 'field_1792698695921_1',
          label: 'ثانياً: أدوات ومعدات التنظيف والتطهير',
          fieldType: 'table',
          optionsJson: '{"columns":[{"key":"col_0","title":"نوع الأداة","type":"text","widthRatio":2.0},{"key":"col_1","title":"اللون / الترميز","type":"text","widthRatio":2.0},{"key":"col_2","title":"منطقة الاستخدام","type":"text","widthRatio":2.0},{"key":"col_3","title":"طريقة التنظيف بعد الأستخدام","type":"text","widthRatio":2.0},{"key":"col_4","title":"مكان التخزين","type":"text","widthRatio":2.0},{"key":"col_5","title":"الحالة (جيدة / تحتاج لاستبدال)","type":"text","widthRatio":2.0},{"key":"col_6","title":"تاريخ اخر فحص","type":"date","widthRatio":1.3},{"key":"col_7","title":"ملاحظات","type":"text","widthRatio":2.0}],"rowCount":3}',
        ),
        DynamicReportField(
          id: 101175,
          reportId: 1020,
          sectionId: 10127,
          fieldKey: 'field_1792699274903_2',
          label: 'تعليمات الأستخدام',
          fieldType: 'instructions',
          defaultValue: '1.يسمح باستخدام المواد المعتمدة فقط والمسجلة في القسم الأول من هذا النموذج.\n2.يجب توفر بطاقة بيانات السلامة (MSDS) لكل مادة كيميائية والاحتفاظ بها في ملف منفصل.\n3.يتم تحديد مناطق الاستخدام والتركيزات المعتمدة لكل مادة وفق إجراء التنظيف والتطهير.\n4.تستخدم الأدوات المرمزة لونياً لمنع التلوث التبادلي.',
        ),
      ],
    );

    final report = DynamicReport(
      id: 1020,
      name: 'سجل التحكم في المواد الكيميائية وأدوات التنظيف',
      orientation: 'landscape',
      approvalType: 'two_level',
      sections: [sec1],
    );

    final record = DynamicReportRecord(
      id: 57,
      reportId: 1020,
      createdBy: 'م. صلاح الجابري',
      createdAt: DateTime.now(),
      status: 'Pending_QM',
      approvalStatus: 'Pending_QM',
    );

    final values = [
      DynamicReportValue(id: 1, recordId: 57, fieldId: 101172, value: '2026/10/22'),
      DynamicReportValue(id: 2, recordId: 57, fieldId: 101173, value: '[{"col_0":"مادة معقمة A","col_1":"كلور","col_2":"تنظيف وتطهير","col_7":"نعم"},{"col_0":"مادة B","col_7":"نعم"},{"col_0":"مادة C","col_7":"نعم"}]'),
      DynamicReportValue(id: 3, recordId: 57, fieldId: 101174, value: '[{"col_0":"ممسحة أرضيات","col_1":"أزرق","col_2":"صالة التعبئة","col_5":"جيدة"},{"col_0":"فرشاة تنظيف","col_1":"أحمر","col_2":"المستودع","col_5":"جيدة"},{"col_0":"مكشطة","col_1":"أخضر","col_2":"خط الإنتاج","col_5":"جيدة"}]'),
    ];

    print('Calling DynamicReportPdfGenerator.generate on updated code...');
    final pdfBytes = await DynamicReportPdfGenerator.generate(
      report: report,
      record: record,
      values: values,
    );

    final file = File('C:/Users/REYADH/Desktop/test_report_1020_real_generator.pdf');
    await file.writeAsBytes(pdfBytes);
    print('REAL_GENERATOR_SUCCESS');
  });
}
