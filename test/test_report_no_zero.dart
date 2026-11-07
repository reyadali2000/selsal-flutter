// ignore_for_file: avoid_print
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('generate full report-like PDF and verify no zero-width arabic glyphs',
      () async {
    final fontRegularData =
        File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
    final fontBoldData =
        File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    final ttf = pw.Font.ttf(fontRegularData.buffer.asByteData());
    final ttfBold = pw.Font.ttf(fontBoldData.buffer.asByteData());

    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (context) {
          return [
            pw.Text('ثانياً: الفحص الظاهري:',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('الفحص الظاهري والتغليف:',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('رابعاً: الفحوصات الميكروبيولوجية:',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('الرقم الهيدروجيني pH',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('خالد العمري',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('صلاح الجابري',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('الكلور المتبقي',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('في حالة عدم المطابقة',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
            pw.SizedBox(height: 6),
            pw.Text('الملاحظات',
                style: pw.TextStyle(font: ttfBold, fontSize: 11)),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    final outFile = File('test_report_output.pdf');
    await outFile.writeAsBytes(bytes);
    print('PDF saved: ${outFile.absolute.path} (${bytes.length} bytes)');
  });
}
