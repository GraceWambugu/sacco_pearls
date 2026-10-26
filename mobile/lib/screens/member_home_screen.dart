import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth_user.dart';
import '../models/directory_request.dart';
import '../models/sacco.dart';
import '../providers/compare_provider.dart';
import '../providers/saved_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';
import 'sacco_profile_screen.dart';

// Tab numbers, matching AppShell (Home 0, Directory 1, Compare 2, Trends 3).
const _compareTab = 2;
const _trendsTab = 3;

/// The Home tab: welcome hero with search, quick actions, the top-scoring
/// SACCOs from /rankings, and a plain-language guide to PEARLS.
class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({
    super.key,
    required this.account,
    required this.rankings,
    required this.onNavigate,
    required this.onOpenDirectory,
    this.onOpenAccount,
    this.onOpenSaved,
  });

  /// Null when nobody is signed in.
  final MemberAccount? account;
  final Future<List<RankedSacco>> rankings;
  final ValueChanged<int> onNavigate;
  final ValueChanged<DirectoryRequest> onOpenDirectory;
  final VoidCallback? onOpenAccount;
  final VoidCallback? onOpenSaved;

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  final _explainerKey = GlobalKey(); // lets the "PEARLS score" tile scroll down to the guide
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchDirectory() =>
      widget.onOpenDirectory(DirectoryRequest(query: _searchController.text.trim()));

  void _showExplainer() {
    final target = _explainerKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compareCount = context.watch<CompareProvider>().count;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<List<RankedSacco>>(
          future: widget.rankings,
          builder: (context, snapshot) {
            final ranked = snapshot.data ?? const <RankedSacco>[];
            final year = ranked.isEmpty ? null : ranked.first.year;
            // A Column inside a scroll view (not a lazy ListView) so the
            // "PEARLS score" tile can always scroll to the guide at the bottom.
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    year: year,
                    signedIn: widget.account != null,
                    onOpenSaved: widget.onOpenSaved,
                    onOpenAccount: widget.onOpenAccount,
                  ),
                  const SizedBox(height: 16),
                  _Hero(
                    controller: _searchController,
                    onSearch: _searchDirectory,
                    onQuickFilter: widget.onOpenDirectory,
                  ),
                  const SizedBox(height: 20),
                  _QuickActions(
                    compareCount: compareCount,
                    onSearch: () => widget.onOpenDirectory(const DirectoryRequest()),
                    onCompare: () => widget.onNavigate(_compareTab),
                    onTrends: () => widget.onNavigate(_trendsTab),
                    onExplain: _showExplainer,
                  ),
                  const SizedBox(height: 28),
                  _TopPerforming(
                    snapshot: snapshot,
                    onViewAll: () => widget.onOpenDirectory(const DirectoryRequest()),
                  ),
                  const SizedBox(height: 28),
                  _PearlsExplainer(key: _explainerKey),
                  const SizedBox(height: 24),
                  const _Footer(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Logo, app name and the data year, with Saved and Account on the right.
class _Header extends StatelessWidget {
  const _Header({required this.year, required this.signedIn, this.onOpenSaved, this.onOpenAccount});

  final int? year;
  final bool signedIn;
  final VoidCallback? onOpenSaved;
  final VoidCallback? onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final savedCount = context.watch<SavedProvider>().saccos.length;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF2DD4BF)]),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
            child: const Text(
              'SL',
              style: TextStyle(color: AppColors.highlight, fontWeight: FontWeight.w900, fontSize: 14),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('SACCOLens', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                year == null ? 'PEARLS benchmarking · Kenya' : '$year SASRA data · Kenya',
                style: const TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Saved SACCOs',
          onPressed: onOpenSaved,
          icon: Badge(
            isLabelVisible: savedCount > 0,
            label: Text('$savedCount'),
            child: const Icon(Icons.bookmark_border_rounded),
          ),
        ),
        IconButton(
          tooltip: signedIn ? 'Account' : 'Sign in',
          onPressed: onOpenAccount,
          icon: Icon(signedIn ? Icons.person_rounded : Icons.login_rounded),
        ),
      ],
    );
  }
}

/// The big welcome card: pill, headline, explanation, search bar and quick-filter chips.
class _Hero extends StatelessWidget {
  const _Hero({required this.controller, required this.onSearch, required this.onQuickFilter});

  final TextEditingController controller;
  final VoidCallback onSearch;
  final ValueChanged<DirectoryRequest> onQuickFilter;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface, AppColors.surface, Color(0xFF0A2620)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.line),
        ),
        child: Stack(
          children: [
            // Two soft glows in the corners, as in the design.
            const Positioned(top: -60, right: -60, child: _Glow(color: Color(0xFF10B981))),
            const Positioned(bottom: -70, left: 60, child: _Glow(color: Color(0xFF14B8A6))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.25)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.highlight),
                        SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'PEARLS decision-support system',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: AppColors.highlight, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.2),
                      children: [
                        const TextSpan(text: 'Jambo! Choose the right '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: ShaderMask(
                            // Emerald-to-teal text, like the design's gradient headline.
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [Color(0xFF34D399), Color(0xFF5EEAD4)],
                            ).createShader(bounds),
                            child: const Text(
                              'Kenyan SACCO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const TextSpan(text: ' with confidence.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Turning SASRA's published supervision reports into plain-English health scores. "
                    'Compare capital strength, loan quality and growth before you join.',
                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => onSearch(),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search SACCO by name, e.g. Stima',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      fillColor: AppColors.paper.withValues(alpha: 0.9),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      suffixIcon: Padding(
                        padding: const EdgeInsets.all(6),
                        child: FilledButton(
                          onPressed: onSearch,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Explore', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Quick filters:', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                      _QuickChip(label: 'All', selected: true, onTap: () => onQuickFilter(const DirectoryRequest())),
                      _QuickChip(
                        label: 'Top rated',
                        onTap: () => onQuickFilter(const DirectoryRequest(quickFilter: QuickFilter.topRated)),
                      ),
                      _QuickChip(
                        label: 'Low NPL',
                        onTap: () => onQuickFilter(const DirectoryRequest(quickFilter: QuickFilter.lowNpl)),
                      ),
                      _QuickChip(
                        label: 'Nairobi',
                        onTap: () => onQuickFilter(const DirectoryRequest(county: 'Nairobi')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap, this.selected = false});

  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.green : AppColors.raised.withValues(alpha: 0.8),
      shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.green : const Color(0xFF334155))),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.paper : const Color(0xFFCBD5E1),
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// The 2 x 2 grid of shortcut tiles.
class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.compareCount,
    required this.onSearch,
    required this.onCompare,
    required this.onTrends,
    required this.onExplain,
  });

  final int compareCount;
  final VoidCallback onSearch;
  final VoidCallback onCompare;
  final VoidCallback onTrends;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _ActionTile(
        icon: Icons.search_rounded,
        color: AppColors.highlight,
        title: 'Search & filter',
        detail: 'Filter by county and rating',
        onTap: onSearch,
      ),
      _ActionTile(
        icon: Icons.balance_rounded,
        color: const Color(0xFF60A5FA),
        title: 'Compare (up to 3)',
        detail: 'Side-by-side PEARLS overlays',
        badge: compareCount > 0 ? '$compareCount active' : null,
        onTap: onCompare,
      ),
      _ActionTile(
        icon: Icons.trending_up_rounded,
        color: const Color(0xFFFBBF24),
        title: 'Trends',
        detail: 'Scores and figures by year',
        onTap: onTrends,
      ),
      _ActionTile(
        icon: Icons.layers_rounded,
        color: const Color(0xFFC084FC),
        title: 'PEARLS score',
        detail: 'Learn how scores are worked out',
        onTap: onExplain,
      ),
    ];
    return Column(
      children: [
        for (var row = 0; row < tiles.length; row += 2) ...[
          if (row > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[row]),
                const SizedBox(width: 12),
                Expanded(child: tiles[row + 1]),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBox(icon: icon, color: color),
                  const Spacer(),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
                      child: Text(
                        badge!,
                        style: const TextStyle(color: AppColors.paper, fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Top performing institutions": the three highest scores from /rankings.
class _TopPerforming extends StatelessWidget {
  const _TopPerforming({required this.snapshot, required this.onViewAll});

  final AsyncSnapshot<List<RankedSacco>> snapshot;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final ranked = snapshot.data ?? const <RankedSacco>[];
    final top = ranked.take(3).toList();
    final year = ranked.isEmpty ? null : ranked.first.year;

    final Widget body;
    if (snapshot.connectionState == ConnectionState.waiting) {
      body = const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (snapshot.hasError) {
      body = const Panel(
        child: Text(
          'Could not reach the server to load the top SACCOs. Check your connection and reopen the app.',
          style: TextStyle(color: AppColors.muted),
        ),
      );
    } else {
      body = Column(
        children: [
          for (final item in top)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TopSaccoCard(item: item, ranked: ranked),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.emoji_events_outlined, color: AppColors.highlight, size: 20),
                      SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Top performing institutions',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    year == null
                        ? 'Based on PEARLS-aligned health scores'
                        : 'Based on PEARLS-aligned scores from $year figures',
                    style: const TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('View all'), Icon(Icons.chevron_right_rounded, size: 18)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        body,
      ],
    );
  }
}

class _TopSaccoCard extends StatelessWidget {
  const _TopSaccoCard({required this.item, required this.ranked});

  final RankedSacco item;
  final List<RankedSacco> ranked;

  @override
  Widget build(BuildContext context) {
    final picks = context.watch<CompareProvider>();
    final picked = picks.contains(item.sacco.id);
    // Many SACCOs score exactly 100, so equal scores share a rank.
    final rank = 1 + ranked.where((other) => other.composite > item.composite).length;
    final tied = ranked.where((other) => other.composite == item.composite).length > 1;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        tied ? 'JOINT #$rank' : '#$rank',
                        style: const TextStyle(
                          color: AppColors.highlight,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(item.sacco.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined, size: 13, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Text(
                          item.sacco.county == null ? 'County not listed' : '${item.sacco.county} County',
                          style: const TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ScoreBadge(composite: item.composite, rating: item.rating),
            ],
          ),
          const SizedBox(height: 12),
          FigureStrip(figures: [
            Figure('Asset base', kesBillions(item.totalAssets)),
            Figure('NPL ratio', percent(item.nplRatio)),
            Figure('Core capital', percent(item.cca), emphasis: true),
          ]),
          const Divider(height: 24),
          Row(
            children: [
              CompareToggle(
                picked: picked,
                compact: true,
                onPressed: () {
                  if (picked) {
                    picks.remove(item.sacco.id);
                  } else if (!picks.add(item.sacco)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Compare already has three SACCOs. Remove one first.')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => SaccoProfileScreen(sacco: item.sacco)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: Text('Full profile', overflow: TextOverflow.ellipsis)),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Understanding the PEARLS framework": what each letter means here, and its threshold.
class _PearlsExplainer extends StatelessWidget {
  const _PearlsExplainer({super.key});

  static const _dimensions = [
    _Dimension('P', 'Protection', 'Not scored', Color(0xFF34D399),
        'Loan-loss provisions set aside against bad loans. SASRA does not publish them for each SACCO, '
            'so this app cannot score Protection.'),
    _Dimension('E', 'Effective financial structure', 'SASRA min: 10% core capital', Color(0xFF60A5FA),
        'Core and institutional capital against assets and deposits, and external borrowing '
            '(at most 25% of assets). Green means comfortably above the SASRA limits.'),
    _Dimension('A', 'Asset quality', 'Green: NPL 5% or less', Color(0xFFFBBF24),
        'Non-performing loans as a share of the loan book. A lower figure means fewer members '
            'are behind on repayments.'),
    _Dimension('R', 'Rates of return and costs', 'Compared with peers', Color(0xFFC084FC),
        'Total income against total assets, compared with the middle SACCO that year. '
            'A rough guide to returns, because SASRA does not publish surplus per SACCO.'),
    _Dimension('L', 'Liquidity', 'Not scored', Color(0xFF2DD4BF),
        'Cash available to pay out withdrawals. SASRA published a liquidity ratio per SACCO only in '
            'its 2022 report, so it is shown where available but not scored.'),
    _Dimension('S', 'Signs of growth', 'Green: growth above inflation', Color(0xFFFB7185),
        'Year-on-year growth in assets, deposits and loans, compared with inflation. '
            'Needs the previous year, so the first year loaded has no growth score.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'METHODOLOGY',
            style: TextStyle(color: AppColors.highlight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
          ),
          const SizedBox(height: 4),
          const Text(
            'Understanding the PEARLS framework',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text(
            'PEARLS was designed by the World Council of Credit Unions (WOCCU). This app applies it '
            'to the figures SASRA publishes for each deposit-taking SACCO.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _LegendPill(color: AppColors.green, text: '75–100: Green'),
              _LegendPill(color: AppColors.amber, text: '50–74.9: Amber'),
              _LegendPill(color: AppColors.red, text: 'Below 50: Red'),
            ],
          ),
          const Divider(height: 28),
          for (final dimension in _dimensions) ...[
            _DimensionCard(dimension: dimension),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Dimension {
  const _Dimension(this.code, this.name, this.threshold, this.color, this.description);

  final String code;
  final String name;
  final String threshold;
  final Color color;
  final String description;
}

class _DimensionCard extends StatelessWidget {
  const _DimensionCard({required this.dimension});

  final _Dimension dimension;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dimension.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  dimension.code,
                  style: TextStyle(color: dimension.color, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  dimension.threshold,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(dimension.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 4),
          Text(dimension.description, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'SACCOLens · Final-year project · PEARLS benchmarking, Kenya',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
        ),
        SizedBox(height: 4),
        Text(
          'Data: SASRA Annual Supervision Reports. Scores describe published figures; '
          'they are not financial advice.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF475569), fontSize: 10),
        ),
      ],
    );
  }
}
