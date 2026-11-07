import '../widgets/corrective_action_submit_dialog.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/approval_status.dart';
import '../controllers/hygiene_report_display_controller.dart';
import '../models/hygiene_models.dart';
import '../services/pdf/arabic_pdf_service.dart';
import '../services/user_session_service.dart';
import '../utils/dynamic_report_pdf_generator.dart';
import '../widgets/factory_manager_rejection_card.dart';
import '../widgets/zoomable_document_view.dart';
import '../widgets/gm_decision_dialog.dart';
import '../widgets/reject_report_dialog.dart';
import '../widgets/ds/ds.dart';

class HygieneReportDisplayView extends StatelessWidget {
  HygieneReportDisplayView({super.key, required this.reportId});

  final int reportId;
  late final HygieneReportDisplayController controller = Get.put(
    HygieneReportDisplayController(reportId),
    tag: 'hygiene_report_$reportId',
  );

  // Fixed column widths
  final double colEmployeeWidth = 160.0;
  final double colActionWidth = 320.0;
  final double colCriteriaWidth = 80.0; // 40 for Yes, 40 for No

  double get tableWidth {
    final count = controller.criteria.isEmpty ? 9 : controller.criteria.length;
    return colEmployeeWidth + (count * colCriteriaWidth) + colActionWidth;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'قائمة التفتيش على النظافة الشخصية',
      actions: [
        if (UserSessionService.to.canExportPdf)
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'طباعة / تصدير PDF',
            onPressed: controller.printReport,
          ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: AppLoading(message: 'جاري تحميل التقرير...'));
        }

        if (!UserSessionService.to.canViewBranchData(controller.reportBranchId)) {
          return _buildAccessDeniedWidget(context);
        }

        final currentTableWidth = tableWidth;

        // شريط الاعتماد يبقى ثابتاً في الأعلى (غير خاضع للتكبير)
        return Column(
          children: [
            Expanded(
              child: ZoomableDocumentView(
                documentWidth: currentTableWidth + 100,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. Interactive Approval Status Banner & Action Buttons (يسكرول مع التقرير)
                      _buildApprovalActionBar(context),
                      const SizedBox(height: 16),

                      // 2. The Official Report Document (Pinch-to-Zoom + Pan)
                      Container(
                        width: currentTableWidth + 60, // padding + border buffer
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                           color: Theme.of(context).colorScheme.surface,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Watermark Logo
                            Positioned.fill(
                              child: Center(
                                child: Opacity(
                                  opacity: 0.05,
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 400,
                                    height: 400,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.water_drop, size: 400, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            
                            // Foreground Content
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildOfficialHeaderAndTitle(currentTableWidth),
                                const SizedBox(height: 16),
                                _buildInfoTable(),
                                const SizedBox(height: 16),
                                _buildMainTable(context),
                                const SizedBox(height: 24),
                                _buildSignaturesTable(currentTableWidth),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildOfficialHeaderAndTitle(double width) {
    return Column(
      children: [
        SizedBox(
          width: width,
          height: 76,
          child: Image.asset(
            'assets/images/selsal_pdf_header.png',
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.primaryDark,
              alignment: Alignment.center,
              child: const Text('مصنع سلسال للمياه', style: TextStyle(fontFamily: 'Tajawal', color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFD6E6F5),
            border: Border.all(color: const Color(0xFF173A5E), width: 1.2),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'قائمة التفتيش على النظافة الشخصية',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTable() {
    return Container(
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 1.5)),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoCell('الشركة (الفرع)', isLabel: true, width: 120),
              _infoCell('مصنع سلسال', isLabel: false, width: 180),
              _infoCell('التاريخ', isLabel: true, width: 120),
              _infoCell(controller.reportDate, isLabel: false, width: 180),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoCell('مراقب السلامة الغذائية', isLabel: true, width: 120),
              _infoCell(controller.supervisorName, isLabel: false, width: 180),
              _infoCell('الوردية', isLabel: true, width: 120),
              _infoCell('الأولى', isLabel: false, width: 180),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoCell(String text, {required bool isLabel, required double width}) {
    return Container(
      width: width,
      height: 30,
      decoration: BoxDecoration(
        color: isLabel ? Colors.grey.shade300 : Colors.white,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          fontWeight: isLabel ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildMainTable(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTableHeader(),
        // Build data rows
        ...controller.employees.map((emp) => _buildEmployeeRow(context, emp)),
        // Fill empty rows to look like the paper form (total 15 rows)
        for (int i = controller.employees.length; i < 15; i++)
          _buildEmptyRow(context),
      ],
    );
  }

  Widget _buildTableHeader() {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Employee Name Header
          _headerCell('اسم الموظف', width: colEmployeeWidth),
          
          // Criteria Headers
          ...controller.criteria.map((c) => _criteriaHeaderCell(c.itemName)),
          
          // Action Header
          _headerCell('إذا اجبت ب لا ما التصرف\nالذي قمت به لتصحيح\nالوضع', width: colActionWidth),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {required double width}) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _criteriaHeaderCell(String text) {
    // In the image, criteria text is sometimes written vertically or wrapped.
    return Container(
      width: colCriteriaWidth,
      decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 0.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              alignment: Alignment.center,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    border: const Border(
                      top: BorderSide(color: Colors.black, width: 0.5),
                      left: BorderSide(color: Colors.black, width: 0.5), // For RTL, left is internal border
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('نعم', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              ),
              Expanded(
                child: Container(
                  height: 25,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: const Border(
                      top: BorderSide(color: Colors.black, width: 0.5),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('لا', style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow(BuildContext context, Employee emp) {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name
          _dataCell(context, emp.fullName, width: colEmployeeWidth, alignRight: true),
          
          // Checks
          ...controller.criteria.map((c) {
            final isCompliant = controller.complianceMatrix['${emp.id}_${c.id}'];
            return _checkCell(context, isCompliant);
          }),

          // Action
          _dataCell(context, controller.correctiveActions[emp.id!] ?? '', width: colActionWidth, alignRight: true),
        ],
      ),
    );
  }

  Widget _buildEmptyRow(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _dataCell(context, '', width: colEmployeeWidth),
          ...controller.criteria.map((c) => _checkCell(context, null)),
          _dataCell(context, '', width: colActionWidth),
        ],
      ),
    );
  }

  Widget _dataCell(BuildContext context, String text, {required double width, bool alignRight = false}) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 30),
      decoration: BoxDecoration(
         color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alignment: alignRight ? Alignment.centerRight : Alignment.center,
      child: Text(
        text,
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
      ),
    );
  }

  Widget _checkCell(BuildContext context, bool? isCompliant) {
    return Container(
      width: colCriteriaWidth,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // نعم Column
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surface,
                border: Border(left: BorderSide(color: Colors.black, width: 0.5)),
              ),
              alignment: Alignment.center,
              child: (isCompliant == true) ? const Icon(Icons.check, color: Colors.green, size: 18) : null,
            ),
          ),
          // لا Column
          Expanded(
            child: Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: (isCompliant == false) ? const Icon(Icons.check, color: Colors.red, size: 18) : null,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== SIGNATURES TABLE ====================

  Widget _buildSignaturesTable(double width) {
    final status = controller.approvalStatus.value;
    final supervisorName = controller.supervisorName;

    final isQmRejected = ApprovalStatus.rejectedByQualityManager(
      rejectedBy: controller.rejectedBy.value,
      gmDecisionBy: controller.gmDecisionBy.value,
      qmApprovedBy: controller.qmApprovedBy.value,
      status: status,
    );
    final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
      rejectedBy: controller.rejectedBy.value,
      gmDecisionBy: controller.gmDecisionBy.value,
      qmApprovedBy: controller.qmApprovedBy.value,
      status: status,
    );
    final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
      qmApprovedBy: controller.qmApprovedBy.value,
      rejectedBy: controller.rejectedBy.value,
      gmDecisionBy: controller.gmDecisionBy.value,
      status: status,
    );

    final hasCorrectiveAction = (controller.correctiveAction.value ?? '').trim().isNotEmpty || controller.rejectionReason.value != null;
    final isQmCorrective = hasCorrectiveAction && (status == 'Closed' || status == 'Pending_GM_Decision' || status == 'Rejected_By_GM');

    final rawQmName = controller.qmApprovedBy.value ??
        ((isQmCorrective || status == 'Approved' || status == 'Pending_GM' || wasQmApproved)
            ? (controller.rejectedBy.value ?? 'أ. حمود يسر')
            : '________________');
    final qmName = isQmRejected ? (controller.rejectedBy.value ?? 'مدير الجودة') : rawQmName;

    final rawGmName = controller.gmApprovedBy.value ??
        ((status == 'Approved' || status == 'Closed') ? (controller.gmDecisionBy.value ?? 'خالد العمري') : '________________');
    final gmName = isGmRejected ? (controller.gmDecisionBy.value ?? controller.rejectedBy.value ?? 'مدير المصنع') : rawGmName;

    final qmDate = controller.qmApprovedAt.value != null
        ? DynamicReportPdfGenerator.formatArabicDate(controller.qmApprovedAt.value)
        : (isQmCorrective
            ? 'مرفوض بإجراء تصحيحي'
            : (isQmRejected ? 'مرفوض' : (wasQmApproved ? 'معتمد سابقاً' : (status == 'Approved' || status == 'Pending_GM' ? 'معتمد' : '  /  / 2026م'))));
    final gmDate = controller.gmApprovedAt.value != null
        ? DynamicReportPdfGenerator.formatArabicDate(controller.gmApprovedAt.value)
        : (isGmRejected
            ? 'مرفوض'
            : (status == 'Closed' ? 'معتمد' : (status == 'Approved' ? 'معتمد' : '  /  / 2026م')));
    final entryDate = controller.reportDate;

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black, width: 1.2),
      ),
      child: Table(
        border: TableBorder.all(color: Colors.black, width: 1),
        columnWidths: const {
          0: FlexColumnWidth(1),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
        },
        children: [
          const TableRow(
            decoration: BoxDecoration(color: Color(0xFFD6E6F5)),
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('منفذ الفحص (المفتش)', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('مدير الجودة', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('اعتماد مدير المصنع', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
          TableRow(
            children: [
              _buildSigBox(
                name: supervisorName,
                statusBadge: 'مكتمل ومُرسل',
                isApproved: true,
                date: entryDate,
                signatureBytes: controller.inspectorSignatureBytes.value,
              ),
              _buildSigBox(
                name: qmName,
                statusBadge: isQmCorrective
                    ? 'مرفوض بإجراء تصحيحي'
                    : (isQmRejected
                        ? 'مرفوض'
                        : ((status == 'Approved' || status == 'Pending_GM')
                            ? 'معتمد'
                            : (wasQmApproved
                                ? 'معتمد سابقاً (أُلغي برفض الإدارة)'
                                : (status == 'Pending_QM' ? 'بانتظار الاعتماد' : 'لم يعتمد بعد')))),
                isApproved: status == 'Approved' || status == 'Pending_GM',
                isRejected: isQmRejected,
                isVoided: isQmCorrective || wasQmApproved,
                date: qmDate,
                signatureBytes: (isQmCorrective || status == 'Approved' || status == 'Pending_GM' || wasQmApproved)
                    ? (controller.qmSignatureBytes.value ?? controller.rejectedSignatureBytes.value)
                    : (isQmRejected ? controller.rejectedSignatureBytes.value : null),
              ),
              _buildSigBox(
                name: gmName,
                statusBadge: isGmRejected
                    ? 'مرفوض'
                    : (status == 'Closed'
                        ? 'معتمد (إغلاق الإجراء التصحيحي)'
                        : (status == 'Approved'
                            ? 'معتمد'
                            : (status == 'Pending_GM' || status == 'Pending_GM_Decision' ? 'بانتظار الاعتماد' : 'لم يعتمد بعد'))),
                isApproved: status == 'Approved' || status == 'Closed',
                isRejected: isGmRejected,
                date: gmDate,
                signatureBytes: isGmRejected
                    ? controller.rejectedSignatureBytes.value
                    : ((status == 'Approved' || status == 'Closed') ? controller.gmSignatureBytes.value : null),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSigBox({
    required String name,
    required String statusBadge,
    required bool isApproved,
    required String date,
    Uint8List? signatureBytes,
    bool isRejected = false,
    bool isVoided = false,
  }) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Column(
            children: [
              Builder(
                builder: (context) {
                  final parsed = ArabicPdfService.splitNameAndRole(name);
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الاسم: ${parsed.name}',
                        style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      if (parsed.role != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          parsed.role!,
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 10.5, color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isRejected
                      ? Colors.red.shade50
                      : (isVoided
                          ? const Color(0xFFFFF8E1)
                          : (isApproved ? Colors.green.shade50 : Colors.amber.shade50)),
                  border: Border.all(
                    color: isRejected
                        ? Colors.red.shade600
                        : (isVoided
                            ? const Color(0xFFFFB300)
                            : (isApproved ? Colors.green.shade600 : Colors.amber.shade700)),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusBadge,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isRejected
                        ? Colors.red.shade800
                        : (isVoided
                            ? const Color(0xFFB78103)
                            : (isApproved ? Colors.green.shade800 : Colors.amber.shade900)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'التاريخ: $date',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 11,
                  color: isRejected ? Colors.red.shade800 : Colors.grey,
                ),
              ),
            ],
          ),
          if (signatureBytes != null && (isApproved || isRejected || isVoided))
            Positioned.fill(
              child: Opacity(
                opacity: 0.42,
                child: Center(
                  child: Image.memory(
                    signatureBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ==================== APPROVAL ACTION BAR ====================

  Widget _buildApprovalActionBar(BuildContext context) {
    final status = controller.approvalStatus.value;
    final session = UserSessionService.to;
    final currentRole = session.currentRole.value;

    Color bannerColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    switch (status) {
      case 'Draft':
        bannerColor = Colors.grey.shade700;
        statusTitle = 'مسودة (Draft)';
        statusSubtitle = 'التقرير لم يتم رفعه للاعتماد بعد.';
        statusIcon = Icons.edit_note;
        break;
      case 'Pending_QM':
        bannerColor = const Color(0xFFE65100); // Orange
        statusTitle = 'بانتظار اعتماد مدير الجودة (Pending QM)';
        statusSubtitle = 'تم إرسال التقرير وهو بانتظار مراجعة واعتماد مدير الجودة (حمود يسر).';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'Pending_GM':
        bannerColor = const Color(0xFF6A1B9A); // Purple
        statusTitle = 'بانتظار اعتماد مدير المصنع (Pending GM)';
        statusSubtitle = 'تم اعتماد التقرير من مدير الجودة وبانتظار الاعتماد النهائي لمدير المصنع (خالد العمري).';
        statusIcon = Icons.verified_user;
        break;
      case 'Approved':
        bannerColor = const Color(0xFF2E7D32); // Green
        statusTitle = 'مُعتمد نهائياً (Approved)';
        statusSubtitle = 'تم اعتماد التقرير رسمياً من جميع المستويات وهو مقفل وجاهز للطباعة.';
        statusIcon = Icons.check_circle;
        break;
      case 'Rejected':
        bannerColor = const Color(0xFFC62828); // Red
        final rejectorLabel = (controller.rejectedBy.value != null && controller.rejectedBy.value!.isNotEmpty)
            ? ' من قِبل ${controller.rejectedBy.value}'
            : '';
        statusTitle = 'تم رفض التقرير$rejectorLabel';
        statusSubtitle = 'سبب الرفض: ${controller.rejectionReason.value ?? "غير محدد"}';
        statusIcon = Icons.cancel;
        break;
      case 'Corrective_In_Progress':
        bannerColor = const Color(0xFF1565C0); // Blue
        statusTitle = 'الإجراء التصحيحي قيد التنفيذ';
        statusSubtitle = (controller.correctiveAction.value ?? '').isNotEmpty
            ? 'الإجراء المطلوب: ${controller.correctiveAction.value} — المسؤول: ${controller.correctiveOwner.value ?? "غير محدد"}'
            : 'المسؤول المختص يعمل على تنفيذ الإجراء التصحيحي.';
        statusIcon = Icons.build_circle;
        break;
      case 'Pending_QM_Decision':
        bannerColor = const Color(0xFFEF6C00); // Orange
        statusTitle = 'بانتظار اعتماد مدير الجودة للإجراء التصحيحي';
        statusSubtitle = 'تم تنفيذ وتوثيق الإجراء التصحيحي وهو بانتظار مراجعة واعتماد مدير الجودة.';
        statusIcon = Icons.fact_check_outlined;
        break;
      case 'Pending_GM_Decision':
        bannerColor = const Color(0xFFAD6800); // Dark Amber
        statusTitle = 'بانتظار اعتماد مدير المصنع للإجراء التصحيحي';
        statusSubtitle = 'تم اعتماد الإجراء التصحيحي من مدير الجودة وهو بانتظار قرار مدير المصنع النهائي.';
        statusIcon = Icons.pending_actions;
        break;
      case 'Rejected_By_GM':
        bannerColor = const Color(0xFF8B0000); // Dark Red
        statusTitle = 'مرفوض نهائياً — انتهاء دورة الاعتماد';
        statusSubtitle = (controller.gmDecisionNotes.value ?? '').isNotEmpty
            ? 'تم رفض الإجراء التصحيحي: ${controller.gmDecisionNotes.value} (انتهت دورة الاعتماد بالرفض النهائي)'
            : 'تم رفض الإجراء التصحيحي من مدير المصنع، وانتهت دورة الاعتماد بالرفض النهائي للتقرير دون إمكانية تصحيح إضافي.';
        statusIcon = Icons.cancel_presentation;
        break;
      case 'Closed':
        bannerColor = const Color(0xFF2E7D32); // Green
        statusTitle = 'معتمد بعد إجراء تصحيحي';
        statusSubtitle = 'تم اعتماد الإجراء التصحيحي من مدير المصنع وإغلاق التقرير نهائياً.';
        statusIcon = Icons.task_alt;
        break;
      default:
        bannerColor = Colors.blueGrey;
        statusTitle = status;
        statusSubtitle = '';
        statusIcon = Icons.info;
    }

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
        ),
        child: Column(
          children: [
            // Banner Top
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(bottom: BorderSide(color: bannerColor.withValues(alpha: 0.3))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: bannerColor, shape: BoxShape.circle),
                    child: Icon(statusIcon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: bannerColor,
                          ),
                        ),
                        if (statusSubtitle.isNotEmpty)
                          Text(
                            statusSubtitle,
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Visual Signatures Bar
            _buildVisualSignaturesBar(context),

            // Actions Area
            Padding(
              padding: const EdgeInsets.all(16),
              child: _buildRoleActions(context, currentRole, status),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualSignaturesBar(BuildContext context) {
    return Obx(() {
      final status = controller.approvalStatus.value;
      final bool isClosed = status == 'Closed';
      final isQmDone = status == 'Approved' || status == 'Pending_GM';
      final isGmDone = status == 'Approved' || status == 'Closed';

      // تحديد الجهة التي رفضت التقرير لعرض توقيعها باللون الأحمر
      final isQmRejected = ApprovalStatus.rejectedByQualityManager(
        rejectedBy: controller.rejectedBy.value,
        gmDecisionBy: controller.gmDecisionBy.value,
        qmApprovedBy: controller.qmApprovedBy.value,
        status: status,
      );
      final isGmRejected = ApprovalStatus.rejectedByFactoryManager(
        rejectedBy: controller.rejectedBy.value,
        gmDecisionBy: controller.gmDecisionBy.value,
        qmApprovedBy: controller.qmApprovedBy.value,
        status: status,
      );
      final wasQmApproved = ApprovalStatus.wasApprovedByQmPriorToGmRejection(
        qmApprovedBy: controller.qmApprovedBy.value,
        rejectedBy: controller.rejectedBy.value,
        gmDecisionBy: controller.gmDecisionBy.value,
        status: status,
      );
      final wasQmRejected = ApprovalStatus.wasRejectedByQmPriorToGmRejection(
        rejectedBy: controller.rejectedBy.value,
        gmDecisionBy: controller.gmDecisionBy.value,
        status: status,
      );

      final hasCorrectiveAction = (controller.correctiveAction.value ?? '').trim().isNotEmpty || controller.rejectionReason.value != null;
      final isQmCorrective = hasCorrectiveAction && (status == 'Closed' || status == 'Pending_GM_Decision' || status == 'Rejected_By_GM');

      final qmDate = controller.qmApprovedAt.value != null
          ? DynamicReportPdfGenerator.formatArabicDate(controller.qmApprovedAt.value)
          : (isQmCorrective ? 'مرفوض بإجراء تصحيحي' : (isQmDone ? 'معتمد' : (isQmRejected ? 'مرفوض' : (wasQmApproved ? 'معتمد سابقاً' : 'لم يعتمد بعد'))));
      final gmDate = controller.gmApprovedAt.value != null
          ? DynamicReportPdfGenerator.formatArabicDate(controller.gmApprovedAt.value)
          : (status == 'Closed' ? 'معتمد (إغلاق الإجراء)' : (isGmDone ? 'معتمد نهائياً' : (isGmRejected ? 'مرفوض' : 'لم يعتمد بعد')));

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.draw_rounded, size: 14, color: AppColors.primaryDark),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'حالة التوقيعات الرقمية المعتمدة (Visual Overlay Signatures)',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildSignatureBoxUI(
                    roleTitle: 'منفذ الفحص (المفتش)',
                    signerName: controller.supervisorName.isNotEmpty ? controller.supervisorName : 'مفتش الجودة',
                    dateStr: controller.reportDate,
                    isApproved: true,
                    signatureBytes: controller.inspectorSignatureBytes.value,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSignatureBoxUI(
                    roleTitle: isQmCorrective
                        ? 'مراجعة مدير الجودة (إجراء تصحيحي)'
                        : (wasQmApproved ? 'اعتماد مدير الجودة (سابقاً)' : 'اعتماد مدير الجودة'),
                    signerName: (isQmCorrective || isQmRejected || wasQmRejected)
                        ? (controller.rejectedBy.value ?? controller.qmApprovedBy.value ?? 'أ. حمود يسر (مدير الجودة)')
                        : controller.qmApprovedBy.value ?? (isQmDone || wasQmApproved ? 'حمود يسر (مدير الجودة)' : 'بانتظار الاعتماد'),
                    dateStr: qmDate,
                    isApproved: isQmDone && !isQmCorrective && !wasQmRejected,
                    isRejected: (isQmRejected || wasQmRejected || isQmCorrective) && !isClosed,
                    isVoided: isClosed || wasQmApproved,
                    signatureBytes: (isQmCorrective || isQmRejected || wasQmRejected)
                        ? (controller.rejectedSignatureBytes.value ?? controller.qmSignatureBytes.value)
                        : ((isQmDone || wasQmApproved) ? controller.qmSignatureBytes.value : null),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSignatureBoxUI(
                    roleTitle: status == 'Closed' ? 'اعتماد مدير المصنع (إغلاق الإجراء)' : 'اعتماد مدير المصنع',
                    signerName: isGmRejected
                        ? (controller.gmDecisionBy.value ?? controller.rejectedBy.value ?? 'مدير المصنع')
                        : controller.gmApprovedBy.value ?? (isGmDone ? (controller.gmDecisionBy.value ?? 'خالد العمري (مدير المصنع)') : 'بانتظار الاعتماد'),
                    dateStr: gmDate,
                    isApproved: isGmDone,
                    isRejected: isGmRejected,
                    signatureBytes: isGmRejected
                        ? controller.rejectedSignatureBytes.value
                        : (isGmDone ? controller.gmSignatureBytes.value : null),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Widget _buildSignatureBoxUI({
    required String roleTitle,
    required String signerName,
    required String dateStr,
    required bool isApproved,
    Uint8List? signatureBytes,
    bool isRejected = false,
    bool isVoided = false,
  }) {
    // ألوان المربع: أخضر للاعتماد، أحمر للرفض، كهرماني للمعتمد سابقاً الملغى، رمادي للانتظار
    final Color boxColor = isRejected
        ? const Color(0xFFFFEBEE)
        : (isVoided
            ? const Color(0xFFFFF8E1)
            : (isApproved ? const Color(0xFFF1F8E9) : Colors.white));
    final Color borderColor = isRejected
        ? const Color(0xFFE53935)
        : (isVoided
            ? const Color(0xFFFFB300)
            : (isApproved ? const Color(0xFF81C784) : Colors.grey.shade300));
    final Color titleColor = isRejected
        ? const Color(0xFFC62828)
        : (isVoided
            ? const Color(0xFFB78103)
            : (isApproved ? const Color(0xFF2E7D32) : Colors.blueGrey.shade800));
    final Color nameColor =
        isRejected ? const Color(0xFFC62828) : (isVoided ? const Color(0xFFB78103) : Colors.black87);

    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: boxColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        roleTitle,
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                          height: 1.0,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRejected)
                      const Icon(
                        Icons.cancel_rounded,
                        size: 12,
                        color: Color(0xFFC62828),
                      )
                    else if (isVoided)
                      const Icon(
                        Icons.history_edu_rounded,
                        size: 12,
                        color: Color(0xFFB78103),
                      )
                    else if (isApproved)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 12,
                        color: Color(0xFF2E7D32),
                      ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  signerName,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: nameColor,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    height: 1.0,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            if (signatureBytes != null && (isApproved || isRejected || isVoided))
              Positioned.fill(
                child: Opacity(
                  opacity: 0.42,
                  child: Center(
                    child: Image.memory(
                      signatureBytes,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleActions(BuildContext context, UserRole currentRole, String status) {
    if (status == 'Approved') {

      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified,
                color: Colors.teal,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  'التقرير معتمد رسمياً ومقفل ضد التعديل.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (UserSessionService.to.canExportPdf)
            ElevatedButton.icon(
              onPressed: controller.printReport,
              icon: const Icon(Icons.print, size: 18),
              label: const Text(
                'طباعة التقرير الرسمي',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4472C4),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      );
    }

    final session = UserSessionService.to;
    if (status == 'Pending_QM') {
      if (session.canApproveQM && session.canApproveBranchData(controller.reportBranchId)) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'اعتماد مدير الجودة',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF2E7D32),
                onPressed: () => _confirmQualityManagerApproval(context),
              ),
            ),
            if (session.canRejectReports) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.outlined(
                  label: 'رفض / إعادة للتعديل',
                  icon: Icons.cancel_outlined,
                  foregroundColor: Colors.redAccent,
                  color: Colors.redAccent,
                  onPressed: () => _showRejectDialog(context),
                ),
              ),
            ],
          ],
        );
      } else if (session.canApproveQM && !session.canApproveBranchData(controller.reportBranchId)) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${controller.branchName})، بينما حسابك مقيد بفرع آخر. لا تملك صلاحية اعتماده.',
          targetRole: UserRole.qualityManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مدير الجودة. حسابك الحالي لا يمتلك صلاحية اعتماد مدير الجودة لهذا التقرير.',
          targetRole: UserRole.qualityManager,
        );
      }
    }

    if (status == 'Pending_GM') {
      if (session.canApproveGM && session.canApproveBranchData(controller.reportBranchId)) {
        return Row(
          children: [
            Expanded(
              child: AppButton.primary(
                label: 'اعتماد مدير المصنع',
                icon: Icons.verified,
                color: const Color(0xFF6A1B9A),
                onPressed: () => _confirmFactoryManagerApproval(context),
              ),
            ),
            if (session.canRejectReports) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppButton.outlined(
                  label: 'رفض التقرير',
                  icon: Icons.cancel_outlined,
                  foregroundColor: Colors.redAccent,
                  color: Colors.redAccent,
                  onPressed: () => _showRejectDialog(context),
                ),
              ),
            ],
          ],
        );
      } else if (session.canApproveGM && !session.canApproveBranchData(controller.reportBranchId)) {
        return _buildRolePromptCard(
          prompt: 'هذا التقرير يتبع لـ (${controller.branchName})، بينما حسابك مسند إلى (${session.assignedBranchName}). لا تملك صلاحية اعتماد تقارير مصنع آخر.',
          targetRole: UserRole.factoryManager,
        );
      } else {
        return _buildRolePromptCard(
          prompt: 'التقرير بانتظار اعتماد مدير المصنع. حسابك الحالي لا يمتلك صلاحية اعتماد مدير المصنع.',
          targetRole: UserRole.factoryManager,
        );
      }
    }

    if (status == 'Rejected' ||
        status == 'Corrective_In_Progress' ||
        status == 'Pending_QM_Decision' ||
        status == 'Pending_GM_Decision' ||
        status == 'Rejected_By_GM' ||
        status == 'Closed') {
      return _buildCorrectiveActionSection(status);
    }

    return const SizedBox.shrink();
  }

  /// قسم الإجراء التصحيحي — يعرض بطاقة الإجراء التصحيحي الكاملة وأزرار الإجراءات
  Widget _buildCorrectiveActionSection(String status) {
    final session = UserSessionService.to;
    final canQmDecide = ApprovalStatus.qmCanDecide(status) &&
        session.canApproveQM &&
        session.canApproveBranchData(controller.reportBranchId);
    final canGmDecide = ApprovalStatus.gmCanDecide(status) &&
        session.canApproveGM &&
        session.canApproveBranchData(controller.reportBranchId);
    final canDecide = canQmDecide || canGmDecide;
    final canSubmit = (status == 'Rejected' || status == 'Corrective_In_Progress') &&
        (session.canEditReports || session.canCreateHygieneReports || session.canRejectReports || session.isAdmin) &&
        session.canApproveBranchData(controller.reportBranchId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FactoryManagerRejectionCard(
          title: 'تقرير فحص النظافة العامة #${controller.reportId}',
          subtitle: '${controller.branchName} • ${controller.reportDate}',
          status: status,
          rejectionReason: controller.rejectionReason.value,
          rejectedBy: controller.rejectedBy.value,
          rejectionCategory: controller.rejectionCategory.value,
          severity: controller.severityLevel.value,
          affectedProducts: controller.affectedProducts.value,
          immediateAction: controller.immediateAction.value,
          correctiveAction: controller.correctiveAction.value,
          correctiveOwner: controller.correctiveOwner.value,
          correctiveDueDate: controller.correctiveDueDate.value,
          gmDecision: controller.gmDecision.value,
          gmDecisionBy: controller.gmDecisionBy.value,
          gmDecisionNotes: controller.gmDecisionNotes.value,
          rejectionCount: controller.rejectionCount.value,
          onApprove: canDecide ? () => _showGmDecisionDialog() : null,
          onReject: canDecide ? () => _showGmDecisionDialog() : null,
        ),
        if (canSubmit) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showSubmitCorrectiveDialog(),
              icon: const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 18),
              label: const Text(
                'توثيق وإرسال الإجراء التصحيحي لمدير الجودة',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showSubmitCorrectiveDialog() async {
    final action = await CorrectiveActionSubmitDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص النظافة العامة #${controller.reportId}',
      rejectionReason: (controller.rejectionReason.value?.isNotEmpty == true) ? controller.rejectionReason.value! : 'غير محدد',
      rejectedBy: controller.rejectedBy.value,
      initialCorrectiveAction: controller.correctiveAction.value,
      correctiveOwner: controller.correctiveOwner.value,
    );
    if (action != null && action.isNotEmpty) {
      controller.submitCorrectiveAction(action);
    }
  }

  /// شاشة قرار مدير الجودة أو مدير المصنع على الإجراء التصحيحي
  void _showGmDecisionDialog() async {
    final status = controller.approvalStatus.value;
    final isQmStage = status == 'Pending_QM_Decision';

    final decision = await GmDecisionDialog.show(
      Get.context!,
      reportTitle: 'تقرير فحص النظافة العامة #${controller.reportId}',
      correctiveAction: controller.correctiveAction.value ?? 'غير محدد',
      correctiveOwner: controller.correctiveOwner.value ?? 'غير محدد',
      severity: controller.severityLevel.value,
      decisionTitle: isQmStage
          ? 'قرار مدير الجودة على الإجراء التصحيحي'
          : 'القرار النهائي لمدير المصنع على الإجراء التصحيحي',
      isFinalStage: !isQmStage,
      rejectionCount: controller.rejectionCount.value,
    );

    if (decision == null) return;
    if (isQmStage) {
      if (decision.isApproved) {
        controller.qmApproveCorrectiveAction(decision.notes);
      } else {
        controller.qmRejectCorrectiveAction(decision.notes);
      }
    } else {
      if (decision.isApproved) {
        controller.gmApproveCorrectiveAction(decision.notes);
      } else {
        controller.gmRejectCorrectiveAction(decision.notes);
      }
    }
  }

  Widget _buildRolePromptCard({required String prompt, UserRole? targetRole}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              prompt,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmQualityManagerApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'اعتماد مدير الجودة',
      message: 'هل أنت متأكد من مراجعة واعتماد هذا التقرير؟ سيتم رفعه لمدير المصنع للاعتماد النهائي.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF2E7D32),
      onConfirm: () => controller.approveByQualityManager(),
    );
  }

  void _confirmFactoryManagerApproval(BuildContext context) {
    AppDialog.confirm(
      context: context,
      title: 'الاعتماد النهائي',
      message: 'هل أنت متأكد من الاعتماد النهائي لهذا التقرير؟ سيصبح مقفلاً ومعتمداً رسمياً.',
      confirmLabel: 'تأكيد الاعتماد',
      cancelLabel: 'إلغاء',
      confirmColor: const Color(0xFF6A1B9A),
      onConfirm: () => controller.approveByFactoryManager(),
    );
  }

  void _showRejectDialog(BuildContext context) async {
    final payload = await RejectReportDialog.show(
      context,
      reportTitle: 'تقرير فحص النظافة العامة #${controller.reportId}',
      reportSubtitle: '${controller.branchName} • التاريخ: ${controller.reportDate}',
      rejectionCount: controller.rejectionCount.value,
    );

    if (payload == null) return;
    controller.rejectReport(payload);
  }

  Widget _buildAccessDeniedWidget(BuildContext context) {
    final session = UserSessionService.to;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
           color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: Colors.red.shade200, width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_person_rounded, size: 56, color: Colors.red.shade700),
            ),
            const SizedBox(height: 20),
            const Text(
              'وصول مقيد - عزل بيانات الفروع',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'هذا التقرير يتبع لـ (${controller.branchName}).\nحسابك الحالي مقيد بصلاحيات (${session.assignedBranchName}).\nلا يمكنك استعراض أو تعديل أو اعتماد تقارير مصانع أخرى.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              label: const Text(
                'العودة إلى تقارير مصنعك',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
