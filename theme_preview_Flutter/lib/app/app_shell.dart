import 'package:flutter/material.dart';

import '../design_system/components/role_tag.dart';
import '../design_system/components/status_badge.dart';
import '../domain/models.dart';
import '../domain/screen_descriptor.dart';
import '../screens/generated_screen.dart';
import '../screens/screen_registry.dart';
import 'app_state.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.state});

  final PreviewAppState state;

  @override
  Widget build(BuildContext context) {
    final List<ScreenDescriptor> screens =
        ScreenRegistry.visibleFor(state.role);
    final ScreenDescriptor active = screens.firstWhere(
      (ScreenDescriptor item) => item.id == state.activeScreenId,
      orElse: () => screens.first,
    );

    final bool desktopLayout = MediaQuery.sizeOf(context).width >= 1080;

    return Scaffold(
      drawer: desktopLayout
          ? null
          : _NavigationDrawer(state: state, active: active, screens: screens),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('GitVibe UX + Theme Workspace'),
            Text(
              'Inference-driven preview • ${active.classification.label}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: StatusBadge(
              label: state.runtimeMode.label.toUpperCase(),
              tone: state.runtimeMode == RuntimeMode.demo
                  ? StatusTone.info
                  : StatusTone.success,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: RoleTag(role: state.role),
          ),
          IconButton(
            tooltip: 'Toggle light/dark',
            icon: Icon(state.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode),
            onPressed: () {
              state.setThemeMode(state.themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark);
            },
          ),
          IconButton(
            tooltip: 'Open settings',
            icon: const Icon(Icons.settings),
            onPressed: () => state.setActiveScreen('settings'),
          ),
          IconButton(
            tooltip: 'Runtime controls',
            icon: const Icon(Icons.tune),
            onPressed: () => _showRuntimeControls(context, state),
          ),
          IconButton(
            tooltip: state.showContextPanel
                ? 'Hide context panel'
                : 'Show context panel',
            icon: Icon(state.showContextPanel
                ? Icons.view_sidebar
                : Icons.view_sidebar_outlined),
            onPressed: state.toggleContextPanel,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: <Widget>[
          if (desktopLayout)
            SizedBox(
              width: 290,
              child: _NavigationPane(
                state: state,
                active: active,
                screens: screens,
              ),
            ),
          Expanded(
            child: Column(
              children: <Widget>[
                if (state.runtimeMode == RuntimeMode.demo)
                  Container(
                    margin: const EdgeInsets.all(12),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      children: <Widget>[
                        Icon(Icons.shield_moon_outlined),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'DEMO MODE active: frontend workflow simulation only; '
                            'no production backend dependencies.',
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: InferredScreenRenderer(
                    descriptor: active,
                    state: state,
                  ),
                ),
              ],
            ),
          ),
          if (desktopLayout && state.showContextPanel)
            SizedBox(
              width: 330,
              child: _ContextPanel(state: state),
            ),
        ],
      ),
    );
  }

  Future<void> _showRuntimeControls(
      BuildContext context, PreviewAppState state) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                _enumDropdown<RuntimeMode>(
                  label: 'Runtime Mode',
                  value: state.runtimeMode,
                  values: RuntimeMode.values,
                  text: (RuntimeMode value) => value.label,
                  onChanged: state.setRuntimeMode,
                ),
                _enumDropdown<UserRole>(
                  label: 'Role',
                  value: state.role,
                  values: UserRole.values,
                  text: (UserRole value) => value.label,
                  onChanged: state.setRole,
                ),
                _enumDropdown<ThemeVariant>(
                  label: 'Theme Variant',
                  value: state.variant,
                  values: ThemeVariant.values,
                  text: (ThemeVariant value) => value.label,
                  onChanged: state.setVariant,
                ),
                _enumDropdown<DensityMode>(
                  label: 'Density',
                  value: state.density,
                  values: DensityMode.values,
                  text: (DensityMode value) => value.label,
                  onChanged: state.setDensity,
                ),
                _enumDropdown<WorkMode>(
                  label: 'Work Mode',
                  value: state.workMode,
                  values: WorkMode.values,
                  text: (WorkMode value) => value.label,
                  onChanged: state.setWorkMode,
                ),
                _enumDropdown<DeviceType>(
                  label: 'Device Profile',
                  value: state.deviceType,
                  values: DeviceType.values,
                  text: (DeviceType value) => value.label,
                  onChanged: state.setDeviceType,
                ),
                _enumDropdown<TaskComplexity>(
                  label: 'Task Complexity',
                  value: state.complexity,
                  values: TaskComplexity.values,
                  text: (TaskComplexity value) => value.label,
                  onChanged: state.setComplexity,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _enumDropdown<T>({
    required String label,
    required T value,
    required List<T> values,
    required String Function(T) text,
    required Future<void> Function(T) onChanged,
  }) {
    return SizedBox(
      width: 280,
      child: Row(
        children: <Widget>[
          Expanded(flex: 2, child: Text(label)),
          Expanded(
            flex: 3,
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              onChanged: (T? next) {
                if (next == null) return;
                onChanged(next);
              },
              items: values
                  .map((T item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(text(item)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationDrawer extends StatelessWidget {
  const _NavigationDrawer({
    required this.state,
    required this.active,
    required this.screens,
  });

  final PreviewAppState state;
  final ScreenDescriptor active;
  final List<ScreenDescriptor> screens;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: _NavigationList(
        state: state,
        active: active,
        screens: screens,
        closeDrawerOnSelect: true,
      ),
    );
  }
}

class _NavigationPane extends StatelessWidget {
  const _NavigationPane({
    required this.state,
    required this.active,
    required this.screens,
  });

  final PreviewAppState state;
  final ScreenDescriptor active;
  final List<ScreenDescriptor> screens;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: _NavigationList(
        state: state,
        active: active,
        screens: screens,
        closeDrawerOnSelect: false,
      ),
    );
  }
}

class _NavigationList extends StatelessWidget {
  const _NavigationList({
    required this.state,
    required this.active,
    required this.screens,
    required this.closeDrawerOnSelect,
  });

  final PreviewAppState state;
  final ScreenDescriptor active;
  final List<ScreenDescriptor> screens;
  final bool closeDrawerOnSelect;

  @override
  Widget build(BuildContext context) {
    final Map<ScreenClass, List<ScreenDescriptor>> grouped =
        <ScreenClass, List<ScreenDescriptor>>{};
    for (final ScreenDescriptor screen in screens) {
      grouped
          .putIfAbsent(screen.classification, () => <ScreenDescriptor>[])
          .add(screen);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            'Screen Taxonomy',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        for (final ScreenClass type in ScreenClass.values)
          if (grouped[type] != null && grouped[type]!.isNotEmpty) ...<Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
              child: Text(
                type.label.toUpperCase(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ...grouped[type]!.map((ScreenDescriptor descriptor) {
              return ListTile(
                dense: true,
                selected: descriptor.id == active.id,
                title: Text(descriptor.title),
                subtitle: Text(descriptor.summary,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () {
                  state.setActiveScreen(descriptor.id);
                  if (closeDrawerOnSelect) Navigator.of(context).pop();
                },
              );
            }),
          ],
      ],
    );
  }
}

class _PanelBundle {
  const _PanelBundle({required this.notifications, required this.activities});

  final List<NotificationItem> notifications;
  final List<ActivityEvent> activities;
}

class _ContextPanel extends StatelessWidget {
  const _ContextPanel({required this.state});

  final PreviewAppState state;

  Future<_PanelBundle> _load() async {
    final List<NotificationItem> notifications =
        await state.repository.listNotifications();
    final List<ActivityEvent> activities =
        await state.repository.listActivities();
    return _PanelBundle(notifications: notifications, activities: activities);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: FutureBuilder<_PanelBundle>(
        future: _load(),
        builder: (BuildContext context, AsyncSnapshot<_PanelBundle> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final _PanelBundle data = snapshot.data!;
          final List<NotificationItem> unread = data.notifications
              .where((NotificationItem item) => !item.read)
              .toList();
          return ListView(
            padding: const EdgeInsets.all(12),
            children: <Widget>[
              Text('Context Panel',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              StatusBadge(
                  label: '${unread.length} unread alerts',
                  tone:
                      unread.isEmpty ? StatusTone.success : StatusTone.warning),
              const SizedBox(height: 10),
              Text('Latest Alerts',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...unread.take(4).map((NotificationItem item) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(item.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.message,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  )),
              const SizedBox(height: 12),
              Text('Recent Activity',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...data.activities.take(5).map((ActivityEvent item) => ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    title: Text('${item.actor} • ${item.action}',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.target,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  )),
            ],
          );
        },
      ),
    );
  }
}
