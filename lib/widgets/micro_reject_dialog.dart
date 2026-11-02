import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'ds/ds.dart';

/// نتيجة نافذة رفض نتائج الفحص الميكروبيولوجي
class MicroRejectionResult {
  final String reason;
  final String actionType; // 'resample' أو 'corrective'
  final String? correctiveAction;
  final String? correctiveOwner;
  final DateTime? dueDate;
  final String? notes;

  const MicroRejectionResult({
    required this.reason,
    required this.actionType,
    this.correctiveAction,
    this.correctiveOwner,
    this.dueDate,
    this.notes,
  });
}

/// نافذة مخصصة لرفض نتائج الفحص الميكروبيولوجي بشكل معزول
/// تتيح الاختيار بين:
/// 1. إعادة سحب عينة ميكروبيولوجية جديدة (Re-sampling)
/// 2. تأكيد عدم المطابقة الميكروبيولوجية وتنفيذ إجراء تصحيحي
class MicroRejectDialog extends StatefulWidget {
  const MicroRejectDialog({
    super.key,
    required this.reportTitle,
    this.reportSubtitle,
  });

  final String reportTitle;
  final String? reportSubtitle;

  static Future<MicroRejectionResult?> show(
    BuildContext context, {
    required String reportTitle,
    String? reportSubtitle,
  }) {
    return showDialog<MicroRejectionResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MicroRejectDialog(
        reportTitle: reportTitle,
        reportSubtitle: reportSubtitle,
      ),
    );
  }

  @override
  State<MicroRejectDialog> createState() => _MicroRejectDialogState();
}

class _MicroRejectDialogState extends State<MicroRejectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _reasonController;
  late final TextEditingController _correctiveController;
  late final TextEditingController _ownerController;
  late final TextEditingController _notesController;

  String _actionType = 'resample'; // 'resample' أو 'corrective'
  DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _reasonController = TextEditingController();
    _correctiveController = TextEditingController();
    _ownerController = TextEditingController(text: 'أخصائي الجودة / مسؤول التعقيم');
    _notesController = TextEditingController();
    _dueDate = DateTime.now().add(const Duration(days: 2));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _correctiveController.dispose();
    _ownerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 14),
                  _buildIsolationNotice(),
                  const SizedBox(height: 14),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildActionTypeSelector(),
                          const SizedBox(height: 14),
                          _buildReasonField(),
                          if (_actionType == 'corrective') ...[
                            const SizedBox(height: 14),
                            _buildCorrectiveFields(),
                          ],
                          const SizedBox(height: 14),
                          _buildNotesField(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFEBEE),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade300),
          ),
          child: const Icon(Icons.biotech_outlined, color: Color(0xFFC62828), size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'رفض نتائج الفحص الميكروبيولوجي',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
              if (widget.reportSubtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.reportSubtitle!,
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.grey),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildIsolationNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE0F2F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF80CBC4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFF00695C)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'حماية التقرير الأولي: سيقتصر الرفض على نتائج الفحص الميكروبيولوجي فقط، وستظل نتائج الفحص الفيزيائي والكيميائي وتوقيعات الاعتماد الأولي معتمدة وسارية.',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 11.5,
                color: Color(0xFF004D40),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نوع الإجراء المطلوب لنتائج الميكروبيولوجي *',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildChoiceCard(
                type: 'resample',
                title: 'إعادة سحب عينة جديدة',
                subtitle: 'في حال الشك بتلوث العبوة أو التحضين (Re-sample)',
                icon: Icons.refresh_rounded,
                selectedColor: const Color(0xFF00838F),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildChoiceCard(
                type: 'corrective',
                title: 'تأكيد تلوث وإجراء تصحيحي',
                subtitle: 'عزل التشغيلة وتطهير السير/الفلاتر',
                icon: Icons.warning_amber_rounded,
                selectedColor: const Color(0xFFC62828),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChoiceCard({
    required String type,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color selectedColor,
  }) {
    final isSelected = _actionType == type;
    return InkWell(
      onTap: () => setState(() => _actionType = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade300,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? selectedColor : Colors.grey.shade600),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? selectedColor : Colors.blueGrey.shade800,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle, size: 16, color: selectedColor),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontSize: 10.5,
                color: Colors.grey.shade600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'سبب الرفض والملاحظات المخبرية *',
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _reasonController,
          maxLines: 3,
          style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12.5),
          decoration: InputDecoration(
            hintText: _actionType == 'resample'
                ? 'مثال: وجود اشتباه في عكارة طبق التحضين أو خطأ أثناء فتح العبوة المعقمة، يُطلب سحب عينة جديدة من نفس التشغيلة.'
                : 'مثال: ظهور مستعمرات بكتيريا قولونية (Coliforms) تتجاوز المواصفة القياسية، يلزم حجز التشغيلة وتعقيم الخط.',
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.all(12),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) {
              return 'يرجى كتابة سبب رفض نتائج الميكروبيولوجي';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildCorrectiveFields() {
    final dateFormat = intl.DateFormat('yyyy/MM/dd');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD54F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_outlined, size: 16, color: Color(0xFFF57F17)),
              SizedBox(width: 6),
              Text(
                'بيانات الإجراء التصحيحي الميكروبيولوجي',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                  color: Color(0xFFE65100),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _correctiveController,
            maxLines: 2,
            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
            decoration: InputDecoration(
              labelText: 'الإجراء التصحيحي المطلوب *',
              hintText: 'مثال: عزل الدفعة وتكثيف تعقيم فلاتر الميكرون ونظام الأوزون',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              contentPadding: const EdgeInsets.all(10),
            ),
            validator: (v) {
              if (_actionType == 'corrective' && (v == null || v.trim().isEmpty)) {
                return 'يرجى تحديد الإجراء التصحيحي المطلوب';
              }
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ownerController,
                  style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'المسؤول عن التنفيذ',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 2)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 60)),
                    );
                    if (picked != null) {
                      setState(() => _dueDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _dueDate != null ? dateFormat.format(_dueDate!) : 'تاريخ الإنجاز',
                            style: const TextStyle(fontFamily: 'Tajawal', fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField() {
    return TextFormField(
      controller: _notesController,
      maxLines: 2,
      style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
      decoration: InputDecoration(
        labelText: 'ملاحظات إضافية أو أرقام المستعمرات (اختياري)',
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.all(10),
      ),
    );
  }

  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: AppButton.outlined(
            label: 'إلغاء',
            color: Colors.grey.shade700,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: AppButton.primary(
            label: _actionType == 'resample' ? 'تأكيد طلب إعادة السحب' : 'تأكيد رفض الميكروبيولوجي',
            icon: _actionType == 'resample' ? Icons.refresh : Icons.cancel_outlined,
            color: _actionType == 'resample' ? const Color(0xFF00838F) : const Color(0xFFC62828),
            onPressed: _onSubmit,
          ),
        ),
      ],
    );
  }

  void _onSubmit() {
    if (!_formKey.currentState!.validate()) return;

    final result = MicroRejectionResult(
      reason: _reasonController.text.trim(),
      actionType: _actionType,
      correctiveAction: _actionType == 'corrective' ? _correctiveController.text.trim() : null,
      correctiveOwner: _actionType == 'corrective' ? _ownerController.text.trim() : null,
      dueDate: _actionType == 'corrective' ? _dueDate : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    Navigator.of(context).pop(result);
  }
}
