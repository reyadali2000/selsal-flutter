import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ds/ds.dart';

/// شاشة قرار مدير المصنع أو مدير الجودة على الإجراء التصحيحي
/// تسمح للمسؤول المعتمد بـ:
/// - اعتماد الإجراء التصحيحي (يرفعه للمرحلة التالية أو يغلق التقرير في المرحلة النهائية)
/// - رفضه مع ذكر السبب (يُعيده للمسؤول لإجراء بديل، أو يغلقه بالرفض النهائي في مرحلة مدير المصنع)
///
/// تُرجع [GmDecision] عند التأكيد، أو null عند الإلغاء.
class GmDecisionDialog extends StatefulWidget {
  const GmDecisionDialog({
    super.key,
    required this.reportTitle,
    required this.correctiveAction,
    required this.correctiveOwner,
    this.severity,
    this.decisionTitle = 'قرار مدير المصنع على الإجراء التصحيحي',
    this.isFinalStage = true,
    this.rejectionCount = 0,
  });

  final String reportTitle;
  final String correctiveAction;
  final String correctiveOwner;
  final String? severity;
  final String decisionTitle;
  final bool isFinalStage;
  final int rejectionCount;

  /// فتح الشاشة وإرجاع القرار
  static Future<GmDecision?> show(
    BuildContext context, {
    required String reportTitle,
    required String correctiveAction,
    required String correctiveOwner,
    String? severity,
    String decisionTitle = 'قرار مدير المصنع على الإجراء التصحيحي',
    bool isFinalStage = true,
    int rejectionCount = 0,
  }) {
    return showDialog<GmDecision>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => GmDecisionDialog(
        reportTitle: reportTitle,
        correctiveAction: correctiveAction,
        correctiveOwner: correctiveOwner,
        severity: severity,
        decisionTitle: decisionTitle,
        isFinalStage: isFinalStage,
        rejectionCount: rejectionCount,
      ),
    );
  }

  @override
  State<GmDecisionDialog> createState() => _GmDecisionDialogState();
}

class _GmDecisionDialogState extends State<GmDecisionDialog> {
  final _notesController = TextEditingController();
  bool _isApprove = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_isApprove && _notesController.text.trim().isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى ذكر سبب رفض الإجراء التصحيحي',
        backgroundColor: Colors.amber.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final decision = GmDecision(
      isApproved: _isApprove,
      notes: _notesController.text.trim(),
    );

    setState(() => _isSubmitting = false);
    Navigator.of(context).pop(decision);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF6A1B9A),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gavel, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.decisionTitle,
                style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.reportTitle,
                style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(label: 'الإجراء التصحيحي:', value: widget.correctiveAction),
              const SizedBox(height: 8),
              _buildSummaryRow(label: 'المسؤول:', value: widget.correctiveOwner),
              if (widget.severity != null && widget.severity!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _buildSummaryRow(label: 'مستوى الخطورة:', value: widget.severity!),
              ],
              const SizedBox(height: 16),
              const Text(
                'القرار:',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF052659)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _buildChoiceButton(true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildChoiceButton(false)),
                ],
              ),
              const SizedBox(height: 14),
              if (!_isApprove) ...[
                const Text(
                  'سبب الرفض *',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFFC62828)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'اكتب سبب رفض الإجراء التصحيحي...',
                    hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade500),
                    filled: true,
                    fillColor: const Color(0xFFFFF5F5),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ] else ...[
                const Text(
                  'ملاحظات الاعتماد (اختياري):',
                  style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF2E7D32)),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'أي ملاحظات إضافية على الاعتماد...',
                    hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade500),
                    filled: true,
                    fillColor: const Color(0xFFF5FBF6),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isApprove ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _isApprove ? Colors.green.shade200 : Colors.red.shade200),
                ),
                child: Text(
                  _isApprove
                      ? (widget.isFinalStage
                          ? 'سيُغلق التقرير نهائياً بعد الاعتماد، ويصبح الإجراء التصحيحي معتمداً رسمياً.'
                          : 'سيتم اعتماد الإجراء التصحيحي من إدارة الجودة ورفعه إلى مدير المصنع لاتخاذ القرار النهائي.')
                      : (widget.isFinalStage
                          ? 'سيتم رفض التقرير قطعياً وإغلاق دورة الاعتماد بالرفض النهائي من مدير المصنع دون إمكانية إرجاعه لأي شخص آخر.'
                          : (widget.rejectionCount >= 1
                              ? 'المحاولة الثانية والأخيرة: هذا الرفض سيكون رفضاً قطعياً ويُغلق التقرير نهائياً أو يُحال لمدير المصنع للاعتماد الإداري للإغلاق.'
                              : 'المحاولة الأولى: سيتم إرجاع التقرير للمسؤول لتنفيذ إجراء تصحيحي بديل (متبقية فرصة أخيرة).')),
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 11,
                    color: _isApprove ? Colors.green.shade900 : Colors.red.shade900,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          AppButton.text(
            label: 'تراجع',
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
          AppButton.primary(
            label: _isSubmitting ? 'جاري التأكيد...' : 'تأكيد القرار',
            icon: _isSubmitting ? null : (_isApprove ? Icons.check : Icons.close),
            isLoading: _isSubmitting,
            color: _isApprove ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RichText(
      text: TextSpan(
        style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: isDark ? AppColors.darkInk : const Color(0xFF142B4A), height: 1.4),
        children: [
          TextSpan(text: '$label ', style: const TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: value),
        ],
      ),
    );
  }

  Widget _buildChoiceButton(bool isApprove) {
    final selected = _isApprove == isApprove;
    final color = isApprove ? const Color(0xFF2E7D32) : const Color(0xFFC62828);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => setState(() => _isApprove = isApprove),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: isDark ? 0.22 : 0.1) : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : (isDark ? AppColors.darkBorder : Colors.grey.shade400), width: selected ? 1.6 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isApprove ? Icons.check_circle_outline : Icons.cancel_outlined, size: 18, color: selected ? color : Colors.grey.shade600),
            const SizedBox(width: 8),
            Text(
              isApprove ? 'اعتماد الإجراء' : 'رفض الإجراء',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: selected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ناتج قرار مدير المصنع أو مدير الجودة
class GmDecision {
  final bool isApproved;
  final String notes;

  const GmDecision({required this.isApproved, required this.notes});
}
