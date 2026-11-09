import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../constants/approval_status.dart';
import '../models/dynamic_report_models.dart';
import '../services/api/dynamic_reports_api_service.dart';
import '../services/pdf/arabic_pdf_service.dart';
import '../services/user_signature_service.dart';
import 'calculated_field_helper.dart';

class DynamicReportPdfGenerator {
  static const PdfColor _headerLightBlue = PdfColor.fromInt(0xFFBDD7EE);
  static const PdfColor _zebraRowColor = PdfColor.fromInt(0xFFD9E1F3);
  static const PdfColor _tableBorder = PdfColor.fromInt(0xFF8DB4E2);

  /// تحويل كود اللون السداسي Hex (مثل #BDD7EE أو BDD7EE) إلى PdfColor متوافق
  static PdfColor? parseHexPdfColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) return null;
    var c = hex.replaceAll('#', '').trim();
    if (c.length == 6) c = 'FF$c';
    final val = int.tryParse(c, radix: 16);
    return val != null ? PdfColor.fromInt(val) : null;
  }

  static Future<Uint8List> generate({
    required DynamicReport report,
    required DynamicReportRecord record,
    required List<DynamicReportValue> values,
    List<ReportApproval>? approvals,
    Uint8List? qsSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? creatorSignatureBytes,
    Uint8List? rejectedSignatureBytes,
  }) async {
    await ArabicPdfService.initialize();
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

    await _appendRecordToDocument(
      pdf: pdf,
      report: report,
      record: record,
      values: values,
      ttf: ttf,
      ttfBold: ttfBold,
      logoImage: logoImage,
      approvals: approvals,
      qsSignatureBytes: qsSignatureBytes,
      qmSignatureBytes: qmSignatureBytes,
      gmSignatureBytes: gmSignatureBytes,
      creatorSignatureBytes: creatorSignatureBytes,
      rejectedSignatureBytes: rejectedSignatureBytes,
    );

    return pdf.save();
  }

  /// توليد حزمة تدقيق مجمّعة (Batch Audit Pack PDF) تضم صفحة غلاف وفهرس رسمي + كافة السجلات المحددة
  static Future<Uint8List> generateBatchAuditPack({
    required DynamicReport report,
    required List<({DynamicReportRecord record, List<DynamicReportValue> values, List<ReportApproval>? approvals})> entries,
    String? filterLabel,
  }) async {
    await ArabicPdfService.initialize();
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

    // 1. بناء صفحة غلاف وفهرس حزمة التدقيق الرسمية
    _addAuditPackCoverPage(
      pdf: pdf,
      report: report,
      entries: entries,
      ttf: ttf,
      ttfBold: ttfBold,
      logoImage: logoImage,
      filterLabel: filterLabel,
    );

    // 2. إلحاق صفحات كل سجل بالترتيب
    for (final item in entries) {
      await _appendRecordToDocument(
        pdf: pdf,
        report: report,
        record: item.record,
        values: item.values,
        ttf: ttf,
        ttfBold: ttfBold,
        logoImage: logoImage,
        approvals: item.approvals,
      );
    }

    return pdf.save();
  }

  static void _addAuditPackCoverPage({
    required pw.Document pdf,
    required DynamicReport report,
    required List<({DynamicReportRecord record, List<DynamicReportValue> values, List<ReportApproval>? approvals})> entries,
    required pw.Font ttf,
    required pw.Font ttfBold,
    pw.MemoryImage? logoImage,
    String? filterLabel,
  }) {
    final bool isLandscape = report.orientation == 'landscape';
    final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    final double horizontalMargin = isLandscape ? 16 : 24;
    final double verticalMargin = isLandscape ? 14 : 20;
    final double contentWidth = pageFormat.width - (horizontalMargin * 2);

    final int totalCount = entries.length;
    final int approvedCount = entries.where((e) => e.record.approvalStatus == 'Approved' || e.record.approvalStatus == 'Closed').length;
    final int rejectedCount = entries.where((e) => ApprovalStatus.isRejectedStatus(e.record.approvalStatus)).length;
    final int pendingCount = totalCount - approvedCount - rejectedCount;

    final String exportDateStr = formatArabicDate(DateTime.now());
    final int maxIndexRows = isLandscape ? 14 : 22;
    final displayEntries = entries.take(maxIndexRows).toList();

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        textDirection: pw.TextDirection.rtl,
        margin: pw.EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(logoImage, ttf, ttfBold, 'ملف تدقيق رسمي (Audit Pack)', contentWidth),
                pw.SizedBox(height: 6),
                _buildTitleBox('حزمة التدقيق المجمّعة — ${report.name}', ttfBold, isLandscape),
                pw.SizedBox(height: 8),
                // بطاقة ملخص الحزمة الإحصائي
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFFF0F5FA),
                    border: pw.Border.all(color: _tableBorder, width: 0.9),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('إجمالي السجلات المرفقة: $totalCount', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
                      pw.Text('معتمد نهائياً: $approvedCount', style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: const PdfColor.fromInt(0xFF1B5E20))),
                      pw.Text('قيد الاعتماد: $pendingCount', style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: const PdfColor.fromInt(0xFFE65100))),
                      pw.Text('مرفوض / تصحيحي: $rejectedCount', style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: const PdfColor.fromInt(0xFFB71C1C))),
                      pw.Text('تاريخ الاستخراج: $exportDateStr', style: pw.TextStyle(font: ttf, fontSize: 8.5)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  color: _headerLightBlue,
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'فهرس السجلات المضمّنة في الحزمة${filterLabel != null && filterLabel.isNotEmpty ? " ($filterLabel)" : ""}:',
                    style: pw.TextStyle(font: ttfBold, fontSize: 9.5),
                  ),
                ),
                pw.Table(
                  border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
                  columnWidths: const {
                    0: pw.FlexColumnWidth(2.2), // الحالة
                    1: pw.FlexColumnWidth(1.8), // الفرع
                    2: pw.FlexColumnWidth(2.5), // مُعد التقرير
                    3: pw.FlexColumnWidth(2.2), // تاريخ التعبئة
                    4: pw.FlexColumnWidth(1.2), // رقم السجل
                    5: pw.FlexColumnWidth(0.7), // م
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: _headerLightBlue),
                      children: [
                        _indexCell('حالة الاعتماد', ttfBold, isHeader: true),
                        _indexCell('المصنع / الفرع', ttfBold, isHeader: true),
                        _indexCell('منفذ الفحص', ttfBold, isHeader: true),
                        _indexCell('تاريخ التعبئة', ttfBold, isHeader: true),
                        _indexCell('رقم السجل', ttfBold, isHeader: true),
                        _indexCell('م', ttfBold, isHeader: true),
                      ],
                    ),
                    for (int i = 0; i < displayEntries.length; i++)
                      pw.TableRow(
                        decoration: i.isEven ? const pw.BoxDecoration(color: _zebraRowColor) : null,
                        children: [
                          _indexCell(formatArabicStatus(displayEntries[i].record.approvalStatus), ttfBold),
                          _indexCell(displayEntries[i].record.effectiveBranchName, ttf),
                          _indexCell(formatCreatorName(displayEntries[i].record.createdBy), ttf),
                          _indexCell(formatArabicDate(displayEntries[i].record.createdAt), ttf),
                          _indexCell(displayEntries[i].record.effectiveRecordCode, ttfBold),
                          _indexCell('${i + 1}', ttfBold),
                        ],
                      ),
                  ],
                ),
                if (entries.length > maxIndexRows) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '* ملاحظة: يعرض الفهرس أعلاه أول $maxIndexRows سجلاً، بينما تتضمن الصفحات التالية كافة السجلات المحددة بالكامل ($totalCount سجلاً).',
                    style: pw.TextStyle(font: ttf, fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
                pw.Spacer(),
                _buildFooter(report, ttf),
              ],
            ),
          );
        },
      ),
    );
  }

  static pw.Widget _indexCell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(font: font, fontSize: isHeader ? 8.5 : 8.0),
      ),
    );
  }

  static Future<void> _appendRecordToDocument({
    required pw.Document pdf,
    required DynamicReport report,
    required DynamicReportRecord record,
    required List<DynamicReportValue> values,
    required pw.Font ttf,
    required pw.Font ttfBold,
    pw.MemoryImage? logoImage,
    List<ReportApproval>? approvals,
    Uint8List? qsSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? creatorSignatureBytes,
    Uint8List? rejectedSignatureBytes,
  }) async {

    // استخراج وتجهيز لقطات التوقيعات الرقمية المعتمدة
    Uint8List? effectiveQsSignature = qsSignatureBytes;
    Uint8List? effectiveQmSignature = qmSignatureBytes;
    Uint8List? effectiveGmSignature = gmSignatureBytes;
    Uint8List? effectiveCreatorSignature = creatorSignatureBytes;
    String? qsSigHash;
    String? qmSigHash;
    String? gmSigHash;

    final bool isClosed = record.approvalStatus == 'Closed';
    final wasQsApprovedTop = ApprovalStatus.wasApprovedByQsPriorToRejection(
      qsApprovedBy: record.qsApprovedBy,
      status: record.approvalStatus,
    );
    final isQsDone = record.approvalStatus == 'Approved' ||
        record.approvalStatus == 'Pending_GM' ||
        record.approvalStatus == 'Pending_QM' ||
        isClosed ||
        wasQsApprovedTop;
    final isQmDone = record.approvalStatus == 'Approved' || record.approvalStatus == 'Pending_GM';
    final isGmDone = record.approvalStatus == 'Approved' || isClosed;

    List<ReportApproval>? trail = approvals;
    if (trail == null && record.id != null) {
      try {
        trail = await DynamicReportsApiService.to.getApprovalTrail(record.id!);
      } catch (_) {}
    }

    if (trail != null && trail.isNotEmpty) {
      for (var app in trail) {
        if (effectiveQsSignature == null &&
            (app.stepName?.contains('مشرف') == true ||
             app.actionByPosition?.contains('مشرف') == true ||
             app.newStatus == 'Pending_QM')) {
          Uint8List? latest;
          if (app.actedByUserId != null) {
            latest = await UserSignatureService.instance.getCustomUserSignatureBytes(app.actedByUserId!);
          }
          if (latest == null && app.actedBy != null && app.actedBy!.isNotEmpty) {
            latest = await UserSignatureService.instance.getSignatureBytesForUser(
              userName: app.actedBy!,
              userPosition: 'مشرف الجودة',
            );
          }
          effectiveQsSignature = latest ?? app.signatureBytes;
          qsSigHash = app.signatureHash;
        }
        if (effectiveQmSignature == null &&
            (app.stepName?.contains('الجودة') == true ||
             (app.actionByPosition?.contains('الجودة') == true && !(app.actionByPosition?.contains('مشرف') ?? false)) ||
             app.newStatus == 'Pending_GM' ||
             app.newStatus == 'Corrective_In_Progress' ||
             app.newStatus == 'Pending_GM_Decision')) {
          Uint8List? latest;
          if (app.actedByUserId != null) {
            latest = await UserSignatureService.instance.getCustomUserSignatureBytes(app.actedByUserId!);
          }
          if (latest == null && app.actedBy != null && app.actedBy!.isNotEmpty) {
            latest = await UserSignatureService.instance.getSignatureBytesForUser(
              userName: app.actedBy!,
              userPosition: 'مدير الجودة',
            );
          }
          effectiveQmSignature = latest ?? app.signatureBytes;
          qmSigHash = app.signatureHash;
        }
        if (effectiveGmSignature == null &&
            (app.stepName?.contains('المصنع') == true ||
             app.actionByPosition?.contains('المصنع') == true ||
             app.newStatus == 'Approved' ||
             app.newStatus == 'Closed')) {
          Uint8List? latest;
          if (app.actedByUserId != null) {
            latest = await UserSignatureService.instance.getCustomUserSignatureBytes(app.actedByUserId!);
          }
          if (latest == null && app.actedBy != null && app.actedBy!.isNotEmpty) {
            latest = await UserSignatureService.instance.getSignatureBytesForUser(
              userName: app.actedBy!,
              userPosition: 'مدير المصنع',
            );
          }
          effectiveGmSignature = latest ?? app.signatureBytes;
          gmSigHash = app.signatureHash;
        }
      }
    }

    if (effectiveQsSignature == null && isQsDone) {
      try {
        effectiveQsSignature = await UserSignatureService.instance.getSignatureBytesForUser(
          userName: record.qsApprovedBy ?? 'مشرف الجودة',
          userPosition: 'مشرف الجودة',
        );
      } catch (_) {}
    }
    if (effectiveQmSignature == null && isQmDone) {
      try {
        effectiveQmSignature = await UserSignatureService.instance.getSignatureBytesForUser(
          userName: record.qmApprovedBy ?? 'حمود يسر',
          userPosition: 'مدير توكيد ورقابة الجودة',
        );
      } catch (_) {}
    }
    if (effectiveGmSignature == null && isGmDone) {
      try {
        effectiveGmSignature = await UserSignatureService.instance.getSignatureBytesForUser(
          userName: record.gmApprovedBy ?? 'خالد العمري',
          userPosition: 'مدير مصنع وادي العين',
        );
      } catch (_) {}
    }
    if (effectiveCreatorSignature == null) {
      try {
        final creatorName = DynamicReportRecord.sanitizeCreatorName(record.createdBy);
        effectiveCreatorSignature = await UserSignatureService.instance.getSignatureBytesForUser(
          userName: creatorName,
          userPosition: 'أخصائي الجودة / منفذ الفحص',
        );
      } catch (_) {}
    }

    // Map values by fieldId for quick access (with fieldKey fallback for historical schema safety)
    final Map<int, String> valueMap = {};
    final Map<String, String> keyValueMap = {};
    for (var v in values) {
      valueMap[v.fieldId] = v.value ?? '';
      if (v.fieldKey != null && v.fieldKey!.isNotEmpty && (v.value ?? '').isNotEmpty) {
        keyValueMap[v.fieldKey!] = v.value!;
      }
    }

    if (keyValueMap.isNotEmpty && report.sections != null) {
      for (var sec in report.sections!) {
        for (var fld in sec.fields ?? <DynamicReportField>[]) {
          if (fld.id != null && (!valueMap.containsKey(fld.id) || valueMap[fld.id]!.isEmpty)) {
            if (keyValueMap.containsKey(fld.fieldKey)) {
              valueMap[fld.id!] = keyValueMap[fld.fieldKey]!;
            }
          }
        }
      }
    }

    // Fallback to data_json (المحرك الهجين) if values are empty or incomplete
    if (record.dataJson != null && record.dataJson!.isNotEmpty) {
      try {
        final dataMap = record.dataMap;
        if (dataMap != null && report.sections != null) {
          for (var sec in report.sections!) {
            if (sec.fields != null) {
              for (var fld in sec.fields!) {
                if (fld.id != null && (!valueMap.containsKey(fld.id) || valueMap[fld.id]!.isEmpty)) {
                  if (dataMap.containsKey(fld.fieldKey)) {
                    final item = dataMap[fld.fieldKey];
                    if (item is Map && item.containsKey('value')) {
                      valueMap[fld.id!] = item['value']?.toString() ?? '';
                    } else if (item != null) {
                      valueMap[fld.id!] = item.toString();
                    }
                  }
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    final dateStr = formatArabicDate(record.createdAt);

    final bool isLandscape = report.orientation == 'landscape';

    final pageFormat = isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;
    final double horizontalMargin = isLandscape ? 16 : 24;
    final double verticalMargin = isLandscape ? 14 : 20;
    final double contentWidth = pageFormat.width - (horizontalMargin * 2);

    final expandedSections = _expandLongTableSections(report.sections ?? [], valueMap, isLandscape);
    final tableSections = expandedSections.where((sec) =>
        sec.fields?.any((f) => f.fieldType == 'table') ?? false).toList();
    final bool useDedicatedTablePages = isLandscape && tableSections.isNotEmpty;

    if (useDedicatedTablePages) {
      // استخراج بيانات التشغيل العامة مع بدائل تلقائية تمنع ظهور 'غير متوفر' نهائياً
      String reportDate = '';
      String dayName = '';
      String lineNumber = '';

      for (var sec in report.sections ?? []) {
        for (var fld in sec.fields ?? []) {
          final k = fld.fieldKey.toLowerCase();
          final l = fld.label.toLowerCase();
          final val = (valueMap[fld.id] ?? '').trim();
          if (val.isNotEmpty && val != 'غير متوفر') {
            if (fld.fieldType == 'date' || k.contains('date') || l.contains('تاريخ')) {
              reportDate = val;
            } else if (k.contains('day') || l.contains('اليوم')) {
              dayName = val;
            } else if (k.contains('line') || l.contains('خط')) {
              lineNumber = val;
            }
          }
        }
      }

      final effectiveDate = record.createdAt ?? DateTime.now();
      if (reportDate.isEmpty) {
        reportDate = DateFormat('yyyy/MM/dd').format(effectiveDate);
      }
      if (dayName.isEmpty) {
        dayName = _getArabicDayName(effectiveDate);
      }
      if (lineNumber.isEmpty) {
        lineNumber = 'خط الإنتاج 1';
      }

      final int totalPages = tableSections.length;

      for (int pageIdx = 0; pageIdx < tableSections.length; pageIdx++) {
        final sec = tableSections[pageIdx];
        final currentTableFields = (sec.fields ?? []).where((f) => f.fieldType == 'table').toList();
        final bool isLastPage = (pageIdx == tableSections.length - 1);
        final pageNumStr = 'الصفحة ${pageIdx + 1} من $totalPages';

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            textDirection: pw.TextDirection.rtl,
            margin: pw.EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
            theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
            build: (context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(logoImage, ttf, ttfBold, pageNumStr, contentWidth),
                    pw.SizedBox(height: 3),
                    _buildTitleBox(report.name, ttfBold, true),
                    pw.SizedBox(height: 3),
                    _buildCompactOperatingBar(
                      record: record,
                      reportDate: reportDate,
                      dayName: dayName,
                      lineNumber: lineNumber,
                      ttf: ttf,
                      ttfBold: ttfBold,
                      headerConfig: report.headerConfig,
                    ),
                    pw.SizedBox(height: 3),
                    _buildSectionBanner(sec, ttf, ttfBold),
                    pw.SizedBox(height: 3),
                    for (int tIdx = 0; tIdx < currentTableFields.length; tIdx++) ...[
                      if (currentTableFields.length > 1) ...[
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                          decoration: pw.BoxDecoration(
                            color: const PdfColor.fromInt(0xFFEBF1F8),
                            border: pw.Border.all(color: _tableBorder, width: 0.6),
                            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
                          ),
                          alignment: pw.Alignment.centerRight,
                          child: pw.Text(
                            currentTableFields[tIdx].label,
                            style: pw.TextStyle(font: ttfBold, fontSize: 8.5, color: const PdfColor.fromInt(0xFF1565C0)),
                            textAlign: pw.TextAlign.right,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                      ],
                      _buildPdfTableField(
                        currentTableFields[tIdx],
                        valueMap[currentTableFields[tIdx].id!] ?? '',
                        ttf,
                        ttfBold,
                        true,
                        isDedicatedPage: true,
                        isLastPage: isLastPage,
                        isCompact: currentTableFields.length > 1,
                      ),
                      if (tIdx < currentTableFields.length - 1) pw.SizedBox(height: 3),
                    ],
                    for (var boxField in (sec.fields ?? []).where((f) => f.fieldType == 'note' || f.fieldType == 'instructions'))
                      _buildPdfBoxField(boxField, valueMap[boxField.id!], ttf, ttfBold, isCompact: currentTableFields.length > 1),
                    pw.Spacer(),
                    // جدول الاعتماد الإداري يظهر حصرياً في الصفحة الأخيرة فقط من التقرير
                    if (isLastPage && report.approvalType != 'none') ...[
                      _buildSignaturesTable(
                        record,
                        ttf,
                        ttfBold,
                        report: report,
                        isSingleLevel: report.approvalType == 'single_level',
                        isLandscape: true,
                        qsSignatureBytes: effectiveQsSignature,
                        qmSignatureBytes: effectiveQmSignature,
                        gmSignatureBytes: effectiveGmSignature,
                        creatorSignatureBytes: effectiveCreatorSignature,
                        rejectedSignatureBytes: rejectedSignatureBytes,
                        qsSignatureHash: qsSigHash,
                        qmSignatureHash: qmSigHash,
                        gmSignatureHash: gmSigHash,
                      ),
                      pw.SizedBox(height: 3),
                    ],
                    _buildFooter(report, ttf, record),
                  ],
                ),
              );
            },
          ),
        );
      }
    } else {
      final allSections = expandedSections;
      final List<double> sectionHeights = [];
      double totalSectionsHeight = 0;
      for (var sec in allSections) {
        final h = _estimateSectionHeight(sec, valueMap, isLandscape);
        sectionHeights.add(h);
        totalSectionsHeight += h;
      }

      final double maxContentHeightP1 = isLandscape ? 385 : 595;
      final double maxContentHeightP2 = isLandscape ? 435 : 630;
      final double sigHeight = isLandscape ? 65 : 85;

      final List<List<DynamicReportSection>> pagedSections = [];

      if (allSections.isEmpty) {
        pagedSections.add([]);
      } else if (totalSectionsHeight + sigHeight <= maxContentHeightP1) {
        // التقرير يتسع بالكامل في صفحة واحدة
        pagedSections.add(allSections);
      } else {
        // التقرير يتطلب صفحتين أو أكثر: تقسيم ذكي ومتقن للأقسام
        List<DynamicReportSection> currentPage = [];
        double currentHeight = 0;
        double currentMax = maxContentHeightP1;

        for (int i = 0; i < allSections.length; i++) {
          final sec = allSections[i];
          final secH = sectionHeights[i];

          if (currentPage.isNotEmpty && (currentHeight + secH > currentMax)) {
            pagedSections.add(currentPage);
            currentPage = [sec];
            currentHeight = secH;
            currentMax = maxContentHeightP2;
          } else {
            currentPage.add(sec);
            currentHeight += secH;
          }
        }
        if (currentPage.isNotEmpty) {
          pagedSections.add(currentPage);
        }
      }

      final int totalPages = pagedSections.length;
      for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
        final bool isFirstPage = (pageIdx == 0);
        final bool isLastPage = (pageIdx == totalPages - 1);
        final pageNumStr = 'الصفحة ${pageIdx + 1} من $totalPages';
        final pageSecs = pagedSections[pageIdx];

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            textDirection: pw.TextDirection.rtl,
            margin: pw.EdgeInsets.symmetric(horizontal: horizontalMargin, vertical: verticalMargin),
            theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
            build: (context) {
              return pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(logoImage, ttf, ttfBold, pageNumStr, contentWidth),
                    pw.SizedBox(height: isLandscape ? 3 : 5),
                    _buildTitleBox(report.name, ttfBold, isLandscape),
                    pw.SizedBox(height: isLandscape ? 3 : 5),
                    if (isFirstPage) ...[
                      _buildRecordInfoSection(record, dateStr, ttf, ttfBold, isLandscape, report.headerConfig),
                      pw.SizedBox(height: isLandscape ? 4 : 6),
                    ],
                    ..._buildSectionsList(pageSecs, valueMap, ttf, ttfBold, isLandscape),
                    pw.Spacer(),
                    // جدول الاعتماد الإداري: يثبت ميكانيكياً في أسفل الصفحة الأخيرة حصراً
                    if (isLastPage && report.approvalType != 'none') ...[
                      _buildSignaturesTable(
                        record,
                        ttf,
                        ttfBold,
                        report: report,
                        isSingleLevel: report.approvalType == 'single_level',
                        isLandscape: isLandscape,
                        qsSignatureBytes: effectiveQsSignature,
                        qmSignatureBytes: effectiveQmSignature,
                        gmSignatureBytes: effectiveGmSignature,
                        creatorSignatureBytes: effectiveCreatorSignature,
                        rejectedSignatureBytes: rejectedSignatureBytes,
                        qsSignatureHash: qsSigHash,
                        qmSignatureHash: qmSigHash,
                        gmSignatureHash: gmSigHash,
                      ),
                      pw.SizedBox(height: isLandscape ? 3 : 6),
                    ],
                    _buildFooter(report, ttf, record),
                  ],
                ),
              );
            },
          ),
        );
      }
    }
  }

    static String _getArabicDayName(DateTime date) {
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[date.weekday - 1];
  }

  static pw.Widget _buildCompactOperatingBar({
    required DynamicReportRecord record,
    required String reportDate,
    required String dayName,
    required String lineNumber,
    required pw.Font ttf,
    required pw.Font ttfBold,
    DynamicReportHeaderConfig? headerConfig,
  }) {
    final creator = formatCreatorName(record.createdBy);
    final statusText = formatArabicStatus(record.approvalStatus);
    final recId = record.effectiveRecordCode;
    final cfg = headerConfig ?? const DynamicReportHeaderConfig();

    pw.Widget item(String label, String value, {bool isStatus = false}) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('$label: ', style: pw.TextStyle(font: ttfBold, fontSize: 8.5)),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: isStatus ? ttfBold : ttf,
              fontSize: 8.5,
              color: isStatus ? const PdfColor(0, 0.38, 0.39) : PdfColors.black,
            ),
          ),
        ],
      );
    }

    pw.Widget divider() {
      return pw.Container(
        height: 12,
        width: 1,
        color: _tableBorder,
        margin: const pw.EdgeInsets.symmetric(horizontal: 6),
      );
    }

    final List<pw.Widget> items = [];

    // 1. رقم السجل (إجباري دائم لا يمكن إخفاؤه)
    items.add(item('رقم السجل', recId));

    // 2. مُعد التقرير (اختياري)
    if (cfg.showCreator) {
      items.add(item('مُعد التقرير', creator));
    }

    // 3. تاريخ الفحص (اختياري)
    if (cfg.showDate) {
      items.add(item('تاريخ الفحص', reportDate));
    }

    // 4. اليوم (اختياري)
    if (cfg.showDay) {
      items.add(item('اليوم', dayName));
    }

    // 5. خط الإنتاج (اختياري)
    if (cfg.showLine) {
      items.add(item('خط الإنتاج', lineNumber));
    }

    // 6. الحالة (إجباري دائم لا يمكن إخفاؤه)
    items.add(item('الحالة', statusText, isStatus: true));

    final List<pw.Widget> rowChildren = [];
    for (int i = 0; i < items.length; i++) {
      rowChildren.add(items[i]);
      if (i < items.length - 1) {
        rowChildren.add(divider());
      }
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF7F9FC),
        border: pw.Border.all(color: _tableBorder, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: rowChildren,
      ),
    );
  }

  static pw.Widget _buildSectionBanner(DynamicReportSection section, pw.Font ttf, pw.Font ttfBold) {
    final hasDesc = section.description != null && section.description!.trim().isNotEmpty;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.0),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFEBF1F8),
        border: pw.Border.all(color: _tableBorder, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            flex: 4,
            child: pw.Text(
              section.title,
              style: pw.TextStyle(font: ttfBold, fontSize: 9.5),
              textAlign: pw.TextAlign.right,
            ),
          ),
          if (hasDesc) ...[
            pw.SizedBox(width: 8),
            pw.Expanded(
              flex: 6,
              child: pw.Text(
                section.description!.trim(),
                style: pw.TextStyle(font: ttf, fontSize: 8.0, color: PdfColors.grey800),
                textAlign: pw.TextAlign.right,
                textDirection: pw.TextDirection.rtl,
              ),
            ),
          ],
        ],
      ),
    );
  }

static pw.Widget _buildHeader(pw.MemoryImage? logoImage, pw.Font ttf, pw.Font ttfBold, String pageNum, double headerWidth) {
    if (logoImage != null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Image(
            logoImage,
            width: headerWidth,
            height: 58,
            fit: pw.BoxFit.fill,
          ),
          pw.SizedBox(height: 2),
          pw.Align(
            alignment: pw.Alignment.topLeft,
            child: pw.Text(pageNum, style: pw.TextStyle(font: ttfBold, fontSize: 9)),
          ),
        ],
      );
    }
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('مصنع سلسال للمياه\nSELSAL WATER FACTORY', style: pw.TextStyle(font: ttfBold, fontSize: 10)),
        pw.Text(pageNum, style: pw.TextStyle(font: ttfBold, fontSize: 10)),
      ],
    );
  }

  static pw.Widget _buildTitleBox(String title, pw.Font ttfBold, [bool isLandscape = false]) {
    return pw.Center(
      child: pw.Container(
        padding: pw.EdgeInsets.symmetric(horizontal: isLandscape ? 16 : 20, vertical: isLandscape ? 3.5 : 5),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: _headerLightBlue,
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(font: ttfBold, fontSize: isLandscape ? 12 : 13.5),
        ),
      ),
    );
  }

  static String formatCreatorName(String? raw) {
    return DynamicReportRecord.sanitizeCreatorName(raw);
  }

  static pw.Widget _buildRecordInfoSection(
    DynamicReportRecord record,
    String dateStr,
    pw.Font ttf,
    pw.Font ttfBold, [
    bool isLandscape = false,
    DynamicReportHeaderConfig? headerConfig,
  ]) {
    final creator = formatCreatorName(record.createdBy);
    final statusText = formatArabicStatus(record.approvalStatus);
    final cfg = headerConfig ?? const DynamicReportHeaderConfig();

    final List<pw.Widget> items = [];

    // 1. رقم السجل (إجباري دائم لا يمكن إخفاؤه)
    items.add(pw.Text('رقم السجل: ${record.effectiveRecordCode}', style: pw.TextStyle(font: ttfBold, fontSize: 10)));

    // 2. مُعد التقرير (اختياري)
    if (cfg.showCreator) {
      items.add(pw.Text('مُعد التقرير: $creator', style: pw.TextStyle(font: ttfBold, fontSize: 10)));
    }

    // 3. تاريخ التعبئة (اختياري)
    if (cfg.showDate) {
      items.add(pw.Text('تاريخ التعبئة: $dateStr', style: pw.TextStyle(font: ttfBold, fontSize: 10)));
    }

    // 4. الحالة (إجباري دائم لا يمكن إخفاؤه)
    items.add(pw.Text('الحالة: $statusText', style: pw.TextStyle(font: ttfBold, fontSize: 10)));

    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 8, vertical: isLandscape ? 4 : 6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _tableBorder, width: 1),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: items,
      ),
    );
  }

  /// تقسيم الجداول الطويلة تلقائياً عبر الصفحات (Auto Row-Chunking) لمنع فيضان الصفحة (Overflow)
  /// مع الحفاظ على تكرار رأس الجدول في كل صفحة واستمرار الترقيم التسلسلي للصفوف (م).
  static List<DynamicReportSection> _expandLongTableSections(
    List<DynamicReportSection> sections,
    Map<int, String> valueMap,
    bool isLandscape,
  ) {
    final int maxRowsPerPage = isLandscape ? 16 : 22;
    final List<DynamicReportSection> result = [];
    int syntheticIdCounter = -900000;

    for (final sec in sections) {
      final secFields = sec.fields ?? [];
      final tableFields = secFields.where((f) => f.fieldType == 'table').toList();

      if (tableFields.length != 1) {
        result.add(sec);
        continue;
      }

      final tf = tableFields.first;
      final rawJson = (tf.id != null ? valueMap[tf.id!] : null) ?? '';
      List<Map<String, dynamic>> rows = [];
      if (rawJson.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawJson);
          if (decoded is List) {
            rows = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          }
        } catch (_) {}
      }
      final config = tf.tableConfig ?? DynamicTableConfig.inspectionChecklistTemplate();
      if (rows.isEmpty && config.defaultRows.isNotEmpty) {
        rows = config.defaultRows.map((e) => Map<String, dynamic>.from(e)).toList();
      } else if (rows.isEmpty && config.rowCount > 0) {
        rows = List.generate(config.rowCount, (_) => <String, dynamic>{});
      }

      if (rows.length <= maxRowsPerPage) {
        result.add(sec);
        continue;
      }

      final boxFieldTypes = ['note', 'instructions'];
      final standardFields = secFields
          .where((f) => f.fieldType != 'table' && !boxFieldTypes.contains(f.fieldType))
          .toList();
      final boxFields = secFields.where((f) => boxFieldTypes.contains(f.fieldType)).toList();

      final int totalChunks = (rows.length / maxRowsPerPage).ceil();
      for (int chunkIdx = 0; chunkIdx < totalChunks; chunkIdx++) {
        final int start = chunkIdx * maxRowsPerPage;
        final int end = (start + maxRowsPerPage < rows.length) ? start + maxRowsPerPage : rows.length;
        final List<Map<String, dynamic>> chunkRows = [];
        for (int rIdx = start; rIdx < end; rIdx++) {
          final rowCopy = Map<String, dynamic>.from(rows[rIdx]);
          rowCopy['_row_num'] = rIdx + 1;
          chunkRows.add(rowCopy);
        }

        final int chunkFieldId = syntheticIdCounter--;
        valueMap[chunkFieldId] = jsonEncode(chunkRows);
        final chunkTableField = tf.copyWith(id: chunkFieldId);

        final List<DynamicReportField> chunkFields = [
          if (chunkIdx == 0) ...standardFields,
          chunkTableField,
          if (chunkIdx == totalChunks - 1) ...boxFields,
        ];

        result.add(
          sec.copyWith(
            title: chunkIdx == 0 ? sec.title : '${sec.title} (تابع ${chunkIdx + 1}/$totalChunks)',
            description: chunkIdx == 0 ? sec.description : null,
            fields: chunkFields,
          ),
        );
      }
    }

    return result;
  }

  static double _estimateSectionHeight(
    DynamicReportSection sec,
    Map<int, String> valueMap,
    bool isLandscape,
  ) {
    double h = isLandscape ? 18.0 : 22.0;
    if (sec.description != null && sec.description!.trim().isNotEmpty) {
      h += isLandscape ? 10.0 : 14.0;
    }
    final fields = sec.fields ?? [];
    if (fields.isEmpty) {
      return h + 15.0;
    }

    final boxFieldTypes = ['note', 'instructions'];
    final standardFields = fields
        .where((f) => f.fieldType != 'table' && !boxFieldTypes.contains(f.fieldType))
        .toList();
    final boxFields = fields.where((f) => boxFieldTypes.contains(f.fieldType)).toList();
    final tableFields = fields.where((f) => f.fieldType == 'table').toList();

    h += standardFields.length * (isLandscape ? 16.0 : 20.0);
    h += boxFields.length * (isLandscape ? 40.0 : 50.0);

    for (var tf in tableFields) {
      int rows = 3;
      final raw = valueMap[tf.id] ?? '';
      if (raw.isNotEmpty) {
        try {
          final data = jsonDecode(raw);
          if (data is List && data.isNotEmpty) rows = data.length;
        } catch (_) {}
      }
      h += (isLandscape ? 18.0 : 20.0) + (rows * (isLandscape ? 13.0 : 13.5));
    }

    return h;
  }

  static List<pw.Widget> _buildSingleSection(
    DynamicReportSection section,
    Map<int, String> valueMap,
    pw.Font ttf,
    pw.Font ttfBold,
    bool isLandscape,
  ) {
    List<pw.Widget> sectionWidgets = [];

    sectionWidgets.add(
      pw.Container(
        margin: pw.EdgeInsets.only(top: isLandscape ? 5 : 8, bottom: isLandscape ? 3 : 5),
        padding: pw.EdgeInsets.symmetric(horizontal: 5, vertical: isLandscape ? 2.5 : 4),
        color: PdfColors.grey200,
        alignment: pw.Alignment.centerRight,
        child: pw.Text(section.title, style: pw.TextStyle(font: ttfBold, fontSize: isLandscape ? 9.5 : 11), textAlign: pw.TextAlign.right),
      ),
    );

    if (section.description != null && section.description!.isNotEmpty) {
      sectionWidgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(section.description!, textAlign: pw.TextAlign.right, textDirection: pw.TextDirection.rtl, style: pw.TextStyle(font: ttf, fontSize: 9.5, color: PdfColors.grey700)),
        ),
      );
    }

    if (section.fields == null || section.fields!.isEmpty) {
      sectionWidgets.add(pw.Text('لا توجد حقول في هذا القسم.', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: ttf, fontSize: 10)));
      return sectionWidgets;
    }

    // فصل الحقول: قياسية (صفوف) / صناديق (ملاحظة وتعليمات) / جداول
    final boxFieldTypes = ['note', 'instructions'];
    final standardFields = section.fields!
        .where((f) => f.fieldType != 'table' && !boxFieldTypes.contains(f.fieldType))
        .toList();
    final boxFields = section.fields!.where((f) => boxFieldTypes.contains(f.fieldType)).toList();
    final tableFields = section.fields!.where((f) => f.fieldType == 'table').toList();

    if (standardFields.isNotEmpty) {
      List<pw.TableRow> rows = [];
      for (var field in standardFields) {
        String displayValue = valueMap[field.id!] ?? 'غير متوفر';
        final bool isCheckboxField = field.fieldType == 'checkbox';
        final bool isRatingField = field.fieldType == 'rating';

        if (field.fieldType == 'switch') {
          displayValue = (displayValue == 'true') ? 'نعم' : 'لا';
        }

        if (!isRatingField &&
            field.unit != null &&
            field.unit!.isNotEmpty &&
            valueMap.containsKey(field.id!)) {
          displayValue += ' ${field.unit}';
        }

        // خلية القيمة: checkbox يُرسم كمربع ☐/☑، والتقييم يُرسم كنجوم
        final pw.Widget valueChild;
        if (isCheckboxField) {
          valueChild = pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              _buildPdfCheckbox(displayValue == 'true'),
              pw.SizedBox(width: 5),
              pw.Text(
                displayValue == 'true' ? 'نعم' : 'لا',
                style: pw.TextStyle(font: ttf, fontSize: 10),
              ),
            ],
          );
        } else if (isRatingField) {
          valueChild = _buildPdfRatingRow(field, valueMap[field.id!], ttf);
        } else {
          valueChild = pw.Text(displayValue,
              textAlign: pw.TextAlign.right, style: pw.TextStyle(font: ttf, fontSize: 10));
        }

        // استخراج ألوان الحقل المخصصة (أو الافتراضية الأنيقة)
        final PdfColor labelBg = parseHexPdfColor(field.headerBgColor) ?? _headerLightBlue;
        final PdfColor? valBg = parseHexPdfColor(field.valueBgColor);

        // In RTL: child 0 is Left (value / التفاصيل), child 1 is Right (label / البند)
        rows.add(
          pw.TableRow(
            children: [
              pw.Container(
                color: valBg,
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: valueChild,
              ),
              pw.Container(
                color: labelBg,
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text(field.label, textAlign: pw.TextAlign.right, style: pw.TextStyle(font: ttfBold, fontSize: 10)),
              ),
            ],
          ),
        );
      }

      sectionWidgets.add(
        pw.Table(
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
          border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
          columnWidths: {
            0: const pw.FlexColumnWidth(3), // Left = Value
            1: const pw.FlexColumnWidth(2), // Right = Label
          },
          children: rows,
        ),
      );
    }

    // Add table fields
    for (var tableField in tableFields) {
      final rawJson = valueMap[tableField.id!] ?? '';
      sectionWidgets.add(
        _buildPdfTableField(tableField, rawJson, ttf, ttfBold, isLandscape),
      );
    }

    // Add note & instructions boxes
    for (var boxField in boxFields) {
      sectionWidgets.add(
        _buildPdfBoxField(boxField, valueMap[boxField.id!], ttf, ttfBold),
      );
    }

    return sectionWidgets;
  }

  static List<pw.Widget> _buildSectionsList(
    List<DynamicReportSection> sections,
    Map<int, String> valueMap,
    pw.Font ttf,
    pw.Font ttfBold,
    bool isLandscape,
  ) {
    if (sections.isEmpty) return [];
    List<pw.Widget> widgets = [];
    for (var sec in sections) {
      widgets.addAll(_buildSingleSection(sec, valueMap, ttf, ttfBold, isLandscape));
    }
    return widgets;
  }


  /// يبني صندوق الملاحظة أو التعليمات في الـ PDF (بعرض كامل).
  /// - الملاحظة: قيمتها من الإدخال (valueMap).
  /// - التعليمات: نصها الثابت في defaultValue.
  static pw.Widget _buildPdfBoxField(DynamicReportField field, String? value, pw.Font ttf, pw.Font ttfBold, {bool isCompact = false}) {
    final bool isNote = field.fieldType == 'note';
    final PdfColor headerColor = parseHexPdfColor(field.headerBgColor) ??
        (isNote ? const PdfColor.fromInt(0xFFFFE082) : const PdfColor.fromInt(0xFF90CAF9));
    final PdfColor bodyColor = parseHexPdfColor(field.valueBgColor) ??
        (isNote ? const PdfColor.fromInt(0xFFFFF8E1) : const PdfColor.fromInt(0xFFE3F2FD));
    final PdfColor headerTextColor =
        isNote ? const PdfColor.fromInt(0xFFE65100) : const PdfColor.fromInt(0xFF1565C0);

    final String body = isNote
        ? ((value ?? '').trim().isNotEmpty ? value!.trim() : 'غير متوفر')
        : (field.defaultValue ?? '');

    return pw.Container(
      margin: pw.EdgeInsets.only(top: isCompact ? 3 : 8),
      decoration: pw.BoxDecoration(
        color: bodyColor,
        border: pw.Border.all(color: headerColor, width: isCompact ? 0.7 : 1),
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(isCompact ? 4 : 6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            padding: pw.EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: isCompact ? 2 : 4),
            color: headerColor,
            child: pw.Text(
              field.label,
              style: pw.TextStyle(font: ttfBold, fontSize: isCompact ? 8 : 10, color: headerTextColor),
              textAlign: pw.TextAlign.right,
            ),
          ),
          pw.Padding(
            padding: pw.EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: isCompact ? 3 : 8),
            child: pw.Text(
              body,
              style: pw.TextStyle(font: ttf, fontSize: isCompact ? 7.2 : 9.5, height: isCompact ? 1.25 : 1.5),
              textAlign: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfTableField(DynamicReportField field, String rawJson, pw.Font ttf, pw.Font ttfBold, bool isLandscape, {bool isDedicatedPage = false, bool isLastPage = true, bool isCompact = false}) {
    final config = field.tableConfig ?? DynamicTableConfig.inspectionChecklistTemplate();
    List<Map<String, dynamic>> rows = [];
    if (rawJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawJson);
        if (decoded is List) {
          rows = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    if (rows.isEmpty && config.defaultRows.isNotEmpty) {
      rows = config.defaultRows.map((e) => Map<String, dynamic>.from(e)).toList();
    } else if (rows.isEmpty && config.rowCount > 0) {
      rows = List.generate(config.rowCount, (_) => <String, dynamic>{});
    }

    final isWide = isLandscape || config.columns.length > 5;
    final double headerFontSize = isDedicatedPage ? (isCompact ? 5.8 : 6.5) : (isWide ? 6.5 : 8.5);
    final double cellFontSize = isDedicatedPage ? (isCompact ? 5.8 : (isLastPage ? 6.5 : 7.2)) : (isWide ? 6.5 : 8.0);
    final double rowPadY = isDedicatedPage ? (isCompact ? 1.2 : (isLastPage ? 1.8 : 3.0)) : 3.0;

    List<pw.Widget> headerWidgets = [];
    List<double> widthRatios = [];

    // Serial number column (# / م)
    final bool hasExplicitNumCol = config.columns.any((c) => c.key == 'no' || c.key == 'num' || c.key == '#');
    if (!hasExplicitNumCol) {
      headerWidgets.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          alignment: pw.Alignment.center,
          child: pw.Text('م', style: pw.TextStyle(font: ttfBold, fontSize: headerFontSize), textAlign: pw.TextAlign.center),
        ),
      );
      widthRatios.add(0.45);
    }

    for (var col in config.columns) {
      final isTwoChoice = col.type == 'yes_no' || (col.type == 'radio' && (col.options.length == 2 || col.options.isEmpty));

      if (isTwoChoice) {
        final opt1 = col.type == 'yes_no' ? 'نعم' : (col.options.isNotEmpty ? col.options[0] : 'مطابق');
        final opt2 = col.type == 'yes_no' ? 'لا' : (col.options.length > 1 ? col.options[1] : 'غير مطابق');

        headerWidgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 1),
            alignment: pw.Alignment.center,
            child: pw.Column(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  col.title,
                  style: pw.TextStyle(font: ttfBold, fontSize: headerFontSize),
                  textAlign: pw.TextAlign.center,
                  maxLines: 3,
                ),
                pw.SizedBox(height: 2),
                pw.Container(
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide(color: _tableBorder, width: 0.5)),
                  ),
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        child: pw.Text(opt1, style: pw.TextStyle(font: ttfBold, fontSize: headerFontSize - 0.5), textAlign: pw.TextAlign.center),
                      ),
                      pw.Container(width: 0.5, height: 8, color: _tableBorder),
                      pw.Expanded(
                        child: pw.Text(opt2, style: pw.TextStyle(font: ttfBold, fontSize: headerFontSize - 0.5), textAlign: pw.TextAlign.center),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
        widthRatios.add(col.widthRatio);
      } else {
        double colWidth = col.widthRatio;
        if (col.key == 'leak_test' || col.title.contains('تسريب')) {
          colWidth = 1.45;
        }
        double colHeaderFontSize = headerFontSize;
        if (col.title.length > 15 || col.key == 'leak_test') {
          colHeaderFontSize = 5.8;
        }

        headerWidgets.add(
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 1.5),
            alignment: pw.Alignment.center,
            child: pw.Text(
              col.title,
              style: pw.TextStyle(font: ttfBold, fontSize: colHeaderFontSize),
              textAlign: pw.TextAlign.center,
              maxLines: 3,
            ),
          ),
        );
        widthRatios.add(colWidth);
      }
    }

    List<List<pw.Widget>> rowsCells = [];
    for (int rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final r = rows[rowIndex];
      List<pw.Widget> cellWidgets = [];

      if (!hasExplicitNumCol) {
        final displayRowNum = r['_row_num']?.toString() ?? '${rowIndex + 1}';
        cellWidgets.add(
          pw.Container(
            padding: pw.EdgeInsets.symmetric(vertical: rowPadY),
            alignment: pw.Alignment.center,
            child: pw.Text(displayRowNum, style: pw.TextStyle(font: ttfBold, fontSize: cellFontSize)),
          ),
        );
      }

      for (var col in config.columns) {
        final isTwoChoice = col.type == 'yes_no' || (col.type == 'radio' && (col.options.length == 2 || col.options.isEmpty));

        if (isTwoChoice) {
          final opt1 = col.type == 'yes_no' ? 'نعم' : (col.options.isNotEmpty ? col.options[0] : 'مطابق');
          final opt2 = col.type == 'yes_no' ? 'لا' : (col.options.length > 1 ? col.options[1] : 'غير مطابق');
          final val = r[col.key]?.toString() ?? '';
          final isOpt1 = val == opt1;
          final isOpt2 = val == opt2;

          cellWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              alignment: pw.Alignment.center,
              child: pw.Row(
                children: [
                  pw.Expanded(child: pw.Center(child: _buildPdfCheckbox(isOpt1, isWide))),
                  pw.Container(width: 0.5, height: 12, color: _tableBorder),
                  pw.Expanded(child: pw.Center(child: _buildPdfCheckbox(isOpt2, isWide))),
                ],
              ),
            ),
          );
        } else if (col.type == 'checkbox') {
          // عمود اختيار (Checkbox): يُرسم كمربع ☐/☑ بدلاً من نص true/false
          final bool isChecked =
              r[col.key] == true || r[col.key]?.toString().toLowerCase() == 'true';

          cellWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              alignment: pw.Alignment.center,
              child: _buildPdfCheckbox(isChecked, isWide),
            ),
          );
        } else if (col.type == 'signature' || col.key == 'signature') {
          // توقيع المراقب داخل الجدول
          final val = r[col.key]?.toString() ?? '';
          final bool isSigned = val.isNotEmpty && (val.contains('معتمد') || val.contains('✓') || val.contains('تم التوقيع'));

          cellWidgets.add(
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2),
              alignment: pw.Alignment.center,
              child: isSigned
                  ? pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.green700, width: 0.8),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                        color: PdfColors.green50,
                      ),
                      child: pw.Row(
                        mainAxisSize: pw.MainAxisSize.min,
                        children: [
                          _buildPdfCheckbox(true, true),
                          pw.SizedBox(width: 2.5),
                          pw.Text(
                            'معتمد',
                            style: pw.TextStyle(font: ttfBold, fontSize: cellFontSize, color: PdfColors.green800),
                            textAlign: pw.TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : pw.Text(
                      val,
                      style: pw.TextStyle(font: ttf, fontSize: cellFontSize),
                      textAlign: pw.TextAlign.center,
                    ),
            ),
          );
        } else {
          final val = r[col.key]?.toString() ?? '';
          final isItemCol = col.type == 'label' || col.key == 'item' || col.key == 'employee';

          cellWidgets.add(
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: rowPadY, horizontal: 2),
              alignment: isItemCol ? pw.Alignment.centerRight : pw.Alignment.center,
              child: pw.Text(
                val,
                style: pw.TextStyle(font: isItemCol ? ttfBold : ttf, fontSize: cellFontSize),
                textAlign: isItemCol ? pw.TextAlign.right : pw.TextAlign.center,
                maxLines: 3,
              ),
            ),
          );
        }
      }
      rowsCells.add(cellWidgets);
    }

    // In package:pdf, pw.Table column 0 is on the LEFT and column N is on the RIGHT.
    // To render right-to-left (RTL) for Arabic, we reverse the columns so column 0
    // is the leftmost on page (notes/corrective action), and column N is on the rightmost (م / serial number).
    final reversedHeader = headerWidgets.reversed.toList();
    final reversedWidths = widthRatios.reversed.toList();
    Map<int, pw.TableColumnWidth> columnWidths = {};
    for (int i = 0; i < reversedWidths.length; i++) {
      columnWidths[i] = pw.FlexColumnWidth(reversedWidths[i]);
    }

    List<pw.TableRow> tableRows = [];
    tableRows.add(pw.TableRow(decoration: const pw.BoxDecoration(color: _headerLightBlue), children: reversedHeader));

    for (int i = 0; i < rowsCells.length; i++) {
      final isColored = (i % 2 == 0);
      tableRows.add(
        pw.TableRow(
          decoration: isColored ? const pw.BoxDecoration(color: _zebraRowColor) : null,
          children: rowsCells[i].reversed.toList(),
        ),
      );
    }

    if (isDedicatedPage) {
      return pw.Table(
        border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
        columnWidths: columnWidths,
        children: tableRows,
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 6),
          color: PdfColors.grey100,
          alignment: pw.Alignment.centerRight,
          child: pw.Text(field.label, style: pw.TextStyle(font: ttfBold, fontSize: 10), textAlign: pw.TextAlign.right),
        ),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: _tableBorder, width: 0.6),
          columnWidths: columnWidths,
          children: tableRows,
        ),
        pw.SizedBox(height: 6),
      ],
    );
  }

  static pw.Widget _buildPdfCheckbox(bool checked, [bool isSmall = false]) {
    final double boxSize = isSmall ? 8.0 : 10.5;

    return pw.Container(
      width: boxSize,
      height: boxSize,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.7),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1)),
      ),
      child: checked
          ? pw.Center(
              child: pw.SvgImage(
                svg: '<svg viewBox="0 0 24 24" fill="none" stroke="#008000" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"></polyline></svg>',
              ),
            )
          : null,
    );
  }

  /// يبني صف نجوم لعرض قيمة حقل التقييم في الـ PDF (نجوم متجهية لا تعتمد على خط).
  static pw.Widget _buildPdfRatingRow(DynamicReportField field, String? rawValue, pw.Font ttf) {
    final bounds = CalculatedFieldHelper.ratingBounds(field);
    final current = int.tryParse((rawValue ?? '').trim()) ?? 0;
    const double starSize = 10.0;

    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        for (var v = bounds.min; v <= bounds.max; v++)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 1.5),
            child: pw.SizedBox(
              width: starSize,
              height: starSize,
              child: pw.Polygon(
                points: _starPoints(starSize),
                fillColor: (current != 0 && v <= current)
                    ? const PdfColor.fromInt(0xFFF9A825)
                    : const PdfColor.fromInt(0xFFE0E0E0),
                strokeColor: const PdfColor.fromInt(0xFF9E9E9E),
                strokeWidth: 0.6,
              ),
            ),
          ),
        pw.SizedBox(width: 6),
        pw.Text(
          current == 0 ? 'لم يُحدد' : '$current / ${bounds.max}',
          style: pw.TextStyle(font: ttf, fontSize: 9),
        ),
      ],
    );
  }

  /// يولّد نقاط نجمة خماسية ضمن مربع حجم [size] (إحداثيات الشاشة: y للأسفل).
  static List<PdfPoint> _starPoints(double size) {
    // نقاط وحدة النجمة (مضلع ذاتي-التقاطع بـ 10 رؤوس، الرأس للأعلى)
    const unit = <PdfPoint>[
      PdfPoint(0.5, 0.0),
      PdfPoint(0.6123, 0.3455),
      PdfPoint(0.9755, 0.3455),
      PdfPoint(0.6816, 0.5590),
      PdfPoint(0.7939, 0.9045),
      PdfPoint(0.5, 0.6910),
      PdfPoint(0.2061, 0.9045),
      PdfPoint(0.3184, 0.5590),
      PdfPoint(0.0245, 0.3455),
      PdfPoint(0.3877, 0.3455),
    ];
    return unit.map((p) => PdfPoint(p.x * size, p.y * size)).toList();
  }

  static pw.Widget _buildFooter(DynamicReport report, pw.Font ttf, [DynamicReportRecord? record]) {
    final docNum = (report.docNumber != null && report.docNumber!.trim().isNotEmpty)
        ? report.docNumber!.trim()
        : (report.name.isNotEmpty ? report.name : 'SELSAL-QA-DR');
    final versionNum = (report.versionNumber != null && report.versionNumber!.trim().isNotEmpty)
        ? report.versionNumber!.trim()
        : '01';
    final issueDate = (report.issueDate != null && report.issueDate!.trim().isNotEmpty)
        ? report.issueDate!.trim()
        : '2026/07/15';

    final recCode = record?.effectiveRecordCode ?? (record?.id != null ? '#${record!.id}' : '0');
    final recStatus = record?.approvalStatus ?? 'Approved';
    final recDate = DateFormat('yyyy-MM-dd').format(record?.createdAt ?? DateTime.now());
    final qrPayload = 'SELSAL-QMS|DOC:$docNum|VER:$versionNum|REC:$recCode|ST:$recStatus|DT:$recDate';

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text('رقم الوثيقة: $docNum', style: pw.TextStyle(font: ttf, fontSize: 8)),
          pw.Text('تاريخ الاصدار: $issueDate', style: pw.TextStyle(font: ttf, fontSize: 8)),
          pw.Text('إصدار رقم: $versionNum', style: pw.TextStyle(font: ttf, fontSize: 8)),
          pw.Row(
            mainAxisSize: pw.MainAxisSize.min,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'ختم التحقق الرقمي:',
                style: pw.TextStyle(font: ttf, fontSize: 6.8, color: PdfColors.grey800),
              ),
              pw.SizedBox(width: 4),
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrPayload,
                width: 17,
                height: 17,
                drawText: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build the 3-level signatures table at the bottom of the dynamic report
  static pw.Widget _buildSignaturesTable(
    DynamicReportRecord record,
    pw.Font ttf,
    pw.Font ttfBold, {
    required DynamicReport report,
    bool isSingleLevel = false,
    bool isLandscape = false,
    Uint8List? qsSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? creatorSignatureBytes,
    Uint8List? rejectedSignatureBytes,
    String? qsSignatureHash,
    String? qmSignatureHash,
    String? gmSignatureHash,
  }) {
    final sampleTakerName = formatCreatorName(record.createdBy);
    final isQsDone = record.approvalStatus == 'Approved' || record.approvalStatus == 'Pending_GM' || record.approvalStatus == 'Pending_QM';
    final bool isClosed = record.approvalStatus == 'Closed';
    final wasQsApproved = ApprovalStatus.wasApprovedByQsPriorToRejection(
      qsApprovedBy: record.qsApprovedBy,
      status: record.approvalStatus,
    );
    final effectiveQsDone = isQsDone || wasQsApproved || isClosed;
    final isQmDone = record.approvalStatus == 'Approved' || record.approvalStatus == 'Pending_GM';
    final isGmDone = record.approvalStatus == 'Approved' || isClosed;

    final hasCorrectiveAction = (record.correctiveAction ?? '').trim().isNotEmpty ||
        (record.rejectionReason ?? '').trim().isNotEmpty;
    final isQmCorrective = isClosed && hasCorrectiveAction;

    // تحديد حالة الرفض
    final isQsRejected = ApprovalStatus.rejectedByQualitySupervisor(
      rejectedBy: record.rejectedBy,
      qsApprovedBy: record.qsApprovedBy,
      status: record.approvalStatus,
    );
    final isQmRejected = ApprovalStatus.rejectedByQualityManager(
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      qmApprovedBy: record.qmApprovedBy,
      qsApprovedBy: record.qsApprovedBy,
      status: record.approvalStatus,
    );
    final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      status: record.approvalStatus,
    );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: record.qmApprovedBy,
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      status: record.approvalStatus,
    );
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: record.rejectedBy,
      gmDecisionBy: record.gmDecisionBy,
      status: record.approvalStatus,
    );

    final qsName = isQsRejected
        ? (record.rejectedBy ?? 'مشرف الجودة')
        : record.qsApprovedBy ?? (effectiveQsDone ? 'مشرف الجودة' : '________________');
    
    final bool isRejectorGm = (record.gmDecisionBy != null && record.gmDecisionBy == record.rejectedBy) ||
        (record.rejectedBy != null && (record.rejectedBy!.contains('مدير المصنع') || record.rejectedBy!.contains('العمري')));
    // اسم مدير الجودة: يظل اسم مدير الجودة الذي اعتمد أو رفض التقرير حتى بعد إغلاقه
    final qmName = record.qmApprovedBy ?? (!isRejectorGm ? record.rejectedBy : null) ?? 'مدير الجودة';
    
    final gmName = isGmRejected
        ? (record.gmDecisionBy ?? record.rejectedBy ?? 'مدير المصنع')
        : (record.gmDecisionBy ?? record.gmApprovedBy ?? (isGmDone ? 'د. خالد العمري (مدير المصنع)' : '________________'));

    final bool isThreeLevelQm = report.approvalType == 'three_level_qm';
    final bool endsAtQm = isSingleLevel || isThreeLevelQm;

    final qsStatusText = isQsRejected
        ? 'مرفوض'
        : (effectiveQsDone ? 'معتمد' : 'بانتظار الاعتماد');

    final qmStatusText = isClosed
        ? (endsAtQm ? 'معتمد بعد إجراء تصحيحي' : 'معتمد سابقاً')
        : ((isQmRejected || wasQmRejected)
            ? 'مرفوض'
            : (wasQmApproved || isGmRejected
                ? 'معتمد سابقاً (أُلغي برفض الإدارة)'
                : (isQmDone ? 'معتمد' : 'بانتظار الاعتماد')));

    final gmStatusText = isGmRejected
        ? 'مرفوض'
        : (isClosed
            ? 'معتمد بعد إجراء تصحيحي'
            : (isGmDone ? 'معتمد' : 'بانتظار الاعتماد'));

    final qsDate = isQsRejected
        ? (record.rejectedAt != null ? formatArabicDate(record.rejectedAt!) : formatArabicDate(DateTime.now()))
        : (record.qsApprovedAt != null
            ? formatArabicDate(record.qsApprovedAt!)
            : (effectiveQsDone ? formatArabicDate(DateTime.now()) : '  /  / 2026م'));
    final qmDate = isQmCorrective
        ? (record.rejectedAt != null ? formatArabicDate(record.rejectedAt!) : 'طلب إجراء تصحيحي')
        : (record.qmApprovedAt != null
            ? formatArabicDate(record.qmApprovedAt!)
            : (isQmDone || wasQmApproved || isQmRejected ? formatArabicDate(DateTime.now()) : '  /  / 2026م'));
    final gmDate = isClosed
        ? (record.gmDecisionAt != null
            ? formatArabicDate(record.gmDecisionAt!)
            : (record.gmApprovedAt != null
                ? formatArabicDate(record.gmApprovedAt!)
                : formatArabicDate(DateTime.now())))
        : (record.gmApprovedAt != null
            ? formatArabicDate(record.gmApprovedAt!)
            : (isGmDone || isGmRejected ? formatArabicDate(DateTime.now()) : '  /  / 2026م'));
    final entryDate = record.createdAt != null
        ? DateFormat('yyyy/MM/dd').format(record.createdAt!)
        : DateFormat('yyyy/MM/dd').format(DateTime.now());

    final creatorHeader = _buildHeaderCell('منفذ الفحص', ttfBold);
    final creatorCell = _buildSignatureCell(
      rawName: sampleTakerName,
      statusText: 'مكتمل ومُرسل',
      date: 'التاريخ: $entryDate',
      ttf: ttf,
      ttfBold: ttfBold,
      isLandscape: isLandscape,
      signatureBytes: creatorSignatureBytes,
      isApproved: true,
    );

    final qsHeader = _buildHeaderCell('مشرف الجودة', ttfBold);
    final qsCell = _buildSignatureCell(
      rawName: qsName,
      statusText: qsStatusText,
      date: 'التاريخ: $qsDate',
      ttf: ttf,
      ttfBold: ttfBold,
      isLandscape: isLandscape,
      signatureBytes: isQsRejected ? rejectedSignatureBytes : (effectiveQsDone ? qsSignatureBytes : null),
      signatureHash: qsSignatureHash,
      isRejected: isQsRejected,
      isApproved: effectiveQsDone && !isQsRejected,
    );

    final qmHeader = _buildHeaderCell(
      endsAtQm ? 'اعتماد مدير الجودة' : 'مدير الجودة',
      ttfBold,
      subtitle: isClosed ? (endsAtQm ? 'معتمد بعد إجراء تصحيحي' : 'معتمد سابقاً') : null,
    );
    final qmCell = _buildSignatureCell(
      rawName: qmName,
      statusText: qmStatusText,
      date: 'التاريخ: $qmDate',
      ttf: ttf,
      ttfBold: ttfBold,
      isLandscape: isLandscape,
      signatureBytes: isClosed
          ? qmSignatureBytes
          : ((isQmRejected || wasQmRejected) ? rejectedSignatureBytes : ((isQmDone || wasQmApproved) ? qmSignatureBytes : null)),
      signatureHash: qmSignatureHash,
      isRejected: (isQmRejected || wasQmRejected) && !isClosed,
      isApproved: endsAtQm
          ? ((isQmDone || isClosed) && !(isQmRejected || wasQmRejected))
          : (isQmDone && !isClosed && !(isQmRejected || wasQmRejected) && !wasQmApproved && !isGmRejected),
      isVoided: (!endsAtQm && isClosed) || wasQmApproved || isGmRejected,
    );

    final gmHeader = _buildHeaderCell('اعتماد مدير المصنع', ttfBold, subtitle: isClosed ? 'معتمد بعد إجراء تصحيحي' : null);
    final gmCell = _buildSignatureCell(
      rawName: gmName,
      statusText: gmStatusText,
      date: 'التاريخ: $gmDate',
      ttf: ttf,
      ttfBold: ttfBold,
      isLandscape: isLandscape,
      signatureBytes: isGmRejected ? rejectedSignatureBytes : (isGmDone ? gmSignatureBytes : null),
      signatureHash: gmSignatureHash,
      isRejected: isGmRejected,
      isApproved: (isClosed || isGmDone) && !isGmRejected,
    );

    final bool hasTableSignatures = report.sections?.any((sec) =>
        sec.fields?.any((f) {
          if (f.fieldType == 'table' && f.optionsJson != null) {
            try {
              final map = jsonDecode(f.optionsJson!);
              final cols = map['columns'] as List?;
              return cols?.any((c) => c['type'] == 'signature' || c['key'] == 'signature') ?? false;
            } catch (_) {}
          }
          return false;
        }) ?? false) ?? false;

    final List<pw.Widget> headerCells;
    final List<pw.Widget> dataCells;
    final Map<int, pw.TableColumnWidth> columnWidths;

    if (hasTableSignatures) {
      final qmReviewHeader = _buildHeaderCell('القائم بالتحقق والمراجعة', ttfBold, subtitle: '(مدير الجودة)');
      final gmApproveHeader = _buildHeaderCell('اعتماد', ttfBold, subtitle: 'مدير المصنع');
      if (report.approvalType == 'three_level') {
        headerCells = [gmApproveHeader, qmReviewHeader, qsHeader, creatorHeader];
        dataCells = [gmCell, qmCell, qsCell, creatorCell];
        columnWidths = {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
          3: const pw.FlexColumnWidth(1),
        };
      } else if (isThreeLevelQm) {
        headerCells = [qmReviewHeader, qsHeader, creatorHeader];
        dataCells = [qmCell, qsCell, creatorCell];
        columnWidths = {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
        };
      } else if (isSingleLevel) {
        headerCells = [qmReviewHeader, creatorHeader];
        dataCells = [qmCell, creatorCell];
        columnWidths = {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
        };
      } else {
        headerCells = [gmApproveHeader, qmReviewHeader, creatorHeader];
        dataCells = [gmCell, qmCell, creatorCell];
        columnWidths = {
          0: const pw.FlexColumnWidth(1),
          1: const pw.FlexColumnWidth(1),
          2: const pw.FlexColumnWidth(1),
        };
      }
    } else if (isThreeLevelQm) {
      headerCells = [qmHeader, qsHeader, creatorHeader];
      dataCells = [qmCell, qsCell, creatorCell];
      columnWidths = {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      };
    } else if (isSingleLevel) {
      headerCells = [qmHeader, creatorHeader];
      dataCells = [qmCell, creatorCell];
      columnWidths = {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
      };
    } else if (report.approvalType == 'three_level') {
      headerCells = [gmHeader, qmHeader, qsHeader, creatorHeader];
      dataCells = [gmCell, qmCell, qsCell, creatorCell];
      columnWidths = {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(1),
      };
    } else {
      headerCells = [gmHeader, qmHeader, creatorHeader];
      dataCells = [gmCell, qmCell, creatorCell];
      columnWidths = {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
      };
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
      columnWidths: columnWidths,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _headerLightBlue),
          children: headerCells,
        ),
        pw.TableRow(
          children: dataCells,
        ),
      ],
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font font, {String? subtitle}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 4),
      alignment: pw.Alignment.center,
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            text,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: font, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(
              subtitle,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: font, fontSize: 8.0, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ],
      ),
    );
  }

  /// خلية اعتماد مخصصة تضمن ثبات أبعاد المربع 100% بدون أي تمدد أو تغير في الشكل
  /// مع تراكب التوقيع كلياً فوق النصوص بأسلوب الختم الحي (Zero Layout Shift)
  static pw.Widget _buildSignatureCell({
    required String rawName,
    required String statusText,
    required String date,
    required pw.Font ttf,
    required pw.Font ttfBold,
    bool isLandscape = false,
    Uint8List? signatureBytes,
    String? signatureHash,
    bool isRejected = false,
    bool isVoided = false,
    bool isApproved = false,
  }) {
    final parsed = ArabicPdfService.splitNameAndRole(rawName);

    return pw.Container(
      padding: pw.EdgeInsets.symmetric(horizontal: 4, vertical: isLandscape ? 3 : 5),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            mainAxisSize: pw.MainAxisSize.min,
            children: [
              pw.Text(
                'الاسم: ${parsed.name}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: ttfBold, fontSize: 8),
              ),
              if (parsed.role != null) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  parsed.role!,
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttf, fontSize: 6.5, color: PdfColors.grey700),
                ),
              ],
              pw.SizedBox(height: 2),
              ArabicPdfService.statusBadge(
                text: statusText,
                isApproved: isApproved && !isRejected && !isVoided,
                isRejected: isRejected,
                fontSize: 7.5,
                font: ttfBold,
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                date,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: ttf, fontSize: 7, color: isRejected ? const PdfColor.fromInt(0xFFB71C1C) : PdfColors.grey700),
              ),
              if (signatureHash != null && signatureHash.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  'بصمة: ${signatureHash.length > 8 ? signatureHash.substring(0, 8) : signatureHash}',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: ttf, fontSize: 5.5, color: PdfColors.grey600),
                ),
              ],
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

  /// Helper to format dates cleanly in Arabic format
  static String formatArabicDate(DateTime? dt) {
    if (dt == null) return 'تاريخ غير متوفر';
    final date = DateFormat('yyyy/MM/dd').format(dt);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$date - $hour:$minute $period';
  }

  /// Helper to map English or raw status strings to Arabic
  static String formatArabicStatus(String? status) {
    if (status == null || status.trim().isEmpty) return 'مكتمل';
    switch (status.toLowerCase().trim()) {
      case 'approved':
      case 'معتمد':
        return 'معتمد';
      case 'pending_qm':
        return 'بانتظار اعتماد الجودة';
      case 'pending_gm':
        return 'بانتظار اعتماد الإدارة';
      case 'pending':
      case 'قيد الاعتماد':
        return 'قيد الاعتماد';
      case 'draft':
      case 'مسودة':
        return 'مسودة';
      case 'rejected':
      case 'مرفوض':
        return 'مرفوض';
      case 'completed':
      case 'مكتمل':
      default:
        return status.toLowerCase() == 'completed' ? 'مكتمل' : status;
    }
  }
}

