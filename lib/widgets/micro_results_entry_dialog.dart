import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/standards_models.dart';
import '../models/water_quality_models.dart';
import 'ds/ds.dart';

/// نافذة إدخال نتائج الفحوصات الميكروبيولوجية (المرحلة الثانية).
///
/// تُعرض بعد الاعتماد المبدئي للتقرير (Awaiting_Micro_Results) حيث يدخل
/// أخصائي الجودة النتائج التي تصل بعد 24 ساعة من أخذ العينة.
///
/// تُرجع قائمة [WaterQualityResult] الخاصة بالمعاملات الميكروبيولوجية،
/// أو null عند الإلغاء.
class MicroResultsEntryDialog extends StatefulWidget {
  const MicroResultsEntryDialog({
    super.key,
    required this.standards,
    required this.parameters,
    this.existingResults = const [],
    this.reportTitle = '',
  });

  final List<QualityStandard> standards;
  final Map<int, TestParameter> parameters;
  final List<WaterQualityResult> existingResults;
  final String reportTitle;

  static Future<List<WaterQualityResult>?> show(
    BuildContext context, {
    required List<QualityStandard> standards,
    required Map<int, TestParameter> parameters,
    List<WaterQualityResult> existingResults = const [],
    String reportTitle = '',
  }) {
    return showDialog<List<WaterQualityResult>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => MicroResultsEntryDialog(
        standards: standards,
        parameters: parameters,
        existingResults: existingResults,
        reportTitle: reportTitle,
      ),
    );
  }

  @override
  State<MicroResultsEntryDialog> createState() => _MicroResultsEntryDialogState();
}

class _MicroResultsEntryDialogState extends State<MicroResultsEntryDialog> {
  final Map<int, TextEditingController> _valueControllers = {};
  final Map<int, TextEditingController> _noteControllers = {};
  final Set<int> _noteVisible = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    for (final std in widget.standards) {
      final ctrl = TextEditingController();
      // ملء القيمة الموجودة مسبقاً (إن أُدخلت في مسودة سابقة)
      final existing = widget.existingResults
          .firstWhereOrNull((r) => r.parameterId == std.parameterId);
      if (existing != null) {
        if (existing.textResult != null && existing.textResult!.isNotEmpty) {
          ctrl.text = existing.textResult!;
        } else if (existing.numericResult != null) {
          ctrl.text = existing.numericResult.toString();
        }
        if (existing.notes != null && existing.notes!.isNotEmpty) {
          _noteControllers[std.parameterId] = TextEditingController(text: existing.notes);
          _noteVisible.add(std.parameterId);
        }
      }
      ctrl.addListener(() => setState(() {}));
      _valueControllers[std.parameterId] = ctrl;
      _noteControllers.putIfAbsent(std.parameterId, () => TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final c in _valueControllers.values) {
      c.dispose();
    }
    for (final c in _noteControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isCompliant(int parameterId) {
    final val = _valueControllers[parameterId]?.text.trim().toLowerCase() ?? '';
    return val == 'خالية تماماً' || val == 'خالية';
  }

  bool _getHasValue(int parameterId) {
    return (_valueControllers[parameterId]?.text.trim() ?? '').isNotEmpty;
  }

  bool get _allFilled {
    for (final std in widget.standards) {
      if (!_getHasValue(std.parameterId)) return false;
    }
    return true;
  }

  void _submit() {
    if (widget.standards.isEmpty) {
      Navigator.of(context).pop(<WaterQualityResult>[]);
      return;
    }

    if (!_allFilled) {
      Get.snackbar(
        'تنبيه',
        'الرجاء تعبئة جميع النتائج الميكروبيولوجية قبل الرفع',
        backgroundColor: Colors.amber.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final results = <WaterQualityResult>[];
    for (final std in widget.standards) {
      final pId = std.parameterId;
      final text = _valueControllers[pId]!.text.trim();
      final note = _noteControllers[pId]?.text.trim() ?? '';
      final param = widget.parameters[pId];

      double? numVal;
      String? textVal;
      if (param?.inputType == 'Numeric') {
        numVal = double.tryParse(text);
      } else {
        textVal = text;
      }

      results.add(WaterQualityResult(
        logId: 0,
        parameterId: pId,
        numericResult: numVal,
        textResult: textVal,
        isCompliant: _isCompliant(pId),
        notes: note.isNotEmpty ? note : null,
      ));
    }

    setState(() => _isSubmitting = false);
    Navigator.of(context).pop(results);
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
                color: Color(0xFF00838F),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.science_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'نتائج الفحوصات الميكروبيولوجية',
                style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 15),
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
              if (widget.reportTitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    widget.reportTitle,
                    style: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade700),
                  ),
                ),
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: const Text(
                  'المرحلة الثانية: اعتُمد هذا التقرير مبدئياً. أدخل نتائج الفحص الميكروبيولوجي '
                  'لتُرسل لمدير الجودة ثم مدير المصنع للاعتماد النهائي.',
                  style: TextStyle(fontFamily: 'Tajawal', fontSize: 11.5, color: Color(0xFF006064), height: 1.4),
                ),
              ),
              Flexible(
                child: widget.standards.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'لا توجد معايير ميكروبيولوجية مسجلة لهذا التقرير',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: widget.standards.length,
                        itemBuilder: (context, index) {
                          final std = widget.standards[index];
                          return _buildMicroField(std);
                        },
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
            label: _isSubmitting ? 'جاري الرفع...' : 'رفع النتائج',
            icon: _isSubmitting ? null : Icons.send,
            isLoading: _isSubmitting,
            color: const Color(0xFF00838F),
            onPressed: _isSubmitting ? null : _submit,
          ),
        ],
      ),
    );
  }

  Widget _buildMicroField(QualityStandard std) {
    final param = widget.parameters[std.parameterId];
    if (param == null) return const SizedBox.shrink();

    final hasValue = _getHasValue(std.parameterId);
    final isCompliant = hasValue && _isCompliant(std.parameterId);
    final isNotCompliant = hasValue && !isCompliant;
    final isNoteVis = _noteVisible.contains(std.parameterId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: !hasValue
            ? Colors.grey.shade50
            : (isCompliant ? Colors.green.shade50.withValues(alpha: 0.5) : Colors.red.shade50.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: !hasValue
              ? Colors.grey.shade200
              : (isCompliant ? Colors.green.shade200 : Colors.red.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      param.nameAr,
                      style: const TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'معيار القبول: خالية تماماً',
                      style: TextStyle(fontFamily: 'Tajawal', color: Colors.grey.shade600, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.note_add_outlined,
                  size: 20,
                  color: isNoteVis ? Colors.blue : Colors.grey.shade500,
                ),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.all(4),
                onPressed: () {
                  setState(() {
                    if (isNoteVis) {
                      _noteVisible.remove(std.parameterId);
                    } else {
                      _noteVisible.add(std.parameterId);
                    }
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isCompliant ? Colors.green : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isCompliant ? Colors.green : Colors.grey.shade300, width: isCompliant ? 1.5 : 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _valueControllers[std.parameterId]!.text = isCompliant ? '' : 'خالية تماماً';
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isCompliant) ...[
                              const Icon(Icons.check_circle, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                'خالية تماماً',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isCompliant ? Colors.white : Colors.green.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isNotCompliant ? Colors.red : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isNotCompliant ? Colors.red : Colors.grey.shade300, width: isNotCompliant ? 1.5 : 1),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _valueControllers[std.parameterId]!.text = isNotCompliant ? '' : 'موجبة / ملوثة';
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isNotCompliant) ...[
                              const Icon(Icons.cancel, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                'توجد ميكروبات',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isNotCompliant ? Colors.white : Colors.red.shade700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isNoteVis) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _noteControllers[std.parameterId],
              style: const TextStyle(fontFamily: 'Tajawal', fontSize: 12),
              decoration: InputDecoration(
                hintText: 'ملاحظة حول ${param.nameAr}...',
                hintStyle: TextStyle(fontFamily: 'Tajawal', fontSize: 12, color: Colors.grey.shade500),
                filled: true,
                fillColor: Colors.blue.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
