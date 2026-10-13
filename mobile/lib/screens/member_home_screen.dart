import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../models/sacco.dart';
import '../services/api_service.dart';
import 'compare_screen.dart';
import 'sacco_profile_screen.dart';
import 'sacco_search_screen.dart';
import 'watchlist_screen.dart';
import '../theme/app_colors.dart';

class MemberShell extends StatefulWidget {
  const MemberShell({super.key, required this.account, required this.onLogout});

  final MemberAccount account;
  final Future<void> Function() onLogout;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _selectedIndex = 0;
  late final _directory = ApiService.searchSaccos('');

  @override
  Widget build(BuildContext context) {
    final pages = [
      MemberHomeScreen(
        account: widget.account,
        onNavigate: (index) => setState(() => _selectedIndex = index),
        directory: _directory,
      ),
      const SaccoSearchScreen(),
      const WatchlistScreen(),
      MemberAccountScreen(account: widget.account, onLogout: widget.onLogout),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.lime,
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search_rounded), label: 'Directory'),
          NavigationDestination(icon: Icon(Icons.bookmark_border_rounded), selectedIcon: Icon(Icons.bookmark_rounded), label: 'Saved'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Account'),
        ],
      ),
    );
  }
}

class MemberHomeScreen extends StatelessWidget {
  const MemberHomeScreen({
    super.key,
    required this.account,
    required this.onNavigate,
    required this.directory,
  });

  final MemberAccount account;
  final ValueChanged<int> onNavigate;
  final Future<List<SaccoRecord>> directory;

  @override
  Widget build(BuildContext context) {
    final firstName = account.fullName.trim().split(RegExp(r'\s+')).first;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.canvas,
        title: const Text(
          'SACCOLens',
          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Explain rating colors',
            onPressed: () => showRatingGuide(context),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.limeSoft,
              foregroundColor: AppColors.charcoal,
            ),
            icon: const Icon(Icons.info_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Text(
            'Good day, $firstName',
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 29,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Explore financial health across Kenya’s SACCOs.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _DirectorySummary(onTap: () => onNavigate(1), directory: directory),
          const SizedBox(height: 28),
          const Text(
            'YOUR TOOLS',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.65,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _HomeActionTile(
                icon: Icons.search_rounded,
                title: 'Find a SACCO',
                detail: 'Browse directory',
                background: AppColors.charcoal,
                foreground: Colors.white,
                iconBackground: AppColors.lime,
                onTap: () => onNavigate(1),
              ),
              _HomeActionTile(
                icon: Icons.compare_arrows_rounded,
                title: 'Compare',
                detail: 'Choose up to three',
                background: AppColors.lime,
                foreground: AppColors.charcoal,
                iconBackground: AppColors.surface,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CompareScreen()),
                ),
              ),
              _HomeActionTile(
                icon: Icons.bookmark_border_rounded,
                title: 'Saved',
                detail: 'Your shortlist',
                background: AppColors.surface,
                foreground: AppColors.ink,
                iconBackground: AppColors.limeSoft,
                onTap: () => onNavigate(2),
              ),
              _HomeActionTile(
                icon: Icons.person_outline_rounded,
                title: 'Account',
                detail: 'Member settings',
                background: AppColors.surface,
                foreground: AppColors.ink,
                iconBackground: AppColors.limeSoft,
                onTap: () => onNavigate(3),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Rating guide',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Explain rating colors',
                onPressed: () => showRatingGuide(context),
                icon: const Icon(Icons.info_outline_rounded),
              ),
            ],
          ),
          const Text(
            'The overall rating summarizes the scored PEARLS dimensions.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const _RatingLegendRow(
            color: AppColors.green,
            label: 'Green',
            detail: '75 or higher',
          ),
          const _RatingLegendRow(
            color: AppColors.amber,
            label: 'Amber',
            detail: '50 to under 75',
          ),
          const _RatingLegendRow(
            color: AppColors.red,
            label: 'Red',
            detail: 'Below 50 or a critical override',
          ),
          const SizedBox(height: 6),
          const Text(
            'Not scored means the report does not publish that data.',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          _PopularSaccos(onOpenDirectory: () => onNavigate(1), directory: directory),
        ],
      ),
    );
  }
}

class _DirectorySummary extends StatelessWidget {
  const _DirectorySummary({required this.onTap, required this.directory});

  final VoidCallback onTap;
  final Future<List<SaccoRecord>> directory;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SaccoRecord>>(
      future: directory,
      builder: (context, snapshot) {
        final count = snapshot.data?.length;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.charcoal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_rounded, color: AppColors.lime, size: 30),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        count == null ? 'SACCO directory' : '$count SACCOs listed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Browse scores and financial indicators',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.lime),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HomeActionTile extends StatelessWidget {
  const _HomeActionTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.background,
    required this.foreground,
    required this.iconBackground,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String detail;
  final Color background;
  final Color foreground;
  final Color iconBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppColors.charcoal, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingLegendRow extends StatelessWidget {
  const _RatingLegendRow({
    required this.color,
    required this.label,
    required this.detail,
  });

  final Color color;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 58,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(detail, style: const TextStyle(color: AppColors.muted)),
          ),
        ],
      ),
    );
  }
}

class _PopularSaccos extends StatelessWidget {
  const _PopularSaccos({required this.onOpenDirectory, required this.directory});

  final VoidCallback onOpenDirectory;
  final Future<List<SaccoRecord>> directory;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SaccoRecord>>(
      future: directory,
      builder: (context, snapshot) {
        final saccos = snapshot.data?.take(3).toList() ?? const <SaccoRecord>[];
        if (saccos.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'From the directory',
                    style: TextStyle(
                      color: Color(0xFF18312D),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(onPressed: onOpenDirectory, child: const Text('See all')),
              ],
            ),
            for (final sacco in saccos)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(sacco.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(sacco.county ?? 'County not listed'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 15),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => SaccoProfileScreen(sacco: sacco),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class MemberAccountScreen extends StatelessWidget {
  const MemberAccountScreen({
    super.key,
    required this.account,
    required this.onLogout,
  });

  final MemberAccount account;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: const Color(0xFFDCEFE9),
            child: Text(
              account.fullName.isEmpty ? 'M' : account.fullName[0].toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF126B5B),
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            account.fullName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF18312D),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            account.email,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF638078)),
          ),
          const SizedBox(height: 30),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Member account'),
            subtitle: Text('Role: ${account.role}'),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

void showRatingGuide(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Understanding the ratings',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Composite ratings combine the PEARLS dimensions that have available data.',
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            const _RatingLegendRow(color: Color(0xFF24866B), label: 'Green', detail: '75 or higher, unless a regulatory breach caps the rating.'),
            const _RatingLegendRow(color: Color(0xFFB78020), label: 'Amber', detail: '50 to under 75, or capped for a regulatory breach.'),
            const _RatingLegendRow(color: Color(0xFFC44F43), label: 'Red', detail: 'Below 50, negative core capital, or NPL above 25%.'),
            const SizedBox(height: 12),
            const Text(
              'Indicator colors use their own thresholds. “Not scored” means a report does not publish that SACCO-level data; it is not the same as Red.',
              style: TextStyle(
                color: AppColors.muted,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}