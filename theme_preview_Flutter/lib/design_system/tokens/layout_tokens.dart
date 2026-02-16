import '../../domain/models.dart';

class LayoutTokens {
  const LayoutTokens({
    required this.spacingXs,
    required this.spacingSm,
    required this.spacingMd,
    required this.spacingLg,
    required this.spacingXl,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
  });

  final double spacingXs;
  final double spacingSm;
  final double spacingMd;
  final double spacingLg;
  final double spacingXl;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;

  static LayoutTokens forDensity(DensityMode density) {
    final double multiplier = density == DensityMode.compact ? 0.85 : 1.0;
    return LayoutTokens(
      spacingXs: 4 * multiplier,
      spacingSm: 8 * multiplier,
      spacingMd: 12 * multiplier,
      spacingLg: 16 * multiplier,
      spacingXl: 24 * multiplier,
      radiusSm: 8,
      radiusMd: 12,
      radiusLg: 18,
    );
  }
}
