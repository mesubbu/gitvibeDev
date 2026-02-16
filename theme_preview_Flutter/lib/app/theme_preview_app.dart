import 'package:flutter/material.dart';

import '../design_system/design_system.dart';
import 'app_shell.dart';
import 'app_state.dart';

class ThemePreviewApp extends StatefulWidget {
  const ThemePreviewApp({super.key});

  @override
  State<ThemePreviewApp> createState() => _ThemePreviewAppState();
}

class _ThemePreviewAppState extends State<ThemePreviewApp> {
  late final Future<PreviewAppState> _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = PreviewAppState.bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PreviewAppState>(
      future: _bootstrapFuture,
      builder: (BuildContext context, AsyncSnapshot<PreviewAppState> snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text(
                    'Failed to initialize preview workspace: ${snapshot.error}'),
              ),
            ),
          );
        }

        final PreviewAppState state = snapshot.data!;
        return AnimatedBuilder(
          animation: state,
          builder: (BuildContext context, Widget? child) {
            return MaterialApp(
              title: 'GitVibe Theme Preview',
              debugShowCheckedModeBanner: false,
              themeMode: state.themeMode,
              theme: AppThemeEngine.build(
                brightness: Brightness.light,
                variant: state.variant,
                density: state.density,
                workMode: state.workMode,
                role: state.role,
                deviceType: state.deviceType,
                complexity: state.complexity,
              ),
              darkTheme: AppThemeEngine.build(
                brightness: Brightness.dark,
                variant: state.variant,
                density: state.density,
                workMode: state.workMode,
                role: state.role,
                deviceType: state.deviceType,
                complexity: state.complexity,
              ),
              home: AppShell(state: state),
            );
          },
        );
      },
    );
  }
}
