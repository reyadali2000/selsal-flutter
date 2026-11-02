import 'package:flutter/material.dart';

import '../utils/vvk_ui_kit/src/core/theme/ui_component_themes.dart';
import 'app_colors.dart';

/// الثيم الموحّد للتطبيق.
///
/// يجمع إعدادات Material الأساسية + امتدادات مكتبة vvk_ui_kit
/// (الأزرار، الحقول، الزجاج، البطاقات) بألوان [AppColors] وخط Tajawal،
/// مع دعم احترافي عالي التباين والأناقة للوضع الليلي (Dark Mode).
abstract final class AppTheme {
  static const String fontFamily = 'Tajawal';

  // ===== مقاسات موحّدة (Design Tokens) =====
  static const double radiusSm = 10;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double controlHeight = 52;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.surface;
    final border = isDark ? AppColors.darkBorder : AppColors.border;
    final primary = isDark ? AppColors.darkPrimary : AppColors.primaryDark;
    final primaryLight = isDark ? AppColors.darkPrimaryLight : AppColors.primaryMedium;
    final textColor = isDark ? AppColors.darkInk : AppColors.ink;
    final mutedColor = isDark ? AppColors.darkMuted : AppColors.muted;

    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: AppColors.darkPrimary,
            onPrimary: Colors.white,
            primaryContainer: AppColors.darkPrimaryDark,
            onPrimaryContainer: Color(0xFFE0F2FE),
            secondary: AppColors.darkPrimaryLight,
            onSecondary: Color(0xFF082F49),
            secondaryContainer: Color(0xFF1E2B3E),
            onSecondaryContainer: Color(0xFFBAE6FD),
            surface: AppColors.darkSurface,
            onSurface: AppColors.darkInk,
            error: AppColors.darkDanger,
            onError: Colors.white,
            outline: AppColors.darkBorder,
            outlineVariant: Color(0xFF1E2738),
          )
        : ColorScheme.fromSeed(
            seedColor: AppColors.primaryDark,
            brightness: Brightness.light,
            surface: surface,
          );

    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? AppColors.darkInk : Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDark ? AppColors.darkInk : Colors.white,
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkInk : Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        contentTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          color: mutedColor,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: isDark ? 2 : 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          side: BorderSide(color: primaryLight, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          textStyle: const TextStyle(fontFamily: fontFamily, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? const Color(0xFF1E2B3E) : const Color(0xFFF1F5F9),
        selectedColor: primary,
        labelStyle: TextStyle(
          fontFamily: fontFamily,
          color: textColor,
        ),
        secondaryLabelStyle: const TextStyle(
          fontFamily: fontFamily,
          color: Colors.white,
        ),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(fontFamily: fontFamily, color: textColor),
        displayMedium: TextStyle(fontFamily: fontFamily, color: textColor),
        displaySmall: TextStyle(fontFamily: fontFamily, color: textColor),
        headlineLarge: TextStyle(fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
        headlineMedium: TextStyle(fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
        headlineSmall: TextStyle(fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
        titleSmall: TextStyle(fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
        bodyLarge: TextStyle(fontFamily: fontFamily, color: textColor),
        bodyMedium: TextStyle(fontFamily: fontFamily, color: textColor),
        bodySmall: TextStyle(fontFamily: fontFamily, color: mutedColor),
        labelLarge: TextStyle(fontFamily: fontFamily, color: textColor, fontWeight: FontWeight.bold),
        labelMedium: TextStyle(fontFamily: fontFamily, color: mutedColor),
        labelSmall: TextStyle(fontFamily: fontFamily, color: mutedColor),
      ),
      iconTheme: IconThemeData(
        color: textColor,
        size: 22,
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: _inputDecorationTheme(isDark, surface, border, primaryLight, textColor, mutedColor),

      // ===== امتدادات vvk_ui_kit =====
      extensions: const <ThemeExtension<dynamic>>[
        UIButtonTheme(
          borderRadius: radiusMd,
          height: controlHeight,
          primaryHeight: controlHeight,
          primaryRadius: radiusMd,
          outlinedHeight: controlHeight,
          outlinedRadius: radiusMd,
          elevatedHeight: controlHeight,
          elevatedRadius: radiusMd,
          textHeight: 44,
          textRadius: radiusSm,
        ),
        UIInputTheme(
          borderRadius: radiusMd,
          borderWidth: 1,
          focusedBorderWidth: 1.5,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        ),
        UIGlassMetrics(
          blur: 12,
          tintOpacity: 0.14,
          borderRadius: radiusLg,
          borderWidth: 1,
          performanceMode: UIGlassPerformanceMode.auto,
          wrapInRepaintBoundary: true,
        ),
      ],
    );
  }

  static InputDecorationTheme _inputDecorationTheme(
    bool isDark,
    Color surface,
    Color border,
    Color primaryLight,
    Color textColor,
    Color mutedColor,
  ) {
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkSurfaceElevated : surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      hintStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        color: mutedColor,
      ),
      labelStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        color: mutedColor,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: primaryLight, width: 1.5),
      ),
    );
  }
}
