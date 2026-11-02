import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:intl/intl.dart';
import '../constants/approval_status.dart';

/// بطاقة عرض التقرير المرفوض والإجراء التصحيحي
/// تعرض بشكل مختصر ومُنظَّم:
/// - ملخص التقرير
/// - سبب الرفض
/// - التأثير على الإنتاج والجودة
/// - الإجراءات الحالية (الإجراء الفوري + الإجراء التصحيحي)
/// - القرار المطلوب من مدير الجودة أو مدير المصنع
/// - نسبة أو حالة الإنجاز
class FactoryManagerRejectionCard extends StatelessWidget {
  const FactoryManagerRejectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.status,
    this.rejectionReason,
    this.rejectedBy,
    this.rejectionCategory,
    this.severity,
    this.affectedProducts,
    this.immediateAction,
    this.correctiveAction,
    this.correctiveOwner,
    this.correctiveDueDate,
    this.gmDecision,
    this.gmDecisionBy,
    this.gmDecisionNotes,
    this.progress,
    this.onApprove,
    this.onReject,
    this.onView,
    this.compact = false,
  });

  /// عنوان التقرير
  final String title;

  /// وصف مختصر (رقم الدفعة/المنتج)
  final String? subtitle;

  /// حالة التقرير الحالية
  final String status;

  /// بيانات الرفض
  final String? rejectionReason;
  final String? rejectedBy;
  final String? rejectionCategory;
  final String? severity;

  /// التأثير على الإنتاج والجودة
  final String? affectedProducts;
  final String? immediateAction;

  /// الإجراء التصحيحي
  final String? correctiveAction;
  final String? correctiveOwner;
  final DateTime? correctiveDueDate;

  /// قرار مدير الجودة / مدير المصنع (إن وُجد)
  final String? gmDecision;
  final String? gmDecisionBy;
  final String? gmDecisionNotes;

  /// نسبة الإنجاز (0.0 - 1.0) إن وُجدت
  final double? progress;

  /// أزرار الإجراءات
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onView;

  /// وضع العرض المختصر (للقوائم)
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final statusColor = ApprovalStatus.color(status);
    final canDecide =
        (ApprovalStatus.gmCanDecide(status) || ApprovalStatus.qmCanDecide(status)) &&
        onApprove != null;
    final hasDecision = gmDecision != null && gmDecision!.isNotEmpty;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: isDark ? 0.45 : 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(statusColor),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // سبب الرفض
                _buildInfoRow(
                  icon: Icons.error_outline,
                  label: 'سبب الرفض',
                  value: rejectionReason ?? 'غير محدد',
                  iconColor: Colors.red.shade700,
                ),
                const SizedBox(height: 10),

                // التأثير على الإنتاج والجودة
                _buildImpactSection(),
                const SizedBox(height: 10),

                // الإجراءات الحالية
                _buildActionsSection(),
                const SizedBox(height: 10),

                // الموعد المستهدف
                if (correctiveDueDate != null) ...[
                  _buildDueDateRow(),
                  const SizedBox(height: 10),
                ],

                // نسبة الإنجاز
                _buildProgressSection(),
                const SizedBox(height: 10),

                // القرار السابق
                if (hasDecision) ...[
                  _buildDecisionSummary(),
                  const SizedBox(height: 10),
                ],

                // القرار المطلوب
                _buildDecisionRequest(statusColor),
              ],
            ),
          ),
          if (canDecide || onReject != null || onView != null) _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.25))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            child: Icon(ApprovalStatus.icon(status), color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF142B4A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
            ),
            child: Text(
              ApprovalStatus.shortLabel(status),
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: iconColor ?? const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 2),
              Builder(
                builder: (ctx) {
                  final isDark = Theme.of(ctx).brightness == Brightness.dark;
                  return Text(
                    value,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: isDark ? AppColors.darkInk : const Color(0xFF142B4A), height: 1.4),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImpactSection() {
    final hasAffected = (affectedProducts ?? '').isNotEmpty;
    final hasSeverity = (severity ?? '').isNotEmpty;
    if (!hasAffected && !hasSeverity) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber, size: 15, color: Colors.amber.shade800),
              const SizedBox(width: 6),
              const Text(
                'التأثير على الإنتاج والجودة',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFAD6800)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasSeverity)
            _buildChipRow(
              'مستوى الخطورة:',
              severity!,
              SeverityLevel.color(severity!),
            ),
          if (hasAffected) ...[
            const SizedBox(height: 4),
            _buildChipRow('الكميات المتأثرة:', affectedProducts!, Colors.blueGrey.shade700),
          ],
          if ((immediateAction ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildChipRow('الإجراء الفوري:', immediateAction!, Colors.blueGrey.shade700),
          ],
        ],
      ),
    );
  }

  Widget _buildChipRow(String label, String value, Color color) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF142B4A), height: 1.4),
        children: [
          TextSpan(text: '$label ', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    final hasCorrective = (correctiveAction ?? '').isNotEmpty;
    final hasOwner = (correctiveOwner ?? '').isNotEmpty;
    if (!hasCorrective && !hasOwner) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.build_circle, size: 15, color: Colors.blue.shade800),
              const SizedBox(width: 6),
              const Text(
                'الإجراء التصحيحي المطلوب',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (hasCorrective)
            Text(
              correctiveAction!,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: Color(0xFF142B4A), height: 1.4),
            ),
          if (hasOwner) ...[
            const SizedBox(height: 4),
            _buildChipRow('المسؤول:', correctiveOwner!, Colors.blue.shade800),
          ],
        ],
      ),
    );
  }

  Widget _buildDueDateRow() {
    final isOverdue = correctiveDueDate!.isBefore(DateTime.now()) && status != 'Closed';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isOverdue ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isOverdue ? Colors.red.shade300 : Colors.green.shade300),
      ),
      child: Row(
        children: [
          Icon(
            isOverdue ? Icons.warning : Icons.event_available,
            size: 15,
            color: isOverdue ? Colors.red.shade700 : Colors.green.shade700,
          ),
          const SizedBox(width: 8),
          Text(
            'الموعد المستهدف: ',
            style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700),
          ),
          Text(
            DateFormat('yyyy/MM/dd').format(correctiveDueDate!),
            style: TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isOverdue ? Colors.red.shade800 : Colors.green.shade800,
            ),
          ),
          if (isOverdue) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'متأخر',
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red.shade800),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    // اشتقاق نسبة الإنجاز من الحالة
    final pct = progress ?? _progressFromStatus(status);
    if (pct <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, size: 15, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                const Text(
                  'حالة الإنجاز',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF118A68)),
                ),
              ],
            ),
            Text(
              '${(pct * 100).round()}%',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: ApprovalStatus.color(status),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 7,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(ApprovalStatus.color(status)),
          ),
        ),
      ],
    );
  }

  /// اشتقاق نسبة الإنجاز من الحالة الحالية
  double _progressFromStatus(String status) {
    switch (status) {
      case 'Rejected':
        return 0.15;
      case 'Corrective_In_Progress':
        return 0.40;
      case 'Pending_QM_Decision':
        return 0.65;
      case 'Pending_GM_Decision':
        return 0.85;
      case 'Rejected_By_GM':
        return 1.0;
      case 'Closed':
      case 'Approved':
        return 1.0;
      default:
        return 0.0;
    }
  }

  Widget _buildDecisionSummary() {
    final approved = gmDecision == 'Approved';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: approved ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: approved ? Colors.green.shade300 : Colors.red.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                approved ? Icons.check_circle : Icons.cancel,
                size: 15,
                color: approved ? Colors.green.shade700 : Colors.red.shade700,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  approved ? 'تم اعتماد الإجراء التصحيحي' : 'تم رفض الإجراء التصحيحي',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: approved ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ),
          if ((gmDecisionBy ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildChipRow('بواسطة:', gmDecisionBy!, Colors.grey.shade700),
          ],
          if ((gmDecisionNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              gmDecisionNotes!,
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Color(0xFF142B4A), height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDecisionRequest(Color statusColor) {
    final headerTitle = status == 'Pending_QM_Decision'
        ? 'القرار المطلوب من مدير الجودة'
        : 'القرار المطلوب على الإجراء التصحيحي';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel, size: 15, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headerTitle,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF142B4A)),
                ),
                const SizedBox(height: 3),
                Text(
                  _decisionText(),
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade800, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _decisionText() {
    switch (status) {
      case 'Pending_GM':
        return 'اعتماد التقرير نهائياً أو رفضه مع تعيين إجراء تصحيحي.';
      case 'Pending_QM_Decision':
        return 'تم إنجاز وتوثيق الإجراء التصحيحي — المطلوب مراجعته واعتماده من مدير الجودة قبل رفعه لمدير المصنع.';
      case 'Pending_GM_Decision':
        return 'تم اعتماد الإجراء التصحيحي من مدير الجودة — المطلوب قرار مدير المصنع النهائي بالاعتماد أو الرفض القاطع.';
      case 'Corrective_In_Progress':
        return 'الإجراء التصحيحي قيد التنفيذ من قبل المسؤول المختص وبانتظار توثيقه ورفعه لمدير الجودة.';
      case 'Rejected_By_GM':
        return 'تم رفض الإجراء التصحيحي قطعياً، وانتهت دورة الاعتماد بالرفض النهائي للتقرير دون إمكانية اتخاذ إجراء تصحيحي آخر.';
      case 'Rejected':
        return 'متابعة تنفيذ الإجراء التصحيحي وتوثيقه لرفعه لمدير الجودة.';
      default:
        return 'مراجعة التقرير واتخاذ القرار المناسب.';
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canDecide =
        (ApprovalStatus.gmCanDecide(status) || ApprovalStatus.qmCanDecide(status)) &&
        onApprove != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          if (onView != null)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onView,
                icon: const Icon(Icons.visibility_outlined, size: 16),
                label: const Text('عرض التقرير', style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? AppColors.darkPrimaryLight : const Color(0xFF052659),
                  side: BorderSide(color: isDark ? AppColors.darkPrimaryLight : const Color(0xFF052659)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          if (canDecide) ...[
            if (onView != null) const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onApprove,
                icon: const Icon(Icons.check, size: 16, color: Colors.white),
                label: const Text(
                  'اعتماد',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          if (canDecide && onReject != null) ...[
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onReject,
                icon: const Icon(Icons.close, size: 16, color: Colors.white),
                label: const Text(
                  'رفض',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
