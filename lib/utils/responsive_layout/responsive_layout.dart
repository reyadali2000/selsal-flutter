import 'package:flutter/material.dart';
import 'dimensions.dart';

/// يختار الواجهة المناسبة حسب عرض المساحة المتاحة.
///
/// - [mobileBody]: أقل من [mobileWidth].
/// - [tabletBody]: اختياري، بين [mobileWidth] و [desktopWidth].
///   إذا لم يُمرَّر تُستخدم [desktopBody].
/// - [desktopBody]: من [desktopWidth] فأكثر.
class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget? tabletBody;
  final Widget desktopBody;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    this.tabletBody,
    required this.desktopBody,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < mobileWidth;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= mobileWidth && w < desktopWidth;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < mobileWidth) return mobileBody;
        if (width < desktopWidth && tabletBody != null) return tabletBody!;
        return desktopBody;
      },
    );
  }
}
