// ignore_for_file: avoid_print

import 'dart:io';

import 'package:theme_preview/integration/diff_detector.dart';
import 'package:theme_preview/screens/screen_registry.dart';
import 'package:theme_preview/domain/models.dart';
import 'package:theme_preview/domain/screen_descriptor.dart';

void main() {
  final List<String> passes = <String>[];
  final List<String> failures = <String>[];

  void check(bool condition, String description) {
    if (condition) {
      passes.add(description);
    } else {
      failures.add(description);
    }
  }

  final Map<String, ScreenDescriptor> registryById = <String, ScreenDescriptor>{
    for (final ScreenDescriptor descriptor in ScreenRegistry.canonical)
      descriptor.id: descriptor,
  };

  const List<String> parityScreens = <String>[
    'repositories',
    'pull-requests',
    'pr-detail',
    'issues',
    'settings',
  ];
  for (final String id in parityScreens) {
    final ScreenDescriptor? descriptor = registryById[id];
    check(descriptor != null, 'Core parity screen "$id" is registered');
    if (descriptor == null) continue;
    check(descriptor.actions.isNotEmpty, 'Screen "$id" has action bindings');
    check(descriptor.dataFlow.isNotEmpty, 'Screen "$id" has data-flow mapping');
    check(
      descriptor.roles.containsAll(UserRole.values),
      'Screen "$id" is visible to viewer/operator/admin',
    );
  }

  final ScreenDescriptor? workflow = registryById['workflow-console'];
  check(workflow != null, 'Workflow console screen is registered');
  if (workflow != null) {
    check(
      !workflow.roles.contains(UserRole.viewer),
      'Workflow console is hidden from viewer role',
    );
  }

  final ScreenDescriptor? advanced = registryById['advanced-settings'];
  check(advanced != null, 'Advanced settings screen is registered');
  if (advanced != null) {
    check(
      advanced.roles.length == 1 && advanced.roles.contains(UserRole.admin),
      'Advanced settings is admin-only',
    );
  }

  final ScreenDescriptor? moderation = registryById['moderation'];
  check(moderation != null, 'Moderation screen is registered');
  if (moderation != null) {
    check(
      moderation.roles.length == 1 && moderation.roles.contains(UserRole.admin),
      'Moderation is admin-only',
    );
  }

  for (final String id in <String>[
    'permission-denied',
    'provider-misconfig',
    'offline-fallback',
    'recovery-center',
  ]) {
    check(registryById.containsKey(id), 'Error-state screen "$id" is present');
  }

  final List<DiffFinding> findings = DiffDetector().analyze();
  check(findings.isEmpty, 'Structural diff detector reports zero findings');

  print('## Parity Check Report');
  for (final String pass in passes) {
    print('- [PASS] $pass');
  }
  for (final String failure in failures) {
    print('- [FAIL] $failure');
  }

  if (findings.isNotEmpty) {
    print('\n## Diff Findings');
    for (final DiffFinding finding in findings) {
      print('- ${finding.type}: ${finding.message}');
    }
  }

  if (failures.isEmpty && findings.isEmpty) {
    print('\nStatus: PASS');
    return;
  }
  print('\nStatus: FAIL');
  exitCode = 1;
}
