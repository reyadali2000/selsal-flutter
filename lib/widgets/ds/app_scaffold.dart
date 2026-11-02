import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';
import '../../constants/app_theme.dart';

/// هيكل شاشة موحّد: AppBar بلون النظام + خلفية متدرّجة + توسيط المحتوى
/// على الشاشات العريضة بعرض أقصى [maxContentWidth].
///
/// ```dart
/// AppScaffold(
///   title: 'التقارير',
///   actions: [IconButton(...)],
///   body: ...,
/// )
/// ```
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.leading,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.maxContentWidth = 1400,
    this.gradientBackground = true,
    this.centerTitle = true,
    this.showAppBar = true,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? leading;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;

  /// أقصى عرض للمحتوى على الديسكتوب؛ `double.infinity` لتعطيله.
  final double maxContentWidth;
  final bool gradientBackground;
  final bool centerTitle;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canvas = isDark ? AppColors.darkCanvas : AppColors.canvas;

    Widget content = body;
    if (maxContentWidth != double.infinity) {
      content = Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: body,
        ),
      );
    }

    return Scaffold(
      backgroundColor: canvas,
      drawer: drawer,
      appBar: showAppBar
          ? AppBar(
              backgroundColor: AppColors.primaryDark,
              foregroundColor: Colors.white,
              elevation: 1,
              centerTitle: centerTitle,
              leading: leading,
              actions: actions,
              title: Column(
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            )
          : null,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      body: gradientBackground
          ? DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0, 0.35],
                  colors: [
                    AppColors.primaryDark.withValues(alpha: isDark ? 0.35 : 0.12),
                    canvas,
                  ],
                ),
              ),
              child: content,
            )
          : content,
    );
  }
}
