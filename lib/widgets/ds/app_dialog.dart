import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';
import 'app_button.dart';

/// حوارات موحّدة للنظام (تعمل بدون BuildContext عبر GetX).
abstract final class AppDialog {
  /// حوار عام بمحتوى مخصص.
  static Future<T?> show<T>({
    required String title,
    required Widget content,
    IconData? icon,
    Color? iconColor,
    List<Widget>? actions,
    bool barrierDismissible = true,
    double maxWidth = 520,
  }) {
    return Get.dialog<T>(
      _AppDialogShell(
        title: title,
        icon: icon,
        iconColor: iconColor,
        content: content,
        actions: actions,
        maxWidth: maxWidth,
      ),
      barrierDismissible: barrierDismissible,
    );
  }

  /// حوار تأكيد — يرجع `true` عند الموافقة وينفذ `onConfirm` إن وُجد.
  static Future<bool> confirm({
    BuildContext? context,
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool isDanger = false,
    Color? confirmColor,
    VoidCallback? onConfirm,
    IconData? icon,
  }) async {
    final danger = isDanger || confirmColor == Colors.redAccent || confirmColor == Colors.red;
    final result = await show<bool>(
      title: title,
      icon: icon ??
          (danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
      iconColor: confirmColor ?? (danger ? AppButton.dangerColor : AppColors.primaryDark),
      content: Text(
        message,
        style: const TextStyle(fontFamily: AppTheme.fontFamily, height: 1.5),
      ),
      actions: [
        AppButton.text(
          label: cancelLabel,
          onPressed: () => Get.back(result: false),
        ),
        danger
            ? AppButton.danger(
                label: confirmLabel,
                onPressed: () {
                  Get.back(result: true);
                  onConfirm?.call();
                },
              )
            : AppButton.primary(
                label: confirmLabel,
                color: confirmColor,
                onPressed: () {
                  Get.back(result: true);
                  onConfirm?.call();
                },
              ),
      ],
    );
    return result ?? false;
  }

  /// رسالة معلومات بزر واحد.
  static Future<void> info({
    BuildContext? context,
    required String title,
    required String message,
    String okLabel = 'حسناً',
    IconData icon = Icons.info_outline_rounded,
  }) {
    return show<void>(
      title: title,
      icon: icon,
      content: Text(
        message,
        style: const TextStyle(fontFamily: AppTheme.fontFamily, height: 1.5),
      ),
      actions: [AppButton.primary(label: okLabel, onPressed: () => Get.back())],
    );
  }

  /// رسالة تحذير وتنبيه بزر واحد.
  static Future<void> warning({
    BuildContext? context,
    required String title,
    required String message,
    String okLabel = 'حسناً',
    IconData icon = Icons.warning_amber_rounded,
  }) {
    return show<void>(
      title: title,
      icon: icon,
      iconColor: Colors.amber.shade800,
      content: Text(
        message,
        style: const TextStyle(fontFamily: AppTheme.fontFamily, height: 1.5),
      ),
      actions: [AppButton.primary(label: okLabel, onPressed: () => Get.back())],
    );
  }
}

class _AppDialogShell extends StatelessWidget {
  const _AppDialogShell({
    required this.title,
    required this.content,
    required this.maxWidth,
    this.icon,
    this.iconColor,
    this.actions,
  });

  final String title;
  final Widget content;
  final IconData? icon;
  final Color? iconColor;
  final List<Widget>? actions;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = iconColor ?? AppColors.primaryDark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.darkInk : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: content)),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: actions!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
