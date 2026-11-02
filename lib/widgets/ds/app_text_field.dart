import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';

/// حقل نص موحّد يعتمد على [InputDecorationTheme] المعرّف في [AppTheme]
/// (يدعم الوضع الليلي تلقائياً).
///
/// - [isRequired] يضيف علامة * ويتحقق من أن الحقل غير فارغ إن لم يُمرَّر [validator].
/// - الحقول الرقمية تُعرض باتجاه LTR تلقائياً.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.helperText,
    this.prefixIcon,
    this.suffixIcon,
    this.suffixText,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.inputFormatters,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.isRequired = false,
    this.readOnly = false,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.focusNode,
    this.textDirection,
    this.bottomSpacing = 0,
  });

  final String? label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? helperText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? suffixText;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool isRequired;
  final bool readOnly;
  final bool enabled;
  final bool obscureText;
  final bool autofocus;
  final FocusNode? focusNode;
  final TextDirection? textDirection;

  /// مسافة أسفل الحقل (للتوافق مع CustomTextField القديم = 16).
  final double bottomSpacing;

  bool get _isNumeric =>
      keyboardType == TextInputType.number ||
      keyboardType == TextInputType.phone ||
      keyboardType.decimal == true;

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      textDirection:
          textDirection ?? (_isNumeric ? TextDirection.ltr : null),
      maxLines: obscureText ? 1 : maxLines,
      minLines: minLines,
      maxLength: maxLength,
      readOnly: readOnly,
      enabled: enabled,
      obscureText: obscureText,
      autofocus: autofocus,
      focusNode: focusNode,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontWeight: FontWeight.w500,
        color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkInk : AppColors.ink,
      ),
      validator: validator ??
          (isRequired
              ? (v) => (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null
              : null),
      decoration: InputDecoration(
        labelText: label != null ? (isRequired ? '$label *' : label) : null,
        hintText: hint,
        helperText: helperText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
        suffixIcon: suffixIcon,
        suffixText: suffixText,
      ),
    );

    if (bottomSpacing == 0) return field;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomSpacing),
      child: field,
    );
  }
}

/// قائمة منسدلة موحّدة.
///
/// ```dart
/// AppDropdown<int>(
///   label: 'القسم',
///   value: selectedId,
///   items: {1: 'الجودة', 2: 'الإنتاج'},
///   onChanged: (v) => ...,
/// )
/// ```
class AppDropdown<T> extends StatelessWidget {
  const AppDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onChanged,
    this.value,
    this.prefixIcon,
    this.validator,
    this.isRequired = false,
    this.enabled = true,
    this.hint,
  });

  final String label;

  /// القيمة ← النص المعروض.
  final Map<T, String> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final IconData? prefixIcon;
  final FormFieldValidator<T>? validator;
  final bool isRequired;
  final bool enabled;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // تجنّب خطأ Flutter إذا كانت القيمة غير موجودة ضمن العناصر
    final safeValue = (value != null && items.containsKey(value)) ? value : null;

    return DropdownButtonFormField<T>(
      // ignore: deprecated_member_use
      value: safeValue,
      isExpanded: true,
      hint: hint == null ? null : Text(hint!),
      dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      style: TextStyle(
        fontFamily: AppTheme.fontFamily,
        fontWeight: FontWeight.w500,
        color: isDark ? AppColors.darkInk : AppColors.ink,
      ),
      decoration: InputDecoration(
        labelText: isRequired ? '$label *' : label,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      ),
      items: items.entries
          .map((e) => DropdownMenuItem<T>(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onChanged: enabled ? onChanged : null,
      validator: validator ??
          (isRequired ? (v) => v == null ? 'يرجى الاختيار' : null : null),
    );
  }
}
