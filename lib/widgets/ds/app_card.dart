import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';
import '../../utils/vvk_ui_kit/src/widgets/glass/ui_glass_card.dart';
import '../app_panel.dart';

/// بطاقة موحّدة للنظام.
///
/// - الافتراضي: بطاقة صلبة (نفس شكل [AppPanel]) — مناسبة للقوائم الطويلة.
/// - `AppCard.glass`: بطاقة زجاجية — للبطاقات الرئيسية فقط (الأداء على Windows).
/// - [title]/[subtitle]/[icon] تضيف ترويسة تلقائياً.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = AppTheme.radiusLg,
  }) : glass = false;

  const AppCard.glass({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1,
    this.radius = AppTheme.radiusLg,
  }) : glass = true;

  final Widget child;
  final String? title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double radius;
  final bool glass;

  Widget _content(BuildContext context) {
    if (title == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: icon != null
                  ? AppPanelHeader(
                      title: title!,
                      subtitle: subtitle ?? '',
                      icon: icon!,
                      iconColor: iconColor,
                    )
                  : _PlainHeader(title: title!, subtitle: subtitle),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _content(context);

    if (!glass) {
      return AppPanel(
        padding: padding,
        radius: radius,
        margin: margin,
        onTap: onTap,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        borderWidth: borderWidth,
        child: content,
      );
    }

    final card = UIGlassCard(
      borderRadius: radius,
      padding: padding,
      tintColor: backgroundColor,
      onTap: onTap,
      child: content,
    );
    return margin == null ? card : Padding(padding: margin!, child: card);
  }
}

class _PlainHeader extends StatelessWidget {
  const _PlainHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.darkInk : AppColors.ink,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: isDark ? AppColors.darkMuted : AppColors.muted,
            ),
          ),
      ],
    );
  }
}
