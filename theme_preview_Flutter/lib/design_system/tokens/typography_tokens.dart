import 'package:flutter/material.dart';

import '../../domain/models.dart';

class TypographyTokens {
  const TypographyTokens({required this.textTheme});

  final TextTheme textTheme;

  static TypographyTokens forContext({
    required DeviceType deviceType,
    required DensityMode density,
  }) {
    final double baseScale = switch (deviceType) {
      DeviceType.mobile => 0.95,
      DeviceType.tablet => 1.0,
      DeviceType.desktop => 1.05,
    };

    final double densityScale = density == DensityMode.compact ? 0.94 : 1.0;
    final double scale = baseScale * densityScale;

    return TypographyTokens(
      textTheme: TextTheme(
        displaySmall: TextStyle(fontSize: 34 * scale, fontWeight: FontWeight.w700, letterSpacing: -0.5),
        headlineMedium: TextStyle(fontSize: 24 * scale, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(fontSize: 20 * scale, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(fontSize: 16 * scale, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 15 * scale, fontWeight: FontWeight.w400, height: 1.45),
        bodyMedium: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: TextStyle(fontSize: 13 * scale, fontWeight: FontWeight.w600, letterSpacing: 0.15),
      ),
    );
  }
}
