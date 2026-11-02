import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';
import 'app_button.dart';

/// مؤشر تحميل موحّد مع رسالة اختيارية.
class AppLoading extends StatelessWidget {
  const AppLoading({super.key, this.message});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: isDark ? AppColors.darkMuted : AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// حالة فارغة موحّدة: أيقونة + عنوان + وصف + زر إجراء اختياري.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primaryMedium.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primaryMedium),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.darkInk : AppColors.ink,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: isDark ? AppColors.darkMuted : AppColors.muted,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              AppButton.primary(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// إشعارات موحّدة (SnackBar) عبر GetX.
abstract final class AppToast {
  static void success(String message, {String title = 'تم بنجاح'}) =>
      _show(title, message, AppColors.success, Icons.check_circle_rounded);

  static void error(String message, {String title = 'خطأ'}) =>
      _show(title, message, AppButton.dangerColor, Icons.error_rounded);

  static void warning(String message, {String title = 'تنبيه'}) =>
      _show(title, message, const Color(0xFFB7791F), Icons.warning_rounded);

  static void info(String message, {String title = 'معلومة'}) =>
      _show(title, message, AppColors.primaryDark, Icons.info_rounded);

  static void _show(String title, String message, Color color, IconData icon) {
    if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      icon: Icon(icon, color: Colors.white),
      backgroundColor: color,
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: AppTheme.radiusMd,
      maxWidth: 520,
      duration: const Duration(seconds: 3),
    );
  }
}
