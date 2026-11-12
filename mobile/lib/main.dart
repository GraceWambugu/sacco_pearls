import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/compare_provider.dart';
import 'providers/saved_provider.dart';
import 'screens/app_shell.dart';
import 'theme/app_theme.dart';

void main() => runApp(const SaccoLensApp());

class SaccoLensApp extends StatelessWidget {
  const SaccoLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Shared state lives above the whole app, so every screen sees the same values.
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..restoreSession()),
        ChangeNotifierProvider(create: (_) => CompareProvider()),
        // The saved list depends on who is signed in, so it is rebuilt when AuthProvider changes.
        ChangeNotifierProxyProvider<AuthProvider, SavedProvider>(
          create: (_) => SavedProvider(),
          update: (_, auth, saved) => saved!..updateAuth(auth),
        ),
      ],
      child: MaterialApp(
        title: 'SACCOLens',
        theme: buildAppTheme(),
        // No login wall: anyone can search, view and compare. Sign-in is only needed to save.
        home: const AppShell(),
      ),
    );
  }
}
