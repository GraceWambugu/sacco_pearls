import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/providers/compare_provider.dart';
import 'package:saccolens/screens/compare_screen.dart';
import 'package:saccolens/widgets/pearls_radar.dart';
import 'package:saccolens/widgets/rating.dart';

const stima = SaccoRecord(id: 4, name: 'STIMA DT.', county: 'Nairobi');
const mwalimu = SaccoRecord(id: 7, name: 'MWALIMU NATIONAL DT.');
const afya = SaccoRecord(id: 9, name: 'AFYA', county: 'Nairobi');

/// A score object shaped like the API's, with the given composite and E/A/R/S scores.
Map<String, dynamic> scoreJson(SaccoRecord sacco, num? composite, String? rating,
    {num? e = 100, num? a = 50, num? r = 100, num? s = 100}) {
  Map<String, dynamic> dim(String code, String name, num? score, {String? reason}) => {
        'code': code, 'name': name, 'scored': score != null, 'score': score,
        'reason': ?reason, 'indicators': [],
      };
  return {
    'sacco': {'id': sacco.id, 'name': sacco.name, 'county': sacco.county},
    'year': 2024,
    'composite': composite,
    'rating': rating,
    'dimensions_scored': 4,
    'dimensions_total': 6,
    'dimensions': {
      'P': dim('P', 'Protection', null, reason: 'Not published'),
      'E': dim('E', 'Effective financial structure', e),
      'A': dim('A', 'Asset quality', a),
      'R': dim('R', 'Rates of return and costs', r),
      'L': dim('L', 'Liquidity', null, reason: 'Not published'),
      'S': dim('S', 'Signs of growth', s, reason: s == null ? 'No prior-year figures' : null),
    },
    'overrides': [],
    'flags': [],
  };
}

CompareResult compareOf(List<Map<String, dynamic>> results) => CompareResult.fromJson({
      'year': 2024,
      'results': results,
      'ranking': [for (final r in results) (r['sacco'] as Map)['id']],
    });

Future<CompareProvider> pumpCompare(WidgetTester tester, List<SaccoRecord> picked,
    Future<CompareResult> Function(List<int> ids) loader) async {
  tester.view.physicalSize = const Size(1200, 9000); // 400 x 3000: the whole page is built
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final picks = CompareProvider();
  for (final sacco in picked) {
    picks.add(sacco);
  }
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: picks,
      child: MaterialApp(
        home: CompareScreen(
          compareLoader: loader,
          searchLoader: (query, {county}) async => const [stima, mwalimu, afya],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picks;
}

void main() {
  group('CompareResult ranking', () {
    test('higher composite ranks first', () {
      final result = compareOf([
        scoreJson(mwalimu, 71.7, 'Amber'),
        scoreJson(stima, 85.0, 'Green'),
      ]);
      expect(result.rankOf(result.results[1]), 1); // STIMA
      expect(result.rankOf(result.results[0]), 2); // MWALIMU
      expect(result.isTied(result.results[1]), isFalse);
    });

    test('equal composites share a rank', () {
      final result = compareOf([
        scoreJson(stima, 100.0, 'Green'),
        scoreJson(afya, 100.0, 'Green'),
        scoreJson(mwalimu, 71.7, 'Amber'),
      ]);
      expect(result.rankOf(result.results[0]), 1);
      expect(result.rankOf(result.results[1]), 1);
      expect(result.isTied(result.results[0]), isTrue);
      expect(result.rankOf(result.results[2]), 3); // two SACCOs scored higher
    });

    test('an unrated SACCO has no rank', () {
      final result = compareOf([scoreJson(stima, 85.0, 'Green'), scoreJson(afya, null, null)]);
      expect(result.rankOf(result.results[1]), isNull);
    });
  });

  test('the radar has exactly the four scored dimensions', () {
    expect(radarAxes, ['E', 'A', 'R', 'S']);
  });

  group('Compare screen', () {
    testWidgets('asks for picks when fewer than two are chosen', (tester) async {
      var calls = 0;
      await pumpCompare(tester, [stima], (ids) async {
        calls++;
        throw StateError('should not be called');
      });

      expect(find.text('Pick 1 more SACCO to compare'), findsOneWidget);
      expect(calls, 0); // no API call until there are two picks
    });

    testWidgets('two picks are compared automatically with rank, rating word and radar', (tester) async {
      List<int>? requested;
      await pumpCompare(tester, [mwalimu, stima], (ids) async {
        requested = ids;
        return compareOf([
          scoreJson(mwalimu, 71.7, 'Amber', e: 87.5),
          scoreJson(stima, 85.0, 'Green'),
        ]);
      });

      expect(requested, [7, 4]);
      expect(find.text('2nd of 2'), findsOneWidget); // MWALIMU, in the table's Rank row
      expect(find.text('1st of 2'), findsOneWidget); // STIMA
      expect(find.text('85/100'), findsOneWidget);
      expect(find.text('71.7/100'), findsOneWidget);
      // The rating word sits in each SACCO's chip, not only its colour.
      Finder chipWord(String word) => find.descendant(of: find.byType(RatingChip), matching: find.text(word));
      expect(chipWord('Green'), findsOneWidget);
      expect(chipWord('Amber'), findsOneWidget);
      expect(find.byType(RadarChart), findsOneWidget);
      expect(find.textContaining('Scores and charts use E, A, R and S'), findsOneWidget);
      expect(find.text('Protection'), findsNothing);
      expect(find.text('Liquidity'), findsNothing);
    });

    testWidgets('ties are shown as joint', (tester) async {
      await pumpCompare(tester, [stima, afya], (ids) async => compareOf([
            scoreJson(stima, 100.0, 'Green'),
            scoreJson(afya, 100.0, 'Green'),
          ]));

      expect(find.text('Joint 1st of 2'), findsNWidgets(2));
    });

    testWidgets('a missing growth score is explained', (tester) async {
      await pumpCompare(tester, [stima, afya], (ids) async => compareOf([
            scoreJson(stima, 85.0, 'Green'),
            scoreJson(afya, 80.0, 'Green', s: null),
          ]));

      expect(find.textContaining('No growth (S) score for AFYA'), findsOneWidget);
    });

    testWidgets('removing a pick goes back to the prompt', (tester) async {
      await pumpCompare(tester, [stima, afya], (ids) async => compareOf([
            scoreJson(stima, 85.0, 'Green'),
            scoreJson(afya, 80.0, 'Green'),
          ]));

      await tester.tap(find.byTooltip('Remove AFYA'));
      await tester.pumpAndSettle();

      expect(find.text('Pick 1 more SACCO to compare'), findsOneWidget);
      expect(find.byType(RadarChart), findsNothing);
    });

    testWidgets('Add a SACCO opens a picker that adds to compare', (tester) async {
      final picks = await pumpCompare(tester, [stima], (ids) async => compareOf([
            scoreJson(stima, 85.0, 'Green'),
            scoreJson(afya, 80.0, 'Green'),
          ]));

      await tester.tap(find.text('Add SACCO'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AFYA').last);
      await tester.pumpAndSettle();

      expect(picks.contains(afya.id), isTrue);
      expect(find.text('1st of 2'), findsOneWidget);
    });
  });
}
