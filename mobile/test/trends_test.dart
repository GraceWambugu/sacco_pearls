import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/providers/compare_provider.dart';
import 'package:saccolens/screens/trends_screen.dart';

const stima = SaccoRecord(id: 4, name: 'STIMA DT.', county: 'Nairobi');

/// STIMA's real trend from the API (2022-2024).
const stimaTrend = [
  TrendPoint(year: 2022, composite: 93.8, rating: 'Green', totalAssets: 53.78, cca: 19.0, nplRatio: 4.1),
  TrendPoint(year: 2023, composite: 100.0, rating: 'Green', totalAssets: 59.15, cca: 19.1, nplRatio: null),
  TrendPoint(year: 2024, composite: 85.0, rating: 'Green', totalAssets: 66.51, cca: 19.22, nplRatio: 6.53),
];

Future<void> pumpTrends(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final picks = CompareProvider()..add(stima); // the first Compare pick is charted first
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: picks,
      child: MaterialApp(
        home: TrendsScreen(
          trendLoader: (id) async => stimaTrend,
          searchLoader: (query, {county}) async => const [stima],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('trendAssessment', () {
    test('describes the score change and the rating', () {
      expect(
        trendAssessment('STIMA DT.', stimaTrend, TrendMetric.score),
        "STIMA DT.'s PEARLS health score fell to 85/100 in 2024, from 93.8/100 in 2022 "
        '(down 8.8 points). The rating stayed Green.',
      );
    });

    test('skips years without the figure and explains NPL direction', () {
      final text = trendAssessment('STIMA DT.', stimaTrend, TrendMetric.npl);
      expect(text, contains('rose to 6.5% in 2024, from 4.1% in 2022'));
      expect(text, contains('more loans are in arrears'));
    });

    test('one year only is not called a trend', () {
      final text = trendAssessment('STIMA DT.', stimaTrend.sublist(2), TrendMetric.assets);
      expect(text, contains('Only one year has this figure'));
    });
  });

  testWidgets('charts the first Compare pick and explains missing years', (tester) async {
    await pumpTrends(tester);

    expect(find.text('STIMA DT.'), findsOneWidget); // the SACCO picker shows the choice
    expect(find.byType(LineChart), findsOneWidget);
    expect(find.text('2022–2024'), findsOneWidget);
    expect(find.textContaining('fell to 85/100 in 2024'), findsOneWidget);
  });

  testWidgets('switching metric updates the assessment and notes the gap', (tester) async {
    await pumpTrends(tester);

    await tester.tap(find.text('PEARLS health score'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NPL ratio (%)').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('rose to 6.5% in 2024'), findsOneWidget);
    expect(find.textContaining('No NPL ratio for 2023'), findsOneWidget);
    expect(find.textContaining('broken there rather than guessed'), findsOneWidget);
  });
}
