import 'package:flutter/material.dart';

import '../../domain/models.dart';

class ColorTokens {
  const ColorTokens({
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

  static ColorTokens forContext({
    required ThemeVariant variant,
    required Brightness brightness,
    required WorkMode workMode,
    required UserRole role,
  }) {
    final bool dark = brightness == Brightness.dark;

    Color brand;
    Color brandStrong;
    Color surface;
    Color surfaceAlt;

    switch (variant) {
      case ThemeVariant.variantA:
        brand = const Color(0xFF4F8CFF);
        brandStrong = const Color(0xFF2566E8);
        surface = dark ? const Color(0xFF151A23) : const Color(0xFFFFFFFF);
        surfaceAlt = dark ? const Color(0xFF1D2430) : const Color(0xFFF7F9FD);
      case ThemeVariant.variantB:
        brand = const Color(0xFF2EC4B6);
        brandStrong = const Color(0xFF149A8E);
        surface = dark ? const Color(0xFF111A1C) : const Color(0xFFF9FFFE);
        surfaceAlt = dark ? const Color(0xFF182429) : const Color(0xFFEFFFFC);
      case ThemeVariant.variantC:
        brand = const Color(0xFFB784F7);
        brandStrong = const Color(0xFF8A59D6);
        surface = dark ? const Color(0xFF171322) : const Color(0xFFFCFAFF);
        surfaceAlt = dark ? const Color(0xFF201A2D) : const Color(0xFFF4EEFF);
    }

    final Color background = dark ? const Color(0xFF0E1117) : const Color(0xFFF2F4F8);
    final Color foreground = dark ? const Color(0xFFE7EBF1) : const Color(0xFF1B2430);
    final Color muted = dark ? const Color(0xFFA4AFBF) : const Color(0xFF5F6B7A);

    final Color roleAccent = switch (role) {
      UserRole.viewer => const Color(0xFF5D8BF4),
      UserRole.operator => const Color(0xFF2FBF71),
      UserRole.admin => const Color(0xFFF06449),
    };

    final Color focusBoost = workMode == WorkMode.focus
        ? (dark ? const Color(0xFFEAF2FF) : const Color(0xFF13213A))
        : foreground;

    return ColorTokens(
      brand: brand,
      brandStrong: brandStrong,
      background: background,
      surface: surface,
      surfaceAlt: surfaceAlt,
      foreground: focusBoost,
      foregroundMuted: muted,
      success: const Color(0xFF2FBF71),
      warning: const Color(0xFFF5A524),
      danger: const Color(0xFFF06449),
      info: brand,
      roleAccent: roleAccent,
    );
  }
}
