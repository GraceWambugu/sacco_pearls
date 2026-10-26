import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pearls_radar.dart';
import '../widgets/rating.dart';

typedef CompareLoader = Future<CompareResult> Function(List<int> saccoIds);
typedef PickerSearch = Future<List<SaccoRecord>> Function(String query, {String? county});

const _dimensionOrder = ['P', 'E', 'A', 'R', 'L', 'S'];

/// The Compare tab: 2 or 3 SACCOs side by side, with a rank, a radar chart of
/// the four scored PEARLS dimensions, and a row-by-row breakdown.
class CompareScreen extends StatefulWidget {
  const CompareScreen({
    super.key,
    this.onBrowse,
    this.compareLoader = ApiService.compareSaccos,
    this.searchLoader = ApiService.searchSaccos,
  });

  /// Opens the Search tab.
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
      backgroundColor: AppColors.surface,
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
      appBar: AppBar(
        title: const Text('Compare SACCOs'),
        actions: [
          if (picks.count > 0) TextButton(onPressed: picks.clear, child: const Text('Clear all')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _PickedSaccos(picks: picks, onAdd: _openPicker),
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
                    child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
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
    );
  }
}

/// The 2-3 chosen SACCOs as small cards, each with its chart colour and a remove button.
class _PickedSaccos extends StatelessWidget {
  const _PickedSaccos({required this.picks, required this.onAdd});

  final CompareProvider picks;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'YOUR PICKS · ${picks.count} OF ${CompareProvider.maxSaccos}',
          style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final (index, sacco) in picks.selected.indexed)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.line),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.compareSeries[index],
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: AppColors.paper, fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
              title: Text(sacco.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(sacco.county ?? 'County not listed'),
              trailing: IconButton(
                tooltip: 'Remove ${sacco.name}',
                onPressed: () => picks.remove(sacco.id),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        if (!picks.isFull)
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(picks.count == 0 ? 'Add a SACCO' : 'Add another SACCO'),
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
          ),
      ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Icon(Icons.compare_arrows_rounded, size: 36, color: AppColors.forest),
          const SizedBox(height: 10),
          Text(
            count == 0 ? 'Pick 2 or 3 SACCOs to compare' : 'Pick 1 more SACCO to compare',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Use "Add a SACCO" above, the + button on the Search tab, '
            'or "Add to compare" on any SACCO profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.35),
          ),
          if (onBrowse != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onBrowse,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Go to Search'),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(unreachable ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 36, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(
            unreachable ? 'Could not reach the server' : 'These SACCOs could not be compared',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            unreachable ? 'Check your internet connection, then try again.' : '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// Everything shown once the comparison has loaded.
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
        Text(
          'Compared on ${result.year} figures, the latest year all of them have.',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (index, score) in results.indexed) ...[
                if (index > 0) const SizedBox(width: 8),
                Expanded(child: _ScoreColumn(result: result, score: score, color: AppColors.compareSeries[index])),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Heading('PEARLS shape'),
        const Text(
          'Further out is healthier. Each colour matches a SACCO above.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
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
        const SizedBox(height: 4),
        _Note(
          'Protection (P) and Liquidity (L) are not on the chart: SASRA does not publish '
          'the figures they need for each SACCO, so they are not scored.',
        ),
        if (missingGrowth.isNotEmpty)
          _Note(
            'No growth (S) score for ${missingGrowth.join(' and ')}: there are no figures '
            'for the year before, so it is drawn at 0 on the chart.',
          ),
        const SizedBox(height: 22),
        const _Heading('Dimension by dimension'),
        const Text(
          'The highest score in each row is highlighted.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        for (final code in _dimensionOrder) _DimensionCompareRow(code: code, results: results),
        const SizedBox(height: 20),
        const Text(
          'Ratings describe the figures SASRA published. They do not predict whether a SACCO '
          'will fail and are not financial advice.',
          style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

/// One SACCO's column: its colour, rank, name, composite and rating word.
class _ScoreColumn extends StatelessWidget {
  const _ScoreColumn({required this.result, required this.score, required this.color});

  final CompareResult result;
  final SaccoScore score;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final rank = result.rankOf(score);
    final rankText = rank == null
        ? 'Not ranked'
        : '${result.isTied(score) ? 'Joint ' : ''}${_ordinal(rank)} of ${result.results.length}';
    final isBest = rank == 1;
    final composite = score.composite;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isBest ? color : AppColors.line, width: isBest ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 6, margin: const EdgeInsets.only(bottom: 10), color: color),
          Row(
            children: [
              if (isBest) const Icon(Icons.emoji_events_rounded, size: 16, color: AppColors.amber),
              if (isBest) const SizedBox(width: 4),
              Flexible(
                child: Text(
                  rankText,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            score.sacco?.name ?? 'SACCO',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
          ),
          const Spacer(),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              composite == null ? '—' : composite.toDouble().toStringAsFixed(1),
              style: const TextStyle(color: AppColors.ink, fontSize: 30, fontWeight: FontWeight.w800, height: 1),
            ),
          ),
          const Text('out of 100', style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RatingChip(rating: composite == null ? null : score.rating),
          ),
        ],
      ),
    );
  }
}

/// One PEARLS dimension across the 2-3 SACCOs, with the best score highlighted.
class _DimensionCompareRow extends StatelessWidget {
  const _DimensionCompareRow({required this.code, required this.results});

  final String code;
  final List<SaccoScore> results;

  @override
  Widget build(BuildContext context) {
    final dimensions = [for (final r in results) r.dimensions[code]];
    final name = dimensions.firstWhere((d) => d != null, orElse: () => null)?.name ?? code;
    final scores = [for (final d in dimensions) (d?.scored ?? false) ? d!.score : null];
    final scored = scores.whereType<num>().toList();
    // Highlight only when there is something to choose between.
    final best = scored.isEmpty || scored.toSet().length == 1 && scored.length == results.length
        ? null
        : scored.reduce((a, b) => a > b ? a : b);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$code · $name', style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (scored.isEmpty)
            const Text('Not available for any SACCO', style: TextStyle(color: AppColors.muted))
          else
            Row(
              children: [
                for (final (index, score) in scores.indexed) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _ScoreCell(
                      score: score,
                      color: AppColors.compareSeries[index],
                      highlighted: best != null && score == best,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  const _ScoreCell({required this.score, required this.color, required this.highlighted});

  final num? score;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final value = score;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.accentSoft : AppColors.paper,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: value == null
          ? const Text('Not available', style: TextStyle(color: AppColors.muted, fontSize: 12))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatNumber(value),
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: highlighted ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                Text(bandForScore(value), style: const TextStyle(color: AppColors.muted, fontSize: 11)),
              ],
            ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: AppColors.ink, fontSize: 19, fontWeight: FontWeight.w800));
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
              decoration: InputDecoration(
                hintText: 'Search by SACCO name',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<SaccoRecord>>(
              future: _results,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.forest));
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
                        color: picked ? AppColors.forest : AppColors.muted,
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

String _ordinal(int n) => switch (n) { 1 => '1st', 2 => '2nd', 3 => '3rd', _ => '${n}th' };
