import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';
import '../../utils/vvk_ui_kit/src/widgets/buttons/ui_styled_button.dart';

/// أنواع الأزرار الموحّدة في النظام.
enum AppButtonVariant { primary, secondary, outlined, danger, text }

/// زر موحّد للنظام مبني على [UIStyledButton].
///
/// ```dart
/// AppButton.primary(label: 'حفظ', icon: Icons.save, onPressed: save)
/// AppButton.danger(label: 'حذف', onPressed: delete, isLoading: busy)
/// ```
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.width,
    this.height,
    this.color,
    this.foregroundColor,
    this.fontSize = 15,
  });

  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.width,
    this.height,
    this.color,
    this.foregroundColor,
    this.fontSize = 15,
  }) : variant = AppButtonVariant.primary;

  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.width,
    this.height,
    this.color,
    this.foregroundColor,
    this.fontSize = 15,
  }) : variant = AppButtonVariant.secondary;

  const AppButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.width,
    this.height,
    this.color,
    this.foregroundColor,
    this.fontSize = 15,
  }) : variant = AppButtonVariant.outlined;

  const AppButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.width,
    this.height,
    this.color,
    this.foregroundColor,
    this.fontSize = 15,
  }) : variant = AppButtonVariant.danger;

  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.expanded = false,
    this.width,
    this.height,
    this.color,
    this.foregroundColor,
    this.fontSize = 15,
  }) : variant = AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool isLoading;

  /// يملأ العرض المتاح بالكامل.
  final bool expanded;
  final double? width;
  final double? height;

  /// لون الخلفية (أو لون الحدود/النص في outlined و text).
  final Color? color;
  final Color? foregroundColor;
  final double fontSize;

  static const Color dangerColor = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textStyle = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );

    late final UIStyledButtonStyle style;
    late final UIStyledButtonVariant kitVariant;

    switch (variant) {
      case AppButtonVariant.primary:
        style = UIStyledButtonStyle.primary(
          context,
          height: height,
          backgroundColor: color ?? (isDark ? AppColors.darkPrimary : AppColors.primaryDark),
          foregroundColor: foregroundColor ?? Colors.white,
          textStyle: textStyle,
        );
        kitVariant = UIStyledButtonVariant.primary;
      case AppButtonVariant.secondary:
        style = UIStyledButtonStyle.primary(
          context,
          height: height,
          backgroundColor: color ?? (isDark ? const Color(0xFF1E2B3E) : AppColors.primaryLightest),
          foregroundColor: foregroundColor ?? (isDark ? AppColors.darkPrimaryLight : AppColors.primaryDark),
          textStyle: textStyle,
        );
        kitVariant = UIStyledButtonVariant.primary;
      case AppButtonVariant.danger:
        style = UIStyledButtonStyle.primary(
          context,
          height: height,
          backgroundColor: color ?? (isDark ? AppColors.darkDanger : dangerColor),
          foregroundColor: foregroundColor ?? Colors.white,
          textStyle: textStyle,
        );
        kitVariant = UIStyledButtonVariant.primary;
      case AppButtonVariant.outlined:
        final c = color ?? (isDark ? AppColors.darkPrimaryLight : AppColors.primaryDark);
        style = UIStyledButtonStyle.outlined(
          context,
          height: height,
          borderColor: c,
          foregroundColor: foregroundColor ?? c,
          backgroundColor: Colors.transparent,
          textStyle: textStyle,
        );
        kitVariant = UIStyledButtonVariant.outline;
      case AppButtonVariant.text:
        style = UIStyledButtonStyle.text(
          context,
          height: height,
          foregroundColor: foregroundColor ??
              color ??
              (isDark ? AppColors.darkPrimaryLight : AppColors.primaryDark),
          textStyle: textStyle,
        );
        kitVariant = UIStyledButtonVariant.text;
    }

    final iconColor = style.foregroundColor;

    return UIStyledButton(
      style: style,
      variant: kitVariant,
      onPressed: onPressed,
      isDisabled: onPressed == null,
      isLoading: isLoading,
      width: expanded ? double.infinity : width,
      icon: icon == null ? null : Icon(icon, size: 20, color: iconColor),
      child: Text(label, style: textStyle, overflow: TextOverflow.ellipsis),
    );
  }
}
