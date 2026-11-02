import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dynamic_report_pdf_generator.dart';
import '../constants/approval_status.dart';
import '../models/raw_material_models.dart';
import '../services/user_signature_service.dart';

class RawMaterialReportPdfGenerator {
  static const PdfColor _headerLightBlue = PdfColor.fromInt(0xFFBDD7EE);
  static const PdfColor _tableBorder = PdfColor.fromInt(0xFF8DB4E2);
  static const PdfColor _rowRed = PdfColor.fromInt(0xFFFFE9E9);

  static Future<Uint8List> generate({
    required RawMaterialReport report,
    required List<RawMaterialItemResult> generalResults,
    required List<RawMaterialItemResult> annexResults,
    Uint8List? inspectorSignatureBytes,
    Uint8List? qsSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? rejectedSignatureBytes,
  }) async {
    // Auto-load signatures if not supplied
    inspectorSignatureBytes ??= await UserSignatureService.instance.getSignatureBytesForUser(
      userName: report.inspectorName,
      userPosition: 'مفتش الجودة',
    );

    final bool isRejectorGmEarly = (report.gmDecisionBy != null && report.gmDecisionBy == report.rejectedBy) ||
        (report.rejectedBy != null && (report.rejectedBy!.contains('مدير المصنع') || report.rejectedBy!.contains('العمري')));
    final effectiveQmUser = report.qmApprovedBy ?? (!isRejectorGmEarly ? report.rejectedBy : null);
    if (effectiveQmUser != null && effectiveQmUser.isNotEmpty) {
      qmSignatureBytes ??= await UserSignatureService.instance.getSignatureBytesForUser(
        userName: effectiveQmUser,
        userPosition: 'مدير الجودة',
      );
    }

    // اعتماد مشرف الجودة يُحتسب من حالة التقرير أيضاً، حتى لو لم يصل حقل
    // lab_responsibleName من الـ API بعد تجاوز مرحلة المشرف.
    final isQsDone = report.approvalStatus == 'Approved' ||
        report.approvalStatus == 'Pending_GM' ||
        report.approvalStatus == 'Pending_QM';
    final qsSignerName =
        (report.labResponsibleName != null && report.labResponsibleName!.isNotEmpty)
            ? report.labResponsibleName!
            : (isQsDone ? 'مشرف الجودة' : '');
    if (qsSignerName.isNotEmpty) {
      qsSignatureBytes ??= await UserSignatureService.instance.getSignatureBytesForUser(
        userName: qsSignerName,
        userPosition: 'مشرف الجودة',
      );
    }

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

    // ==================== PAGE 1: GENERAL RECEIPT & CHECKLIST ====================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(logoImage, ttf, ttfBold, '7 - 1'),
                pw.SizedBox(height: 6),
                _buildTitleBox('نموذج فحص المواد الخام', ttfBold),
                pw.SizedBox(height: 8),
                _buildReceiptDataSection(report, ttf, ttfBold),
                pw.SizedBox(height: 8),
                _buildGeneralChecklistSection(generalResults, ttf, ttfBold),
                pw.SizedBox(height: 8),
                _buildDecisionAndActionsSection(report, ttf, ttfBold),
                pw.SizedBox(height: 6),
                _buildNotesBox(report.generalNotes, ttf, ttfBold, 'الملاحظات:'),
                pw.Spacer(),
                _buildFooter('SELSAL-IMSF-19-03', ttf),
              ],
            ),
          );
        },
      ),
    );

    // ==================== PAGE 2: SPECIALIZED ANNEX ====================
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        theme: pw.ThemeData.withFont(base: ttf, bold: ttfBold),
        build: (context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                _buildHeader(logoImage, ttf, ttfBold, '7 - 2'),
                pw.SizedBox(height: 6),
                _buildTitleBox('نموذج فحص المواد الخام', ttfBold),
                pw.SizedBox(height: 8),
                _buildAnnexHeader(report, ttf, ttfBold),
                pw.SizedBox(height: 8),
                _buildAnnexChecklistSection(annexResults, ttf, ttfBold),
                pw.SizedBox(height: 8),
                _buildNotesBox(report.annexNotes, ttf, ttfBold, 'ملاحظات:'),
                pw.SizedBox(height: 12),
                pw.Spacer(),
                _buildSignaturesTable(
                  report,
                  ttf,
                  ttfBold,
                  inspectorSignatureBytes: inspectorSignatureBytes,
                  qsSignatureBytes: qsSignatureBytes,
                  qmSignatureBytes: qmSignatureBytes,
                  gmSignatureBytes: gmSignatureBytes,
                  rejectedSignatureBytes: rejectedSignatureBytes,
                ),
                _buildFooter(report.annexCode, ttf),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(pw.MemoryImage? logoImage, pw.Font ttf, pw.Font ttfBold, String pageNum) {
    if (logoImage != null) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Image(
            logoImage,
            width: PdfPageFormat.a4.width - 48,
            height: 62,
            fit: pw.BoxFit.fill,
          ),
          pw.SizedBox(height: 2),
          pw.Align(
            alignment: pw.Alignment.topLeft, // in RTL this appears on the top-left/right edge
            child: pw.Text(pageNum, style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
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

  static pw.Widget _buildTitleBox(String title, pw.Font ttfBold) {
    return pw.Center(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.black, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
        ),
        child: pw.Text(
          title,
          style: pw.TextStyle(font: ttfBold, fontSize: 13),
        ),
      ),
    );
  }

  static pw.Widget _buildReceiptDataSection(RawMaterialReport report, pw.Font ttf, pw.Font ttfBold) {
    pw.Widget cell(String label, String value, {bool isLabel = false}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3.5),
        alignment: pw.Alignment.centerRight,
        color: isLabel ? _headerLightBlue : PdfColors.white,
        child: pw.Text(
          isLabel ? label : value,
          style: pw.TextStyle(font: isLabel ? ttfBold : ttf, fontSize: 8),
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('أولاً: بيانات الاستلام:', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.0), // قيمة 2 (اليسار)
            1: pw.FlexColumnWidth(1.2), // عنوان 2
            2: pw.FlexColumnWidth(2.0), // قيمة 1
            3: pw.FlexColumnWidth(1.2), // عنوان 1 (اليمين)
          },
          children: [
            pw.TableRow(children: [
              cell('', report.timeStr),
              cell('الوقت', '', isLabel: true),
              cell('', report.dateStr),
              cell('التاريخ', '', isLabel: true),
            ]),
            pw.TableRow(children: [
              cell('', report.poNumber),
              cell('رقم أمر الشراء', '', isLabel: true),
              cell('', report.supplierName),
              cell('اسم المورد', '', isLabel: true),
            ]),
            pw.TableRow(children: [
              cell('', report.receiptNumber),
              cell('رقم إذن الاستلام', '', isLabel: true),
              cell('', report.materialName),
              cell('اسم المادة', '', isLabel: true),
            ]),
            pw.TableRow(children: [
              cell('', report.inspectedQuantity),
              cell('الكمية المفحوصة', '', isLabel: true),
              cell('', report.receivedQuantity),
              cell('الكمية المستلمة', '', isLabel: true),
            ]),
            pw.TableRow(children: [
              cell('', report.rejectedQuantity),
              cell('الكمية المرفوضة', '', isLabel: true),
              cell('', report.acceptedQuantity),
              cell('الكمية المقبولة', '', isLabel: true),
            ]),
            pw.TableRow(children: [
              cell('', report.batchNumber),
              cell('رقم التشغيلة', '', isLabel: true),
              cell('', report.inspectorName),
              cell('اسم المفتش', '', isLabel: true),
            ]),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildPdfCheckbox({required bool isChecked, double size = 9.5, String strokeColor = '#2E7D32'}) {
    return pw.Container(
      width: size,
      height: size,
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
                svg: '<svg viewBox="0 0 24 24"><path fill="none" stroke="$strokeColor" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" d="M4 12.5l5.5 5.5L20 6.5"/></svg>',
              ),
            )
          : null,
    );
  }

  static pw.Widget _buildPdfCross({required bool isChecked, double size = 9.5}) {
    return pw.Container(
      width: size,
      height: size,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: isChecked ? const PdfColor.fromInt(0xFFC62828) : PdfColors.grey600, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(1.5)),
        color: isChecked ? const PdfColor.fromInt(0xFFFFEBEE) : PdfColors.white,
      ),
      alignment: pw.Alignment.center,
      child: isChecked
          ? pw.Padding(
              padding: const pw.EdgeInsets.all(1.0),
              child: pw.SvgImage(
                svg: '<svg viewBox="0 0 24 24"><path fill="none" stroke="#C62828" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round" d="M6 6l12 12M18 6L6 18"/></svg>',
              ),
            )
          : null,
    );
  }

  static pw.Widget _buildGeneralChecklistSection(List<RawMaterialItemResult> results, pw.Font ttf, pw.Font ttfBold) {
    pw.Widget th(String text) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3.5, horizontal: 3),
        alignment: pw.Alignment.center,
        color: _headerLightBlue,
        child: pw.Text(text, style: pw.TextStyle(font: ttfBold, fontSize: 8), textAlign: pw.TextAlign.center),
      );
    }

    pw.Widget td(String text, {pw.Alignment alignment = pw.Alignment.centerRight, PdfColor? bg}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 3),
        alignment: alignment,
        color: bg ?? PdfColors.white,
        child: pw.Text(text, style: pw.TextStyle(font: ttf, fontSize: 7.5), textAlign: pw.TextAlign.right),
      );
    }

    pw.Widget tdCheck(bool checked) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        alignment: pw.Alignment.center,
        child: _buildPdfCheckbox(isChecked: checked, size: 9),
      );
    }

    pw.Widget tdCross(bool checked) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        alignment: pw.Alignment.center,
        child: _buildPdfCross(isChecked: checked, size: 9),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('ثانياً: نتائج الفحص:', style: pw.TextStyle(font: ttfBold, fontSize: 9.5)),
        pw.SizedBox(height: 3),
        pw.Table(
          border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
          columnWidths: const {
            0: pw.FlexColumnWidth(2.5), // الملاحظات (اليسار)
            1: pw.FlexColumnWidth(1.0), // غير مطابق
            2: pw.FlexColumnWidth(1.0), // مطابق
            3: pw.FlexColumnWidth(1.8), // النتيجة
            4: pw.FlexColumnWidth(2.5), // معيار القبول
            5: pw.FlexColumnWidth(3.0), // بند الفحص (اليمين)
          },
          children: [
            pw.TableRow(children: [
              th('الملاحظات'),
              th('غير مطابق'),
              th('مطابق'),
              th('النتيجة'),
              th('معيار القبول'),
              th('بند الفحص'),
            ]),
            ...results.map((r) {
              final isCompliant = r.isCompliant == true;
              final isNonCompliant = r.isCompliant == false;
              final bg = isNonCompliant ? _rowRed : PdfColors.white;

              return pw.TableRow(
                decoration: pw.BoxDecoration(color: bg),
                children: [
                  td(r.notes ?? '', bg: bg),
                  tdCross(isNonCompliant),
                  tdCheck(isCompliant),
                  td(r.resultValue ?? (isCompliant ? 'مطابق' : ''), alignment: pw.Alignment.center, bg: bg),
                  td(r.acceptanceCriteria, bg: bg),
                  td(r.itemName, bg: bg),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildDecisionAndActionsSection(RawMaterialReport report, pw.Font ttf, pw.Font ttfBold) {
    pw.Widget checkItem(String label, bool isChecked, {String strokeColor = '#0D47A1'}) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          _buildPdfCheckbox(isChecked: isChecked, size: 8.5, strokeColor: strokeColor),
          pw.SizedBox(width: 4),
          pw.Text(label, style: pw.TextStyle(font: isChecked ? ttfBold : ttf, fontSize: 8)),
        ],
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _tableBorder, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Actions Taken (Left in LTR coordinate space = Left in visual)
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('الإجراءات المتخذة:', style: pw.TextStyle(font: ttfBold, fontSize: 8.5)),
                pw.SizedBox(height: 3),
                checkItem('وضع بطاقة HOLD.', report.actionHold),
                pw.SizedBox(height: 2),
                checkItem('وضع بطاقة REJECT.', report.actionReject, strokeColor: '#C62828'),
                pw.SizedBox(height: 2),
                checkItem('إعادة للمورد.', report.actionReturnToSupplier),
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    _buildPdfCheckbox(isChecked: report.actionNcr, size: 8.5, strokeColor: '#C62828'),
                    pw.SizedBox(width: 4),
                    pw.Text('تم فتح NCR رقم: ${report.ncrNumber ?? '........'}', style: pw.TextStyle(font: ttf, fontSize: 8)),
                  ],
                ),
              ],
            ),
          ),
          pw.Container(width: 0.5, height: 65, color: _tableBorder),
          pw.SizedBox(width: 10),
          // Quality Decision (Right in visual)
          pw.Expanded(
            flex: 5,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('قرار الجودة:', style: pw.TextStyle(font: ttfBold, fontSize: 8.5)),
                pw.SizedBox(height: 3),
                checkItem('مقبول للاستخدام.', report.qualityDecision == 'Accepted', strokeColor: '#2E7D32'),
                pw.SizedBox(height: 2),
                checkItem('مقبول بشروط.', report.qualityDecision == 'AcceptedWithConditions', strokeColor: '#E65100'),
                pw.SizedBox(height: 2),
                checkItem('حجز (HOLD)', report.qualityDecision == 'Hold', strokeColor: '#F57F17'),
                pw.SizedBox(height: 2),
                checkItem('مرفوض (REJECT)', report.qualityDecision == 'Reject', strokeColor: '#C62828'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAnnexHeader(RawMaterialReport report, pw.Font ttf, pw.Font ttfBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(report.annexTitle, style: pw.TextStyle(font: ttfBold, fontSize: 11), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text('رقم الملحق: ${report.annexCode}', style: pw.TextStyle(font: ttfBold, fontSize: 9.5, color: PdfColors.grey800)),
      ],
    );
  }

  static pw.Widget _buildAnnexChecklistSection(List<RawMaterialItemResult> results, pw.Font ttf, pw.Font ttfBold) {
    pw.Widget th(String text) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        alignment: pw.Alignment.center,
        color: _headerLightBlue,
        child: pw.Text(text, style: pw.TextStyle(font: ttfBold, fontSize: 8.5), textAlign: pw.TextAlign.center),
      );
    }

    pw.Widget td(String text, {pw.Alignment alignment = pw.Alignment.centerRight, PdfColor? bg}) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        alignment: alignment,
        color: bg ?? PdfColors.white,
        child: pw.Text(text, style: pw.TextStyle(font: ttf, fontSize: 8), textAlign: pw.TextAlign.right),
      );
    }

    pw.Widget tdCheck(bool checked) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        alignment: pw.Alignment.center,
        child: _buildPdfCheckbox(isChecked: checked, size: 9),
      );
    }

    pw.Widget tdCross(bool checked) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        alignment: pw.Alignment.center,
        child: _buildPdfCross(isChecked: checked, size: 9),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(color: _tableBorder, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(3.0), // الملاحظات (اليسار)
        1: pw.FlexColumnWidth(1.2), // غير مطابق
        2: pw.FlexColumnWidth(1.2), // مطابق
        3: pw.FlexColumnWidth(3.0), // معيار القبول
        4: pw.FlexColumnWidth(3.5), // بند الفحص (اليمين)
      },
      children: [
        pw.TableRow(children: [
          th('الملاحظات'),
          th('غير مطابق'),
          th('مطابق'),
          th('معيار القبول'),
          th('بند الفحص'),
        ]),
        ...results.map((r) {
          final isCompliant = r.isCompliant == true;
          final isNonCompliant = r.isCompliant == false;
          final bg = isNonCompliant ? _rowRed : PdfColors.white;

          return pw.TableRow(
            decoration: pw.BoxDecoration(color: bg),
            children: [
              td(r.notes ?? '', bg: bg),
              tdCross(isNonCompliant),
              tdCheck(isCompliant),
              td(r.acceptanceCriteria, bg: bg),
              td(r.itemName, bg: bg),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _buildNotesBox(String? notes, pw.Font ttf, pw.Font ttfBold, String label) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(font: ttfBold, fontSize: 9)),
        pw.SizedBox(height: 2),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(6),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _tableBorder, width: 0.5),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
          ),
          child: pw.Text(
            notes != null && notes.isNotEmpty ? notes : 'لا توجد ملاحظات إضافية.',
            style: pw.TextStyle(font: ttf, fontSize: 8),
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildSignaturesTable(
    RawMaterialReport report,
    pw.Font ttf,
    pw.Font ttfBold, {
    Uint8List? inspectorSignatureBytes,
    Uint8List? qsSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? rejectedSignatureBytes,
  }) {
    final status = report.approvalStatus;
    final bool isClosed = status == 'Closed';
    final wasQsApproved = ApprovalStatus.wasApprovedByQsPriorToRejection(
      qsApprovedBy: report.labResponsibleName,
      status: status,
    );
    final isQsDone = status == 'Approved' || status == 'Pending_GM' || status == 'Pending_QM' || isClosed || wasQsApproved;
    final isQmDone = status == 'Approved' || status == 'Pending_GM';
    final isGmDone = status == 'Approved' || isClosed;

    final hasCorrectiveAction = (report.correctiveAction ?? '').trim().isNotEmpty ||
        (report.rejectionReason ?? '').trim().isNotEmpty;
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      status: status,
    );
    final isQmCorrective = (isClosed || status == 'Pending_GM_Decision' || status == 'Rejected_By_GM') && (hasCorrectiveAction || wasQmRejected);

    final isQsRejected = ApprovalStatus.rejectedByQualitySupervisor(
      rejectedBy: report.rejectedBy,
      qsApprovedBy: report.labResponsibleName,
      status: status,
    );
    final isQmRejected = ApprovalStatus.rejectedByQualityManager(
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      qmApprovedBy: report.qmApprovedBy,
      qsApprovedBy: report.labResponsibleName,
      status: status,
    );
    final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      status: status,
    );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: report.qmApprovedBy,
      rejectedBy: report.rejectedBy,
      gmDecisionBy: report.gmDecisionBy,
      status: status,
    );
    final bool isRejectorGm = (report.gmDecisionBy != null && report.gmDecisionBy == report.rejectedBy) ||
        (report.rejectedBy != null && (report.rejectedBy!.contains('مدير المصنع') || report.rejectedBy!.contains('العمري')));

    final inspector = report.inspectorName;

    final qsName = isQsRejected
        ? (report.rejectedBy ?? 'مشرف الجودة')
        : report.labResponsibleName ?? (isQsDone ? 'مشرف الجودة' : '');
    final qsDate = isQsRejected
        ? 'مرفوض'
        : (report.labResponsibleAt != null
            ? DynamicReportPdfGenerator.formatArabicDate(report.labResponsibleAt!)
            : (isQsDone ? DynamicReportPdfGenerator.formatArabicDate(DateTime.now()) : ''));

    final qmTitle = isClosed
        ? 'مدير الجودة (معتمد سابقاً)'
        : (isQmCorrective ? 'مراجعة مدير الجودة (إجراء تصحيحي)' : (wasQmApproved ? 'اعتماد مدير الجودة (سابقاً)' : 'اعتماد مدير الجودة'));
    final qm = isClosed
        ? (report.qmApprovedBy ?? 'أ. حمود يسر (مدير الجودة)')
        : (isQmCorrective
            ? (report.rejectedBy ?? report.qmApprovedBy ?? 'أ. حمود يسر (مدير الجودة)')
            : (isQmRejected || wasQmRejected
                ? (report.rejectedBy ?? 'مدير الجودة')
                : (report.qmApprovedBy ?? (!isRejectorGm ? report.rejectedBy : null) ?? (isQmDone || wasQmApproved ? 'حمود يسر (مدير الجودة)' : ''))));
    final qmDate = isClosed
        ? (report.qmApprovedAt != null ? DynamicReportPdfGenerator.formatArabicDate(report.qmApprovedAt!) : 'معتمد سابقاً')
        : (isQmCorrective
            ? 'مرفوض بإجراء تصحيحي'
            : (report.qmApprovedAt != null 
                ? DynamicReportPdfGenerator.formatArabicDate(report.qmApprovedAt!) 
                : (isQmDone || wasQmApproved || isQmRejected || wasQmRejected ? DynamicReportPdfGenerator.formatArabicDate(DateTime.now()) : '')));

    final gmTitle = isClosed ? 'اعتماد مدير المصنع (بعد إجراء تصحيحي)' : 'اعتماد مدير المصنع';
    final gm = isGmRejected && !isClosed
        ? (report.gmDecisionBy ?? report.rejectedBy ?? 'مدير المصنع')
        : (report.gmDecisionBy ?? report.gmApprovedBy ?? (isGmDone ? 'خالد العمري (مدير المصنع)' : ''));
    final gmDate = isClosed
        ? (report.gmDecisionAt != null
            ? DynamicReportPdfGenerator.formatArabicDate(report.gmDecisionAt!)
            : 'معتمد بعد إجراء تصحيحي')
        : (report.gmApprovedAt != null 
            ? DynamicReportPdfGenerator.formatArabicDate(report.gmApprovedAt!) 
            : (isGmDone || isGmRejected ? DynamicReportPdfGenerator.formatArabicDate(DateTime.now()) : ''));

    pw.Widget sigCol(String title, String name, String date, {Uint8List? signatureBytes, bool isRejected = false, bool isApproved = false, bool isVoided = false}) {
      final pdfRed = PdfColor.fromHex('#C62828');
      final pdfGreen = PdfColor.fromHex('#2E7D32');
      final pdfAmber = PdfColor.fromHex('#E65100');
      final borderColor = isRejected ? pdfRed : (isVoided ? pdfAmber : (isApproved ? pdfGreen : _tableBorder));
      final bgColor = isRejected ? PdfColor.fromHex('#FFEBEE') : (isVoided ? PdfColor.fromHex('#FFF8E1') : (isApproved ? PdfColor.fromHex('#F1F8E9') : PdfColors.white));
      final textColor = isRejected ? pdfRed : (isVoided ? pdfAmber : (isApproved ? pdfGreen : PdfColors.black));

      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: borderColor, width: 0.5),
            color: bgColor,
          ),
          child: pw.Stack(
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    color: isRejected ? pdfRed : (isApproved ? pdfGreen : _headerLightBlue),
                    alignment: pw.Alignment.center,
                    child: pw.Text(title, style: pw.TextStyle(font: ttfBold, fontSize: 8, color: isRejected || isApproved ? PdfColors.white : PdfColors.black)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('الاسم: $name', style: pw.TextStyle(font: ttf, fontSize: 7.5, color: textColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('التوقيع: ${name.isNotEmpty ? (isRejected ? "مرفوض" : "معتمد إلكترونياً") : "................"}', style: pw.TextStyle(font: ttf, fontSize: 7.5, color: textColor)),
                  pw.SizedBox(height: 2),
                  pw.Text('التاريخ: ${date.isNotEmpty ? date : "2026/  /  م"}', style: pw.TextStyle(font: ttf, fontSize: 7.5, color: textColor)),
                ],
              ),
              if (name.isNotEmpty && signatureBytes != null && (isApproved || isRejected || isVoided))
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
        ),
      );
    }

    return pw.Row(
      children: [
        sigCol(gmTitle, gm, gmDate, signatureBytes: isGmRejected && !isClosed ? rejectedSignatureBytes : (isGmDone || isClosed ? gmSignatureBytes : null), isRejected: isGmRejected && !isClosed, isApproved: isGmDone || isClosed),
        pw.SizedBox(width: 4),
        sigCol(qmTitle, qm, qmDate, signatureBytes: isClosed ? qmSignatureBytes : (isQmCorrective ? (rejectedSignatureBytes ?? qmSignatureBytes) : ((isQmRejected || wasQmRejected || (!isRejectorGm && report.rejectedBy != null)) ? (rejectedSignatureBytes ?? qmSignatureBytes) : ((isQmDone || wasQmApproved) ? qmSignatureBytes : null))), isRejected: (isQmRejected || wasQmRejected || isQmCorrective || (!isRejectorGm && report.rejectedBy != null)) && !isClosed, isApproved: isQmDone && !isQmCorrective && !isClosed, isVoided: isClosed || wasQmApproved),
        pw.SizedBox(width: 4),
        sigCol('اعتماد مشرف الجودة', qsName, qsDate, signatureBytes: isQsRejected ? rejectedSignatureBytes : (isQsDone ? qsSignatureBytes : null), isRejected: isQsRejected, isApproved: isQsDone && !isQsRejected),
        pw.SizedBox(width: 4),
        sigCol('مفتش الجودة', inspector, report.dateStr, signatureBytes: inspectorSignatureBytes, isApproved: true),
      ],
    );
  }

  static pw.Widget _buildFooter(String docNum, pw.Font ttf) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.black, width: 0.8),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('إصدار رقم: 01', style: pw.TextStyle(font: ttf, fontSize: 8)),
          pw.Text('تاريخ الاصدار: 2026/07/15', style: pw.TextStyle(font: ttf, fontSize: 8)),
          pw.Text('رقم الوثيقة: $docNum', style: pw.TextStyle(font: ttf, fontSize: 8)),
        ],
      ),
    );
  }
}
