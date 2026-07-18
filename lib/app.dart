import 'package:flutter/material.dart';

import 'core/app_constants.dart';
import 'core/app_theme.dart';
import 'screens/modern_shell_screen.dart';
import 'state/app_state.dart';
import 'state/printing_app_state.dart';

class AirmonlinkBusinessManagerApp extends StatefulWidget {
  const AirmonlinkBusinessManagerApp({super.key});

  @override
  State<AirmonlinkBusinessManagerApp> createState() =>
      _AirmonlinkBusinessManagerAppState();
}

class _AirmonlinkBusinessManagerAppState
    extends State<AirmonlinkBusinessManagerApp> {
  late final AppState state;

  @override
  void initState() {
    super.initState();
    state = PrintingAppState()..initialize();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: state,
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const ModernShellScreen(),
      ),
    );
  }
}
