import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../theme/app_theme_extensions.dart';

class RoleTag extends StatelessWidget {
  const RoleTag({
    super.key,
    required this.role,
  });

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final AppColorExtension colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.roleAccent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.roleAccent.withValues(alpha: 0.45)),
      ),
      child: Text(
        role.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: colors.roleAccent,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
