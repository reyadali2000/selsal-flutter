import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../constants/approval_status.dart';
import '../models/water_quality_models.dart';

/// بطاقة دورة اعتماد الفحوصات الميكروبيولوجية.
///
/// تُعرض داخل التقرير تحت قسم "الفحوصات الميكروبيولوجية" مباشرةً، وتُظهر
/// جولة الاعتماد الخاصة بهذا القسم بشكل مستقل عن شريط الاعتماد الكلي:
///
///  ① إدخال النتائج  →  ② اعتماد مدير الجودة  →  ③ اعتماد مدير المصنع
///
/// تعرض الحالة الحالية لكل مرحلة (المنفِّذ والتاريخ) وأزرار الإجراءات
/// المتاحة للدور الحالي.
class MicroApprovalCycleCard extends StatelessWidget {
  const MicroApprovalCycleCard({
    super.key,
    required this.log,
    this.onEnterResults,
    this.onApproveQM,
    this.onApproveGM,
    this.onReject,
    this.canEnter = false,
    this.canApproveQM = false,
    this.canApproveGM = false,
    this.canReject = false,
    this.rolePromptText,
    this.onSwitchRole,
    this.showActions = false,
  });

  /// إظهار أزرار الإجراءات داخل البطاقة (افتراضياً معطل لأن الاعتماد يتم من شريط أعلى التقرير)
  final bool showActions;

  final WaterQualityLog log;

  /// إجراء إدخال نتائج الفحص الميكروبيولوجي (للأخصائي)
  final VoidCallback? onEnterResults;

  /// إجراء اعتماد مدير الجودة لنتائج الميكروبيولوجي
  final VoidCallback? onApproveQM;

  /// إجراء اعتماد مدير المصنع النهائي لنتائج الميكروبيولوجي
  final VoidCallback? onApproveGM;

  /// إجراء رفض نتائج الميكروبيولوجي
  final VoidCallback? onReject;

  /// صلاحيات الدور الحالي
  final bool canEnter;
  final bool canApproveQM;
  final bool canApproveGM;
  final bool canReject;

  /// نص يُعرض عندما لا يملك المستخدم صلاحية الإجراء المطلوب
  final String? rolePromptText;

  /// تبديل الدور (اختياري)
  final VoidCallback? onSwitchRole;

  static const Color _accent = Color(0xFF00838F);

  /// هل يجب عرض البطاقة لهذا التقرير؟
  /// تُعرض فقط للتقارير التي تملك قسم ميكروبيولوجي ودخلت ( أو تجاوزت )
  /// جولة اعتماد الميكروبيولوجي المستقلة.
  static bool shouldShow(WaterQualityLog log) {
    final inMicroStage = ApprovalStatus.isMicroStage(log.approvalStatus);
    final hasMicroApprovalData = (log.microEnteredBy ?? '').isNotEmpty ||
        (log.microQmApprovedBy ?? '').isNotEmpty ||
        (log.microGmApprovedBy ?? '').isNotEmpty;
    return inMicroStage || hasMicroApprovalData;
  }

  @override
  Widget build(BuildContext context) {
    final status = log.approvalStatus;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.35), width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(status),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepper(),
                const SizedBox(height: 12),
                _buildAuditLines(),
                if (status == 'Rejected' ||
                    status == 'Micro_Rejected' ||
                    status == 'Micro_Resample_Pending' ||
                    status == 'Micro_Corrective_In_Progress' ||
                    status == 'Corrective_In_Progress' ||
                    status == 'Pending_QM_Decision' ||
                    status == 'Pending_GM_Decision' ||
                    status == 'Rejected_By_GM') ...[
                  const SizedBox(height: 10),
                  _buildRejectedNote(),
                ],
                if (showActions) ...[
                  const SizedBox(height: 12),
                  _buildActions(),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String status) {
    final (label, color) = _statusBadge(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
        border: Border(bottom: BorderSide(color: _accent.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          const Icon(Icons.biotech_outlined, color: _accent, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'دورة اعتماد الفحوصات الميكروبيولوجية',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 13.5,
                color: Color(0xFF006064),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusBadge(String status) {
    switch (status) {
      case 'Awaiting_Micro_Results':
        return ('بانتظار إدخال النتائج', const Color(0xFF00838F));
      case 'Pending_Micro_QM':
        return ('بانتظار اعتماد مدير الجودة', const Color(0xFFE65100));
      case 'Pending_Micro_GM':
        return ('بانتظار اعتماد مدير المصنع', const Color(0xFF6A1B9A));
      case 'Approved':
        return ('معتمد نهائياً', const Color(0xFF2E7D32));
      case 'Micro_Rejected':
        return ('نتائج الميكروبيولوجي مرفوضة', const Color(0xFFC62828));
      case 'Micro_Resample_Pending':
        return ('بانتظار إعادة سحب العينة', const Color(0xFFD84315));
      case 'Micro_Corrective_In_Progress':
        return ('إجراء تصحيحي ميكروبيولوجي', const Color(0xFF1565C0));
      case 'Rejected':
      case 'Corrective_In_Progress':
      case 'Pending_QM_Decision':
      case 'Pending_GM_Decision':
      case 'Rejected_By_GM':
        return ('مرفوض — يتطلب إجراءً', const Color(0xFFC62828));
      default:
        return ('ضمن جولة الاعتماد الكلي', Colors.blueGrey);
    }
  }

  Widget _buildStepper() {
    final steps = [
      _stepState(step: 1),
      _stepState(step: 2),
      _stepState(step: 3),
    ];

    return Row(
      children: [
        Expanded(child: _buildStepNode(1, steps[0])),
        Expanded(child: _connector(steps[0], steps[1])),
        Expanded(child: _buildStepNode(2, steps[1])),
        Expanded(child: _connector(steps[1], steps[2])),
        Expanded(child: _buildStepNode(3, steps[2])),
      ],
    );
  }

  ({_StepPhase phase, String title, String? who, String? when}) _stepState({required int step}) {
    final fmt = DateFormat('yyyy/MM/dd - HH:mm');
    switch (step) {
      case 1:
        final active = log.approvalStatus == 'Awaiting_Micro_Results' ||
            log.approvalStatus == 'Micro_Resample_Pending' ||
            log.approvalStatus == 'Micro_Rejected' ||
            log.approvalStatus == 'Micro_Corrective_In_Progress';
        final done = (log.microEnteredBy ?? '').isNotEmpty && !active;
        return (
          phase: done
              ? _StepPhase.done
              : (active ? _StepPhase.active : _StepPhase.waiting),
          title: 'إدخال النتائج',
          who: done ? log.microEnteredBy : null,
          when: log.microEnteredAt != null ? fmt.format(log.microEnteredAt!) : null,
        );
      case 2:
        final done = (log.microQmApprovedBy ?? '').isNotEmpty;
        final active = log.approvalStatus == 'Pending_Micro_QM';
        return (
          phase: done
              ? _StepPhase.done
              : (active ? _StepPhase.active : _StepPhase.waiting),
          title: 'اعتماد مدير الجودة',
          who: done ? log.microQmApprovedBy : null,
          when: log.microQmApprovedAt != null ? fmt.format(log.microQmApprovedAt!) : null,
        );
      case 3:
        final done = (log.microGmApprovedBy ?? '').isNotEmpty;
        final active = log.approvalStatus == 'Pending_Micro_GM';
        return (
          phase: done
              ? _StepPhase.done
              : (active ? _StepPhase.active : _StepPhase.waiting),
          title: 'اعتماد مدير المصنع',
          who: done ? log.microGmApprovedBy : null,
          when: log.microGmApprovedAt != null ? fmt.format(log.microGmApprovedAt!) : null,
        );
      default:
        return (phase: _StepPhase.waiting, title: '', who: null, when: null);
    }
  }

  Widget _buildStepNode(int number, ({_StepPhase phase, String title, String? who, String? when}) step) {
    final color = step.phase == _StepPhase.done
        ? const Color(0xFF2E7D32)
        : step.phase == _StepPhase.active
            ? const Color(0xFFE65100)
            : Colors.grey.shade400;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: step.phase == _StepPhase.done
                ? color
                : color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: step.phase == _StepPhase.waiting ? 1.2 : 1.8),
          ),
          child: step.phase == _StepPhase.done
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : step.phase == _StepPhase.active
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE65100)),
                    )
                  : Text(
                      '$number',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
        ),
        const SizedBox(height: 6),
        Text(
          step.title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontWeight: step.phase == _StepPhase.waiting ? FontWeight.normal : FontWeight.bold,
            fontSize: 10.5,
            color: step.phase == _StepPhase.waiting ? Colors.grey.shade600 : color,
            height: 1.2,
          ),
        ),
        if (step.when != null) ...[
          const SizedBox(height: 2),
          Text(
            step.when!,
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 8.5, color: Colors.grey.shade500),
          ),
        ],
      ],
    );
  }

  Widget _connector(
    ({_StepPhase phase, String title, String? who, String? when}) left,
    ({_StepPhase phase, String title, String? who, String? when}) right,
  ) {
    final filled = left.phase == _StepPhase.done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF2E7D32) : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildAuditLines() {
    final lines = <_AuditLine>[];

    if ((log.microEnteredBy ?? '').isNotEmpty) {
      lines.add(_AuditLine(
        icon: Icons.edit_note,
        text: 'أُدخلت النتائج بواسطة ${log.microEnteredBy}',
        at: log.microEnteredAt,
      ));
    }
    if ((log.microQmApprovedBy ?? '').isNotEmpty) {
      lines.add(_AuditLine(
        icon: Icons.check_circle_outline,
        text: 'اعتماد مدير الجودة: ${log.microQmApprovedBy}',
        at: log.microQmApprovedAt,
      ));
    }
    if ((log.microGmApprovedBy ?? '').isNotEmpty) {
      lines.add(_AuditLine(
        icon: Icons.verified,
        text: 'الاعتماد النهائي: ${log.microGmApprovedBy}',
        at: log.microGmApprovedAt,
      ));
    }

    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }

    final fmt = DateFormat('yyyy/MM/dd - HH:mm');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lines
            .map((l) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.5),
                  child: Row(
                    children: [
                      Icon(l.icon, size: 14, color: const Color(0xFF006064)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.at != null ? '${l.text} — ${fmt.format(l.at!)}' : l.text,
                          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Color(0xFF00525B)),
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildRejectedNote() {
    final reason = (log.microRejectionReason ?? '').isNotEmpty ? log.microRejectionReason! : (log.rejectionReason ?? '');
    final rejectedBy = (log.microRejectedBy ?? '').isNotEmpty ? log.microRejectedBy! : (log.rejectedBy ?? '');
    final isResample = log.approvalStatus == 'Micro_Resample_Pending' || log.microRejectionAction == 'resample';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isResample ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isResample ? Colors.orange.shade300 : Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isResample ? Icons.refresh : Icons.cancel_outlined,
            size: 16,
            color: isResample ? Colors.orange.shade800 : Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reason.isNotEmpty
                      ? (isResample
                          ? 'مطلوب إعادة سحب عينة ميكروبيولوجية: $reason'
                          : 'تم رفض نتائج الفحص الميكروبيولوجي: $reason')
                      : (isResample
                          ? 'تم طلب إعادة سحب عينة ميكروبيولوجية جديدة وفحصها.'
                          : 'تم رفض نتائج الفحص الميكروبيولوجي ويتطلب التقرير إجراءً تصحيحياً.'),
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                    color: isResample ? Colors.orange.shade900 : Colors.red.shade900,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
                if (rejectedBy.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    'الجهة الموجهة للرفض: $rejectedBy',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 10.5,
                      color: isResample ? Colors.brown.shade700 : Colors.red.shade800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    final status = log.approvalStatus;

    if (status == 'Awaiting_Micro_Results' ||
        status == 'Micro_Resample_Pending' ||
        status == 'Micro_Rejected' ||
        status == 'Micro_Corrective_In_Progress') {
      if (canEnter && onEnterResults != null) {
        return _actionButton(
          label: status == 'Micro_Resample_Pending'
              ? 'إدخال نتائج العينة الميكروبيولوجية الجديدة'
              : 'إدخال نتائج الفحص الميكروبيولوجي',
          icon: Icons.science_outlined,
          color: _accent,
          onTap: onEnterResults!,
        );
      }
      return _rolePrompt('بانتظار إدخال نتائج الفحص الميكروبيولوجي من أخصائي الجودة.');
    }

    if (status == 'Pending_Micro_QM') {
      if (canApproveQM && onApproveQM != null) {
        return _approvalRow(
          approveLabel: 'اعتماد نتائج الميكروبيولوجي — مدير الجودة',
          approveColor: const Color(0xFF2E7D32),
          onApprove: onApproveQM!,
        );
      }
      return _rolePrompt('نتائج الفحص الميكروبيولوجي بانتظار اعتماد مدير الجودة.');
    }

    if (status == 'Pending_Micro_GM') {
      if (canApproveGM && onApproveGM != null) {
        return _approvalRow(
          approveLabel: 'الاعتماد النهائي للنتائج — مدير المصنع',
          approveColor: const Color(0xFF6A1B9A),
          onApprove: onApproveGM!,
        );
      }
      return _rolePrompt('نتائج الفحص الميكروبيولوجي بانتظار الاعتماد النهائي لمدير المصنع.');
    }

    if (status == 'Approved') {
      return const Row(
        children: [
          Icon(Icons.verified, size: 16, color: Color(0xFF2E7D32)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'اكتملت دورة اعتماد الفحوصات الميكروبيولوجية وهي معتمدة نهائياً.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
            ),
          ),
        ],
      );
    }

    if (status == 'Rejected' ||
        status == 'Corrective_In_Progress' ||
        status == 'Pending_QM_Decision' ||
        status == 'Pending_GM_Decision' ||
        status == 'Rejected_By_GM') {
      return const Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Color(0xFFC62828)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تُدار معالجة رفض النتائج من خلال دورة الإجراء التصحيحية الكاملة للتقرير.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFFC62828)),
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _approvalRow({
    required String approveLabel,
    required Color approveColor,
    required VoidCallback onApprove,
  }) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: onApprove,
            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            style: ElevatedButton.styleFrom(
              backgroundColor: approveColor,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            label: Text(
              approveLabel,
              style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white),
            ),
          ),
        ),
        if (canReject && onReject != null) ...[
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: onReject,
            icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 18),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            label: const Text(
              'رفض',
              style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
          ),
        ],
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 18),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        label: Text(
          label,
          style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
        ),
      ),
    );
  }

  Widget _rolePrompt(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline, size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rolePromptText ?? message,
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Colors.orange.shade900, height: 1.4),
            ),
          ),

        ],
      ),
    );
  }
}

enum _StepPhase { waiting, active, done }

class _AuditLine {
  final IconData icon;
  final String text;
  final DateTime? at;

  const _AuditLine({required this.icon, required this.text, this.at});
}
