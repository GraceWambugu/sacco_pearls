import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:saccolens/core/api_client.dart';
import 'package:saccolens/models/sacco.dart';
import 'package:saccolens/providers/compare_provider.dart';
import 'package:saccolens/screens/sacco_search_screen.dart';

const directory = [
  SaccoRecord(id: 1, name: 'STIMA DT.', county: 'Nairobi'),
  SaccoRecord(id: 2, name: 'ACUMEN DT.', county: 'Kajiado'),
  SaccoRecord(id: 3, name: 'AINABKOI FARMERS'), // no county in the data
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

Future<CompareProvider> pumpSearch(WidgetTester tester, FakeLoader loader) async {
  final picks = CompareProvider();
  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: picks,
      child: MaterialApp(home: SaccoSearchScreen(loader: loader.call)),
    ),
  );
  await tester.pumpAndSettle();
  return picks;
}

void main() {
  testWidgets('lists SACCOs and searches after typing stops', (tester) async {
    final loader = FakeLoader();
    await pumpSearch(tester, loader);

    expect(find.text('STIMA DT.'), findsOneWidget);
    expect(find.text('County not listed'), findsOneWidget); // null county handled
    expect(find.text('3 SACCOS'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'stima');
    await tester.pump(const Duration(milliseconds: 350)); // past the 300 ms wait
    await tester.pumpAndSettle();

    expect(loader.calls.last, 'stima|');
    expect(find.text('STIMA DT.'), findsOneWidget);
    expect(find.text('ACUMEN DT.'), findsNothing);
  });

  testWidgets('county chips filter the list', (tester) async {
    final loader = FakeLoader();
    await pumpSearch(tester, loader);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Kajiado'));
    await tester.pumpAndSettle();

    expect(loader.calls.last, '|Kajiado');
    expect(find.text('ACUMEN DT.'), findsOneWidget);
    expect(find.text('STIMA DT.'), findsNothing);
  });

  testWidgets('the + button adds a SACCO to Compare', (tester) async {
    final picks = await pumpSearch(tester, FakeLoader());

    await tester.tap(find.byTooltip('Add STIMA DT. to compare'));
    await tester.pump();

    expect(picks.contains(1), isTrue);
    expect(find.byTooltip('Remove STIMA DT. from compare'), findsOneWidget);
    expect(find.text('STIMA DT. added to compare (1 of 3)'), findsOneWidget);
  });

  testWidgets('long-press also adds to Compare', (tester) async {
    final picks = await pumpSearch(tester, FakeLoader());

    await tester.longPress(find.text('ACUMEN DT.'));
    await tester.pump();

    expect(picks.contains(2), isTrue);
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

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('No SACCOs found'), findsOneWidget);
    expect(find.textContaining('No SACCO names match "zzz"'), findsOneWidget);
  });
}
