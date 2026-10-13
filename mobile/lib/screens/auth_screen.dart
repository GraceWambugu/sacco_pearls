import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

enum _AuthMode { login, signUp, forgotPassword, resetPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.onAuthenticated});

  final ValueChanged<MemberAccount> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _tokenController = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _setMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _notice = null;
      _passwordController.clear();
      _confirmationController.clear();
      if (mode != _AuthMode.resetPassword) _tokenController.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _notice = null;
    });

    try {
      switch (_mode) {
        case _AuthMode.login:
          final account = await ApiService.login(
            email: _emailController.text,
            password: _passwordController.text,
          );
          if (mounted) widget.onAuthenticated(account);
        case _AuthMode.signUp:
          final account = await ApiService.registerMember(
            fullName: _nameController.text,
            email: _emailController.text,
            password: _passwordController.text,
          );
          if (mounted) widget.onAuthenticated(account);
        case _AuthMode.forgotPassword:
          await ApiService.requestPasswordReset(_emailController.text);
          if (!mounted) return;
          setState(() {
            _mode = _AuthMode.resetPassword;
            _notice =
                'If an account exists, a reset token has been sent to your email.';
          });
        case _AuthMode.resetPassword:
          await ApiService.resetPassword(
            token: _tokenController.text,
            newPassword: _passwordController.text,
          );
          if (!mounted) return;
          setState(() {
            _mode = _AuthMode.login;
            _notice = 'Password reset. Sign in with your new password.';
            _tokenController.clear();
          });
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _error = 'The request timed out. Check the connection and try again.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Cannot reach the API. Check that the backend is running.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _title => switch (_mode) {
        _AuthMode.login => 'Welcome back.',
        _AuthMode.signUp => 'Create your account.',
        _AuthMode.forgotPassword => 'Reset your password.',
        _AuthMode.resetPassword => 'Choose a new password.',
      };

  String get _subtitle => switch (_mode) {
        _AuthMode.login => 'Sign in to your member account.',
        _AuthMode.signUp => 'Create an account to save the SACCOs you follow.',
        _AuthMode.forgotPassword => 'We’ll send a one-time reset token to your email.',
        _AuthMode.resetPassword => 'Enter the one-time token from your reset email.',
      };

  String get _buttonLabel => switch (_mode) {
        _AuthMode.login => 'Sign in',
        _AuthMode.signUp => 'Create account',
        _AuthMode.forgotPassword => 'Send reset token',
        _AuthMode.resetPassword => 'Reset password',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(Icons.eco_rounded, color: AppColors.lime, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SACCO PEARLS',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 38),
                  Container(
                    padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _mode == _AuthMode.login || _mode == _AuthMode.signUp
                                ? 'MEMBER ACCESS'
                                : 'ACCOUNT RECOVERY',
                            style: const TextStyle(
                              color: AppColors.forest,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _title,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _subtitle,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_notice != null) ...[
                            _MessageBanner(message: _notice!, isError: false),
                            const SizedBox(height: 14),
                          ],
                          if (_error != null) ...[
                            _MessageBanner(message: _error!, isError: true),
                            const SizedBox(height: 14),
                          ],
                          if (_mode == _AuthMode.signUp) ...[
                            _label('Full name'),
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: _decoration('Your full name'),
                              validator: (value) => value == null || value.trim().isEmpty
                                  ? 'Enter your full name'
                                  : null,
                            ),
                            const SizedBox(height: 15),
                          ],
                          if (_mode != _AuthMode.resetPassword) ...[
                            _label('Email address'),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              textInputAction: _mode == _AuthMode.forgotPassword
                                  ? TextInputAction.done
                                  : TextInputAction.next,
                              decoration: _decoration('name@example.com'),
                              validator: _validateEmail,
                            ),
                            const SizedBox(height: 15),
                          ],
                          if (_mode == _AuthMode.resetPassword) ...[
                            _label('Reset token'),
                            TextFormField(
                              controller: _tokenController,
                              keyboardType: TextInputType.visiblePassword,
                              autocorrect: false,
                              decoration: _decoration('Paste the token from your email'),
                              validator: (value) => value == null || value.trim().length < 30
                                  ? 'Enter the reset token from your email'
                                  : null,
                            ),
                            const SizedBox(height: 15),
                          ],
                          if (_mode == _AuthMode.login ||
                              _mode == _AuthMode.signUp ||
                              _mode == _AuthMode.resetPassword) ...[
                            _label(_mode == _AuthMode.login ? 'Password' : 'New password'),
                            _passwordField(
                              controller: _passwordController,
                              hint: _mode == _AuthMode.login
                                  ? 'Enter your password'
                                  : 'At least 8 characters, with a letter and number',
                              validator: _validatePassword,
                            ),
                            if (_mode != _AuthMode.login) ...[
                              const SizedBox(height: 15),
                              _label('Confirm password'),
                              _passwordField(
                                controller: _confirmationController,
                                hint: 'Enter your password again',
                                validator: (value) => value != _passwordController.text
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                            ],
                          ],
                          if (_mode == _AuthMode.login)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => _setMode(_AuthMode.forgotPassword),
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          if (_mode == _AuthMode.signUp || _mode == _AuthMode.resetPassword)
                            const Padding(
                              padding: EdgeInsets.only(top: 12),
                              child: Text(
                                'Use at least 8 characters, including a letter and a number.',
                                style: TextStyle(color: AppColors.muted, fontSize: 11),
                              ),
                            ),
                          const SizedBox(height: 18),
                          SizedBox(
                            height: 48,
                            child: FilledButton(
                              onPressed: _isLoading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.lime,
                                foregroundColor: AppColors.charcoal,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(7),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.charcoal,
                                      ),
                                    )
                                  : Text(
                                      _buttonLabel,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _modeFooter(),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SACCO PEARLS  ·  MEMBER ACCESS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeFooter() {
    if (_mode == _AuthMode.login) {
      return TextButton(
        onPressed: _isLoading ? null : () => _setMode(_AuthMode.signUp),
        child: const Text('New to SACCO PEARLS? Create an account'),
      );
    }
    if (_mode == _AuthMode.signUp) {
      return TextButton(
        onPressed: _isLoading ? null : () => _setMode(_AuthMode.login),
        child: const Text('Already have an account? Sign in'),
      );
    }
    return TextButton(
      onPressed: _isLoading ? null : () => _setMode(_AuthMode.login),
      child: const Text('Back to sign in'),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required FormFieldValidator<String> validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: _obscurePassword,
      autofillHints: _mode == _AuthMode.login
          ? const [AutofillHints.password]
          : const [AutofillHints.newPassword],
      decoration: _decoration(hint).copyWith(
        suffixIcon: IconButton(
          tooltip: _obscurePassword ? 'Show password' : 'Hide password',
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
        ),
      ),
      validator: validator,
    );
  }

  Widget _label(String value) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Text(
          value,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
      );

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (_mode == _AuthMode.login) {
      return password.isEmpty ? 'Enter your password' : null;
    }
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.red : AppColors.forest;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontSize: 12),
      ),
    );
  }
}