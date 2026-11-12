import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/directory_request.dart';
import '../models/sacco.dart';
import '../providers/auth_provider.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import 'account_screen.dart';
import 'auth_screen.dart';
import 'compare_screen.dart';
import 'member_home_screen.dart';
import 'sacco_search_screen.dart';
import 'trends_screen.dart';
import 'watchlist_screen.dart';

/// The four main tabs: Home, Directory, Compare and Trends.
/// Saved SACCOs and Account open from Home.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const homeTab = 0;
  static const searchTab = 1;
  static const compareTab = 2;
  static const trendsTab = 3;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = AppShell.homeTab;
  // Scores for every SACCO, loaded once and shared by Home and the Directory.
  late final Future<List<RankedSacco>> _rankings = ApiService.getRankings();
  // Home writes here to send the member to the Directory with a search or filter.
  final _directoryRequest = ValueNotifier<DirectoryRequest?>(null);

  @override
  void dispose() {
    _directoryRequest.dispose();
    super.dispose();
  }

  void _goTo(int index) => setState(() => _selectedIndex = index);

  void _openDirectory(DirectoryRequest request) {
    _directoryRequest.value = request;
    _goTo(AppShell.searchTab);
  }

  /// Saved is a page opened from Home, not a tab. "Find a SACCO" on it closes
  /// the page and switches to the Directory tab.
  void _openSaved() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (pageContext) => WatchlistScreen(onBrowse: () {
        Navigator.of(pageContext).pop();
        _goTo(AppShell.searchTab);
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthProvider>().account;
    final compareCount = context.watch<CompareProvider>().count;
    final pages = [
      MemberHomeScreen(
        account: account,
        rankings: _rankings,
        onNavigate: _goTo,
        onOpenDirectory: _openDirectory,
        onOpenAccount: () => openAccount(context),
        onOpenSaved: _openSaved,
      ),
      // The Directory should fetch fresh rankings when opened or refreshed.
      // Reusing the shell's Future could leave it stuck with a startup error
      // if the API was unavailable when the app first launched.
      SaccoSearchScreen(rankingsLoader: ApiService.getRankings, request: _directoryRequest),
      CompareScreen(onBrowse: () => _goTo(AppShell.searchTab)),
      TrendsScreen(rankings: _rankings),
    ];

    return Scaffold(
      // IndexedStack keeps each tab alive, so switching tabs does not lose the search text.
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _goTo,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          const NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Directory'),
          NavigationDestination(
            // The badge shows how many SACCOs are waiting to be compared.
            icon: Badge(
              isLabelVisible: compareCount > 0,
              label: Text('$compareCount'),
              child: const Icon(Icons.compare_arrows_rounded),
            ),
            label: 'Compare',
          ),
          const NavigationDestination(
            icon: Icon(Icons.show_chart_rounded),
            label: 'Trends',
          ),
        ],
      ),
    );
  }
}

/// Opens the account page if signed in, otherwise the sign-in page.
Future<void> openAccount(BuildContext context) {
  final auth = context.read<AuthProvider>();
  final account = auth.account;
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (pageContext) => account != null
          ? MemberAccountScreen(
              account: account,
              onLogout: () async {
                await auth.signOut();
                if (pageContext.mounted) Navigator.of(pageContext).pop();
              },
            )
          : AuthScreen(
              onAuthenticated: (signedIn) {
                auth.signedIn(signedIn);
                Navigator.of(pageContext).pop();
              },
            ),
    ),
  );
}
