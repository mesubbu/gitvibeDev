import 'package:flutter/material.dart';

import '../../domain/models.dart';

class DensityTokens {
  const DensityTokens({
    required this.visualDensity,
    required this.verticalPadding,
    required this.horizontalPadding,
    required this.tableRowHeight,
  });

  final VisualDensity visualDensity;
  final double verticalPadding;
  final double horizontalPadding;
  final double tableRowHeight;

  static DensityTokens forMode(DensityMode mode) {
    if (mode == DensityMode.compact) {
      return const DensityTokens(
        visualDensity: VisualDensity.compact,
        verticalPadding: 8,
        horizontalPadding: 10,
        tableRowHeight: 36,
      );
    }
    return const DensityTokens(
      visualDensity: VisualDensity.standard,
      verticalPadding: 12,
      horizontalPadding: 14,
      tableRowHeight: 44,
    );
  }
}
