import 'package:flutter/material.dart';

import 'models/auth_user.dart';
import 'screens/auth_screen.dart';
import 'screens/member_home_screen.dart';
import 'services/api_service.dart';
import 'theme/app_colors.dart';

void main() => runApp(const SaccoLensApp());

class SaccoLensApp extends StatelessWidget {
  const SaccoLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SACCOLens',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.forest,
          surface: AppColors.canvas,
        ).copyWith(
          primary: AppColors.forest,
          secondary: AppColors.lime,
          surface: AppColors.canvas,
          onSurface: AppColors.ink,
        ),
        scaffoldBackgroundColor: AppColors.canvas,
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  MemberAccount? _account;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      _account = await ApiService.restoreSession();
    } catch (_) {
      _account = null;
    }
    if (!mounted) return;
    setState(() => _loading = false);
  }

  void _onAuthenticated(MemberAccount account) {
    setState(() => _account = account);
  }

  Future<void> _onLogout() async {
    await ApiService.logout();
    if (!mounted) return;
    setState(() => _account = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_account == null) {
      return AuthScreen(onAuthenticated: _onAuthenticated);
    }
    return MemberShell(
      account: _account!,
      onLogout: _onLogout,
    );
  }
}