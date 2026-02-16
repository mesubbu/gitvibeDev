import 'dart:ui';

import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../tokens/color_tokens.dart';

@immutable
class AppColorExtension extends ThemeExtension<AppColorExtension> {
  const AppColorExtension({
    required this.brand,
    required this.brandStrong,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.foreground,
    required this.foregroundMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.roleAccent,
  });

  final Color brand;
  final Color brandStrong;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color foreground;
  final Color foregroundMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color roleAccent;

  factory AppColorExtension.fromTokens(ColorTokens tokens) {
    return AppColorExtension(
      brand: tokens.brand,
      brandStrong: tokens.brandStrong,
      background: tokens.background,
      surface: tokens.surface,
      surfaceAlt: tokens.surfaceAlt,
      foreground: tokens.foreground,
      foregroundMuted: tokens.foregroundMuted,
      success: tokens.success,
      warning: tokens.warning,
      danger: tokens.danger,
      info: tokens.info,
      roleAccent: tokens.roleAccent,
    );
  }

  static AppColorExtension fallback(Brightness brightness) {
    return AppColorExtension.fromTokens(
      ColorTokens.forContext(
        variant: ThemeVariant.variantA,
        brightness: brightness,
        workMode: WorkMode.review,
        role: UserRole.operator,
      ),
    );
  }

  @override
  AppColorExtension copyWith({
    Color? brand,
    Color? brandStrong,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? foreground,
    Color? foregroundMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? roleAccent,
  }) {
    return AppColorExtension(
      brand: brand ?? this.brand,
      brandStrong: brandStrong ?? this.brandStrong,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      foreground: foreground ?? this.foreground,
      foregroundMuted: foregroundMuted ?? this.foregroundMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
      roleAccent: roleAccent ?? this.roleAccent,
    );
  }

  @override
  ThemeExtension<AppColorExtension> lerp(covariant ThemeExtension<AppColorExtension>? other, double t) {
    if (other is! AppColorExtension) return this;
    return AppColorExtension(
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      foreground: Color.lerp(foreground, other.foreground, t)!,
      foregroundMuted: Color.lerp(foregroundMuted, other.foregroundMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      roleAccent: Color.lerp(roleAccent, other.roleAccent, t)!,
    );
  }
}

@immutable
class AppDensityExtension extends ThemeExtension<AppDensityExtension> {
  const AppDensityExtension({
    required this.compact,
    required this.verticalPadding,
    required this.horizontalPadding,
    required this.tableRowHeight,
  });

  final bool compact;
  final double verticalPadding;
  final double horizontalPadding;
  final double tableRowHeight;

  @override
  AppDensityExtension copyWith({
    bool? compact,
    double? verticalPadding,
    double? horizontalPadding,
    double? tableRowHeight,
  }) {
    return AppDensityExtension(
      compact: compact ?? this.compact,
      verticalPadding: verticalPadding ?? this.verticalPadding,
      horizontalPadding: horizontalPadding ?? this.horizontalPadding,
      tableRowHeight: tableRowHeight ?? this.tableRowHeight,
    );
  }

  @override
  ThemeExtension<AppDensityExtension> lerp(covariant ThemeExtension<AppDensityExtension>? other, double t) {
    if (other is! AppDensityExtension) return this;
    return AppDensityExtension(
      compact: t < 0.5 ? compact : other.compact,
      verticalPadding: lerpDouble(verticalPadding, other.verticalPadding, t)!,
      horizontalPadding: lerpDouble(horizontalPadding, other.horizontalPadding, t)!,
      tableRowHeight: lerpDouble(tableRowHeight, other.tableRowHeight, t)!,
    );
  }
}

@immutable
class AppMotionExtension extends ThemeExtension<AppMotionExtension> {
  const AppMotionExtension({
    required this.fast,
    required this.regular,
    required this.slow,
  });

  final Duration fast;
  final Duration regular;
  final Duration slow;

  @override
  AppMotionExtension copyWith({Duration? fast, Duration? regular, Duration? slow}) {
    return AppMotionExtension(
      fast: fast ?? this.fast,
      regular: regular ?? this.regular,
      slow: slow ?? this.slow,
    );
  }

  @override
  ThemeExtension<AppMotionExtension> lerp(covariant ThemeExtension<AppMotionExtension>? other, double t) {
    if (other is! AppMotionExtension) return this;
    return AppMotionExtension(
      fast: Duration(milliseconds: lerpDouble(fast.inMilliseconds.toDouble(), other.fast.inMilliseconds.toDouble(), t)!.round()),
      regular: Duration(milliseconds: lerpDouble(regular.inMilliseconds.toDouble(), other.regular.inMilliseconds.toDouble(), t)!.round()),
      slow: Duration(milliseconds: lerpDouble(slow.inMilliseconds.toDouble(), other.slow.inMilliseconds.toDouble(), t)!.round()),
    );
  }
}

@immutable
class AppContextExtension extends ThemeExtension<AppContextExtension> {
  const AppContextExtension({
    required this.variant,
    required this.density,
    required this.workMode,
    required this.role,
    required this.deviceType,
    required this.complexity,
  });

  final ThemeVariant variant;
  final DensityMode density;
  final WorkMode workMode;
  final UserRole role;
  final DeviceType deviceType;
  final TaskComplexity complexity;

  @override
  AppContextExtension copyWith({
    ThemeVariant? variant,
    DensityMode? density,
    WorkMode? workMode,
    UserRole? role,
    DeviceType? deviceType,
    TaskComplexity? complexity,
  }) {
    return AppContextExtension(
      variant: variant ?? this.variant,
      density: density ?? this.density,
      workMode: workMode ?? this.workMode,
      role: role ?? this.role,
      deviceType: deviceType ?? this.deviceType,
      complexity: complexity ?? this.complexity,
    );
  }

  @override
  ThemeExtension<AppContextExtension> lerp(covariant ThemeExtension<AppContextExtension>? other, double t) {
    if (other is! AppContextExtension) return this;
    return AppContextExtension(
      variant: t < 0.5 ? variant : other.variant,
      density: t < 0.5 ? density : other.density,
      workMode: t < 0.5 ? workMode : other.workMode,
      role: t < 0.5 ? role : other.role,
      deviceType: t < 0.5 ? deviceType : other.deviceType,
      complexity: t < 0.5 ? complexity : other.complexity,
    );
  }
}

extension ThemeLookup on BuildContext {
  AppColorExtension get appColors =>
      Theme.of(this).extension<AppColorExtension>() ?? AppColorExtension.fallback(Theme.of(this).brightness);

  AppDensityExtension get appDensity => Theme.of(this).extension<AppDensityExtension>() ??
      const AppDensityExtension(compact: false, verticalPadding: 12, horizontalPadding: 14, tableRowHeight: 44);

  AppMotionExtension get appMotion => Theme.of(this).extension<AppMotionExtension>() ??
      const AppMotionExtension(
        fast: Duration(milliseconds: 120),
        regular: Duration(milliseconds: 200),
        slow: Duration(milliseconds: 300),
      );

  AppContextExtension get appContext => Theme.of(this).extension<AppContextExtension>() ??
      const AppContextExtension(
        variant: ThemeVariant.variantA,
        density: DensityMode.comfortable,
        workMode: WorkMode.review,
        role: UserRole.operator,
        deviceType: DeviceType.desktop,
        complexity: TaskComplexity.medium,
      );
}
