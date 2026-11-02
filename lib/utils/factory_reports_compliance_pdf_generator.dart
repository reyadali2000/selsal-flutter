import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/factory_compliance_models.dart';

class FactoryReportsCompliancePdfGenerator {
  static const PdfColor _primaryDark = PdfColor.fromInt(0xFF003853);
  static const PdfColor _primaryTeal = PdfColor.fromInt(0xFF007791);
  static const PdfColor _tableHeaderBg = PdfColor.fromInt(0xFFEBF3FB);
  static const PdfColor _tableRowAlt = PdfColor.fromInt(0xFFF7FAFC);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFCBD5E1);
  static const PdfColor _dangerBg = PdfColor.fromInt(0xFFFFF1F0);
  static const PdfColor _dangerText = PdfColor.fromInt(0xFFC62828);
  static const PdfColor _dangerBorder = PdfColor.fromInt(0xFFFFA39E);
  static const PdfColor _successBg = PdfColor.fromInt(0xFFE8F5E9);
  static const PdfColor _successText = PdfColor.fromInt(0xFF2E7D32);

  static Future<Uint8List> generateDailyCompliancePdf({
    required FactoryDailyComplianceReport report,
    String? printedBy,
  }) async {
    final pdf = pw.Document();

    // تحميل الترويسة والخطوط العربية
    pw.MemoryImage? headerImage;
    try {
      final ByteData data =
          await rootBundle.load('assets/images/selsal_pdf_header.png');
      headerImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final ByteData fontData =
        await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);

    final ByteData fontBoldData =
        await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontBoldData);

    final arabicTheme = pw.ThemeData.withFont(
      base: ttf,
      bold: ttfBold,
    );

    final dateFormatted =
        DateFormat('yyyy/MM/dd', 'en_US').format(report.date);

    pdf.addPage(
      pw.MultiPage(
        theme: arabicTheme,
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        header: (context) => _buildPdfHeader(headerImage),
        footer: (context) => _buildPdfFooter(context, ttf),
        build: (context) => [
          pw.SizedBox(height: 4),
          _buildReportTitle(dateFormatted, report.branchName, ttfBold),
          pw.SizedBox(height: 8),
          _buildKpiSummaryRow(report, ttfBold, ttf),
          pw.SizedBox(height: 10),
          _buildSectionHeader(
            'أولاً: التقارير والفحوصات المنجزة وعدد مرات التكرار',
            _primaryDark,
            ttfBold,
          ),
          pw.SizedBox(height: 5),
          _buildExecutedTable(report.executedReports, ttfBold, ttf),
          pw.SizedBox(height: 10),
          _buildSectionHeader(
            'ثانياً: التقارير المتخلفة التي لم يقم بها المصنع اليوم',
            report.missedReports.isNotEmpty ? _dangerText : _primaryDark,
            ttfBold,
          ),
          pw.SizedBox(height: 5),
          _buildMissedSection(report.missedReports, ttfBold, ttf),
          pw.SizedBox(height: 12),
          _buildSignaturesSection(printedBy, ttfBold, ttf),
        ],
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildPdfHeader(pw.MemoryImage? headerImage) {
    if (headerImage != null) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Image(
          headerImage,
          width: PdfPageFormat.a4.width - 40,
          height: 76,
          fit: pw.BoxFit.fill,
        ),
      );
    }
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: _primaryDark, width: 1.5),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'شركة مياه وادي العين المحدودة',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _primaryDark,
            ),
          ),
          pw.Text(
            'نظام سلسال لإدارة الجودة وسلامة الغذاء',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    final nowFormatted =
        DateFormat('yyyy/MM/dd HH:mm', 'en_US').format(DateTime.now());
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 8),
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'وقت وتاريخ الطباعة: $nowFormatted',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
          ),
          pw.Text(
            'نظام سلسال للرقابة وإدارة الجودة',
            style: pw.TextStyle(font: font, fontSize: 8, color: _primaryTeal),
          ),
          pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportTitle(
    String dateStr,
    String branchName,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _primaryDark,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'تقرير متابعة وتحليل التزام المصنع بالفحوصات والتقارير اليومية',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            'المصنع: $branchName  |  تاريخ الفحص: $dateStr',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 9.5,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiSummaryRow(
    FactoryDailyComplianceReport rep,
    pw.Font fontBold,
    pw.Font font,
  ) {
    final rateColor = rep.complianceRate >= 90
        ? _successText
        : (rep.complianceRate >= 75 ? _primaryTeal : _dangerText);

    return pw.Row(
      children: [
        _buildKpiCard(
          'التقارير المقررة',
          '${rep.totalActiveReports}',
          'نموذج مفعل',
          _primaryDark,
          fontBold,
          font,
        ),
        pw.SizedBox(width: 5),
        _buildKpiCard(
          'التقارير المنفذة',
          '${rep.executedReportsCount}',
          'فحص منجز',
          _successText,
          fontBold,
          font,
        ),
        pw.SizedBox(width: 5),
        _buildKpiCard(
          'التقارير المتخلفة',
          '${rep.missedReportsCount}',
          rep.missedReportsCount > 0 ? 'لم تنفذ اليوم' : 'لا يوجد تقصير',
          rep.missedReportsCount > 0 ? _dangerText : PdfColors.grey700,
          fontBold,
          font,
        ),
        pw.SizedBox(width: 5),
        _buildKpiCard(
          'إجمالي مرات الفحص',
          '${rep.totalInspectionsCount}',
          'سجل مدخل اليوم',
          _primaryTeal,
          fontBold,
          font,
        ),
        pw.SizedBox(width: 5),
        _buildKpiCard(
          'نسبة التزام المصنع',
          '${rep.complianceRate.toStringAsFixed(1)}%',
          rep.complianceGrade,
          rateColor,
          fontBold,
          font,
        ),
      ],
    );
  }

  static pw.Widget _buildKpiCard(
    String label,
    String value,
    String sub,
    PdfColor color,
    pw.Font fontBold,
    pw.Font font,
  ) {
    final isDanger = color == _dangerText;
    final isSuccess = color == _successText;
    final bg = isDanger
        ? _dangerBg
        : (isSuccess ? _successBg : _tableRowAlt);

    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 5),
        decoration: pw.BoxDecoration(
          color: bg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(
            color: isDanger ? _dangerBorder : _borderColor,
            width: 0.6,
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                font: font,
                fontSize: 7.5,
                color: PdfColors.grey800,
              ),
              maxLines: 1,
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              value,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: color,
              ),
            ),
            pw.SizedBox(height: 1),
            pw.Text(
              sub,
              style: pw.TextStyle(
                font: font,
                fontSize: 6.5,
                color: isDanger ? _dangerText : PdfColors.grey700,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildSectionHeader(
    String title,
    PdfColor color,
    pw.Font fontBold,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: pw.BoxDecoration(
        border: pw.Border(right: pw.BorderSide(color: color, width: 3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: fontBold,
          fontSize: 9.5,
          fontWeight: pw.FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  static pw.Widget _buildExecutedTable(
    List<ReportExecutionDetail> executed,
    pw.Font fontBold,
    pw.Font font,
  ) {
    if (executed.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: _dangerBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: _dangerBorder, width: 0.5),
        ),
        child: pw.Text(
          'تنبيه: لم يتم تسجيل أي فحص أو تقرير لهذا المصنع في هذا اليوم!',
          style: pw.TextStyle(font: fontBold, fontSize: 8.5, color: _dangerText),
        ),
      );
    }

    final headers = [
      'م',
      'اسم التقرير / الفحص',
      'القسم التابع',
      'تصنيف الفحص',
      'مرات الفحص',
      'الورديات المغطاة',
      'آخر فحص',
      'المطابقة',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5), // م
        1: pw.FlexColumnWidth(3.2), // اسم التقرير
        2: pw.FlexColumnWidth(1.3), // القسم
        3: pw.FlexColumnWidth(1.3), // التصنيف
        4: pw.FlexColumnWidth(1.3), // مرات الفحص
        5: pw.FlexColumnWidth(2.0), // الورديات
        6: pw.FlexColumnWidth(1.1), // التوقيت
        7: pw.FlexColumnWidth(1.3), // المطابقة
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _tableHeaderBg),
          children: headers.map((h) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
            alignment: pw.Alignment.center,
            child: pw.Text(
              h,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _primaryDark,
              ),
            ),
          )).toList(),
        ),
        ...executed.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final r = entry.value;
          final isEven = entry.key % 2 == 0;

          final shiftsText = r.shiftsCovered.isNotEmpty
              ? r.shiftsCovered.join(' ، ')
              : 'وردية تشغيلية';

          final timeText = r.lastExecutionTime != null
              ? DateFormat('HH:mm', 'en_US').format(r.lastExecutionTime!)
              : '-';

          final compText = r.nonCompliantCount == 0
              ? 'مطابق 100%'
              : '${r.compliantCount}/${r.executionCount} مطابق';

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: isEven ? _tableRowAlt : PdfColors.white),
            children: [
              _buildTableCell('$i', fontBold, align: pw.Alignment.center),
              _buildTableCell(r.reportName, fontBold, align: pw.Alignment.centerRight),
              _buildTableCell(r.departmentName, font, align: pw.Alignment.center),
              _buildTableCell(r.sourceType.label, font, align: pw.Alignment.center),
              _buildTableCell('${r.executionCount} مرات', fontBold, align: pw.Alignment.center, textColor: _primaryDark),
              _buildTableCell(shiftsText, font, align: pw.Alignment.center),
              _buildTableCell(timeText, font, align: pw.Alignment.center),
              _buildTableCell(compText, fontBold, align: pw.Alignment.center, textColor: r.nonCompliantCount == 0 ? _successText : _dangerText),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildMissedSection(
    List<ReportExecutionDetail> missed,
    pw.Font fontBold,
    pw.Font font,
  ) {
    if (missed.isEmpty) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _successBg,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: _successText, width: 0.5),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text(
              'التزام كامل بنسبة 100% — لا توجد أية تقارير أو فحوصات متخلفة لهذا اليوم.',
              style: pw.TextStyle(font: fontBold, fontSize: 8.2, color: _successText),
            ),
          ],
        ),
      );
    }

    final headers = [
      'م',
      'اسم التقرير المتخلّف (لم يقم به المصنع اليوم)',
      'القسم الإشرافي',
      'تصنيف الفحص',
      'حالة المتابعة',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: _dangerBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(0.5),
        1: pw.FlexColumnWidth(4.2),
        2: pw.FlexColumnWidth(1.8),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(2.7),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _dangerBg),
          children: headers.map((h) => pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            alignment: pw.Alignment.center,
            child: pw.Text(
              h,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: _dangerText,
              ),
            ),
          )).toList(),
        ),
        ...missed.asMap().entries.map((entry) {
          final i = entry.key + 1;
          final r = entry.value;

          return pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
              _buildTableCell('$i', fontBold, align: pw.Alignment.center, textColor: _dangerText),
              _buildTableCell(r.reportName, fontBold, align: pw.Alignment.centerRight, textColor: _dangerText),
              _buildTableCell(r.departmentName, font, align: pw.Alignment.center),
              _buildTableCell(r.sourceType.label, font, align: pw.Alignment.center),
              _buildTableCell('متخلّف — لم يُسجل طوال اليوم', fontBold, align: pw.Alignment.center, textColor: _dangerText),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.Alignment align = pw.Alignment.centerRight,
    PdfColor textColor = PdfColors.black,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3.5),
      alignment: align,
      child: pw.Text(
        text,
        style: pw.TextStyle(font: font, fontSize: 7.2, color: textColor),
        maxLines: 2,
      ),
    );
  }

  static pw.Widget _buildSignaturesSection(
    String? printedBy,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _tableRowAlt,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: _borderColor, width: 0.5),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSignBox(
            'معد التقرير / منسق الجودة',
            printedBy ?? 'الإدارة التشغيلية',
            fontBold,
            font,
          ),
          _buildSignBox('مدير قسم الجودة وسلامة الغذاء', 'معتمد ومراجع', fontBold, font),
          _buildSignBox('مدير المصنع', 'معتمد', fontBold, font),
          _buildSignBox('اعتماد الإدارة العامة', 'ختم وتصديق رسمي', fontBold, font),
        ],
      ),
    );
  }

  static pw.Widget _buildSignBox(
    String role,
    String name,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Column(
      children: [
        pw.Text(
          role,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 7.2,
            color: _primaryDark,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          '.......................................',
          style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey500),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          name,
          style: pw.TextStyle(font: font, fontSize: 6.8, color: PdfColors.grey800),
        ),
      ],
    );
  }
}
