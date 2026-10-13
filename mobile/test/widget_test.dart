import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/models/auth_user.dart';
import 'package:saccolens/screens/auth_screen.dart';
import 'package:saccolens/screens/member_home_screen.dart';
import 'package:saccolens/screens/sacco_search_screen.dart';

void main() {
  testWidgets('searches the SACCO directory', (WidgetTester tester) async {
    String? requestedQuery;
    await tester.pumpWidget(
      MaterialApp(
        home: SaccoSearchScreen(
          loader: (query) async {
            requestedQuery = query;
            return const [
              SaccoRecord(id: 135, name: 'ACUMEN DT.', county: 'Kajiado'),
            ];
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ACUMEN DT.'), findsOneWidget);
  expect(find.textContaining('135'), findsNothing);
    await tester.enterText(find.byType(TextField), 'acumen');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(requestedQuery, 'acumen');
  });

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

  testWidgets('home explains PEARLS rating colors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MemberHomeScreen(
          account: const MemberAccount(
            id: 1,
            email: 'member@example.com',
            fullName: 'Ava Member',
            role: 'member',
          ),
          onNavigate: (_) {},
          directory: Future.value(const []),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good day, Ava'), findsOneWidget);
    await tester.tap(find.byTooltip('Explain rating colors').first);
    await tester.pumpAndSettle();

    expect(find.text('Understanding the ratings'), findsOneWidget);
    expect(find.text('75 or higher, unless a regulatory breach caps the rating.'), findsOneWidget);
    expect(find.textContaining('Not scored'), findsOneWidget);
  });
}
