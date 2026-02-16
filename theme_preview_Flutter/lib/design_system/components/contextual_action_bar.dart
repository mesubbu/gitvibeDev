import 'package:flutter/material.dart';

class ContextualActionBar extends StatelessWidget {
  const ContextualActionBar({
    super.key,
    required this.actions,
  });

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions,
    );
  }
}
