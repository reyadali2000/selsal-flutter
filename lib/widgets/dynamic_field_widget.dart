import 'package:get/get.dart';
import '../services/user_session_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/dynamic_report_models.dart';
import '../utils/calculated_field_helper.dart';
import '../utils/dynamic_validation_helper.dart';
import '../widgets/ds/ds.dart';
import 'dynamic_table_widget.dart';

class DynamicFieldWidget extends StatelessWidget {
  final DynamicReportField field;
  final TextEditingController? textController;
  final dynamic initialValue;
  final Function(dynamic) onChanged;

  const DynamicFieldWidget({
    super.key,
    required this.field,
    this.textController,
    this.initialValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (!field.isVisible) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildFieldByType(context),
    );
  }

  Widget _buildFieldByType(BuildContext context) {
    final type = field.fieldType.toLowerCase().trim();
    switch (type) {
      case 'text':
      case 'multiline_text':
      case 'textarea':
      case 'multiline':
      case 'number':
      case 'int':
      case 'integer':
      case 'decimal':
      case 'float':
      case 'double':
        return _buildTextFormField();
      case 'note':
        return _buildNoteField(context);
      case 'instructions':
        return _buildInstructionsField();
      case 'dropdown':
      case 'select':
        return _buildDropdown();
      case 'radio':
        return _buildRadio(context);
      case 'checkbox':
        return _buildCheckbox();
      case 'switch':
      case 'toggle':
      case 'bool':
      case 'boolean':
        return _buildSwitch();
      case 'date':
      case 'time':
      case 'datetime':
        return _buildDateTimeField(context);
      case 'rating':
        return _buildRatingField(context);
      case 'calculated':
        return _buildCalculatedField(context);
      case 'table':
        return DynamicTableWidget(
          field: field,
          initialValue: initialValue,
          onChanged: onChanged,
        );
      case 'signature':
        return _buildSignatureField(context);
      default:
        debugPrint('[DynamicFieldWidget] Unknown fieldType "${field.fieldType}", defaulting to text field.');
        return _buildTextFormField();
    }
  }

  Widget _buildTextFormField() {
    final type = field.fieldType.toLowerCase().trim();
    TextInputType keyboardType = TextInputType.text;
    int maxLines = 1;

    if (type == 'number' || type == 'int' || type == 'integer' || type == 'decimal' || type == 'float' || type == 'double') {
      keyboardType = const TextInputType.numberWithOptions(decimal: true);
    } else if (type == 'multiline_text' || type == 'textarea' || type == 'multiline') {
      keyboardType = TextInputType.multiline;
      maxLines = 3;
    }

    return AppTextField(
      controller: textController,
      label: field.label,
      hint: field.hint,
      suffixText: field.unit,
      keyboardType: keyboardType,
      maxLines: maxLines,
      isRequired: field.isRequired,
      validator: (val) => DynamicValidationHelper.validate(field, val),
      onChanged: (val) => onChanged(val),
    );
  }

  /// ملاحظة: حقل إدخال متعدد الأسطر داخل صندوق ملون مميز.
  Widget _buildNoteField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF4A3800).withValues(alpha: 0.3)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: isDark ? const Color(0xFFF57F17) : const Color(0xFFFFE082),
          width: 1.2,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_rounded, size: 18, color: Color(0xFFF9A825)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  field.label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppTextField(
            controller: textController,
            keyboardType: TextInputType.multiline,
            maxLines: 3,
            label: '',
            hint: field.hint ?? 'اكتب ملاحظتك هنا...',
            validator: (val) => DynamicValidationHelper.validate(field, val),
            // ignore: deprecated_member_use
            onChanged: (val) => onChanged(val),
          ),
        ],
      ),
    );
  }

  /// تعليمات: نص توجيهي ثابت للقراءة فقط، يُعرض أثناء التعبئة ولا يُحفظ كقيمة.
  Widget _buildInstructionsField() {
    final body = field.defaultValue ?? '';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 19, color: Color(0xFF1976D2)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (field.label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      field.label,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12.5,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    final options = field.options;
    
    // Ensure initialValue is valid or null
    String? currentValue = initialValue?.toString();
    if (currentValue != null && !options.contains(currentValue)) {
      currentValue = null;
    }

    return AppDropdown<String>(
      label: field.label,
      value: currentValue,
      isRequired: field.isRequired,
      items: {
        for (final opt in options) opt: opt,
      },
      onChanged: (val) => onChanged(val),
      validator: (val) => DynamicValidationHelper.validate(field, val),
    );
  }

  Widget _buildRadio(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final options = field.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          field.label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkInk : AppColors.ink,
          ),
        ),
        ...options.map((option) {
          return RadioListTile<String>(
            title: Text(option, style: const TextStyle(fontFamily: AppTheme.fontFamily)),
            value: option,
            // ignore: deprecated_member_use
            groupValue: initialValue?.toString(),
            // ignore: deprecated_member_use
            onChanged: (val) => onChanged(val),
          );
        }),
      ],
    );
  }

  Widget _buildCheckbox() {
    bool isChecked = initialValue == 'true' || initialValue == true;
    return CheckboxListTile(
      title: Text(field.label, style: const TextStyle(fontFamily: AppTheme.fontFamily)),
      subtitle: field.hint != null ? Text(field.hint!, style: const TextStyle(fontFamily: AppTheme.fontFamily)) : null,
      value: isChecked,
      onChanged: (val) => onChanged(val?.toString()),
    );
  }

  Widget _buildSwitch() {
    bool isSwitched = initialValue == 'true' || initialValue == true;
    return SwitchListTile(
      title: Text(field.label, style: const TextStyle(fontFamily: AppTheme.fontFamily)),
      subtitle: field.hint != null ? Text(field.hint!, style: const TextStyle(fontFamily: AppTheme.fontFamily)) : null,
      value: isSwitched,
      onChanged: (val) => onChanged(val.toString()),
    );
  }

  Widget _buildDateTimeField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDatetime = field.fieldType == 'datetime';
    return InkWell(
      onTap: () async {
        final navigator = Navigator.of(context);
        if (field.fieldType == 'date' || isDatetime) {
          final DateTime? picked = await showDatePicker(
            context: navigator.context,
            initialDate: DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2101),
          );
          if (picked == null) return;

          if (isDatetime) {
            if (!navigator.mounted) return;
            final TimeOfDay? pickedTime = await showTimePicker(
              context: navigator.context,
              initialTime: TimeOfDay.now(),
            );
            if (pickedTime == null) return;
            final dt = DateTime(picked.year, picked.month, picked.day, pickedTime.hour, pickedTime.minute);
            onChanged(DateFormat('yyyy-MM-dd HH:mm').format(dt));
            return;
          }
          onChanged(DateFormat('yyyy-MM-dd').format(picked));
        } else if (field.fieldType == 'time') {
          final TimeOfDay? picked = await showTimePicker(
            context: navigator.context,
            initialTime: TimeOfDay.now(),
          );
          if (picked != null) {
            final now = DateTime.now();
            final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
            onChanged(DateFormat('HH:mm').format(dt));
          }
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          prefixIcon: Icon(
            field.fieldType == 'time' ? Icons.access_time_rounded : Icons.calendar_today_rounded,
          ),
        ),
        child: Text(
          initialValue?.toString() ?? 'اختر...',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            color: initialValue == null
                ? (isDark ? AppColors.darkMuted : Colors.grey)
                : (isDark ? AppColors.darkInk : AppColors.ink),
          ),
        ),
      ),
    );
  }

  Widget _buildRatingField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bounds = CalculatedFieldHelper.ratingBounds(field);
    final minRating = bounds.min;
    final maxRating = bounds.max;

    int currentValue = int.tryParse(initialValue?.toString() ?? '') ?? 0;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(maxRating - minRating + 1, (index) {
              final value = minRating + index;
              final isActive = value <= currentValue && currentValue != 0;
              return GestureDetector(
                onTap: () => onChanged(value.toString()),
                child: Icon(
                  isActive ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 34,
                  color: isActive ? const Color(0xFFF9A825) : Colors.grey.shade400,
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              currentValue == 0
                  ? 'التقييم: لم يُحدد'
                  : 'التقييم: $currentValue / $maxRating',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                color: currentValue == 0
                    ? (isDark ? AppColors.darkMuted : Colors.grey)
                    : (isDark ? AppColors.darkInk : AppColors.ink),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatedField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        prefixIcon: const Icon(Icons.calculate_rounded),
      ),
      child: Text(
        initialValue?.toString().isNotEmpty == true
            ? initialValue.toString()
            : 'يُحسب تلقائياً',
        textAlign: TextAlign.right,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: initialValue == null
              ? (isDark ? AppColors.darkMuted : Colors.grey)
              : (isDark ? AppColors.darkInk : AppColors.ink),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSignatureField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sigValue = initialValue?.toString().trim() ?? '';
    final bool hasSig = sigValue.isNotEmpty;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: hasSig ? AppColors.success : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSig ? Icons.verified_rounded : Icons.draw_rounded,
                color: hasSig ? AppColors.success : (isDark ? AppColors.darkMuted : Colors.grey.shade700),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  field.label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? AppColors.darkInk : AppColors.ink,
                  ),
                ),
              ),
              if (hasSig)
                TextButton.icon(
                  onPressed: () => onChanged(''),
                  icon: const Icon(Icons.clear, size: 16, color: Colors.red),
                  label: const Text('مسح التوقيع', style: TextStyle(color: Colors.red, fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              if (!hasSig) {
                final session = Get.isRegistered<UserSessionService>() ? UserSessionService.to : null;
                String currentUserName = session?.currentUser.value?.fullName.trim() ?? '';
                if (currentUserName.isEmpty || currentUserName.toLowerCase().contains('current_user')) {
                  currentUserName = session?.currentUserName.value.trim() ?? 'المسؤول';
                }
                if (currentUserName.isEmpty || currentUserName.toLowerCase().contains('current_user')) {
                  currentUserName = 'المسؤول';
                }
                final timeStr = DateFormat('yyyy/MM/dd HH:mm').format(DateTime.now());
                onChanged('تم الاعتماد بواسطة: $currentUserName ($timeStr)');
              }
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: hasSig
                    ? (isDark ? Colors.green.shade900.withValues(alpha: 0.3) : Colors.green.shade50)
                    : (isDark ? AppColors.darkSurface : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasSig ? Colors.green.shade500 : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasSig ? Icons.check_circle_outline : Icons.edit_note,
                    size: 18,
                    color: hasSig ? Colors.green.shade700 : AppColors.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      hasSig ? sigValue : 'اضغط هنا للاعتماد والتوقيع الإلكتروني ✍️',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12.5,
                        fontWeight: hasSig ? FontWeight.bold : FontWeight.w600,
                        color: hasSig ? Colors.green.shade800 : AppColors.primaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
