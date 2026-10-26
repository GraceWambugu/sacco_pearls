import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saccolens/screens/auth_screen.dart';

void main() {
  testWidgets('shows member sign-up and password recovery forms', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: AuthScreen(onAuthenticated: (_) {})),
    );

    expect(find.text('Welcome back.'), findsOneWidget);
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.text('Reset your password.'), findsOneWidget);

    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New to SACCO PEARLS? Create an account'));
    await tester.pumpAndSettle();
    expect(find.text('Create your account.'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
  });
}
