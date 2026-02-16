import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.semantic = 'info',
  });

  final String label;
  final String value;
  final String? delta;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    final AppColorExtension colors = context.appColors;
    final Color semanticColor = switch (semantic) {
      'success' => colors.success,
      'warning' => colors.warning,
      'danger' => colors.danger,
      _ => colors.info,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.surfaceAlt),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.foregroundMuted)),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
          if (delta != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                delta!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: semanticColor),
              ),
            ),
        ],
      ),
    );
  }
}
