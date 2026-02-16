import 'models.dart';

enum ScreenClass {
  core,
  secondary,
  adminPower,
  supportSystem,
  edgeException,
  lab,
}

extension ScreenClassX on ScreenClass {
  String get label {
    switch (this) {
      case ScreenClass.core:
        return 'Core';
      case ScreenClass.secondary:
        return 'Secondary';
      case ScreenClass.adminPower:
        return 'Admin / Power';
      case ScreenClass.supportSystem:
        return 'Support / System';
      case ScreenClass.edgeException:
        return 'Edge / Exception';
      case ScreenClass.lab:
        return 'Lab';
    }
  }
}

class ScreenDescriptor {
  const ScreenDescriptor({
    required this.id,
    required this.title,
    required this.summary,
    required this.classification,
    required this.roles,
    required this.actions,
    required this.dataFlow,
    this.tags = const <String>[],
  });

  final String id;
  final String title;
  final String summary;
  final ScreenClass classification;
  final Set<UserRole> roles;
  final List<String> actions;
  final List<String> dataFlow;
  final List<String> tags;

  bool visibleTo(UserRole role) => roles.contains(role);
}
