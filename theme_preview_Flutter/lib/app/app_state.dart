import 'package:flutter/material.dart';

import '../data/gitvibe_repository.dart';
import '../domain/models.dart';
import '../runtime/runtime_factory.dart';

class PreviewAppState extends ChangeNotifier {
  PreviewAppState._({
    required this.repository,
    required this.configuredRuntimeMode,
  });

  static const String _themeModeKey = 'theme_preview.theme_mode';
  static const String _runtimeModeKey = 'theme_preview.runtime_mode';
  static const String _variantKey = 'theme_preview.variant';
  static const String _densityKey = 'theme_preview.density';
  static const String _workModeKey = 'theme_preview.work_mode';
  static const String _deviceTypeKey = 'theme_preview.device_type';
  static const String _complexityKey = 'theme_preview.complexity';
  static const String _roleKey = 'theme_preview.role';
  static const String _activeScreenKey = 'theme_preview.active_screen';
  static const String _contextPanelKey = 'theme_preview.context_panel';

  final GitVibeRepository repository;
  final RuntimeMode configuredRuntimeMode;

  ThemeMode themeMode = ThemeMode.dark;
  RuntimeMode runtimeMode = RuntimeMode.demo;
  ThemeVariant variant = ThemeVariant.variantA;
  DensityMode density = DensityMode.comfortable;
  WorkMode workMode = WorkMode.review;
  DeviceType deviceType = DeviceType.desktop;
  TaskComplexity complexity = TaskComplexity.medium;
  UserRole role = UserRole.operator;
  String activeScreenId = 'dashboard';
  String? selectedRepositoryKey;
  int? selectedPullNumber;
  bool showContextPanel = true;

  static Future<PreviewAppState> bootstrap() async {
    final RuntimeContext runtimeContext = await RuntimeFactory.create();
    final PreviewAppState state = PreviewAppState._(
      repository: runtimeContext.repository,
      configuredRuntimeMode: runtimeContext.config.appMode,
    );
    state._restorePreferences();
    if (runtimeContext.config.appMode != RuntimeMode.demo &&
        runtimeContext.authSession.role.isNotEmpty) {
      state.role = state._parseRole(runtimeContext.authSession.role);
    }
    return state;
  }

  void _restorePreferences() {
    final prefs = repository.preferences;
    themeMode = _parseThemeMode(prefs.getString(_themeModeKey));
    runtimeMode = configuredRuntimeMode == RuntimeMode.demo
        ? _parseRuntimeMode(
            prefs.getString(_runtimeModeKey),
            fallback: RuntimeMode.demo,
          )
        : configuredRuntimeMode;
    variant = _parseVariant(prefs.getString(_variantKey));
    density = _parseDensity(prefs.getString(_densityKey));
    workMode = _parseWorkMode(prefs.getString(_workModeKey));
    deviceType = _parseDeviceType(prefs.getString(_deviceTypeKey));
    complexity = _parseComplexity(prefs.getString(_complexityKey));
    role = _parseRole(prefs.getString(_roleKey));
    activeScreenId = prefs.getString(_activeScreenKey) ?? activeScreenId;
    showContextPanel = prefs.getBool(_contextPanelKey) ?? true;
  }

  Future<void> _persist() async {
    final prefs = repository.preferences;
    await prefs.setString(_themeModeKey, themeMode.name);
    await prefs.setString(_runtimeModeKey, runtimeMode.name);
    await prefs.setString(_variantKey, variant.name);
    await prefs.setString(_densityKey, density.name);
    await prefs.setString(_workModeKey, workMode.name);
    await prefs.setString(_deviceTypeKey, deviceType.name);
    await prefs.setString(_complexityKey, complexity.name);
    await prefs.setString(_roleKey, role.name);
    await prefs.setString(_activeScreenKey, activeScreenId);
    await prefs.setBool(_contextPanelKey, showContextPanel);
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setRuntimeMode(RuntimeMode value) async {
    runtimeMode = configuredRuntimeMode == RuntimeMode.demo
        ? value
        : configuredRuntimeMode;
    await _persist();
    notifyListeners();
  }

  Future<void> setVariant(ThemeVariant value) async {
    variant = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setDensity(DensityMode value) async {
    density = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setWorkMode(WorkMode value) async {
    workMode = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setDeviceType(DeviceType value) async {
    deviceType = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setComplexity(TaskComplexity value) async {
    complexity = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setRole(UserRole value) async {
    role = value;
    await _persist();
    notifyListeners();
  }

  Future<void> setActiveScreen(String screenId) async {
    activeScreenId = screenId;
    await _persist();
    notifyListeners();
  }

  Future<void> toggleContextPanel() async {
    showContextPanel = !showContextPanel;
    await _persist();
    notifyListeners();
  }

  Future<void> selectRepository(String repositoryKey) async {
    selectedRepositoryKey = repositoryKey;
    selectedPullNumber = null;
    notifyListeners();
  }

  Future<void> selectPullRequest(int pullNumber) async {
    selectedPullNumber = pullNumber;
    notifyListeners();
  }

  ThemeMode _parseThemeMode(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.dark;
    }
  }

  RuntimeMode _parseRuntimeMode(
    String? value, {
    required RuntimeMode fallback,
  }) {
    return RuntimeMode.values.firstWhere(
      (RuntimeMode mode) => mode.name == value,
      orElse: () => fallback,
    );
  }

  ThemeVariant _parseVariant(String? value) {
    return ThemeVariant.values.firstWhere(
      (ThemeVariant item) => item.name == value,
      orElse: () => ThemeVariant.variantA,
    );
  }

  DensityMode _parseDensity(String? value) {
    return DensityMode.values.firstWhere(
      (DensityMode item) => item.name == value,
      orElse: () => DensityMode.comfortable,
    );
  }

  WorkMode _parseWorkMode(String? value) {
    return WorkMode.values.firstWhere(
      (WorkMode item) => item.name == value,
      orElse: () => WorkMode.review,
    );
  }

  DeviceType _parseDeviceType(String? value) {
    return DeviceType.values.firstWhere(
      (DeviceType item) => item.name == value,
      orElse: () => DeviceType.desktop,
    );
  }

  TaskComplexity _parseComplexity(String? value) {
    return TaskComplexity.values.firstWhere(
      (TaskComplexity item) => item.name == value,
      orElse: () => TaskComplexity.medium,
    );
  }

  UserRole _parseRole(String? value) {
    return UserRole.values.firstWhere(
      (UserRole item) => item.name == value,
      orElse: () => UserRole.operator,
    );
  }
}
