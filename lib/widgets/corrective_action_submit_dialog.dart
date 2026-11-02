import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../services/user_session_service.dart';

/// نافذة توثيق وإرسال الإجراء التصحيحي المنجز لمدير المصنع
/// تتيح لمنفذ الفحص / مهندس الجودة / المكلف بالتصحيح كتابة الإجراء
/// المنفذ فعلياً ورفعه لمدير المصنع للاعتماد
class CorrectiveActionSubmitDialog extends StatefulWidget {
  const CorrectiveActionSubmitDialog({
    super.key,
    required this.reportTitle,
    required this.rejectionReason,
    this.rejectedBy,
    this.initialCorrectiveAction,
    this.correctiveOwner,
  });

  final String reportTitle;
  final String rejectionReason;
  final String? rejectedBy;
  final String? initialCorrectiveAction;
  final String? correctiveOwner;

  static Future<String?> show(
    BuildContext context, {
    required String reportTitle,
    required String rejectionReason,
    String? rejectedBy,
    String? initialCorrectiveAction,
    String? correctiveOwner,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CorrectiveActionSubmitDialog(
        reportTitle: reportTitle,
        rejectionReason: rejectionReason,
        rejectedBy: rejectedBy,
        initialCorrectiveAction: initialCorrectiveAction,
        correctiveOwner: correctiveOwner,
      ),
    );
  }

  @override
  State<CorrectiveActionSubmitDialog> createState() =>
      _CorrectiveActionSubmitDialogState();
}

class _CorrectiveActionSubmitDialogState
    extends State<CorrectiveActionSubmitDialog> {
  final _actionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _actionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_actionController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.isRegistered<UserSessionService>()
        ? UserSessionService.to
        : null;
    final userName = session?.currentUserName.value.isNotEmpty == true
        ? session!.currentUserName.value
        : 'أخصائي الجودة';
    final userRole = session?.roleTitle ?? '';

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
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_turned_in_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'توثيق وإرسال الإجراء التصحيحي',
                style: TextStyle(
                  fontFamily: 'Tajawal',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF142B4A),
                ),
              ),
            ),
          ],
        ),
        content: Form(
          key: _formKey,
          child: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.reportTitle,
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // بطاقة تلخيص سبب الرفض
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFCDD2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFC62828),
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'سبب الرفض:',
                              style: TextStyle(
                                fontFamily: 'Tajawal',
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: Color(0xFFC62828),
                              ),
                            ),
                            if (widget.rejectedBy != null &&
                                widget.rejectedBy!.isNotEmpty) ...[
                              const Spacer(),
                              Text(
                                'بواسطة: ${widget.rejectedBy}',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 11,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.rejectionReason,
                          style: const TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 12.5,
                            color: Color(0xFF333333),
                          ),
                        ),
                        if (widget.initialCorrectiveAction != null &&
                            widget.initialCorrectiveAction!.isNotEmpty) ...[
                          const Divider(height: 16, color: Color(0xFFFFCDD2)),
                          Text(
                            'الإجراء المطلوب سابقاً: ${widget.initialCorrectiveAction}',
                            style: const TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 12,
                              color: Color(0xFF0D47A1),
                            ),
                          ),
                        ],
                        if (widget.correctiveOwner != null &&
                            widget.correctiveOwner!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'المسؤول المحدد: ${widget.correctiveOwner}',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  const Text(
                    'تفاصيل الإجراء التصحيحي المنفّذ فعلياً *',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF142B4A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _actionController,
                    maxLines: 4,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                    decoration: InputDecoration(
                      hintText:
                          'اكتب بالتفصيل ما تم تنفيذه لمعالجة الخلل (مثلاً: تم إعادة غسيل وتعقيم خط التعبئة وسحب عينة جديدة وفحصها وكانت النتيجة مطابقة)...',
                      hintStyle: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF0F7FF),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFF90CAF9)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: Color(0xFFBBDEFB)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF1565C0),
                          width: 1.5,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'يرجى كتابة تفاصيل الإجراء التصحيحي المنفذ';
                      }
                      if (val.trim().length < 5) {
                        return 'يرجى كتابة وصف كافٍ للإجراء المنفذ (5 أحرف على الأقل)';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 10),

                  // سطر المنفذ والتاريخ
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 15,
                          color: Color(0xFF555555),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'الموثّق: $userName ${userRole.isNotEmpty ? "($userRole)" : ""}',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 11.5,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    'ملاحظة: سيتم رفع التقرير بحالة "بانتظار اعتماد مدير المصنع للإجراء التصحيحي" مع إشعار فوري لمدير المصنع.',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'تراجع',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 13),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            label: const Text(
              'إرسال لمدير المصنع',
              style: TextStyle(
                fontFamily: 'Tajawal',
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
