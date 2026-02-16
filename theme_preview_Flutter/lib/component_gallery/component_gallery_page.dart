import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../design_system/components/adaptive_card.dart';
import '../design_system/components/contextual_action_bar.dart';
import '../design_system/components/metric_tile.dart';
import '../design_system/components/role_tag.dart';
import '../design_system/components/status_badge.dart';

class ComponentGalleryPage extends StatelessWidget {
  const ComponentGalleryPage({super.key, required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        AdaptiveCard(
          title: 'Contextual Component Gallery',
          subtitle: 'Component examples mapped to real SaaS use-cases.',
          trailing: RoleTag(role: state.role),
          child: const Text(
            'Each composition demonstrates variants and states under operational contexts '
            '(review, governance, incidents, and recovery).',
          ),
        ),
        AdaptiveCard(
          title: 'Use Case: PR Triage Header',
          subtitle: 'Use Case → Component → Variants → States',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: const <Widget>[
                  StatusBadge(label: 'OPEN', tone: StatusTone.info),
                  StatusBadge(label: 'CHECKS PASSING', tone: StatusTone.success),
                  StatusBadge(label: 'RISK MEDIUM', tone: StatusTone.warning),
                ],
              ),
              const SizedBox(height: 12),
              const ContextualActionBar(
                actions: <Widget>[
                  FilledButton(onPressed: null, child: Text('Merge')),
                  OutlinedButton(onPressed: null, child: Text('Run AI Review')),
                  OutlinedButton(onPressed: null, child: Text('Open Issue Context')),
                ],
              ),
            ],
          ),
        ),
        AdaptiveCard(
          title: 'Use Case: Operations Dashboard Metrics',
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.8,
            physics: const NeverScrollableScrollPhysics(),
            children: const <Widget>[
              MetricTile(label: 'Open PRs', value: '24', delta: '+3 today', semantic: 'info'),
              MetricTile(label: 'Merged', value: '16', delta: '+11%', semantic: 'success'),
              MetricTile(label: 'Failed Jobs', value: '2', delta: 'Needs recovery', semantic: 'warning'),
              MetricTile(label: 'Policy Drift', value: '1', delta: 'Critical', semantic: 'danger'),
            ],
          ),
        ),
        AdaptiveCard(
          title: 'Use Case: Incident Governance Panel',
          emphasis: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  StatusBadge(label: 'SEV-2', tone: StatusTone.danger),
                  SizedBox(width: 8),
                  StatusBadge(label: 'POLICY', tone: StatusTone.warning),
                  SizedBox(width: 8),
                  StatusBadge(label: 'AUDIT REQUIRED', tone: StatusTone.info),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'A plugin attempted execution outside allowlist scope. '
                'Containment controls are available below.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const ContextualActionBar(
                actions: <Widget>[
                  FilledButton(onPressed: null, child: Text('Disable Plugin')),
                  OutlinedButton(onPressed: null, child: Text('Rotate Signing Key')),
                  OutlinedButton(onPressed: null, child: Text('Open Audit Trail')),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
