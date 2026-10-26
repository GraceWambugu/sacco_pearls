import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/providers/auth_provider.dart';
import 'package:saccolens/providers/compare_provider.dart';
import 'package:saccolens/providers/saved_provider.dart';
import 'package:saccolens/screens/sacco_profile_screen.dart';

/// STIMA DT. 2024 as the API returns it (abridged to one indicator per dimension).
Map<String, dynamic> stimaJson({int year = 2024, List<String> overrides = const [], List<String> flags = const []}) => {
      'sacco': {'id': 4, 'name': 'STIMA DT.', 'county': 'Nairobi'},
      'year': year,
      'composite': 85.0,
      'rating': 'Green',
      'dimensions_scored': 4,
      'dimensions_total': 6,
      'dimensions': {
        'P': {'code': 'P', 'name': 'Protection', 'scored': false, 'score': null,
              'reason': 'Loan-loss provisions are not published per SACCO', 'indicators': []},
        'E': {'code': 'E', 'name': 'Effective financial structure', 'scored': true, 'score': 100.0,
              'indicators': [
                {'key': 'cca', 'label': 'Core capital / total assets', 'value': 19.22, 'unit': '%',
                 'band': 'Green', 'points': 100, 'rule': 'SASRA minimum 10%; Green from 12.5%'},
              ]},
        'A': {'code': 'A', 'name': 'Asset quality', 'scored': true, 'score': 50.0, 'indicators': []},
        'R': {'code': 'R', 'name': 'Rates of return and costs', 'scored': true, 'score': 100.0, 'indicators': []},
        'L': {'code': 'L', 'name': 'Liquidity', 'scored': false, 'score': null,
              'reason': 'A per-SACCO liquidity ratio is not published', 'indicators': []},
        'S': {'code': 'S', 'name': 'Signs of growth', 'scored': true, 'score': 100.0, 'indicators': []},
      },
      'overrides': overrides,
      'flags': flags,
      'weights_used': {'E': 0.4, 'A': 0.3, 'S': 0.2, 'R': 0.1},
    };

const stima = SaccoRecord(id: 4, name: 'STIMA DT.', county: 'Nairobi');

Future<List<int?>> pumpProfile(WidgetTester tester, {Map<String, dynamic>? json}) async {
  final requestedYears = <int?>[];
  // A tall phone-width screen (400 x 3000), so every row of the list is built at once.
  tester.view.physicalSize = const Size(1200, 9000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CompareProvider()),
        ChangeNotifierProxyProvider<AuthProvider, SavedProvider>(
          create: (_) => SavedProvider(),
          update: (_, auth, saved) => saved!..updateAuth(auth),
        ),
      ],
      child: MaterialApp(
        home: SaccoProfileScreen(
          sacco: stima,
          scoreLoader: (id, {year}) async {
            requestedYears.add(year);
            return SaccoScore.fromJson(json ?? stimaJson(year: year ?? 2024));
          },
          trendLoader: (id) async => const [
            TrendPoint(year: 2022),
            TrendPoint(year: 2023),
            TrendPoint(year: 2024),
          ],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requestedYears;
}

void main() {
  group('SaccoScore.fromJson', () {
    test('reads the composite, rating, counts and all six dimensions in order', () {
      final score = SaccoScore.fromJson(stimaJson());
      expect(score.composite, 85.0);
      expect(score.rating, 'Green');
      expect(score.dimensionsScored, 4);
      expect(score.dimensions.keys, ['P', 'E', 'A', 'R', 'L', 'S']);
      expect(score.dimensions['P']!.scored, isFalse);
      expect(score.dimensions['P']!.reason, contains('not published'));
      final cca = score.dimensions['E']!.indicators.single;
      expect(cca.value, 19.22);
      expect(cca.band, 'Green');
      expect(cca.rule, 'SASRA minimum 10%; Green from 12.5%');
    });

    test('a SACCO that cannot be rated becomes "Unrated" with no composite', () {
      final score = SaccoScore.fromJson({...stimaJson(), 'composite': null, 'rating': null});
      expect(score.composite, isNull);
      expect(score.rating, 'Unrated');
    });

    test('missing overrides and flags become empty lists', () {
      final json = stimaJson()..remove('overrides')..remove('flags');
      final score = SaccoScore.fromJson(json);
      expect(score.overrides, isEmpty);
      expect(score.flags, isEmpty);
    });

    test('a trend year can have null figures', () {
      final point = TrendPoint.fromJson({
        'year': 2022, 'composite': 93.8, 'rating': 'Green',
        'dimension_scores': {'E': 100.0, 'A': 100.0, 'R': 50.0, 'S': null},
        'total_assets': 53.78, 'npl_ratio': null, 'data_stale': false,
      });
      expect(point.dimensionScores['S'], isNull);
      expect(point.nplRatio, isNull);
      expect(point.totalAssets, 53.78);
    });
  });

  group('Profile screen', () {
    testWidgets('shows the composite, the rating word and all six PEARLS rows', (tester) async {
      await pumpProfile(tester);

      expect(find.textContaining('85.0 /100', findRichText: true), findsOneWidget); // big number
      expect(find.text('Green rating'), findsOneWidget); // the word, not only the colour
      expect(find.textContaining('STIMA DT. is rated Green (85.0 out of 100) on 2024 figures'), findsOneWidget);
      expect(find.text('4 OF 6 SCORED'), findsOneWidget);
      for (final name in ['Protection', 'Effective financial structure', 'Asset quality',
          'Rates of return and costs', 'Liquidity', 'Signs of growth']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(find.text('Not available'), findsNWidgets(2)); // P and L
      expect(find.text('50 · Amber'), findsOneWidget); // asset quality bar label
      expect(find.textContaining('not financial advice'), findsOneWidget);
    });

    testWidgets('expanding a dimension shows the reason or the indicator rule', (tester) async {
      await pumpProfile(tester);

      await tester.tap(find.text('Protection'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Why: Loan-loss provisions'), findsOneWidget);

      await tester.tap(find.text('Effective financial structure'));
      await tester.pumpAndSettle();
      expect(find.text('19.2%'), findsNWidgets(2)); // in the ratios card and the expanded row
      expect(find.textContaining('How it is rated: SASRA minimum 10%'), findsOneWidget);
    });

    testWidgets('choosing a year reloads that year', (tester) async {
      final requested = await pumpProfile(tester);

      await tester.tap(find.widgetWithText(ChoiceChip, '2023'));
      await tester.pumpAndSettle();

      expect(requested, [null, 2023]); // latest first, then the chosen year
      expect(find.text('PEARLS composite · 2023'), findsOneWidget);
    });

    testWidgets('overrides and data flags are explained in words', (tester) async {
      await pumpProfile(tester, json: stimaJson(
        overrides: ['Capped at Amber: a SASRA regulatory minimum or maximum is breached'],
        flags: ['stale', 'anomaly'],
      ));

      expect(find.text('Rating adjusted'), findsOneWidget);
      expect(find.textContaining('Capped at Amber'), findsOneWidget);
      expect(find.text('Notes on the data'), findsOneWidget);
      expect(find.textContaining('marked these figures with an asterisk'), findsOneWidget);
      expect(find.textContaining('total assets below gross loans'), findsOneWidget);
    });
  });

  testWidgets('a published liquidity ratio is shown but not scored', (tester) async {
    final json = stimaJson();
    (json['dimensions'] as Map)['L'] = {
      'code': 'L', 'name': 'Liquidity', 'scored': false, 'score': null,
      'reason': 'Shown, not scored: SASRA published a per-SACCO liquidity ratio only in its 2022 report',
      'indicators': [
        {'key': 'liquidity_ratio', 'label': 'Liquidity ratio', 'value': 72.39, 'unit': '%', 'band': null,
         'points': null, 'rule': 'SASRA minimum 15% (shown for information, not scored)'},
      ],
    };
    await pumpProfile(tester, json: json);

    expect(find.text('Shown, not scored · 72.4%'), findsOneWidget);
    expect(find.text('Not available'), findsOneWidget); // only Protection now
    expect(find.text('Info'), findsOneWidget); // ratios card: no band for liquidity
  });
}
