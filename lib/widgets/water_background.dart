import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// A subtle, reusable water-inspired background that keeps screen content legible.
class WaterBackground extends StatelessWidget {
  const WaterBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? const [
                      Color(0xFF0B1420),
                      AppColors.darkCanvas,
                      Color(0xFF0A1626),
                    ]
                  : const [
                      Color(0xFFF8FCFF),
                      AppColors.canvas,
                      Color(0xFFEAF4FB),
                    ],
            ),
          ),
        ),
        Positioned(
          top: 120,
          right: -85,
          child: _GlowCircle(
              size: 250,
              color: AppColors.primaryLightest
                  .withValues(alpha: isDark ? 0.10 : 0.28)),
        ),
        Positioned(
          top: 380,
          left: -75,
          child: _GlowCircle(
              size: 200,
              color: const Color(0xFFB9EDE3)
                  .withValues(alpha: isDark ? 0.08 : 0.35)),
        ),
        Positioned(
          bottom: -110,
          right: -25,
          child: _GlowCircle(
              size: 290,
              color: AppColors.primaryLightest
                  .withValues(alpha: isDark ? 0.10 : 0.30)),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (isDark ? AppColors.darkCanvas : Colors.white)
                      .withValues(alpha: 0.52),
                ],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.elliptical(420, 105)),
            ),
          ),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 55, spreadRadius: 12)],
      ),
    );
  }
}
