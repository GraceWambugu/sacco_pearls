import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saccolens/core/api_client.dart';
import 'package:saccolens/models/directory_request.dart';
import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/providers/compare_provider.dart';
import 'package:saccolens/screens/sacco_search_screen.dart';

const stima = SaccoRecord(id: 1, name: 'STIMA DT.', county: 'Nairobi');
const acumen = SaccoRecord(id: 2, name: 'ACUMEN DT.', county: 'Kajiado');
const ainabkoi = SaccoRecord(id: 3, name: 'AINABKOI FARMERS'); // no county in the data
const directory = [stima, acumen, ainabkoi];

/// Scores: STIMA Green with low NPL, ACUMEN Amber with high NPL, AINABKOI unrated.
final scores = [
  const RankedSacco(sacco: stima, composite: 85.0, rating: 'Green', year: 2024, totalAssets: 66.51, nplRatio: 3.1, cca: 19.2),
  const RankedSacco(sacco: acumen, composite: 60.0, rating: 'Amber', year: 2024, totalAssets: 1.2, nplRatio: 9.4, cca: 11.0),
];

/// A fake API: filters the three SACCOs above and records what it was asked.
class FakeLoader {
  final calls = <String>[];
  bool serverDown = false;

  Future<List<SaccoRecord>> call(String query, {String? county}) async {
    calls.add('$query|${county ?? ''}');
    if (serverDown) {
      throw const ApiException(statusCode: 0, message: 'Could not reach the server.');
    }
    return directory
        .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
        .where((s) => county == null || s.county == county)
        .toList();
  }
}

Future<CompareProvider> pumpSearch(WidgetTester tester, FakeLoader loader,
    {ValueNotifier<DirectoryRequest?>? request}) async {
  tester.view.physicalSize = const Size(1200, 9000); // 400 x 3000: every card is built
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final picks = CompareProvider();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: picks,
      child: MaterialApp(
        home: SaccoSearchScreen(
          loader: loader.call,
          rankingsLoader: () async => scores,
          request: request,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return picks;
}

Future<void> typeSearch(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 350)); // past the 300 ms wait
  await tester.pumpAndSettle();
}

Future<void> chooseFromDropdown(WidgetTester tester, String current, String choice) async {
  await tester.tap(find.text(current));
  await tester.pumpAndSettle();
  await tester.tap(find.text(choice).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every SACCO with its real score and figures', (tester) async {
    await pumpSearch(tester, FakeLoader());

    expect(find.textContaining('Showing 3 SACCOs', findRichText: true), findsOneWidget);
    expect(find.text('85/100'), findsOneWidget);
    expect(find.text('Green rating'), findsOneWidget);
    expect(find.text('KES 66.5B'), findsOneWidget);
    expect(find.text('Not rated'), findsOneWidget); // AINABKOI has no score
    expect(find.text('County not listed'), findsOneWidget);
    expect(find.text('Figures: 2024'), findsOneWidget);
  });

  testWidgets('searches after typing stops', (tester) async {
    final loader = FakeLoader();
    await pumpSearch(tester, loader);

    await typeSearch(tester, 'stima');

    expect(loader.calls.last, 'stima|');
    expect(find.text('STIMA DT.'), findsOneWidget);
    expect(find.text('ACUMEN DT.'), findsNothing);
  });

  testWidgets('the county dropdown filters through the API', (tester) async {
    final loader = FakeLoader();
    await pumpSearch(tester, loader);

    await chooseFromDropdown(tester, 'All counties', 'Kajiado');

    expect(loader.calls.last, '|Kajiado');
    expect(find.text('ACUMEN DT.'), findsOneWidget);
    expect(find.text('STIMA DT.'), findsNothing);
  });

  testWidgets('the rating dropdown and Low NPL chip filter by score', (tester) async {
    await pumpSearch(tester, FakeLoader());

    await chooseFromDropdown(tester, 'All ratings', 'Amber (50–74.9)');
    expect(find.text('ACUMEN DT.'), findsOneWidget);
    expect(find.text('STIMA DT.'), findsNothing);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low NPL (5% or less)'));
    await tester.pumpAndSettle();
    expect(find.text('STIMA DT.'), findsOneWidget); // NPL 3.1%
    expect(find.text('ACUMEN DT.'), findsNothing); // NPL 9.4%
  });

  testWidgets('a request from Home applies its filter', (tester) async {
    final request = ValueNotifier<DirectoryRequest?>(null);
    await pumpSearch(tester, FakeLoader(), request: request);

    request.value = const DirectoryRequest(quickFilter: QuickFilter.topRated);
    await tester.pumpAndSettle();

    expect(find.text('STIMA DT.'), findsOneWidget); // the only Green
    expect(find.text('ACUMEN DT.'), findsNothing);
  });

  testWidgets('Add to compare and long-press both add a SACCO', (tester) async {
    final picks = await pumpSearch(tester, FakeLoader());

    await tester.tap(find.text('Add to compare').first);
    await tester.pump();
    expect(picks.contains(stima.id), isTrue);
    expect(find.text('In compare list'), findsOneWidget);

    await tester.longPress(find.text('ACUMEN DT.'));
    await tester.pump();
    expect(picks.contains(acumen.id), isTrue);
  });

  testWidgets('a server that is down shows a message and Try again', (tester) async {
    final loader = FakeLoader()..serverDown = true;
    await pumpSearch(tester, loader);

    expect(find.text('Could not reach the server'), findsOneWidget);

    loader.serverDown = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('STIMA DT.'), findsOneWidget);
  });

  testWidgets('no match explains why the list is empty', (tester) async {
    await pumpSearch(tester, FakeLoader());

    await typeSearch(tester, 'zzz');

    expect(find.text('No SACCOs match your search'), findsOneWidget);
    expect(find.textContaining('No SACCO names match "zzz"'), findsOneWidget);
  });
}
