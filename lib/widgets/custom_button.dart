import 'package:flutter/material.dart';

import 'ds/app_button.dart';

/// زر قديم — أُبقي للتوافق مع الشاشات الحالية، ويعتمد الآن على [AppButton].
/// للشاشات الجديدة استخدم [AppButton] مباشرة.
class CustomButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double? width;
  final double height;
  final double borderRadius;
  final Color textColor;
  final double fontSize;

  const CustomButton({
    super.key,
    required this.text,
    this.icon,
    required this.onPressed,
    this.color,
    this.width,
    this.height = 50.0,
    this.borderRadius = 8.0,
    this.textColor = Colors.white,
    this.fontSize = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    return AppButton.primary(
      label: text,
      icon: icon,
      onPressed: onPressed,
      color: color,
      foregroundColor: textColor,
      width: width ?? double.infinity,
      height: height,
      fontSize: fontSize,
    );
  }
}
