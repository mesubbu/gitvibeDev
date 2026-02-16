import '../domain/feature_map.dart';
import '../screens/screen_registry.dart';

class DiffFinding {
  const DiffFinding({required this.type, required this.message});

  final String type;
  final String message;
}

class DiffDetector {
  List<DiffFinding> analyze() {
    final List<DiffFinding> findings = <DiffFinding>[];
    final Set<String> implemented = ScreenRegistry.expectedScreenIds;
    final Set<String> expected = _expectedFromFeatureMap();

    for (final String missing in expected.difference(implemented)) {
      findings.add(DiffFinding(
          type: 'missing-screen',
          message: 'Expected screen missing: $missing'));
    }
    for (final String extra in implemented.difference(expected)) {
      findings.add(DiffFinding(
          type: 'extra-screen',
          message: 'Unmapped screen in feature map: $extra'));
    }

    for (final descriptor in ScreenRegistry.canonical) {
      if (descriptor.actions.isEmpty) {
        findings.add(
          DiffFinding(
            type: 'missing-action-binding',
            message:
                'Screen ${descriptor.id} does not expose any mapped actions.',
          ),
        );
      }
      if (descriptor.dataFlow.isEmpty) {
        findings.add(
          DiffFinding(
            type: 'model-field-drift',
            message: 'Screen ${descriptor.id} has no data flow mapping.',
          ),
        );
      }
    }

    return findings;
  }

  Set<String> _expectedFromFeatureMap() {
    final Set<String> ids = <String>{};
    for (final FeatureMapRow row in inferredFeatureMap) {
      for (final String screen in row.screens) {
        final String normalized = _normalizeScreenName(screen);
        if (normalized.isNotEmpty) {
          ids.add(normalized);
        }
      }
    }
    return ids;
  }

  String _normalizeScreenName(String input) {
    final String key = input.trim().toLowerCase();
    const Map<String, String> map = <String, String>{
      'dashboard': 'dashboard',
      'repositories': 'repositories',
      'pull requests': 'pull-requests',
      'pr detail': 'pr-detail',
      'issues': 'issues',
      'settings': 'settings',
      'onboarding': 'onboarding',
      'notifications': 'notifications',
      'activity timeline': 'activity-log',
      'analytics overview': 'analytics',
      'advanced settings': 'advanced-settings',
      'moderation': 'moderation',
      'workflow console': 'workflow-console',
      'system health': 'system-health',
      'audit signals': 'audit-signals',
      'recovery center': 'recovery-center',
      'permission denied': 'permission-denied',
      'provider misconfiguration': 'provider-misconfig',
      'offline fallback': 'offline-fallback',
      'workflow demos': 'workflow-demos',
      'component gallery': 'component-gallery',
      'theme lab': 'theme-lab',
    };
    return map[key] ?? '';
  }

  String toMarkdownReport() {
    final List<DiffFinding> findings = analyze();
    if (findings.isEmpty) {
      return 'No structural diffs detected between inferred feature map and screen registry.';
    }
    final StringBuffer buffer = StringBuffer();
    buffer.writeln('## Diff Findings');
    for (final DiffFinding finding in findings) {
      buffer.writeln('- `${finding.type}`: ${finding.message}');
    }
    return buffer.toString();
  }
}
