import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/auth_provider.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import 'auth_screen.dart';
import 'compare_screen.dart';
import 'member_home_screen.dart';
import 'sacco_search_screen.dart';
import 'watchlist_screen.dart';

/// The four main tabs: Home, Search, Compare and Saved.
/// Account is reached from the person icon on Home, not a tab.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const homeTab = 0;
  static const searchTab = 1;
  static const compareTab = 2;
  static const savedTab = 3;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = AppShell.homeTab;
  late final Future<List<SaccoRecord>> _directory = ApiService.searchSaccos('');

  void _goTo(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final account = context.watch<AuthProvider>().account;
    final compareCount = context.watch<CompareProvider>().count;
    final pages = [
      MemberHomeScreen(
        account: account,
        onNavigate: _goTo,
        onOpenAccount: () => openAccount(context),
        directory: _directory,
      ),
      const SaccoSearchScreen(),
      CompareScreen(onBrowse: () => _goTo(AppShell.searchTab)),
      WatchlistScreen(onBrowse: () => _goTo(AppShell.searchTab)),
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
          const NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Search'),
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
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'Saved',
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
