import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dynamic_report_pdf_generator.dart';
import '../constants/approval_status.dart';
import '../models/water_quality_models.dart';
import '../models/standards_models.dart';
import '../services/pdf/arabic_pdf_service.dart';
import '../services/user_signature_service.dart';

class FinalProductReportPdfGenerator {
  static const PdfColor _headerLightBlue = PdfColor.fromInt(0xFFBDD7EE);
  static const PdfColor _tableBorder = PdfColor.fromInt(0xFF8DB4E2);
  static const PdfColor _rowRed = PdfColor.fromInt(0xFFFFE9E9);

  static Future<void> generateAndPrintReport({
    required WaterQualityLog log,
    required List<WaterQualityResult> results,
    required Map<int, TestParameter> parameters,
    Map<int, QualityStandard>? standards,
    required String shiftName,
    required String productName,
    Uint8List? inspectorSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? microEntererSignatureBytes,
    Uint8List? microQmSignatureBytes,
    Uint8List? microGmSignatureBytes,
    Uint8List? rejectedSignatureBytes,
  }) async {
    final pdf = pw.Document();

    pw.MemoryImage? logoImage;
    try {
      final ByteData data = await rootBundle.load('assets/images/selsal_pdf_header.png');
      logoImage = pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {}

    final ByteData fontData = await rootBundle.load('assets/fonts/Tajawal-Regular.ttf');
    final ttf = pw.Font.ttf(fontData);
    final ByteData fontBoldData = await rootBundle.load('assets/fonts/Tajawal-Bold.ttf');
    final ttfBold = pw.Font.ttf(fontBoldData);

    // Auto-load signatures if not supplied
    final sigService = UserSignatureService.instance;
    inspectorSignatureBytes ??= await sigService.getSignatureBytesForUser(
      userName: log.sampleTaker?.isNotEmpty == true ? log.sampleTaker! : 'صلاح الجابري',
      userPosition: 'منفذ الفحص / أخصائي جودة',
    );
    if (qmSignatureBytes == null && (log.qmApprovedBy?.isNotEmpty == true || log.approvalStatus == 'Closed')) {
      qmSignatureBytes = await sigService.getSignatureBytesForUser(
        userName: log.qmApprovedBy?.isNotEmpty == true ? log.qmApprovedBy! : 'حمود يسر',
        userPosition: 'مدير الجودة',
      );
    }
    if (gmSignatureBytes == null && (log.gmApprovedBy?.isNotEmpty == true || log.gmDecisionBy?.isNotEmpty == true || log.approvalStatus == 'Closed')) {
      gmSignatureBytes = await sigService.getSignatureBytesForUser(
        userName: log.gmDecisionBy?.isNotEmpty == true ? log.gmDecisionBy! : (log.gmApprovedBy?.isNotEmpty == true ? log.gmApprovedBy! : 'خالد العمري'),
        userPosition: 'مدير المصنع',
      );
    }

    if (microQmSignatureBytes == null && (log.microQmApprovedBy?.isNotEmpty == true || log.approvalStatus == 'Closed')) {
      microQmSignatureBytes = await sigService.getSignatureBytesForUser(
        userName: log.microQmApprovedBy?.isNotEmpty == true ? log.microQmApprovedBy! : 'حمود يسر',
        userPosition: 'مدير الجودة',
      );
    }
    if (microGmSignatureBytes == null && (log.microGmApprovedBy?.isNotEmpty == true || log.approvalStatus == 'Closed')) {
      microGmSignatureBytes = await sigService.getSignatureBytesForUser(
        userName: log.microGmApprovedBy?.isNotEmpty == true ? log.microGmApprovedBy! : 'خالد العمري',
        userPosition: 'مدير المصنع',
      );
    }
    if (microEntererSignatureBytes == null && log.microEnteredBy != null && log.microEnteredBy!.isNotEmpty) {
      microEntererSignatureBytes = await sigService.getSignatureBytesForUser(
        userName: log.microEnteredBy!,
        userPosition: 'منفذ الفحص / أخصائي جودة',
      );
    }

    final dateStr = DateFormat('yyyy/MM/dd', 'en_US').format(log.createdAt);
    final timeStr = DateFormat('HH:mm', 'en_US').format(log.createdAt);

    // Group results
    List<WaterQualityResult> visual = [];
    List<WaterQualityResult> physio = [];
    List<WaterQualityResult> micro = [];

    for (var r in results) {
      final param = parameters[r.parameterId];
      if (param == null) continue;
      if (param.category == 'Sensory') {
        visual.add(r);
      } else if (param.category == 'Physical' ||
          param.category == 'Chemical' ||
          param.category == 'Physiochemical') {
        physio.add(r);
      } else if (param.category == 'Microbiological') {
        // لا تُدرج نتائج الميكروبيولوجي الفارغة (لم تُدخل بعد)
        final hasValue = (r.textResult ?? '').trim().isNotEmpty || r.numericResult != null;
        if (hasValue) micro.add(r);
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        textDirection: pw.TextDirection.rtl,
        header: (pw.Context context) => pw.Column(
          children: [
            _buildHeader(logoImage),
            pw.SizedBox(height: 6),
            _buildReportTitle(ttfBold),
            pw.SizedBox(height: 10),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.SizedBox(height: 6),
            _buildFooter(ttf),
          ],
        ),
        build: (pw.Context context) {
          return [
            _buildBatchData(log, dateStr, timeStr, ttf, ttfBold),
            pw.SizedBox(height: 12),
            _buildSectionLabel('ثانياً: الفحص الظاهري:', ttfBold),
            pw.SizedBox(height: 4),
            _buildResultsTable(visual, parameters, standards, ttf, ttfBold),
            pw.SizedBox(height: 12),
            _buildSectionLabel('ثالثاً: الفحوصات الفيزيائية والكيميائية:', ttfBold),
            pw.SizedBox(height: 4),
            _buildResultsTable(physio, parameters, standards, ttf, ttfBold),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColor.fromHex('#1565C0'), width: 1.2),
                borderRadius: pw.BorderRadius.circular(8),
                color: PdfColor.fromHex('#F8FBFF'),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSectionLabel('رابعاً: الفحوصات الميكروبيولوجية:', ttfBold),
                  pw.SizedBox(height: 4),
                  micro.isEmpty
                      ? _buildPendingMicroNotice(log, ttf, ttfBold)
                      : _buildResultsTable(micro, parameters, standards, ttf, ttfBold),
                  if (micro.isNotEmpty || log.approvalStatus == 'Awaiting_Micro_Results' || log.approvalStatus == 'Pending_Micro_QM' || log.approvalStatus == 'Pending_Micro_GM') ...[
                    pw.SizedBox(height: 10),
                    _buildSignaturesTable(
                      log,
                      ttf,
                      ttfBold,
                      title: 'اعتماد الفحوصات الميكروبيولوجية',
                      isMicro: true,
                      inspectorSignatureBytes: microEntererSignatureBytes ?? inspectorSignatureBytes,
                      qmSignatureBytes: microQmSignatureBytes,
                      gmSignatureBytes: microGmSignatureBytes,
                      rejectedSignatureBytes: rejectedSignatureBytes,
                    ),
                  ],
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            _buildComplianceSection(log, ttf, ttfBold),
            pw.SizedBox(height: 12),
            _buildNotesSection(log, ttf, ttfBold),
            pw.Spacer(),
            _buildSignaturesTable(
              log,
              ttf,
              ttfBold,
              title: 'اعتماد الفحوصات الظاهرية، الفيزيائية والكيميائية',
              isMicro: false,
              inspectorSignatureBytes: inspectorSignatureBytes,
              qmSignatureBytes: qmSignatureBytes,
              gmSignatureBytes: gmSignatureBytes,
              rejectedSignatureBytes: rejectedSignatureBytes,
            ),
            pw.SizedBox(height: 8),
            _buildStandardNotice(ttf),
          ];
        },
      ),
    );

    final String dateString = DateFormat('yyyyMMdd_HHmm').format(log.createdAt);
    await Printing.layoutPdf(
      format: PdfPageFormat.a4,
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Final_Product_Report_$dateString.pdf',
    );
  }

  static pw.Widget _buildHeader(pw.MemoryImage? logoImage) {
    if (logoImage == null) return pw.SizedBox(height: 76);

    // This is the original header artwork extracted from SELSAL-IMSF-19-02,
    // retaining its exact logo, green end-cap, blue band, and proportions.
    return pw.Image(
      logoImage,
      width: PdfPageFormat.a4.width - 48,
      height: 76,
      fit: pw.BoxFit.fill,
    );
  }

  static pw.Widget _buildReportTitle(pw.Font ttfBold) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: const PdfColor.fromInt(0xFF173A5E), width: 1.2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: const PdfColor.fromInt(0xFFD6E6F5),
        ),
        child: pw.Text(
          ArabicPdfService.cleanArabicText('تقرير فحص المنتج النهائي'),
          style: pw.TextStyle(
            font: ttfBold,
            fontSize: 16,
            color: PdfColors.black,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildSectionLabel(String text, pw.Font ttfBold) {
    return pw.Text(
      ArabicPdfService.cleanArabicText(text),
      style: pw.TextStyle(
        font: ttfBold,
        fontSize: 11,
        color: PdfColors.black,
      ),
    );
  }

  /// تنبيه يُعرض في قسم الفحوصات الميكروبيولوجية عندما لم تُدخل نتائجها بعد
  /// (المرحلة الثانية — تصل خلال 24 ساعة من أخذ العينة).
  static pw.Widget _buildPendingMicroNotice(
    WaterQualityLog log,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    final awaiting = log.approvalStatus == 'Awaiting_Micro_Results';
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.teal50,
        border: pw.Border.all(color: PdfColors.teal200, width: 0.7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 1),
            padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal100,
              borderRadius: pw.BorderRadius.circular(3),
            ),
            child: pw.Text(
              ArabicPdfService.cleanArabicText('ميكروبيولوجي'),
              style: pw.TextStyle(font: ttfBold, fontSize: 7, color: PdfColors.teal900),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              ArabicPdfService.cleanArabicText(
                awaiting
                    ? 'بانتظار إدخال النتائج — تصل خلال 24 ساعة من أخذ العينة وستتطلب جولة اعتماد ثانية.'
                    : 'لم تُسجَّل نتائج للفحوصات الميكروبيولوجية بعد.',
              ),
              style: pw.TextStyle(font: ttf, fontSize: 9.5, color: PdfColors.teal900),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildBatchData(
    WaterQualityLog log,
    String dateStr,
    String timeStr,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    final location = log.samplingLocation ?? 'أثناء التشغيل';
    final isStart = location == 'بداية التشغيل';
    final isDuring = location == 'أثناء التشغيل';
    final isEnd = location == 'نهاية التشغيل';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('أولاً: بيانات التشغيلة:', ttfBold),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3),
            1: const pw.FlexColumnWidth(1.5),
          },
          children: [
            _buildTableRow2Col('اسم المنتج', log.productName ?? 'مصنع سلسال للمياة المعبأة (وادي العين)', ttf, ttfBold),
            _buildTableRow2Col('حجم العبوة', log.bottleSize ?? '330 مل', ttf, ttfBold),
            _buildTableRow2Col('رقم التشغيلة', log.batchNumber ?? '-', ttf, ttfBold),
            _buildTableRow2Col('تاريخ الإنتاج', log.productionDate ?? dateStr, ttf, ttfBold),
            _buildTableRow2Col('وقت أخذ العينة', log.samplingTime ?? timeStr, ttf, ttfBold),
            pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                    children: [
                      _buildCheckbox('بداية التشغيل', isStart, ttf),
                      _buildCheckbox('أثناء التشغيل', isDuring, ttf),
                      _buildCheckbox('نهاية التشغيل', isEnd, ttf),
                    ],
                  ),
                ),
                pw.Container(
                  color: _headerLightBlue,
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(ArabicPdfService.cleanArabicText('مكان أخذ العينة'), style: pw.TextStyle(font: ttfBold, fontSize: 9)),
                ),
              ],
            ),
            _buildTableRow2Col('الكمية المنتجة', log.producedQuantity ?? '5000 كرتون', ttf, ttfBold),
            _buildTableRow2Col('اسم آخذ العينة', log.sampleTaker ?? 'صلاح الجابري', ttf, ttfBold),
          ],
        ),
      ],
    );
  }

  static pw.TableRow _buildTableRow2Col(String label, String value, pw.Font ttf, pw.Font ttfBold) {
    return pw.TableRow(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: pw.Text(ArabicPdfService.cleanArabicText(value), style: pw.TextStyle(font: ttf, fontSize: 9)),
        ),
        pw.Container(
          color: _headerLightBlue,
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          alignment: pw.Alignment.centerRight,
          child: pw.Text(ArabicPdfService.cleanArabicText(label), style: pw.TextStyle(font: ttfBold, fontSize: 9)),
        ),
      ],
    );
  }

  static pw.Widget _buildResultsTable(
    List<WaterQualityResult> resultsList,
    Map<int, TestParameter> parameters,
    Map<int, QualityStandard>? standards,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.5),
        1: const pw.FlexColumnWidth(1.2),
        2: const pw.FlexColumnWidth(1.8),
        3: const pw.FlexColumnWidth(2.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerLightBlue),
          children: [
            _buildHeaderCell('الملاحظات', ttfBold),
            _buildHeaderCell('النتيجة', ttfBold),
            _buildHeaderCell('معيار القبول', ttfBold),
            _buildHeaderCell('الفحص', ttfBold),
          ],
        ),
        ...resultsList.map((r) {
          final param = parameters[r.parameterId];
          final paramName = param != null ? param.nameAr : '-';
          final unit = (param?.unit != null && param!.unit!.isNotEmpty) ? ' ${param.unit}' : '';
          final resultText = r.numericResult != null
              ? '${r.numericResult}$unit'
              : (r.textResult ?? '-');

          String standardLimit = _formatStandard(standards?[r.parameterId], param?.unit);
          if (standardLimit.isEmpty) {
            standardLimit = _getStandardLimitText(paramName);
          }

          final isRowRed = !r.isCompliant;

          return pw.TableRow(
            decoration: isRowRed ? const pw.BoxDecoration(color: _rowRed) : null,
            children: [
              _buildDataCell(r.notes ?? '', ttf, isRed: isRowRed),
              _buildDataCell(resultText, ttfBold, align: pw.TextAlign.center, isRed: isRowRed),
              _buildDataCell(standardLimit, ttf, align: pw.TextAlign.center),
              _buildDataCell(paramName, ttfBold),
            ],
          );
        }),
      ],
    );
  }

  static String _formatStandard(QualityStandard? std, String? unit) {
    if (std == null) return '';
    final unitSuffix = (unit != null && unit.isNotEmpty) ? ' $unit' : '';
    if (std.expectedText != null && std.expectedText!.isNotEmpty) {
      return std.expectedText!;
    }
    if (std.minValue != null && std.maxValue != null) {
      return '${std.minValue} - ${std.maxValue}$unitSuffix';
    }
    if (std.maxValue != null) {
      return '< ${std.maxValue}$unitSuffix';
    }
    if (std.minValue != null) {
      return '> ${std.minValue}$unitSuffix';
    }
    return '';
  }

  static String _getStandardLimitText(String paramName) {
    if (paramName.contains('المواد الغريبة') || paramName.contains('الشوائب')) return 'خالية تماماً';
    if (paramName.contains('المظهر')) return 'طبيعي';
    if (paramName.contains('سلامة العبوة')) return 'بدون تشققات أو تشوهات';
    if (paramName.contains('إحكام الغلق')) return 'لا يوجد تسريب';
    if (paramName.contains('نظافة العبوة')) return 'نظيفة';
    if (paramName.contains('جودة الطباعة')) return 'واضحة';
    if (paramName.contains('رقم التشغيلة')) return 'صحيح';
    if (paramName.contains('تاريخ الإنتاج')) return 'صحيح';
    if (paramName.contains('تاريخ الانتهاء')) return 'صحيح';
    if (paramName.contains('البطاقة التعريفية')) return 'مطابقة';
    if (paramName.contains('التغليف النهائي')) return 'مطابق';

    if (paramName.contains('اللون')) return 'عديم اللون';
    if (paramName.contains('الطعم')) return 'مستساغ';
    if (paramName.contains('الرائحة')) return 'مقبولة';
    if (paramName.contains('العكارة')) return '1 وحدة (NTU) أو < 5';
    if (paramName.contains('درجة الحرارة')) return '-';
    if (paramName.contains('pH') || paramName.contains('الرقم الهيدروجيني')) return '6.5 - 8.5';
    if (paramName.contains('TDS') || paramName.contains('الصلبة الذائبة')) return '100 - 500 mg/l';
    if (paramName.contains('التوصيلية')) return '-';
    if (paramName.contains('العسر الكلي')) return '< 500 mg/l';
    if (paramName.contains('القلوية الكلية')) return '< 200 mg/l';
    if (paramName.contains('الكالسيوم')) return '< 350 mg/l';
    if (paramName.contains('المغنسيوم')) return '< 150 mg/l';
    if (paramName.contains('البوتاسيوم')) return '1 - 10 mg/l';
    if (paramName.contains('الصوديوم')) return '< 200 mg/l';
    if (paramName.contains('الفلورايد')) return '0.7 - 1.5 mg/l';
    if (paramName.contains('الكلورايد')) return '< 250 mg/l';
    if (paramName.contains('الحديد')) return '< 0.3 mg/l';
    if (paramName.contains('النترات')) return '< 50 mg/l';
    if (paramName.contains('الكبريتات')) return '< 250 mg/l';
    if (paramName.contains('البيكربونات')) return '< 250 mg/l';
    if (paramName.contains('الأوزون')) return '0.25 - 0.45 mg/l';
    if (paramName.contains('الكلور')) return '0.2 - 0.5 ppm';

    if (paramName.contains('البكتيريا') || paramName.contains('TPC')) return 'خالية تماماً';
    if (paramName.contains('القولونيات')) return 'خالية تماماً';
    if (paramName.contains('E. coli')) return 'خالية تماماً';
    if (paramName.contains('الخمائر') || paramName.contains('الفطريات')) return 'خالية تماماً';

    return '-';
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font ttfBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        ArabicPdfService.cleanArabicText(text),
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: ttfBold, fontSize: 8.5),
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.right,
    bool isRed = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2.5),
      child: pw.Text(
        ArabicPdfService.cleanArabicText(text),
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 8,
          color: isRed ? PdfColors.red900 : PdfColors.black,
        ),
      ),
    );
  }

  static pw.Widget _buildComplianceSection(WaterQualityLog log, pw.Font ttf, pw.Font ttfBold) {
    final isComp = log.isCompliant;
    final isIsolated = log.isIsolated == true;
    final isHold = log.isHoldIssued == true;
    final isReject = log.isRejectIssued == true;
    final ncr = log.ncrNumber ?? '';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('- في حالة عدم المطابقة:', ttfBold),
              pw.SizedBox(height: 3),
              _buildCheckbox('تم العزل.', isIsolated, ttf),
              pw.SizedBox(height: 2),
              _buildCheckbox('تم إصدار بطاقة HOLD', isHold, ttf),
              pw.SizedBox(height: 2),
              _buildCheckbox('تم إصدار بطاقة REJECT', isReject, ttf),
              pw.SizedBox(height: 2),
              pw.Row(
                children: [
                  _buildCheckbox('تم فتح NCR رقم: ', ncr.isNotEmpty, ttf),
                  pw.Text(ncr.isNotEmpty ? ncr : '________________', style: pw.TextStyle(font: ttf, fontSize: 8.5)),
                ],
              ),
            ],
          ),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildSectionLabel('- قرار المطابقة:', ttfBold),
              pw.SizedBox(height: 4),
              _buildCheckbox('المنتج مطابق للمواصفات.', isComp, ttf),
              pw.SizedBox(height: 4),
              _buildCheckbox('المنتج غير مطابق.', !isComp, ttf),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildCheckbox(String text, bool isChecked, pw.Font font) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 10,
          height: 10,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: isChecked ? PdfColors.grey800 : PdfColors.grey600, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
            color: isChecked ? const PdfColor.fromInt(0xFFE8F5E9) : PdfColors.white,
          ),
          alignment: pw.Alignment.center,
          child: isChecked
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(1.0),
                  child: pw.SvgImage(
                    svg: '<svg viewBox="0 0 24 24"><path fill="none" stroke="#2E7D32" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" d="M4 12.5l5.5 5.5L20 6.5"/></svg>',
                  ),
                )
              : null,
        ),
        pw.SizedBox(width: 4),
        pw.Text(ArabicPdfService.cleanArabicText(text), style: pw.TextStyle(font: font, fontSize: 8.5)),
      ],
    );
  }

  static pw.Widget _buildNotesSection(WaterQualityLog log, pw.Font ttf, pw.Font ttfBold) {
    final hasRejection = log.rejectionReason != null && log.rejectionReason!.isNotEmpty;
    final rejector = log.rejectedBy ?? 'المعتمد';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('- الملاحظات:', ttfBold),
        pw.SizedBox(height: 2),
        if (hasRejection)
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            margin: const pw.EdgeInsets.only(bottom: 4),
            decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFFFEBEE),
              border: pw.Border.all(color: PdfColors.red, width: 0.5),
            ),
            child: pw.Text(
              '[تنبيه] ملاحظة الرفض ($rejector): ${log.rejectionReason}',
              style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: PdfColors.red900),
            ),
          ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          ),
          child: pw.Text(
            ArabicPdfService.cleanArabicText(
              log.generalNotes != null && log.generalNotes!.isNotEmpty
                  ? log.generalNotes!
                  : 'لا توجد ملاحظات إضافية.',
            ),
            style: pw.TextStyle(font: ttf, fontSize: 8.5),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignaturesTable(
    WaterQualityLog log,
    pw.Font ttf,
    pw.Font ttfBold, {
    required String title,
    required bool isMicro,
    Uint8List? inspectorSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? rejectedSignatureBytes,
  }) {
    String sampleTakerName = log.sampleTaker ?? 'صلاح الجابري';
    // المرحلة الأولى (اعتماد مبدئي بدون الميكروبيولوجي)
    bool isQmDone = log.approvalStatus == 'Approved' ||
        log.approvalStatus == 'Pending_GM' ||
        ApprovalStatus.isMicroStage(log.approvalStatus) ||
        (log.stage1QmApprovedBy ?? log.qmApprovedBy ?? '').isNotEmpty;
    bool isGmDone = log.approvalStatus == 'Approved' ||
        log.approvalStatus == 'Awaiting_Micro_Results' ||
        log.approvalStatus == 'Pending_Micro_GM' ||
        (log.stage1GmApprovedBy ?? log.gmApprovedBy ?? '').isNotEmpty;

    final isQmRejected = !ApprovalStatus.isMicroRejected(log.approvalStatus) &&
        ApprovalStatus.rejectedByQualityManager(
          rejectedBy: log.rejectedBy,
          gmDecisionBy: log.gmDecisionBy,
          status: log.approvalStatus,
        );
    final isGmRejected = !ApprovalStatus.isMicroRejected(log.approvalStatus) &&
        ApprovalStatus.rejectedByFactoryManager(
          rejectedBy: log.rejectedBy,
          gmDecisionBy: log.gmDecisionBy,
          status: log.approvalStatus,
        );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: log.qmApprovedBy,
      microQmApprovedBy: log.microQmApprovedBy,
      rejectedBy: log.rejectedBy,
      gmDecisionBy: log.gmDecisionBy,
      status: log.approvalStatus,
    );
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: log.rejectedBy,
      gmDecisionBy: log.gmDecisionBy,
      status: log.approvalStatus,
    );

    final isClosed = log.approvalStatus == 'Closed';
    String qmName = isClosed
        ? (log.qmApprovedBy ?? log.microQmApprovedBy ?? 'حمود يسر')
        : (log.qmApprovedBy ?? (isQmDone || wasQmApproved ? 'حمود يسر' : '________________'));
    String gmName = isClosed
        ? (log.gmDecisionBy ?? log.gmApprovedBy ?? log.microGmApprovedBy ?? 'خالد العمري')
        : (log.gmApprovedBy ?? (isGmDone ? 'خالد العمري' : '________________'));

    if (!isClosed && (isQmRejected || wasQmRejected)) {
      qmName = log.rejectedBy ?? 'مدير الجودة';
    }
    if (!isClosed && isGmRejected) {
      gmName = log.gmDecisionBy ?? log.rejectedBy ?? 'مدير المصنع';
    }

    DateTime? effectiveQmDate = log.qmApprovedAt;
    DateTime? effectiveGmDate = log.gmApprovedAt;
    String entryDate = DateFormat('yyyy/MM/dd').format(log.createdAt);

    if (isMicro) {
      sampleTakerName = log.microEnteredBy ?? sampleTakerName;
      isQmDone = log.approvalStatus == 'Approved' || log.approvalStatus == 'Pending_Micro_GM';
      isGmDone = log.approvalStatus == 'Approved';
      if (!isClosed) {
        qmName = isQmRejected ? (log.rejectedBy ?? 'مدير الجودة') : (log.microQmApprovedBy ?? (isQmDone || wasQmApproved ? 'حمود يسر' : '________________'));
        gmName = isGmRejected ? (log.gmDecisionBy ?? log.rejectedBy ?? 'مدير المصنع') : (log.microGmApprovedBy ?? (isGmDone ? 'خالد العمري' : '________________'));
      }
      effectiveQmDate = log.microQmApprovedAt ?? log.qmApprovedAt;
      effectiveGmDate = log.microGmApprovedAt ?? log.gmApprovedAt;
      entryDate = log.microEnteredAt != null ? DateFormat('yyyy/MM/dd').format(log.microEnteredAt!) : entryDate;
    }

    final qmDate = isClosed
        ? (effectiveQmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveQmDate) : 'معتمد سابقاً')
        : (effectiveQmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveQmDate) : (isQmDone || wasQmApproved || isQmRejected ? 'معتمد' : '  /  / 2026م'));
    final gmDate = isClosed
        ? (effectiveGmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveGmDate) : 'معتمد بعد إجراء تصحيحي')
        : (effectiveGmDate != null ? DynamicReportPdfGenerator.formatArabicDate(effectiveGmDate) : (isGmDone || isGmRejected ? 'معتمد' : '  /  / 2026م'));

    final qmSig = isClosed
        ? 'التوقيع: [معتمد سابقاً]'
        : ((isQmRejected || wasQmRejected)
            ? '[مرفوض]'
            : (isQmDone
                ? 'التوقيع: [معتمد إلكترونياً]'
                : (wasQmApproved
                    ? 'التوقيع: [معتمد سابقاً - أُلغي برفض الإدارة]'
                    : 'التوقيع: .....................')));
    final gmSig = isClosed
        ? 'التوقيع: [معتمد بعد إجراء تصحيحي]'
        : (isGmRejected ? '[مرفوض]' : (isGmDone ? 'التوقيع: [معتمد إلكترونياً]' : 'التوقيع: .....................'));
    const inspectorSig = 'التوقيع: [معتمد إلكترونياً]';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(ArabicPdfService.cleanArabicText(title), style: pw.TextStyle(font: ttfBold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Table(
          border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _headerLightBlue),
              children: [
                _buildHeaderCell('اعتماد مدير المصنع', ttfBold),
                _buildHeaderCell('مدير الجودة', ttfBold),
                _buildHeaderCell('منفذ الفحص', ttfBold),
              ],
            ),
            pw.TableRow(
              children: [
                _buildSignatureCell(rawName: gmName, sig: gmSig, date: 'التاريخ: $gmDate', ttf: ttf, ttfBold: ttfBold, signatureBytes: isGmRejected ? rejectedSignatureBytes : (isClosed || isGmDone ? gmSignatureBytes : null), isRejected: isGmRejected, isApproved: isClosed),
                _buildSignatureCell(rawName: qmName, sig: qmSig, date: 'التاريخ: $qmDate', ttf: ttf, ttfBold: ttfBold, signatureBytes: (isQmRejected || wasQmRejected) ? rejectedSignatureBytes : ((isClosed || isQmDone || wasQmApproved) ? qmSignatureBytes : null), isRejected: (isQmRejected || wasQmRejected), isVoided: isClosed || wasQmApproved),
                _buildSignatureCell(rawName: sampleTakerName, sig: inspectorSig, date: 'التاريخ: $entryDate', ttf: ttf, ttfBold: ttfBold, signatureBytes: inspectorSignatureBytes),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildSignatureCell({
    required String rawName,
    required String sig,
    required String date,
    required pw.Font ttf,
    required pw.Font ttfBold,
    Uint8List? signatureBytes,
    bool isRejected = false,
    bool isVoided = false,
    bool isApproved = false,
  }) {
    final parsed = ArabicPdfService.splitNameAndRole(rawName);

    final pdfRed = PdfColor.fromHex('#C62828');
    final pdfAmber = PdfColor.fromHex('#E65100');
    final pdfGreen = PdfColor.fromHex('#2E7D32');
    final titleColor = isRejected ? pdfRed : (isVoided ? pdfAmber : (isApproved ? pdfGreen : PdfColors.black));
    final sigColor = isRejected ? pdfRed : (isVoided ? pdfAmber : (isApproved || sig.contains('معتمد') ? pdfGreen : PdfColors.black));

    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('الاسم: ${parsed.name}', style: pw.TextStyle(font: ttfBold, fontSize: 8, color: titleColor)),
              if (parsed.role != null) ...[
                pw.SizedBox(height: 1),
                pw.Text(parsed.role!, style: pw.TextStyle(font: ttf, fontSize: 6.5, color: isRejected ? titleColor : PdfColors.grey700)),
              ],
              pw.SizedBox(height: 2),
              pw.Text(
                sig,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 8,
                  color: sigColor,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(date, style: pw.TextStyle(font: ttf, fontSize: 8, color: titleColor)),
            ],
          ),
          if (signatureBytes != null)
            pw.Positioned.fill(
              child: pw.Opacity(
                opacity: 0.42,
                child: pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(signatureBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildStandardNotice(pw.Font ttf) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(ArabicPdfService.cleanArabicText('- ملاحظة:'), style: pw.TextStyle(font: ttf, fontSize: 7.5, color: PdfColors.grey800)),
        pw.Text(ArabicPdfService.cleanArabicText('- كل الفحوصات وفق اشتراطات المواصفة القياسية اليمنية المعتمدة لمياه الشرب المعبأ 2620:2024 YSMO.'), style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700)),
        pw.Text(ArabicPdfService.cleanArabicText('- تدرج فقط الاختبارات التي يقرر المصنع تنفيذها ضمن برنامج المراقبة، أو وفق المواصفة القياسية اليمنية وخطة الـ HACCP.'), style: pw.TextStyle(font: ttf, fontSize: 7, color: PdfColors.grey700)),
      ],
    );
  }

  static pw.Widget _buildFooter(pw.Font ttf) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(ArabicPdfService.cleanArabicText('رقم الوثيقة: SELSAL-IMSF-19-05'), style: pw.TextStyle(font: ttf, fontSize: 7.5)),
          pw.Text(ArabicPdfService.cleanArabicText('تاريخ الاصدار: 2026/07/15'), style: pw.TextStyle(font: ttf, fontSize: 7.5)),
          pw.Text(ArabicPdfService.cleanArabicText('إصدار رقم: 01'), style: pw.TextStyle(font: ttf, fontSize: 7.5)),
        ],
      ),
    );
  }
}
