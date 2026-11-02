import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:wadialain/services/pdf/arabic_pdf_service.dart';

void main() {
  test('test الفحص الظاهري rendering', () async {
    final pdf = pw.Document();
    final fontData = File('assets/fonts/Tajawal-Regular.ttf').readAsBytesSync();
    final fontBoldData = File('assets/fonts/Tajawal-Bold.ttf').readAsBytesSync();
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());
    final ttfBold = pw.Font.ttf(fontBoldData.buffer.asByteData());
    
    pdf.addPage(
      pw.Page(
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (context) {
          final raw = 'ثانياً: الفحص الظاهري:';
          final cleaned = ArabicPdfService.cleanArabicText(raw);
          
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('بدون معالجة: $raw', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
              pw.SizedBox(height: 15),
              pw.Text('مع المعالجة: $cleaned', style: pw.TextStyle(font: ttfBold, fontSize: 16)),
              pw.SizedBox(height: 15),
              pw.Text(ArabicPdfService.cleanArabicText('ثانياً: الفحص الظاهري والتغليف:'), style: pw.TextStyle(font: ttfBold, fontSize: 16)),
            ],
          );
        },
      ),
    );
    
    final bytes = await pdf.save();
    File('test_visual_check.pdf').writeAsBytesSync(bytes);
    print('Saved test_visual_check.pdf');
  });
}
          

