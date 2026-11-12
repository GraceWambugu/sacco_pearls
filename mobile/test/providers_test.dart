import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saccolens/core/api_client.dart';
import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/providers/auth_provider.dart';
import 'package:saccolens/providers/compare_provider.dart';
import 'package:saccolens/providers/saved_provider.dart';
import 'package:saccolens/screens/watchlist_screen.dart';

const stima = SaccoRecord(id: 1, name: 'STIMA DT.', county: 'Nairobi');
const mwalimu = SaccoRecord(id: 2, name: 'MWALIMU NATIONAL DT.');
const afya = SaccoRecord(id: 3, name: 'AFYA', county: 'Nairobi');
const kenyaPolice = SaccoRecord(id: 4, name: 'KENYA NATIONAL POLICE DT.');

void main() {
  group('CompareProvider', () {
    test('holds at most three SACCOs', () {
      final picks = CompareProvider();
      expect(picks.add(stima), isTrue);
      expect(picks.add(mwalimu), isTrue);
      expect(picks.add(afya), isTrue);
      expect(picks.add(kenyaPolice), isFalse); // a fourth is refused
      expect(picks.count, 3);
      expect(picks.isFull, isTrue);
    });

    test('needs two SACCOs before comparing', () {
      final picks = CompareProvider()..add(stima);
      expect(picks.canCompare, isFalse);
      picks.add(mwalimu);
      expect(picks.canCompare, isTrue);
    });

    test('adding the same SACCO twice keeps one copy', () {
      final picks = CompareProvider()
        ..add(stima)
        ..add(stima);
      expect(picks.count, 1);
    });

    test('remove and clear tell listening screens to rebuild', () {
      final picks = CompareProvider()
        ..add(stima)
        ..add(mwalimu);
      var rebuilds = 0;
      picks.addListener(() => rebuilds++);
      picks.remove(stima.id);
      expect(picks.contains(stima.id), isFalse);
      picks.clear();
      expect(picks.count, 0);
      expect(rebuilds, 2);
    });
  });

  test('an unreachable server gives a plain message', () {
    const error = ApiException(
      statusCode: 0,
      message: 'Could not reach the server. Check your connection and try again.',
    );
    expect(error.isUnreachable, isTrue);
    expect(error.toString(), startsWith('Could not reach the server'));
  });

  testWidgets('Saved tab asks a signed-out visitor to sign in', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()), // nobody signed in
          ChangeNotifierProxyProvider<AuthProvider, SavedProvider>(
            create: (_) => SavedProvider(),
            update: (_, auth, saved) => saved!..updateAuth(auth),
          ),
        ],
        child: const MaterialApp(home: WatchlistScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to save SACCOs'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });
}
