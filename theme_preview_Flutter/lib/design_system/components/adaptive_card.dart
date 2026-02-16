import 'package:flutter/material.dart';

import '../theme/app_theme_extensions.dart';

class AdaptiveCard extends StatelessWidget {
  const AdaptiveCard({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.emphasis = false,
    this.child,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool emphasis;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final AppColorExtension colors = context.appColors;
    final AppDensityExtension density = context.appDensity;

    return Card(
      color: emphasis ? colors.surfaceAlt : colors.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: density.horizontalPadding,
          vertical: density.verticalPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: colors.foregroundMuted,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            if (child != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}
