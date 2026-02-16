import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design_system/components/adaptive_card.dart';
import '../design_system/components/contextual_action_bar.dart';
import '../design_system/components/status_badge.dart';
import '../domain/models.dart';

class WorkflowSimulatorPage extends StatefulWidget {
  const WorkflowSimulatorPage({super.key, required this.state});

  final PreviewAppState state;

  @override
  State<WorkflowSimulatorPage> createState() => _WorkflowSimulatorPageState();
}

class _WorkflowSimulatorPageState extends State<WorkflowSimulatorPage> {
  late List<WorkflowScenario> _scenarios;
  String? _selectedScenarioId;
  bool _simulateFailure = false;

  @override
  void initState() {
    super.initState();
    _scenarios = widget.state.repository.listWorkflowScenarios();
    _selectedScenarioId = _scenarios.isNotEmpty ? _scenarios.first.id : null;
  }

  @override
  Widget build(BuildContext context) {
    final WorkflowScenario? scenario = _scenarios.where((WorkflowScenario item) => item.id == _selectedScenarioId).firstOrNull;
    if (scenario == null) {
      return const Center(child: Text('No workflow scenarios available.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AdaptiveCard(
          title: 'Workflow Scenario Simulator',
          subtitle: 'Run inferred end-to-end journeys with failure and density stress simulation.',
          trailing: StatusBadge(label: widget.state.runtimeMode.label.toUpperCase(), tone: StatusTone.info),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              DropdownButton<String>(
                value: _selectedScenarioId,
                onChanged: (String? value) => setState(() => _selectedScenarioId = value),
                items: _scenarios
                    .map((WorkflowScenario item) => DropdownMenuItem<String>(
                          value: item.id,
                          child: Text('${item.name} (${item.persona})'),
                        ))
                    .toList(),
              ),
              FilterChip(
                label: const Text('Simulate failure mode'),
                selected: _simulateFailure,
                onSelected: (bool value) => setState(() => _simulateFailure = value),
              ),
              FilledButton.icon(
                onPressed: () => setState(() {
                  _simulateFailure = !_simulateFailure;
                }),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Replay Scenario'),
              ),
            ],
          ),
        ),
        AdaptiveCard(
          title: scenario.name,
          subtitle: 'Persona: ${scenario.persona} • Data density: ${scenario.heavyDataPoints} records',
          emphasis: true,
          child: Column(
            children: scenario.steps.map((WorkflowStep step) {
              final StatusTone tone = _toneForStep(step.state, _simulateFailure);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    StatusBadge(label: step.state.name.toUpperCase(), tone: tone),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(step.label, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(step.description, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        AdaptiveCard(
          title: 'Recovery Guidance',
          subtitle: _simulateFailure
              ? 'Failure simulation enabled. Follow the fallback workflow.'
              : 'Nominal path active. No intervention required.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(scenario.recoveryHint),
              const SizedBox(height: 12),
              ContextualActionBar(
                actions: <Widget>[
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Last Failed Step'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Apply Smart Defaults'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.description),
                    label: const Text('Open Runbook'),
                  ),
                ],
              ),
            ],
          ),
        ),
        AdaptiveCard(
          title: 'Performance-heavy preview',
          subtitle: 'Synthetic dense rows to validate compact vs comfortable readability.',
          child: SizedBox(
            height: 280,
            child: ListView.builder(
              itemCount: scenario.heavyDataPoints.clamp(40, 220),
              itemBuilder: (BuildContext context, int index) {
                final bool warning = index % 17 == 0;
                return ListTile(
                  dense: widget.state.density == DensityMode.compact,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: StatusBadge(
                    label: warning ? 'RISK' : 'OK',
                    tone: warning ? StatusTone.warning : StatusTone.success,
                  ),
                  title: Text('Synthetic row ${index + 1} • workflow trace segment'),
                  subtitle: Text('Latency ${120 + (index % 9) * 16}ms • actor pipeline-${index % 5}'),
                  trailing: Text('#${9000 + index}'),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  StatusTone _toneForStep(WorkflowStepState state, bool forceFailure) {
    if (forceFailure && state == WorkflowStepState.inProgress) {
      return StatusTone.danger;
    }
    return switch (state) {
      WorkflowStepState.pending => StatusTone.neutral,
      WorkflowStepState.inProgress => StatusTone.info,
      WorkflowStepState.completed => StatusTone.success,
      WorkflowStepState.failed => StatusTone.danger,
    };
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
