import 'dart:math';

import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design_system/components/adaptive_card.dart';
import '../design_system/components/metric_tile.dart';
import '../design_system/components/status_badge.dart';
import '../design_system/theme/app_theme_extensions.dart';
import '../domain/models.dart';

class ThemeLabPage extends StatefulWidget {
  const ThemeLabPage({super.key, required this.state});

  final PreviewAppState state;

  @override
  State<ThemeLabPage> createState() => _ThemeLabPageState();
}

class _ThemeLabPageState extends State<ThemeLabPage> {
  bool _abMode = false;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AdaptiveCard(
          title: 'Theme + UX Lab',
          subtitle: 'Tune role-aware variants, density, and cognitive load behavior.',
          trailing: StatusBadge(
            label: widget.state.variant.label.toUpperCase(),
            tone: StatusTone.info,
          ),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: <Widget>[
              _enumDropdown<ThemeVariant>(
                label: 'Variant',
                value: widget.state.variant,
                items: ThemeVariant.values,
                itemLabel: (ThemeVariant item) => item.label,
                onChanged: (ThemeVariant item) => widget.state.setVariant(item),
              ),
              _enumDropdown<DensityMode>(
                label: 'Density',
                value: widget.state.density,
                items: DensityMode.values,
                itemLabel: (DensityMode item) => item.label,
                onChanged: (DensityMode item) => widget.state.setDensity(item),
              ),
              _enumDropdown<WorkMode>(
                label: 'Work Mode',
                value: widget.state.workMode,
                items: WorkMode.values,
                itemLabel: (WorkMode item) => item.label,
                onChanged: (WorkMode item) => widget.state.setWorkMode(item),
              ),
              _enumDropdown<UserRole>(
                label: 'Role',
                value: widget.state.role,
                items: UserRole.values,
                itemLabel: (UserRole item) => item.label,
                onChanged: (UserRole item) => widget.state.setRole(item),
              ),
              _enumDropdown<DeviceType>(
                label: 'Device',
                value: widget.state.deviceType,
                items: DeviceType.values,
                itemLabel: (DeviceType item) => item.label,
                onChanged: (DeviceType item) => widget.state.setDeviceType(item),
              ),
              _enumDropdown<TaskComplexity>(
                label: 'Complexity',
                value: widget.state.complexity,
                items: TaskComplexity.values,
                itemLabel: (TaskComplexity item) => item.label,
                onChanged: (TaskComplexity item) => widget.state.setComplexity(item),
              ),
              _enumDropdown<RuntimeMode>(
                label: 'Runtime',
                value: widget.state.runtimeMode,
                items: RuntimeMode.values,
                itemLabel: (RuntimeMode item) => item.label,
                onChanged: (RuntimeMode item) => widget.state.setRuntimeMode(item),
              ),
              FilterChip(
                selected: _abMode,
                label: const Text('A/B compare mode'),
                onSelected: (bool value) => setState(() => _abMode = value),
              ),
              OutlinedButton.icon(
                onPressed: () => widget.state.setThemeMode(
                  widget.state.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                ),
                icon: const Icon(Icons.brightness_6),
                label: const Text('Toggle Light / Dark'),
              ),
            ],
          ),
        ),
        AdaptiveCard(
          title: 'Adaptive preview strip',
          subtitle: 'User role, task load, and density directly reshape emphasis and spacing.',
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: <Widget>[
              MetricTile(label: 'Current Role', value: widget.state.role.label, semantic: 'info'),
              MetricTile(label: 'Mode', value: widget.state.workMode.label, semantic: 'warning'),
              MetricTile(label: 'Density', value: widget.state.density.label, semantic: 'success'),
            ],
          ),
        ),
        AdaptiveCard(
          title: 'Simulated attention heatmap',
          subtitle: 'Synthetic cognitive intensity distribution for layout experimentation.',
          child: _HeatmapGrid(
            seed: widget.state.variant.index + widget.state.complexity.index * 7,
            rows: 8,
            columns: 14,
          ),
        ),
        if (_abMode)
          AdaptiveCard(
            title: 'A/B/C Variant Compare',
            subtitle: 'Quick visual deltas across variant families.',
            child: Column(
              children: ThemeVariant.values.map((ThemeVariant variant) {
                final bool active = variant == widget.state.variant;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active ? context.appColors.brand : context.appColors.surfaceAlt,
                      width: active ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${variant.label} • ${active ? 'active' : 'inactive'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => widget.state.setVariant(variant),
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _enumDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T> onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text('$label: '),
        DropdownButton<T>(
          value: value,
          onChanged: (T? next) {
            if (next == null) return;
            onChanged(next);
          },
          items: items
              .map((T item) => DropdownMenuItem<T>(value: item, child: Text(itemLabel(item))))
              .toList(),
        ),
      ],
    );
  }
}

class _HeatmapGrid extends StatelessWidget {
  const _HeatmapGrid({
    required this.seed,
    required this.rows,
    required this.columns,
  });

  final int seed;
  final int rows;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final Random random = Random(seed);
    final AppColorExtension colors = context.appColors;

    return Column(
      children: List<Widget>.generate(rows, (int row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: List<Widget>.generate(columns, (int column) {
              final double intensity = random.nextDouble();
              final Color color = Color.lerp(
                    colors.surfaceAlt,
                    colors.brand,
                    intensity,
                  )!
                  .withValues(alpha: 0.35 + intensity * 0.45);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 14,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}
