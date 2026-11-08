import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../constants/approval_status.dart';
import '../models/hygiene_models.dart';
import '../services/pdf/arabic_pdf_service.dart';
import '../services/user_signature_service.dart';

class HygieneReportPdfGenerator {
  /// توليد بيانات التقرير كـ Uint8List للاستخدام في الطباعة أو المشاركة أو المعاينة
  static Future<Uint8List> generateReportBytes({
    required List<Employee> employees,
    required List<ChecklistItem> criteria,
    required Map<String, bool> complianceMatrix,
    required Map<int, String> correctiveActions,
    required String reportDate,
    required String supervisorName,
    String branchName = 'مصنع أرتل',
    String shiftName = 'الأولى',
    String approvalStatus = 'Approved',
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    Uint8List? inspectorSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? rejectedSignatureBytes,
    String? rejectedBy,
    String? gmDecisionBy,
  }) async {
    // تحميل التوقيعات المعتمدة تلقائياً إذا لم يتم تمريرها
    final sigService = UserSignatureService.instance;
    inspectorSignatureBytes ??= await sigService.getSignatureBytesForUser(
      userName: supervisorName.isNotEmpty ? supervisorName : 'مفتش الجودة',
      userPosition: 'مفتش الجودة / منفذ الفحص',
    );
    if (qmSignatureBytes == null && qmApprovedBy != null && qmApprovedBy.isNotEmpty) {
      qmSignatureBytes = await sigService.getSignatureBytesForUser(
        userName: qmApprovedBy,
        userPosition: 'مدير الجودة',
      );
    }
    if (gmSignatureBytes == null && gmApprovedBy != null && gmApprovedBy.isNotEmpty) {
      gmSignatureBytes = await sigService.getSignatureBytesForUser(
        userName: gmApprovedBy,
        userPosition: 'مدير المصنع',
      );
    }

    await ArabicPdfService.initialize();

    return ArabicPdfService.generate(
      title: 'قائمة التفتيش على النظافة الشخصية - $reportDate',
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => pw.Column(
        children: [
          ArabicPdfService.bannerHeader(
            width: PdfPageFormat.a4.landscape.width - 48,
            height: 76,
          ),
          pw.SizedBox(height: 6),
        ],
      ),
      footer: (context) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6),
        child: _buildDocumentFooter(
          reportDate: reportDate,
          approvalStatus: approvalStatus,
        ),
      ),
      build: (context) {
        return [
          ArabicPdfService.badgeTitle('قائمة التفتيش على النظافة الشخصية'),
          pw.SizedBox(height: 10),
          _buildInfoTable(reportDate, supervisorName, branchName: branchName, shiftName: shiftName),
          pw.SizedBox(height: 12),
          ..._buildMainTable(employees, criteria, complianceMatrix, correctiveActions),
          pw.SizedBox(height: 16),
          pw.Spacer(),
          _buildSignaturesTable(
            supervisorName: supervisorName,
            reportDate: reportDate,
            approvalStatus: approvalStatus,
            qmApprovedBy: qmApprovedBy,
            qmApprovedAt: qmApprovedAt,
            gmApprovedBy: gmApprovedBy,
            gmApprovedAt: gmApprovedAt,
            inspectorSignatureBytes: inspectorSignatureBytes,
            qmSignatureBytes: qmSignatureBytes,
            gmSignatureBytes: gmSignatureBytes,
            rejectedSignatureBytes: rejectedSignatureBytes,
            rejectedBy: rejectedBy,
            gmDecisionBy: gmDecisionBy,
          ),
        ];
      },
    );
  }

  /// توليد وطباعة التقرير مباشرة
  static Future<void> generateAndPrintReport({
    required List<Employee> employees,
    required List<ChecklistItem> criteria,
    required Map<String, bool> complianceMatrix,
    required Map<int, String> correctiveActions,
    required String reportDate,
    required String supervisorName,
    String branchName = 'مصنع أرتل',
    String shiftName = 'الأولى',
    String approvalStatus = 'Approved',
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    Uint8List? inspectorSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? rejectedSignatureBytes,
    String? rejectedBy,
    String? gmDecisionBy,
  }) async {
    final pdfBytes = await generateReportBytes(
      employees: employees,
      criteria: criteria,
      complianceMatrix: complianceMatrix,
      correctiveActions: correctiveActions,
      reportDate: reportDate,
      supervisorName: supervisorName,
      branchName: branchName,
      shiftName: shiftName,
      approvalStatus: approvalStatus,
      qmApprovedBy: qmApprovedBy,
      qmApprovedAt: qmApprovedAt,
      gmApprovedBy: gmApprovedBy,
      gmApprovedAt: gmApprovedAt,
      inspectorSignatureBytes: inspectorSignatureBytes,
      qmSignatureBytes: qmSignatureBytes,
      gmSignatureBytes: gmSignatureBytes,
      rejectedSignatureBytes: rejectedSignatureBytes,
      rejectedBy: rejectedBy,
      gmDecisionBy: gmDecisionBy,
    );

    await ArabicPdfService.printPdf(pdfBytes);
  }

  static pw.Widget _buildInfoTable(
    String reportDate,
    String supervisorName, {
    String branchName = 'مصنع أرتل',
    String shiftName = 'الأولى',
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.0)),
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Row(
            children: [
              _infoCell('الشركة (الفرع)', isLabel: true, flex: 2),
              _infoCell(branchName, isLabel: false, flex: 3),
              _infoCell('التاريخ', isLabel: true, flex: 2),
              _infoCell(reportDate, isLabel: false, flex: 3),
            ],
          ),
          pw.Row(
            children: [
              _infoCell('مراقب السلامة الغذائية', isLabel: true, flex: 2),
              _infoCell(supervisorName, isLabel: false, flex: 3),
              _infoCell('الوردية', isLabel: true, flex: 2),
              _infoCell(shiftName, isLabel: false, flex: 3),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoCell(String text, {required bool isLabel, required int flex}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        height: 20,
        decoration: pw.BoxDecoration(
          color: isLabel ? PdfColors.grey300 : PdfColors.white,
          border: pw.Border.all(color: PdfColors.black, width: 0.5),
        ),
        alignment: pw.Alignment.center,
        child: pw.Text(
          text,
          style: isLabel
              ? ArabicPdfService.bold(fontSize: 10)
              : ArabicPdfService.regular(fontSize: 10),
        ),
      ),
    );
  }

  static List<pw.Widget> _buildMainTable(
    List<Employee> employees,
    List<ChecklistItem> criteria,
    Map<String, bool> complianceMatrix,
    Map<int, String> correctiveActions,
  ) {
    return [
      _buildTableHeader(criteria),
      ...employees.map((emp) => _buildEmployeeRow(emp, criteria, complianceMatrix, correctiveActions)),
      for (int i = employees.length; i < 15; i++)
        _buildEmptyRow(criteria),
    ];
  }

  static pw.Widget _buildTableHeader(List<ChecklistItem> criteria) {
    return pw.Row(
      children: [
        _headerCell('اسم الموظف', flex: 3),
        ...criteria.map((c) => _criteriaHeaderCell(c.itemName)),
        _headerCell('إذا اجبت ب لا ما التصرف\nالذي قمت به لتصحيح\nالوضع', flex: 4),
      ],
    );
  }

  static pw.Widget _headerCell(String text, {required int flex}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        decoration: pw.BoxDecoration(
          color: PdfColors.blue100,
          border: pw.Border.all(color: PdfColors.black, width: 0.5),
        ),
        alignment: pw.Alignment.center,
        padding: const pw.EdgeInsets.all(2),
        child: pw.Text(
          text,
          textAlign: pw.TextAlign.center,
          style: ArabicPdfService.bold(fontSize: 9),
        ),
      ),
    );
  }

  static pw.Widget _criteriaHeaderCell(String text) {
    return pw.Expanded(
      flex: 2,
      child: pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              color: PdfColors.white,
              padding: const pw.EdgeInsets.all(2),
              alignment: pw.Alignment.center,
              child: pw.Text(
                text,
                textAlign: pw.TextAlign.center,
                style: ArabicPdfService.bold(fontSize: 8),
              ),
            ),
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    height: 16,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: const pw.Border(
                        top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                        left: pw.BorderSide(color: PdfColors.black, width: 0.5),
                      ),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'نعم',
                      style: ArabicPdfService.bold(fontSize: 8, color: PdfColors.green),
                    ),
                  ),
                ),
                pw.Expanded(
                  child: pw.Container(
                    height: 16,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.red50,
                      border: const pw.Border(
                        top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                      ),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'لا',
                      style: ArabicPdfService.bold(fontSize: 8, color: PdfColors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildEmployeeRow(
    Employee emp,
    List<ChecklistItem> criteria,
    Map<String, bool> complianceMatrix,
    Map<int, String> correctiveActions,
  ) {
    return pw.Row(
      children: [
        _cell(emp.fullName, flex: 3, alignRight: true),
        ...criteria.map((c) {
          String key = '${emp.id}_${c.id}';
          bool isCompliant = complianceMatrix[key] ?? false;
          return _criteriaCheckCell(isCompliant);
        }),
        _cell(correctiveActions[emp.id] ?? '', flex: 4, alignRight: true),
      ],
    );
  }

  static pw.Widget _buildEmptyRow(List<ChecklistItem> criteria) {
    return pw.Row(
      children: [
        _cell('', flex: 3),
        ...criteria.map((_) => _criteriaCheckCellEmpty()),
        _cell('', flex: 4),
      ],
    );
  }

  static pw.Widget _cell(String text, {required int flex, bool alignRight = false}) {
    return pw.Expanded(
      flex: flex,
      child: pw.Container(
        height: 24,
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
        alignment: alignRight ? pw.Alignment.centerRight : pw.Alignment.center,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4),
        child: pw.Text(
          text,
          style: ArabicPdfService.regular(fontSize: 9),
        ),
      ),
    );
  }

  static pw.Widget _criteriaCheckCell(bool isCompliant) {
    return pw.Expanded(
      flex: 2,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              height: 24,
              decoration: pw.BoxDecoration(
                border: const pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  left: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                ),
              ),
              alignment: pw.Alignment.center,
              child: isCompliant ? _buildCheckmark() : pw.SizedBox(),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 24,
              decoration: pw.BoxDecoration(
                border: const pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                ),
              ),
              alignment: pw.Alignment.center,
              child: !isCompliant ? _buildCheckmark() : pw.SizedBox(),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _criteriaCheckCellEmpty() {
    return pw.Expanded(
      flex: 2,
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Container(
              height: 24,
              decoration: pw.BoxDecoration(
                border: const pw.Border(
                  right: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  left: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                ),
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 24,
              decoration: pw.BoxDecoration(
                border: const pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.black, width: 0.5),
                  top: pw.BorderSide(color: PdfColors.black, width: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildCheckmark() {
    const String svgCheckmark = '''
      <svg viewBox="0 0 24 24" fill="none" stroke="black" stroke-width="3" stroke-linecap="round" stroke-linejoin="round">
        <polyline points="20 6 9 17 4 12"></polyline>
      </svg>
    ''';
    return pw.SvgImage(svg: svgCheckmark, width: 12, height: 12);
  }

  static pw.Widget _buildSignaturesTable({
    required String supervisorName,
    required String reportDate,
    required String approvalStatus,
    String? qmApprovedBy,
    DateTime? qmApprovedAt,
    String? gmApprovedBy,
    DateTime? gmApprovedAt,
    Uint8List? inspectorSignatureBytes,
    Uint8List? qmSignatureBytes,
    Uint8List? gmSignatureBytes,
    Uint8List? rejectedSignatureBytes,
    String? rejectedBy,
    String? gmDecisionBy,
  }) {
    final isClosed = approvalStatus == 'Closed';
    final isRejected = approvalStatus == 'Rejected' || approvalStatus == 'Rejected_By_GM';
    final isPendingGm = approvalStatus == 'Pending_GM';
    final isApproved = approvalStatus == 'Approved';

    bool qmSigned = false;
    bool qmIsApproved = false;
    bool qmIsRejected = false;
    
    bool gmSigned = false;
    bool gmIsApproved = false;
    bool gmIsRejected = false;

    final isQmRejected = ApprovalStatus.rejectedByQualityManager(
      rejectedBy: rejectedBy,
      gmDecisionBy: gmDecisionBy,
      qmApprovedBy: qmApprovedBy,
      status: approvalStatus,
    );
    final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
      rejectedBy: rejectedBy,
      gmDecisionBy: gmDecisionBy,
      qmApprovedBy: qmApprovedBy,
      status: approvalStatus,
    );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: qmApprovedBy,
      rejectedBy: rejectedBy,
      gmDecisionBy: gmDecisionBy,
      status: approvalStatus,
    );
    final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
      rejectedBy: rejectedBy,
      gmDecisionBy: gmDecisionBy,
      status: approvalStatus,
    );

    if (isClosed) {
      qmSigned = true;
      gmSigned = true;
      gmIsApproved = true;
    } else if (isApproved) {
      qmSigned = true; qmIsApproved = true;
      gmSigned = true; gmIsApproved = true;
    } else if (isPendingGm) {
      qmSigned = true; qmIsApproved = true;
    } else if (isRejected) {
      if (isGmRejected || gmApprovedAt != null || (gmApprovedBy != null && gmApprovedBy.isNotEmpty) || wasQmApproved || wasQmRejected) {
        gmSigned = true; gmIsRejected = true;
        if (wasQmRejected) {
          qmSigned = true; qmIsRejected = true; qmIsApproved = false;
        } else {
          qmSigned = true; qmIsApproved = true;
        }
      } else {
        qmSigned = true; qmIsRejected = true;
      }
    }

    final gmName = isGmRejected
        ? (gmDecisionBy ?? rejectedBy ?? 'مدير المصنع')
        : (gmApprovedBy ?? gmDecisionBy ?? (gmSigned ? 'خالد العمري' : '________________'));

    final qmName = (isClosed || isQmRejected || wasQmRejected)
        ? (rejectedBy ?? qmApprovedBy ?? 'حمود يسر')
        : (qmApprovedBy ?? (qmSigned ? 'حمود يسر' : '________________'));

    final gmDateStr = gmApprovedAt != null
        ? ArabicPdfService.formatArabicDate(gmApprovedAt)
        : (isClosed ? 'معتمد' : (gmSigned ? (gmIsRejected ? 'مرفوض' : 'معتمد') : '  /  / 2026م'));

    final qmDateStr = qmApprovedAt != null
        ? ArabicPdfService.formatArabicDate(qmApprovedAt)
        : (isClosed ? 'مرفوض بإجراء تصحيحي' : (qmSigned ? (qmIsRejected ? 'مرفوض' : 'معتمد') : '  /  / 2026م'));

    String gmStatusText = isClosed
        ? 'معتمد (إغلاق الإجراء التصحيحي)'
        : (gmIsApproved ? 'معتمد' : (gmIsRejected ? 'مرفوض' : 'بانتظار الاعتماد'));

    String qmStatusText = isClosed
        ? 'مرفوض بإجراء تصحيحي'
        : (qmIsApproved
            ? (isGmRejected || wasQmApproved ? 'معتمد سابقاً (أُلغي برفض الإدارة)' : 'معتمد')
            : (qmIsRejected ? 'مرفوض' : 'بانتظار الاعتماد'));

    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 1.0)),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
        columnWidths: const {
          0: pw.FlexColumnWidth(1),
          1: pw.FlexColumnWidth(1),
          2: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFD6E6F5)),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  'اعتماد مدير المصنع',
                  textAlign: pw.TextAlign.center,
                  style: ArabicPdfService.bold(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  'مدير الجودة',
                  textAlign: pw.TextAlign.center,
                  style: ArabicPdfService.bold(fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  'منفذ الفحص (المفتش)',
                  textAlign: pw.TextAlign.center,
                  style: ArabicPdfService.bold(fontSize: 10),
                ),
              ),
            ],
          ),
          pw.TableRow(
            children: [
              _buildSigBox(
                name: gmName,
                statusText: gmStatusText,
                dateText: gmDateStr,
                isApproved: gmIsApproved,
                isRejected: gmIsRejected,
                hasSigned: gmSigned,
                signatureBytes: gmIsRejected ? rejectedSignatureBytes : (gmSigned ? gmSignatureBytes : null),
              ),
              _buildSigBox(
                name: qmName,
                statusText: qmStatusText,
                dateText: qmDateStr,
                isApproved: qmIsApproved,
                isRejected: qmIsRejected,
                hasSigned: qmSigned,
                signatureBytes: qmSigned ? (qmSignatureBytes ?? rejectedSignatureBytes) : null,
              ),
              _buildSigBox(
                name: supervisorName,
                statusText: 'مكتمل ومُرسل',
                dateText: reportDate,
                isApproved: true,
                isRejected: false,
                hasSigned: true,
                signatureBytes: inspectorSignatureBytes,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSigBox({
    required String name,
    required String statusText,
    required String dateText,
    required bool isApproved,
    bool isRejected = false,
    bool hasSigned = false,
    Uint8List? signatureBytes,
  }) {
    final parsed = ArabicPdfService.splitNameAndRole(name);

    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Stack(
        alignment: pw.Alignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text('الاسم: ${parsed.name}', style: ArabicPdfService.bold(fontSize: 9)),
              if (parsed.role != null) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  parsed.role!,
                  style: ArabicPdfService.regular(fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
              pw.SizedBox(height: 3),
              ArabicPdfService.statusBadge(
                text: statusText,
                isApproved: isApproved,
                isRejected: isRejected,
                fontSize: 8,
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                'التاريخ: $dateText',
                style: ArabicPdfService.regular(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
          if (signatureBytes != null && hasSigned)
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

  static pw.Widget _buildDocumentFooter({
    String reportDate = '',
    String approvalStatus = 'Approved',
  }) {
    final qrPayload = 'SELSAL-QMS|DOC:SELSAL-PRP-WI-01-01|VER:01|ST:$approvalStatus|DT:$reportDate';
    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey600),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'رقم الوثيقة: SELSAL-PRP-WI-01-01',
                style: ArabicPdfService.regular(fontSize: 9),
              ),
            ),
          ),
          pw.Container(width: 1, height: 24, color: PdfColors.grey400),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'تاريخ الإصدار: 2026/07/15',
                textAlign: pw.TextAlign.center,
                style: ArabicPdfService.regular(fontSize: 9),
              ),
            ),
          ),
          pw.Container(width: 1, height: 24, color: PdfColors.grey400),
          pw.Expanded(
            child: pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'إصدار رقم: 01',
                textAlign: pw.TextAlign.center,
                style: ArabicPdfService.regular(fontSize: 9),
              ),
            ),
          ),
          pw.Container(width: 1, height: 24, color: PdfColors.grey400),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(
                  'ختم التحقق:',
                  style: ArabicPdfService.regular(fontSize: 7.5, color: PdfColors.grey800),
                ),
                pw.SizedBox(width: 4),
                pw.BarcodeWidget(
                  barcode: pw.Barcode.qrCode(),
                  data: qrPayload,
                  width: 18,
                  height: 18,
                  drawText: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
