import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saccolens/models/directory_request.dart';
import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/providers/auth_provider.dart';
import 'package:saccolens/providers/compare_provider.dart';
import 'package:saccolens/providers/saved_provider.dart';
import 'package:saccolens/screens/member_home_screen.dart';
import 'package:saccolens/widgets/ui.dart';

/// Three real 2024 results (figures as SASRA published them), all tied on 100.
final rankings = [
  for (final (id, name, county, assets, npl, cca) in [
    (73, 'FARIDI', 'Busia', 2.49, 0.04, 37.52),
    (5, 'KENYA NATIONAL POLICE DT.', 'Nairobi', 59.83, 2.42, 34.36),
    (93, 'KEYSTONE DT.', 'Kisumu', 1.44, 4.77, 16.82),
  ])
    RankedSacco(
      sacco: SaccoRecord(id: id, name: name, county: county),
      composite: 100.0,
      rating: 'Green',
      year: 2024,
      dimensionsScored: 4,
      totalAssets: assets,
      nplRatio: npl,
      cca: cca,
    ),
];

Future<(CompareProvider, List<DirectoryRequest>, List<int>)> pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 12000); // 400 x 4000: the whole page is built
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final picks = CompareProvider();
  final requests = <DirectoryRequest>[];
  final tabs = <int>[];
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: picks),
        ChangeNotifierProxyProvider<AuthProvider, SavedProvider>(
          create: (_) => SavedProvider(),
          update: (_, auth, saved) => saved!..updateAuth(auth),
        ),
      ],
      child: MaterialApp(
        home: MemberHomeScreen(
          account: null,
          rankings: Future.value(rankings),
          onNavigate: tabs.add,
          onOpenDirectory: requests.add,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (picks, requests, tabs);
}

void main() {
  testWidgets('shows the hero, the data year and the top three real scores', (tester) async {
    await pumpHome(tester);

    expect(find.textContaining('Jambo! Choose the right'), findsOneWidget);
    expect(find.text('2024 SASRA data · Kenya'), findsOneWidget);
    expect(find.text('KENYA NATIONAL POLICE DT.'), findsOneWidget);
    expect(find.text('KES 59.8B'), findsOneWidget); // real asset base
    expect(find.text('2.4%'), findsOneWidget); // real NPL ratio
    expect(find.text('JOINT #1'), findsNWidgets(3)); // three SACCOs tied on 100
    expect(find.text('Green rating'), findsNWidgets(3)); // the word, not only the colour
  });

  testWidgets('the PEARLS guide says P and L are not scored and uses 75/50', (tester) async {
    await pumpHome(tester);

    expect(find.text('Understanding the PEARLS framework'), findsOneWidget);
    expect(find.text('Not scored'), findsNWidgets(2)); // Protection and Liquidity
    expect(find.text('75–100: Green'), findsOneWidget);
    expect(find.text('50–74.9: Amber'), findsOneWidget);
    expect(find.textContaining('Dividend'), findsNothing); // no invented dividend data
  });

  testWidgets('search and quick filters send the member to the Directory', (tester) async {
    final (_, requests, _) = await pumpHome(tester);

    await tester.enterText(find.byType(TextField), 'stima');
    await tester.tap(find.text('Explore'));
    await tester.tap(find.text('Top rated'));
    await tester.tap(find.text('Low NPL'));
    await tester.tap(find.text('Nairobi'));
    await tester.pump();

    expect(requests[0].query, 'stima');
    expect(requests[1].quickFilter, QuickFilter.topRated);
    expect(requests[2].quickFilter, QuickFilter.lowNpl);
    expect(requests[3].county, 'Nairobi');
  });

  testWidgets('Compare on a top card adds it to the compare list', (tester) async {
    final (picks, _, tabs) = await pumpHome(tester);

    await tester.tap(find.widgetWithText(CompareToggle, 'Compare').first);
    await tester.pump();
    expect(picks.contains(73), isTrue);
    expect(find.text('1 active'), findsOneWidget); // badge on the Compare tile

    await tester.tap(find.text('Compare (up to 3)'));
    expect(tabs, [2]); // opens the Compare tab
  });
}
