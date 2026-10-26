import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pearls_radar.dart';
import '../widgets/rating.dart';
import '../widgets/ui.dart';

typedef CompareLoader = Future<CompareResult> Function(List<int> saccoIds);
typedef PickerSearch = Future<List<SaccoRecord>> Function(String query, {String? county});

/// The Compare tab: the chosen SACCOs as pills, a radar of the four scored
/// PEARLS dimensions, and a table of ranks, scores and key figures.
class CompareScreen extends StatefulWidget {
  const CompareScreen({
    super.key,
    this.onBrowse,
    this.compareLoader = ApiService.compareSaccos,
    this.searchLoader = ApiService.searchSaccos,
  });

  /// Opens the Directory tab.
  final VoidCallback? onBrowse;

  /// Tests pass fake loaders; the app uses the real API.
  final CompareLoader compareLoader;
  final PickerSearch searchLoader;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  late final CompareProvider _picks;
  Future<CompareResult>? _comparison;
  String _comparedKey = ''; // the picks the current result belongs to

  @override
  void initState() {
    super.initState();
    _picks = context.read<CompareProvider>();
    _picks.addListener(_onPicksChanged); // picks can change on any screen
    _comparedKey = _key();
    _comparison = _fetch();
  }

  @override
  void dispose() {
    _picks.removeListener(_onPicksChanged);
    super.dispose();
  }

  String _key() => _picks.selected.map((s) => s.id).join(',');

  /// Compare automatically as soon as there are two or three picks.
  Future<CompareResult>? _fetch() =>
      _picks.canCompare ? widget.compareLoader(_picks.selected.map((s) => s.id).toList()) : null;

  void _onPicksChanged() {
    if (!mounted || _key() == _comparedKey) return;
    setState(() {
      _comparedKey = _key();
      _comparison = _fetch();
    });
  }

  void _retry() {
    setState(() {
      _comparison = _fetch();
    });
  }

  Future<void> _openPicker() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: _picks,
        child: _SaccoPicker(searchLoader: widget.searchLoader),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picks = context.watch<CompareProvider>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Side-by-side comparison', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                      Text(
                        'Compare up to 3 SACCOs on the PEARLS dimensions SASRA data supports',
                        style: TextStyle(color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (picks.count > 0) TextButton(onPressed: picks.clear, child: const Text('Clear all')),
              ],
            ),
            const SizedBox(height: 14),
            _SelectedBar(picks: picks, onAdd: _openPicker),
            const SizedBox(height: 16),
            if (!picks.canCompare)
              _PickPrompt(count: picks.count, onAdd: _openPicker, onBrowse: widget.onBrowse)
            else
              FutureBuilder<CompareResult>(
                future: _comparison,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _CompareError(error: snapshot.error, onRetry: _retry);
                  }
                  return _ComparisonView(result: snapshot.data!);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// "Selected SACCOs for comparison": one pill per pick, plus "Add SACCO".
class _SelectedBar extends StatelessWidget {
  const _SelectedBar({required this.picks, required this.onAdd});

  final CompareProvider picks;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected SACCOs for comparison (${picks.count} of ${CompareProvider.maxSaccos}):',
            style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (index, sacco) in picks.selected.indexed)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 4, 2, 4),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The dot matches this SACCO's colour on the radar and in the table.
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: AppColors.compareSeries[index], shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
                        child: Text(
                          sacco.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove ${sacco.name}',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => picks.remove(sacco.id),
                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              if (!picks.isFull)
                InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 16, color: AppColors.highlight),
                        SizedBox(width: 4),
                        Text(
                          'Add SACCO',
                          style: TextStyle(color: AppColors.highlight, fontSize: 12, fontWeight: FontWeight.w800),
                        ),
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

class _PickPrompt extends StatelessWidget {
  const _PickPrompt({required this.count, required this.onAdd, this.onBrowse});

  final int count;
  final VoidCallback onAdd;
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 24,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          const Icon(Icons.balance_rounded, size: 40, color: Color(0xFF64748B)),
          const SizedBox(height: 10),
          Text(
            count == 0 ? 'Pick 2 or 3 SACCOs to compare' : 'Pick 1 more SACCO to compare',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use "Add SACCO" above, "Add to compare" in the Directory, or the button on any SACCO profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
          if (onBrowse != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Go to Directory'),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompareError extends StatelessWidget {
  const _CompareError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final unreachable = error is ApiException && (error as ApiException).isUnreachable;
    return Panel(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(unreachable ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 36, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            unreachable ? 'Could not reach the server' : 'These SACCOs could not be compared',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            unreachable ? 'Check your internet connection, then try again.' : '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ],
      ),
    );
  }
}

/// The radar card and the comparison table, once the result has loaded.
class _ComparisonView extends StatelessWidget {
  const _ComparisonView({required this.result});

  final CompareResult result;

  @override
  Widget build(BuildContext context) {
    final results = result.results;
    final missingGrowth = [
      for (final score in results)
        if (score.dimensions['S']?.scored != true) score.sacco?.name ?? 'One SACCO',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COMPARATIVE PEARLS RADAR',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
              ),
              Text(
                'Compared on ${result.year} figures, the latest year all of them have.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              PearlsRadar(
                series: [
                  for (final (index, score) in results.indexed)
                    RadarSeries(
                      color: AppColors.compareSeries[index],
                      scores: {for (final code in radarAxes) code: score.dimensions[code]?.score},
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final (index, score) in results.indexed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: AppColors.compareSeries[index], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(score.sacco?.name ?? 'SACCO', style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),
              const _Note(
                'Protection (P) and Liquidity (L) are not on the chart: SASRA does not publish '
                'the figures they need for each SACCO, so they are not scored.',
              ),
              if (missingGrowth.isNotEmpty)
                _Note(
                  'No growth (S) score for ${missingGrowth.join(' and ')}: there are no figures '
                  'for the year before, so it is drawn at 0 on the chart.',
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ComparisonTable(result: result),
        const SizedBox(height: 16),
        const Text(
          'Ratings describe the figures SASRA published. They do not predict whether a SACCO '
          'will fail and are not financial advice.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

/// One row of the comparison table: a label and one value per SACCO.
class _TableRow {
  const _TableRow(this.label, this.values, {this.higherIsBetter = true, this.format = _plain});

  final String label;
  final List<num?> values;
  final bool higherIsBetter;
  final String Function(num value) format;

  static String _plain(num value) => formatNumber(value);
}

/// The indicator table: rank, composite, each dimension and key figures,
/// with the best value in each row highlighted.
class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.result});

  final CompareResult result;

  num? _indicator(SaccoScore score, String code, String key) {
    final dimension = score.dimensions[code];
    if (dimension == null) return null;
    for (final indicator in dimension.indicators) {
      if (indicator.key == key) return indicator.value;
    }
    return null;
  }

  num? _dimension(SaccoScore score, String code) {
    final dimension = score.dimensions[code];
    return (dimension?.scored ?? false) ? dimension!.score : null;
  }

  @override
  Widget build(BuildContext context) {
    final results = result.results;
    String pct(num v) => '${formatNumber(v)}%';
    final rows = [
      _TableRow('E · Structure', [for (final s in results) _dimension(s, 'E')]),
      _TableRow('A · Asset quality', [for (final s in results) _dimension(s, 'A')]),
      _TableRow('R · Returns', [for (final s in results) _dimension(s, 'R')]),
      _TableRow('S · Growth', [for (final s in results) _dimension(s, 'S')]),
      _TableRow('NPL ratio', [for (final s in results) _indicator(s, 'A', 'npl_ratio')], higherIsBetter: false, format: pct),
      _TableRow('Core capital / assets', [for (final s in results) _indicator(s, 'E', 'cca')], format: pct),
      _TableRow('Asset growth', [for (final s in results) _indicator(s, 'S', 'asset_growth')], format: pct),
    ];

    return Panel(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Column(
        children: [
          // Header: one coloured name per SACCO.
          _Line(
            label: const Text('Indicator', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
            cells: [
              for (final (index, score) in results.indexed)
                Text(
                  score.sacco?.name ?? 'SACCO',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.compareSeries[index], fontSize: 11, fontWeight: FontWeight.w800),
                ),
            ],
          ),
          const Divider(height: 16),
          _Line(
            label: const _Label('Rank'),
            cells: [
              for (final score in results)
                Text(
                  _rankText(score),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
            ],
          ),
          const Divider(height: 16),
          _Line(
            label: const _Label('PEARLS composite'),
            cells: [
              for (final score in results)
                Column(
                  children: [
                    Text(
                      score.composite == null ? '—' : '${formatNumber(score.composite!)}/100',
                      style: const TextStyle(color: AppColors.highlight, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(child: RatingChip(rating: score.composite == null ? null : score.rating)),
                  ],
                ),
            ],
          ),
          for (final row in rows) ...[
            const Divider(height: 16),
            _Line(label: _Label(row.label), cells: _cells(row)),
          ],
          const Divider(height: 16),
          _Line(
            label: const _Label('P · Protection\nL · Liquidity'),
            cells: [
              for (final _ in results)
                const Text('Not available', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  String _rankText(SaccoScore score) {
    final rank = result.rankOf(score);
    if (rank == null) return 'Not ranked';
    final ordinal = switch (rank) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${rank}th' };
    return '${result.isTied(score) ? 'Joint ' : ''}$ordinal of ${result.results.length}';
  }

  List<Widget> _cells(_TableRow row) {
    final present = row.values.whereType<num>().toList();
    // Highlight the best value only when there is a real difference to show.
    final best = present.length < 2 || present.toSet().length == 1
        ? null
        : present.reduce((a, b) => (row.higherIsBetter ? a > b : a < b) ? a : b);
    return [
      for (final value in row.values)
        value == null
            ? const Text('—', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted))
            : Container(
                padding: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: value == best ? AppColors.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  row.format(value),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: value == best ? AppColors.highlight : AppColors.ink,
                    fontWeight: value == best ? FontWeight.w900 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
    ];
  }
}

/// A table line: a fixed-width label, then equal columns for the SACCOs.
class _Line extends StatelessWidget {
  const _Line({required this.label, required this.cells});

  final Widget label;
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 96, child: label),
        for (final cell in cells) Expanded(child: Center(child: cell)),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, fontWeight: FontWeight.w700));
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline_rounded, size: 15, color: AppColors.muted),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35))),
        ],
      ),
    );
  }
}

/// Bottom sheet for adding a SACCO without leaving the Compare tab.
class _SaccoPicker extends StatefulWidget {
  const _SaccoPicker({required this.searchLoader});

  final PickerSearch searchLoader;

  @override
  State<_SaccoPicker> createState() => _SaccoPickerState();
}

class _SaccoPickerState extends State<_SaccoPicker> {
  Timer? _debounce;
  late Future<List<SaccoRecord>> _results = widget.searchLoader('');

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _results = widget.searchLoader(value.trim());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final picks = context.watch<CompareProvider>();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: _search,
              decoration: const InputDecoration(
                hintText: 'Search by SACCO name',
                prefixIcon: Icon(Icons.search_rounded),
                fillColor: AppColors.paper,
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SaccoRecord>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('${snapshot.error}', textAlign: TextAlign.center));
                }
                final saccos = snapshot.data ?? const <SaccoRecord>[];
                if (saccos.isEmpty) return const Center(child: Text('No SACCOs found.'));
                return ListView.builder(
                  itemCount: saccos.length,
                  itemBuilder: (context, index) {
                    final sacco = saccos[index];
                    final picked = picks.contains(sacco.id);
                    return ListTile(
                      title: Text(sacco.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(sacco.county ?? 'County not listed'),
                      trailing: Icon(
                        picked ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                        color: picked ? AppColors.highlight : AppColors.muted,
                      ),
                      enabled: picked || !picks.isFull,
                      onTap: () {
                        if (!picked) picks.add(sacco);
                        Navigator.of(context).pop();
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
