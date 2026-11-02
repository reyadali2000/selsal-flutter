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

class RawWaterReportPdfGenerator {
  static const PdfColor _headerLightBlue = PdfColor.fromInt(0xFFBDD7EE);
  static const PdfColor _tableBorder = PdfColor.fromInt(0xFF8DB4E2);
  static const PdfColor _rowRed = PdfColor.fromInt(0xFFFFE9E9);

  static Future<void> generateAndPrintReport({
    required WaterQualityLog log,
    required List<WaterQualityResult> results,
    required Map<int, TestParameter> parameters,
    required Map<int, QualityStandard> standards,
    required String shiftName,
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
      userName: log.sampleTaker?.isNotEmpty == true ? log.sampleTaker! : 'أخصائي الجودة',
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

    // Split results by category
    List<WaterQualityResult> sensory = [];
    List<WaterQualityResult> physio = [];
    List<WaterQualityResult> micro = [];

    for (var r in results) {
      final param = parameters[r.parameterId];
      if (param == null) continue;
      if (param.category == 'Sensory') {
        sensory.add(r);
      } else if (param.category == 'Physical' || param.category == 'Chemical' || param.category == 'Physiochemical') {
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
            pw.SizedBox(height: 8),
            _buildReportTitle(ttfBold),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (pw.Context context) => pw.Column(
          children: [
            pw.SizedBox(height: 8),
            _buildFooter(ttf),
          ],
        ),
        build: (pw.Context context) {
          return [
            _buildSampleData(log, dateStr, timeStr, ttf, ttfBold),
            pw.SizedBox(height: 14),
            _buildSectionLabel('ثانياً: الفحص الحسي:', ttfBold),
            pw.SizedBox(height: 6),
            _buildResultsTable(sensory, parameters, standards, ttf, ttfBold),
            pw.SizedBox(height: 14),
            _buildSectionLabel('ثالثاً: الفحوصات الفيزيائية والكيميائية:', ttfBold),
            pw.SizedBox(height: 6),
            _buildResultsTable(physio, parameters, standards, ttf, ttfBold),
            pw.SizedBox(height: 14),
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
                  pw.SizedBox(height: 6),
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
            pw.SizedBox(height: 16),
            _buildComplianceSection(log, ttf, ttfBold),
            pw.SizedBox(height: 14),
            _buildNotesSection(log, ttf, ttfBold),
            pw.SizedBox(height: 20),
            pw.Spacer(),
            _buildSignaturesTable(
              log,
              ttf,
              ttfBold,
              title: 'اعتماد الفحوصات الفيزيائية والكيميائية',
              isMicro: false,
              inspectorSignatureBytes: inspectorSignatureBytes,
              qmSignatureBytes: qmSignatureBytes,
              gmSignatureBytes: gmSignatureBytes,
              rejectedSignatureBytes: rejectedSignatureBytes,
            ),
          ];
        },
      ),
    );

    final String dateString = DateFormat('yyyyMMdd_HHmm').format(log.createdAt);
    await Printing.layoutPdf(
      format: PdfPageFormat.a4,
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Raw_Water_Report_$dateString.pdf',
    );
  }

  static pw.Widget _buildHeader(pw.MemoryImage? logoImage) {
    if (logoImage == null) return pw.SizedBox(height: 76);

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
        padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: const PdfColor.fromInt(0xFF173A5E), width: 1.2),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: const PdfColor.fromInt(0xFFD6E6F5),
        ),
        child: pw.Text(
          'تقرير فحص المياه الخام',
          style: pw.TextStyle(font: ttfBold, fontSize: 16),
        ),
      ),
    );
  }

  static pw.Widget _buildSectionLabel(String text, pw.Font ttfBold) {
    return pw.Text(
      ArabicPdfService.cleanArabicText(text),
      style: pw.TextStyle(
        font: ttfBold,
        fontSize: 12,
        decoration: pw.TextDecoration.underline,
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


  static pw.Widget _buildSampleData(WaterQualityLog log, String dateStr, String timeStr, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('أولاً: بيانات العينة:', ttfBold),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: _tableBorder),
          columnWidths: {
            0: const pw.FlexColumnWidth(2),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(1),
          },
          children: [
            pw.TableRow(children: [
              _sampleCell(timeStr, ttf),
              _sampleCell('الوقت', ttfBold, isLabel: true),
              _sampleCell(dateStr, ttf),
              _sampleCell('التاريخ', ttfBold, isLabel: true),
            ]),
            pw.TableRow(children: [
              _sampleCell(log.wellNumber ?? '', ttf),
              _sampleCell('رقم البئر (إن وجد)', ttfBold, isLabel: true),
              _sampleCell(log.waterSource ?? '', ttf),
              _sampleCell('مصدر المياه', ttfBold, isLabel: true),
            ]),
            pw.TableRow(children: [
              _sampleCell(log.batchNumber ?? '', ttf),
              _sampleCell('رقم العينة', ttfBold, isLabel: true),
              _sampleCell(log.sampleTaker ?? '', ttf),
              _sampleCell('اسم آخذ العينة', ttfBold, isLabel: true),
            ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _sampleCell(String text, pw.Font font, {bool isLabel = false}) {
    return pw.Container(
      color: isLabel ? _headerLightBlue : PdfColors.white,
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: 10),
      ),
    );
  }

  static pw.Widget _buildResultsTable(
    List<WaterQualityResult> results,
    Map<int, TestParameter> parameters,
    Map<int, QualityStandard> standards,
    pw.Font ttf,
    pw.Font ttfBold,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: _tableBorder),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(2),
        3: const pw.FlexColumnWidth(2),
      },
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerLightBlue),
          children: [
            _tableHeaderCell('الملاحظات', ttfBold),
            _tableHeaderCell('النتيجة', ttfBold),
            _tableHeaderCell('معيار القبول', ttfBold),
            _tableHeaderCell('الفحص', ttfBold),
          ],
        ),
        if (results.isEmpty)
          pw.TableRow(children: [
            _tableDataCell('', ttf),
            _tableDataCell('', ttf),
            _tableDataCell('', ttf),
            _tableDataCell('-', ttf),
          ])
        else
          ...results.map((r) {
            final param = parameters[r.parameterId];
            final paramName = param?.nameAr ?? '';
            final unit = param?.unit ?? '';
            final isText = param?.inputType == 'Text';
            final resultStr = isText
                ? (r.textResult ?? '')
                : (r.numericResult != null ? '${r.numericResult}${unit.isNotEmpty ? ' $unit' : ''}' : '');

            final std = standards[r.parameterId];
            String stdStr = '';
            if (std != null) {
              if (std.expectedText != null && std.expectedText!.isNotEmpty) {
                stdStr = std.expectedText!;
              } else if (std.minValue != null && std.maxValue != null) {
                stdStr = '${std.minValue} - ${std.maxValue}';
              } else if (std.maxValue != null) {
                stdStr = 'Max ${std.maxValue}';
              } else if (std.minValue != null) {
                stdStr = 'Min ${std.minValue}';
              }
            }

            return pw.TableRow(
              decoration: pw.BoxDecoration(color: !r.isCompliant ? _rowRed : PdfColors.white),
              children: [
                _tableDataCell(r.notes ?? '', ttf),
                _tableDataCell(resultStr, !r.isCompliant ? ttfBold : ttf, color: !r.isCompliant ? PdfColors.red700 : PdfColors.black),
                _tableDataCell(stdStr, ttf),
                _tableDataCell(paramName, ttf),
              ],
            );
          }),
      ],
    );
  }

  static pw.Widget _tableHeaderCell(String text, pw.Font ttfBold) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 10)),
    );
  }

  static pw.Widget _tableDataCell(String text, pw.Font font, {PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: 10, color: color ?? PdfColors.black)),
    );
  }

  static pw.Widget _buildComplianceSection(WaterQualityLog log, pw.Font ttf, pw.Font ttfBold) {
    final isCompliant = log.isCompliant;
    final managerNotified = log.managerNotified ?? false;
    final sourceSuspended = log.sourceSuspended ?? false;
    final ncrNumber = log.ncrNumber ?? '';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('- قرار المطابقة:', ttfBold),
        pw.SizedBox(height: 6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            _checkboxRow('مطابق للمواصفات', isCompliant, ttf),
            pw.SizedBox(width: 32),
            _checkboxRow('غير مطابق', !isCompliant, ttf),
          ],
        ),
        if (!isCompliant) ...[
          pw.SizedBox(height: 10),
          _buildSectionLabel('- في حالة عدم المطابقة:', ttfBold),
          pw.SizedBox(height: 6),
          pw.Wrap(
            spacing: 20,
            children: [
              _checkboxRow('تم إخطار مدير الجودة', managerNotified, ttf),
              _checkboxRow('تم تعليق استخدام مصدر المياه', sourceSuspended, ttf),
              pw.Row(children: [
                pw.Text('تم فتح NCR رقم: ', style: pw.TextStyle(font: ttf, fontSize: 10)),
                pw.Container(
                  width: 80,
                  decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black))),
                  child: pw.Text(ncrNumber, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttf, fontSize: 10)),
                ),
              ]),
            ],
          ),
        ],
      ],
    );
  }

  static pw.Widget _checkboxRow(String label, bool checked, pw.Font ttf) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Container(
          width: 11,
          height: 11,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: checked ? PdfColors.grey800 : PdfColors.grey600, width: 0.8),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
            color: checked ? const PdfColor.fromInt(0xFFE8F5E9) : PdfColors.white,
          ),
          alignment: pw.Alignment.center,
          child: checked
              ? pw.Padding(
                  padding: const pw.EdgeInsets.all(1.0),
                  child: pw.SvgImage(
                    svg: '<svg viewBox="0 0 24 24"><path fill="none" stroke="#2E7D32" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" d="M4 12.5l5.5 5.5L20 6.5"/></svg>',
                  ),
                )
              : null,
        ),
        pw.SizedBox(width: 4),
        pw.Text(ArabicPdfService.cleanArabicText(label), style: pw.TextStyle(font: ttf, fontSize: 9)),
      ],
    );
  }

  static pw.Widget _buildNotesSection(WaterQualityLog log, pw.Font ttf, pw.Font ttfBold) {
    final notes = log.generalNotes ?? '';
    final rejectionReason = log.rejectionReason ?? '';
    final hasRejection = rejectionReason.isNotEmpty;
    final rejector = log.rejectedBy ?? 'المعتمد';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('- الملاحظات:', ttfBold),
        pw.SizedBox(height: 4),
        if (hasRejection)
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            margin: const pw.EdgeInsets.only(bottom: 6),
            decoration: pw.BoxDecoration(
              color: _rowRed,
              border: pw.Border.all(color: PdfColors.red300, width: 0.5),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              '[تنبيه] ملاحظة الرفض / الإعادة للتعديل ($rejector): $rejectionReason',
              style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: PdfColors.red800),
            ),
          ),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            notes.isNotEmpty ? notes : 'لا توجد ملاحظات إضافية.',
            style: pw.TextStyle(font: ttf, fontSize: 9.5),
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
    final isQmRejected = (!isMicro && ApprovalStatus.isMicroRejected(log.approvalStatus))
        ? false
        : ApprovalStatus.rejectedByQualityManager(
            rejectedBy: log.rejectedBy,
            gmDecisionBy: log.gmDecisionBy,
            status: log.approvalStatus,
          );
    final isGmRejected = (!isMicro && ApprovalStatus.isMicroRejected(log.approvalStatus))
        ? false
        : ApprovalStatus.rejectedByFactoryManager(
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
    String inspectorName = log.sampleTaker ?? 'أخصائي الجودة';
    String qmName = isClosed
        ? (log.qmApprovedBy ?? log.microQmApprovedBy ?? 'حمود يسر')
        : (log.qmApprovedBy ?? '');
    String gmName = isClosed
        ? (log.gmDecisionBy ?? log.gmApprovedBy ?? log.microGmApprovedBy ?? 'خالد العمري')
        : (log.gmApprovedBy ?? '');
    DateTime inspectorDate = log.createdAt;
    DateTime? qmDate = log.qmApprovedAt;
    DateTime? gmDate = log.gmApprovedAt;

    if (isMicro) {
      inspectorName = log.microEnteredBy ?? log.sampleTaker ?? 'أخصائي الجودة';
      if (!isClosed) {
        qmName = isQmRejected ? (log.rejectedBy ?? 'مدير الجودة') : (log.microQmApprovedBy ?? '');
        gmName = isGmRejected
            ? ((log.gmDecisionBy ?? '').isNotEmpty
                ? log.gmDecisionBy!
                : (log.rejectedBy ?? 'مدير المصنع'))
            : (log.microGmApprovedBy ?? '');
      }
      inspectorDate = log.microEnteredAt ?? log.createdAt;
      qmDate = log.microQmApprovedAt ?? log.qmApprovedAt;
      gmDate = log.microGmApprovedAt ?? log.gmApprovedAt;
    } else {
      if (!isClosed) {
        qmName = (isQmRejected || wasQmRejected) ? (log.rejectedBy ?? 'مدير الجودة') : (qmName.isNotEmpty ? qmName : (wasQmApproved ? 'حمود يسر' : ''));
        gmName = isGmRejected
            ? ((log.gmDecisionBy ?? '').isNotEmpty
                ? log.gmDecisionBy!
                : (log.rejectedBy ?? 'مدير المصنع'))
            : gmName;
      }
    }
    
    final inspectorDateStr = DateFormat('yyyy/MM/dd').format(inspectorDate);
    final qmDateStr = isClosed
        ? (qmDate != null ? DynamicReportPdfGenerator.formatArabicDate(qmDate) : 'معتمد سابقاً')
        : (qmDate != null ? DynamicReportPdfGenerator.formatArabicDate(qmDate) : '');
    final gmDateStr = isClosed
        ? (gmDate != null ? DynamicReportPdfGenerator.formatArabicDate(gmDate) : 'معتمد بعد إجراء تصحيحي')
        : (gmDate != null ? DynamicReportPdfGenerator.formatArabicDate(gmDate) : '');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(ArabicPdfService.cleanArabicText(title), style: pw.TextStyle(font: ttfBold, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Table(
      border: pw.TableBorder.all(color: _tableBorder),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerLightBlue),
          children: [
            _tableHeaderCell('اعتماد مدير المصنع', ttfBold),
            _tableHeaderCell('مدير الجودة', ttfBold),
            _tableHeaderCell('منفذ الفحص', ttfBold),
          ],
        ),
        pw.TableRow(children: [
          _buildSignatureCell(
            rawName: gmName.isNotEmpty ? gmName : "..............................",
            sig: isClosed
                ? 'التوقيع: [معتمد بعد إجراء تصحيحي]'
                : (gmName.isNotEmpty ? (isGmRejected ? '[مرفوض]' : 'التوقيع: [معتمد إلكترونياً]') : 'التوقيع: ..............................'),
            date: gmDateStr.isNotEmpty ? 'التاريخ: $gmDateStr م' : 'التاريخ:   /   / 20م',
            ttf: ttf,
            ttfBold: ttfBold,
            signatureBytes: isGmRejected ? rejectedSignatureBytes : ((isClosed || gmName.isNotEmpty) ? gmSignatureBytes : null),
            isRejected: isGmRejected,
            isApproved: isClosed,
          ),
          _buildSignatureCell(
            rawName: qmName.isNotEmpty ? qmName : "..............................",
            sig: isClosed
                ? 'التوقيع: [معتمد سابقاً]'
                : (qmName.isNotEmpty
                    ? (isQmRejected
                        ? '[مرفوض]'
                        : (wasQmApproved
                            ? 'التوقيع: [معتمد سابقاً - أُلغي برفض الإدارة]'
                            : 'التوقيع: [معتمد إلكترونياً]'))
                    : 'التوقيع: ..............................'),
            date: qmDateStr.isNotEmpty ? 'التاريخ: $qmDateStr م' : 'التاريخ:   /   / 20م',
            ttf: ttf,
            ttfBold: ttfBold,
            signatureBytes: isQmRejected ? rejectedSignatureBytes : ((isClosed || qmName.isNotEmpty || wasQmApproved) ? qmSignatureBytes : null),
            isRejected: isQmRejected,
            isVoided: isClosed || wasQmApproved,
          ),
          _buildSignatureCell(
            rawName: inspectorName,
            sig: 'التوقيع: [معتمد إلكترونياً]',
            date: 'التاريخ: $inspectorDateStr م',
            ttf: ttf,
            ttfBold: ttfBold,
            signatureBytes: inspectorSignatureBytes,
          ),
        ]),
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

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text('الاسم: ${parsed.name}', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: titleColor)),
              if (parsed.role != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  parsed.role!,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttf, fontSize: 7.5, color: isRejected ? titleColor : PdfColors.grey700),
                ),
              ],
              pw.SizedBox(height: 4),
              pw.Text(
                sig,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: ttf,
                  fontSize: 9.5,
                  color: sigColor,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(date, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttf, fontSize: 9.5, color: titleColor)),
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

  static pw.Widget _buildFooter(pw.Font ttf) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey600), borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Row(
        children: [
          pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(5),
            child: pw.Text('رقم الوثيقة: SELSAL-IMSF-19-02', style: pw.TextStyle(font: ttf, fontSize: 9)))),
          pw.Container(width: 1, height: 24, color: PdfColors.grey400),
          pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(5),
            child: pw.Text('تاريخ الإصدار: 2026/07/15', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttf, fontSize: 9)))),
          pw.Container(width: 1, height: 24, color: PdfColors.grey400),
          pw.Expanded(child: pw.Padding(padding: const pw.EdgeInsets.all(5),
            child: pw.Text('إصدار رقم: 01', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttf, fontSize: 9)))),
        ],
      ),
    );
  }
}
