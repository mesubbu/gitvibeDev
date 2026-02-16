import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../tokens/color_tokens.dart';
import '../tokens/density_tokens.dart';
import '../tokens/layout_tokens.dart';
import '../tokens/motion_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'app_theme_extensions.dart';

class AppThemeEngine {
  static ThemeData build({
    required Brightness brightness,
    required ThemeVariant variant,
    required DensityMode density,
    required WorkMode workMode,
    required UserRole role,
    required DeviceType deviceType,
    required TaskComplexity complexity,
  }) {
    final ColorTokens colors = ColorTokens.forContext(
      variant: variant,
      brightness: brightness,
      workMode: workMode,
      role: role,
    );
    final TypographyTokens typography = TypographyTokens.forContext(
      deviceType: deviceType,
      density: density,
    );
    final LayoutTokens layout = LayoutTokens.forDensity(density);
    final DensityTokens densityTokens = DensityTokens.forMode(density);
    final MotionTokens motion = MotionTokens.forComplexity(complexity);

    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: colors.brand,
      brightness: brightness,
    ).copyWith(
      primary: colors.brand,
      secondary: colors.info,
      error: colors.danger,
      surface: colors.surface,
      onSurface: colors.foreground,
      onPrimary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: densityTokens.visualDensity,
      scaffoldBackgroundColor: colors.background,
      cardColor: colors.surface,
      textTheme: typography.textTheme.apply(
        bodyColor: colors.foreground,
        displayColor: colors.foreground,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.surface,
        foregroundColor: colors.foreground,
        centerTitle: false,
        elevation: 0,
        titleTextStyle: typography.textTheme.titleLarge?.copyWith(color: colors.foreground),
      ),
      chipTheme: ChipThemeData(
        side: BorderSide(color: colors.surfaceAlt),
        backgroundColor: colors.surfaceAlt,
        labelStyle: typography.textTheme.labelLarge?.copyWith(color: colors.foreground),
        selectedColor: colors.brand.withValues(alpha: 0.2),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(layout.radiusMd),
          side: BorderSide(color: colors.surfaceAlt),
        ),
        margin: EdgeInsets.all(layout.spacingSm),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(layout.radiusSm),
          borderSide: BorderSide(color: colors.surfaceAlt),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppColorExtension.fromTokens(colors),
        AppDensityExtension(
          compact: density == DensityMode.compact,
          verticalPadding: densityTokens.verticalPadding,
          horizontalPadding: densityTokens.horizontalPadding,
          tableRowHeight: densityTokens.tableRowHeight,
        ),
        AppMotionExtension(
          fast: Duration(milliseconds: motion.fastMs),
          regular: Duration(milliseconds: motion.regularMs),
          slow: Duration(milliseconds: motion.slowMs),
        ),
        AppContextExtension(
          variant: variant,
          density: density,
          workMode: workMode,
          role: role,
          deviceType: deviceType,
          complexity: complexity,
        ),
      ],
    );
  }
}
