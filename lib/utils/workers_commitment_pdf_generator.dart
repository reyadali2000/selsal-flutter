import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/worker_commitment_models.dart';
import '../services/pdf/arabic_pdf_service.dart';

class WorkersCommitmentPdfGenerator {
  static const PdfColor _primaryDark = PdfColor.fromInt(0xFF1B365D);
  static const PdfColor _primaryLight = PdfColor.fromInt(0xFF00A3E0);
  static const PdfColor _tableHeaderBg = PdfColor.fromInt(0xFFEBF3FB);
  static const PdfColor _tableRowAlt = PdfColor.fromInt(0xFFF9FBFE);
  static const PdfColor _borderColor = PdfColor.fromInt(0xFFD0D7DE);

  static Future<Uint8List> generateMonthlyReportBytes({
    required int year,
    required int month,
    required String branchName,
    required List<WorkerMonthlyCommitment> workers,
    required WorkersCommitmentKPISummary kpiSummary,
    String? supervisorName,
  }) async {
    final pdf = pw.Document();

    // Load Header & Fonts
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

    final monthNames = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final monthLabel = (month >= 1 && month <= 12)
        ? '${monthNames[month - 1]} $year'
        : '$month / $year';

    pdf.addPage(
      pw.MultiPage(
        theme: arabicTheme,
        textDirection: pw.TextDirection.rtl,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        header: (context) => _buildPdfHeader(headerImage),
        footer: (context) => _buildPdfFooter(context, ttf),
        build: (context) => [
          pw.SizedBox(height: 6),
          _buildReportTitle(monthLabel, branchName, ttfBold),
          pw.SizedBox(height: 8),
          _buildKpiSummaryRow(kpiSummary, ttfBold, ttf),
          pw.SizedBox(height: 10),
          _buildWorkersTable(workers, ttfBold, ttf),
          pw.SizedBox(height: 14),
          _buildSignaturesSection(supervisorName, ttfBold, ttf),
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
        border: pw.Border(bottom: pw.BorderSide(color: _primaryDark, width: 1.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'شركة مياه وادي العين المحدودة',
            style: pw.TextStyle(fontSize: 13, color: _primaryDark),
          ),
          pw.Text(
            'نظام إدارة الجودة وسلامة الغذاء',
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildReportTitle(
      String monthLabel, String branchName, pw.Font fontBold) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: _primaryDark,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'تقرير متابعة التزام العمالة اليومية والورديات (مشتق من النظافة الشخصية)',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 10.5,
              color: PdfColors.white,
            ),
          ),
          pw.Text(
            'الفترة: $monthLabel | $branchName',
            style: pw.TextStyle(
              font: fontBold,
              fontSize: 10,
              color: PdfColors.white,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiSummaryRow(
    WorkersCommitmentKPISummary kpi,
    pw.Font fontBold,
    pw.Font font,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: pw.BoxDecoration(
        color: _tableHeaderBg,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: _borderColor),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildKpiCell('أيام العمل', '${kpi.targetWorkingDays} يوم', fontBold, font),
          _buildKpiDivider(),
          _buildKpiCell('العمال الحاضرون', '${kpi.totalAttendedWorkers} عامل', fontBold, font),
          _buildKpiDivider(),
          _buildKpiCell('معدل الحضور', '${kpi.avgAttendanceRate}%', fontBold, font),
          _buildKpiDivider(),
          _buildKpiCell('مطابقة النظافة', '${kpi.avgHygieneScore}%', fontBold, font),
          _buildKpiDivider(),
          _buildKpiCell('إجمالي الورديات', '${kpi.totalShiftsCovered} وردية', fontBold, font),
        ],
      ),
    );
  }

  static pw.Widget _buildKpiDivider() {
    return pw.Container(
      height: 20,
      width: 1,
      color: _borderColor,
    );
  }

  static pw.Widget _buildKpiCell(
      String label, String value, pw.Font fontBold, pw.Font font) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 9.5,
            color: _primaryDark,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildWorkersTable(
    List<WorkerMonthlyCommitment> workers,
    pw.Font fontBold,
    pw.Font font,
  ) {
    final headers = [
      'م',
      'اسم العامل',
      'المسمى الوظيفي',
      'الحضور',
      'و 1',
      'و 2',
      'و 3',
      'نسبة الحضور',
      'النظافة',
      'المخالفات',
      'مؤشر الالتزام',
      'التقدير',
    ];

    final rows = workers.map((w) {
      final rankText = w.rank > 0 ? '#${w.rank}' : '-';
      return [
        rankText,
        w.fullName,
        w.jobTitle,
        '${w.daysPresent}/${w.targetWorkingDays}',
        '${w.shift1Count}',
        '${w.shift2Count}',
        '${w.shift3Count}',
        '${w.attendanceRate}%',
        '${w.avgHygieneScore}%',
        '${w.totalViolations}',
        '${w.compositeCommitmentScore}%',
        w.commitmentGrade.replaceAll(RegExp(r'[⭐⚠️]'), '').trim(),
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      border: pw.TableBorder.all(color: _borderColor, width: 0.5),
      headerStyle: pw.TextStyle(font: fontBold, fontSize: 7.5, color: _primaryDark),
      headerDecoration: const pw.BoxDecoration(color: _tableHeaderBg),
      headerAlignment: pw.Alignment.center,
      cellStyle: pw.TextStyle(font: font, fontSize: 7),
      cellAlignment: pw.Alignment.center,
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 3),
      rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
      oddRowDecoration: const pw.BoxDecoration(color: _tableRowAlt),
      columnWidths: {
        0: const pw.FixedColumnWidth(18), // م
        1: const pw.FlexColumnWidth(2.2), // الاسم
        2: const pw.FlexColumnWidth(1.6), // المسمى
        3: const pw.FixedColumnWidth(38), // أيام الحضور
        4: const pw.FixedColumnWidth(22), // و 1
        5: const pw.FixedColumnWidth(22), // و 2
        6: const pw.FixedColumnWidth(22), // و 3
        7: const pw.FixedColumnWidth(36), // نسبة الحضور
        8: const pw.FixedColumnWidth(34), // النظافة
        9: const pw.FixedColumnWidth(22), // المخالفات
        10: const pw.FixedColumnWidth(38), // المؤشر
        11: const pw.FlexColumnWidth(1.2), // التقدير
      },
    );
  }

  static pw.Widget _buildSignaturesSection(
      String? supervisorName, pw.Font fontBold, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _buildSignatureBox(
            title: 'إعداد / مفتش الجودة والسلامة',
            name: supervisorName ?? 'صلاح الجابري',
            fontBold: fontBold,
            font: font,
          ),
          _buildSignatureBox(
            title: 'مراجعة / مدير توكيد الجودة',
            name: 'حمود يسر',
            fontBold: fontBold,
            font: font,
          ),
          _buildSignatureBox(
            title: 'اعتماد / مدير المصنع',
            name: 'خالد العمري',
            fontBold: fontBold,
            font: font,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatureBox({
    required String title,
    required String name,
    required pw.Font fontBold,
    required pw.Font font,
  }) {
    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _borderColor, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(font: fontBold, fontSize: 8, color: _primaryDark),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            name,
            style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.black),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: 90,
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'التوقيع والختم',
            style: pw.TextStyle(font: font, fontSize: 6.5, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context, pw.Font font) {
    final nowStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 6),
      padding: const pw.EdgeInsets.only(top: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _borderColor, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'تم استخراج التقرير آلياً عبر نظام إدارة الجودة وسلامة الغذاء - $nowStr',
            style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(
            'صفحة ${context.pageNumber} من ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  static Future<void> printMonthlyReport({
    required int year,
    required int month,
    required String branchName,
    required List<WorkerMonthlyCommitment> workers,
    required WorkersCommitmentKPISummary kpiSummary,
    String? supervisorName,
  }) async {
    final bytes = await generateMonthlyReportBytes(
      year: year,
      month: month,
      branchName: branchName,
      workers: workers,
      kpiSummary: kpiSummary,
      supervisorName: supervisorName,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => bytes,
      name: 'تقرير_التزام_العمالة_${year}_$month',
    );
  }
}
