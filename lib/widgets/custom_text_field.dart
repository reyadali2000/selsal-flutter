import 'package:flutter/material.dart';

import 'ds/app_text_field.dart';

/// حقل نص قديم — أُبقي للتوافق مع الشاشات الحالية، ويعتمد الآن على [AppTextField]
/// (أصبح يدعم الوضع الليلي بدل الخلفية البيضاء الثابتة).
/// للشاشات الجديدة استخدم [AppTextField] مباشرة.
class CustomTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final String? suffixText;
  final Widget? suffixIcon;
  final int maxLines;

  const CustomTextField({
    super.key,
    required this.label,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixText,
    this.suffixIcon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      controller: controller,
      keyboardType: keyboardType,
      prefixIcon: prefixIcon,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      maxLines: maxLines,
      textDirection: keyboardType == TextInputType.number
          ? TextDirection.ltr
          : TextDirection.rtl,
      bottomSpacing: 16,
    );
  }
}
