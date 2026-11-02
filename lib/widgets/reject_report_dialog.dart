import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart' as intl;
import 'dart:ui' as ui;
import '../constants/approval_status.dart';
import '../models/rejection_payload.dart';
import 'ds/ds.dart';

/// شاشة رفض التقرير المطورة
/// تعرض نموذجاً متكاملاً يسمح لمدير الجودة (أو أي معتمد يملك صلاحية الرفض) بتوثيق:
/// - سبب الرفض (إلزامي)
/// - تصنيف السبب ومستوى الخطورة
/// - الملاحظات والأدلة
/// - المنتجات/الكميات المتأثرة
/// - الإجراء الفوري المتخذ
/// - الإجراء التصحيحي المطلوب + المسؤول + الموعد المستهدف
///
/// تُرجع [RejectionPayload] كاملة عند التأكيد، أو null عند الإلغاء.
class RejectReportDialog extends StatefulWidget {
  const RejectReportDialog({
    super.key,
    required this.reportTitle,
    this.reportSubtitle,
    this.initialPayload,
  });

  /// عنوان التقرير المرفوض (مثال: "تقرير فحص المياه الخام #12")
  final String reportTitle;

  /// وصف مختصر للتقرير (رقم الدفعة، المنتج...)
  final String? reportSubtitle;

  /// قيم سابقة عند تعديل بيانات الرفض
  final RejectionPayload? initialPayload;

  /// فتح الشاشة كـ Dialog وإرجاع الحزمة كاملة
  static Future<RejectionPayload?> show(
    BuildContext context, {
    required String reportTitle,
    String? reportSubtitle,
    RejectionPayload? initialPayload,
  }) {
    return showDialog<RejectionPayload>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RejectReportDialog(
        reportTitle: reportTitle,
        reportSubtitle: reportSubtitle,
        initialPayload: initialPayload,
      ),
    );
  }

  @override
  State<RejectReportDialog> createState() => _RejectReportDialogState();
}

class _RejectReportDialogState extends State<RejectReportDialog> {
  late final TextEditingController _reasonController;
  late final TextEditingController _notesController;
  late final TextEditingController _affectedController;
  late final TextEditingController _immediateController;
  late final TextEditingController _correctiveController;
  late final TextEditingController _ownerController;

  String? _selectedCategory;
  String? _selectedSeverity;
  DateTime? _dueDate;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialPayload;
    _reasonController = TextEditingController(text: init?.reason ?? '');
    _notesController = TextEditingController(text: init?.notes ?? '');
    _affectedController = TextEditingController(text: init?.affectedProducts ?? '');
    _immediateController = TextEditingController(text: init?.immediateAction ?? '');
    _correctiveController = TextEditingController(text: init?.correctiveAction ?? '');
    _ownerController = TextEditingController(text: init?.correctiveOwner ?? '');
    _selectedCategory = init?.category;
    _selectedSeverity = init?.severity;
    _dueDate = init?.dueDate;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _notesController.dispose();
    _affectedController.dispose();
    _immediateController.dispose();
    _correctiveController.dispose();
    _ownerController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 3)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'الموعد المستهدف للإغلاق',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
      builder: (ctx, child) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  bool get _isValid {
    if (_reasonController.text.trim().isEmpty) {
      Get.snackbar(
        'تنبيه',
        'يرجى كتابة سبب الرفض — إلزامي',
        backgroundColor: Colors.amber.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return false;
    }
    return true;
  }

  void _submit() {
    if (!_isValid) return;

    setState(() => _isSubmitting = true);

    final payload = RejectionPayload(
      reason: _reasonController.text.trim(),
      category: _selectedCategory,
      severity: _selectedSeverity,
      notes: _notesController.text.trim(),
      affectedProducts: _affectedController.text.trim(),
      immediateAction: _immediateController.text.trim(),
      correctiveAction: _correctiveController.text.trim(),
      correctiveOwner: _ownerController.text.trim(),
      dueDate: _dueDate,
    );

    setState(() => _isSubmitting = false);
    Navigator.of(context).pop(payload);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFC62828),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'رفض التقرير وتعيين إجراء تصحيحي',
                    style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    widget.reportTitle,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.reportSubtitle != null && widget.reportSubtitle!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Text(
                      widget.reportSubtitle!,
                      style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                ],

                // 1) سبب الرفض (إلزامي)
                _sectionLabel(text: 'سبب الرفض *', icon: Icons.error_outline),
                _buildTextField(
                  controller: _reasonController,
                  hint: 'اكتب سبب الرفض بالتفصيل...',
                  maxLines: 3,
                  isError: true,
                ),
                const SizedBox(height: 12),

                // 2) تصنيف السبب + مستوى الخطورة
                Row(
                  children: [
                    Expanded(child: _sectionLabel(text: 'تصنيف السبب', icon: Icons.category_outlined)),
                    const SizedBox(width: 12),
                    Expanded(child: _sectionLabel(text: 'مستوى الخطورة', icon: Icons.flag_outlined)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildCategoryDropdown()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildSeverityDropdown()),
                  ],
                ),
                const SizedBox(height: 12),

                // 3) المنتجات/الكميات المتأثرة
                _sectionLabel(text: 'المنتجات / الكميات المتأثرة', icon: Icons.inventory_2_outlined),
                _buildTextField(
                  controller: _affectedController,
                  hint: 'مثال: 500 وحدة من قوارير 0.5 لتر (دفعة B-1024)',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // 4) الإجراء الفوري المتخذ
                _sectionLabel(text: 'الإجراء الفوري المتخذ', icon: Icons.flash_on),
                _buildTextField(
                  controller: _immediateController,
                  hint: 'مثال: عزل الكمية، إيقاف الخط، إشعار توقيف...',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // 5) الإجراء التصحيحي
                _sectionLabel(text: 'الإجراء التصحيحي المطلوب', icon: Icons.build_circle),
                _buildTextField(
                  controller: _correctiveController,
                  hint: 'مثال: إعادة الفحص، تحليل السبب الجذري، استبدال المادة...',
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // 6) المسؤول + الموعد المستهدف
                Row(
                  children: [
                    Expanded(child: _sectionLabel(text: 'المسؤول عن التصحيح', icon: Icons.person_outline)),
                    const SizedBox(width: 12),
                    Expanded(child: _sectionLabel(text: 'الموعد المستهدف', icon: Icons.event_available)),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _buildOwnerField()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDueDateField()),
                  ],
                ),
                const SizedBox(height: 12),

                // 7) ملاحظات وأدلة إضافية
                _sectionLabel(text: 'ملاحظات / أدلة / مرفقات', icon: Icons.attach_file),
                _buildTextField(
                  controller: _notesController,
                  hint: 'أي ملاحظات أو إشارات لأدلة داعمة...',
                  maxLines: 2,
                ),
                const SizedBox(height: 6),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'سيتم إشعار مدير المصنع بالرفض والإجراء التصحيحي لاعتماده.',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 11, color: Colors.amber.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          AppButton.text(
            label: 'تراجع',
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
          AppButton.primary(
            label: _isSubmitting ? 'جاري التأكيد...' : 'تأكيد الرفض',
            icon: _isSubmitting ? null : Icons.check,
            isLoading: _isSubmitting,
            color: const Color(0xFFC62828),
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel({required String text, required IconData icon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? AppColors.darkPrimaryLight : const Color(0xFF052659);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool isError = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      maxLines: maxLines,
      textDirection: ui.TextDirection.rtl,
      style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: isDark ? AppColors.darkInk : AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isDark ? AppColors.darkMuted : Colors.grey.shade500),
        filled: true,
        fillColor: isError
            ? (isDark ? const Color(0xFF381215) : const Color(0xFFFFF5F5))
            : (isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: isError ? Colors.red.shade400 : (isDark ? AppColors.darkPrimaryLight : const Color(0xFF052659)), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade400),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          hint: Text('اختر التصنيف', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isDark ? AppColors.darkMuted : Colors.grey.shade600)),
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: isDark ? AppColors.darkInk : Colors.black87),
          items: RejectionCategory.all.map((c) {
            return DropdownMenuItem<String>(value: c, child: Text(c));
          }).toList(),
          onChanged: (v) => setState(() => _selectedCategory = v),
        ),
      ),
    );
  }

  Widget _buildSeverityDropdown() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? AppColors.darkBorder : Colors.grey.shade400),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedSeverity,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          hint: Text('اختر المستوى', style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isDark ? AppColors.darkMuted : Colors.grey.shade600)),
          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12.5, color: isDark ? AppColors.darkInk : Colors.black87),
          items: SeverityLevel.all.map((s) {
            return DropdownMenuItem<String>(
              value: s,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: SeverityLevel.color(s), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(s),
                ],
              ),
            );
          }).toList(),
          onChanged: (v) => setState(() => _selectedSeverity = v),
        ),
      ),
    );
  }

  Widget _buildOwnerField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _ownerController,
      textDirection: ui.TextDirection.rtl,
      style: TextStyle(fontFamily: 'Tajawal', fontSize: 13, color: isDark ? AppColors.darkInk : AppColors.ink),
      decoration: InputDecoration(
        hintText: 'اسم المسؤول',
        hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: isDark ? AppColors.darkMuted : Colors.grey.shade500),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceElevated : Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade300)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _buildDueDateField() {
    final hasDate = _dueDate != null;
    return InkWell(
      onTap: _pickDueDate,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: hasDate ? const Color(0xFFE8F5E9) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: hasDate ? Colors.green.shade400 : Colors.grey.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, size: 14, color: hasDate ? Colors.green.shade700 : Colors.grey.shade600),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasDate ? intl.DateFormat('yyyy/MM/dd').format(_dueDate!) : 'تحديد الموعد',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 12.5,
                  fontWeight: hasDate ? FontWeight.bold : FontWeight.normal,
                  color: hasDate ? Colors.green.shade800 : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
