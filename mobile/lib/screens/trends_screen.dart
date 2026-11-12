import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/compare_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/rating.dart';
import '../widgets/ui.dart';

typedef TrendsLoader = Future<List<TrendPoint>> Function(int saccoId);
typedef TrendsSearch = Future<List<SaccoRecord>> Function(String query, {String? county});

/// The figures a member can follow over the years.
enum TrendMetric {
  score('PEARLS health score', '', 'PEARLS health score'),
  npl('NPL ratio', '%', 'NPL ratio'),
  cca('Core capital / total assets', '%', 'core capital ratio'),
  assets('Total assets', 'KES B', 'total assets'),
  deposits('Total deposits', 'KES B', 'total deposits'),
  loans('Gross loans', 'KES B', 'gross loans');

  const TrendMetric(this.label, this.unit, this.phrase);

  final String label;
  final String unit;

  /// How the metric reads inside a sentence (keeps "NPL" and "PEARLS" in capitals).
  final String phrase;

  num? valueOf(TrendPoint point) => switch (this) {
        TrendMetric.score => point.composite,
        TrendMetric.npl => point.nplRatio,
        TrendMetric.cca => point.cca,
        TrendMetric.assets => point.totalAssets,
        TrendMetric.deposits => point.totalDeposits,
        TrendMetric.loans => point.grossLoans,
      };

  String format(num value) => switch (unit) {
        '%' => '${formatNumber(value)}%',
        'KES B' => 'KES ${value.toStringAsFixed(1)}B',
        _ => '${formatNumber(value)}/100',
      };
}

/// The Trends tab: one SACCO's score or a key figure across every year loaded.
class TrendsScreen extends StatefulWidget {
  const TrendsScreen({
    super.key,
    this.rankings,
    this.trendLoader = ApiService.getTrend,
    this.searchLoader = ApiService.searchSaccos,
  });

  /// Used to pick a sensible first SACCO (the top-ranked one) when nothing is in Compare.
  final Future<List<RankedSacco>>? rankings;
  final TrendsLoader trendLoader;
  final TrendsSearch searchLoader;

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  SaccoRecord? _sacco;
  Future<List<TrendPoint>>? _trend;
  TrendMetric _metric = TrendMetric.score;

  @override
  void initState() {
    super.initState();
    _chooseFirstSacco();
  }

  /// Start with the first SACCO in Compare, otherwise the top-ranked SACCO.
  Future<void> _chooseFirstSacco() async {
    final picks = context.read<CompareProvider>().selected;
    if (picks.isNotEmpty) {
      _select(picks.first);
      return;
    }
    try {
      final ranked = await widget.rankings;
      if (mounted && _sacco == null && ranked != null && ranked.isNotEmpty) _select(ranked.first.sacco);
    } catch (_) {
      // The member can still pick a SACCO by hand.
    }
  }

  void _select(SaccoRecord sacco) {
    setState(() {
      _sacco = sacco;
      _trend = widget.trendLoader(sacco.id);
    });
  }

  Future<void> _openPicker() async {
    final chosen = await showModalBottomSheet<SaccoRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SaccoPicker(searchLoader: widget.searchLoader),
    );
    if (chosen != null) _select(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final sacco = _sacco;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            const Text('Financial trends', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const Text(
              'Year-by-year performance from SASRA supervision reports',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select SACCO', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  OutlinedButton(
                    onPressed: _openPicker,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.paper,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            sacco?.name ?? 'Choose a SACCO',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        const Icon(Icons.expand_more_rounded, size: 20, color: AppColors.muted),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Select metric to explore', style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<TrendMetric>(
                    initialValue: _metric,
                    isExpanded: true,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.ink, fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      fillColor: AppColors.paper,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      for (final metric in TrendMetric.values)
                        DropdownMenuItem(
                          value: metric,
                          child: Text(metric.unit == '%' ? '${metric.label} (%)' : metric.label),
                        ),
                    ],
                    onChanged: (metric) => setState(() => _metric = metric ?? _metric),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (sacco == null)
              const Panel(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Choose a SACCO to see how its figures changed over the years.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              )
            else
              FutureBuilder<List<TrendPoint>>(
                future: _trend,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                  }
                  if (snapshot.hasError) {
                    final error = snapshot.error;
                    final unreachable = error is ApiException && error.isUnreachable;
                    return Panel(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            unreachable ? 'Could not reach the server' : 'Trend unavailable',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                          const SizedBox(height: 10),
                          FilledButton.icon(
                            onPressed: () => _select(sacco),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Try again'),
                          ),
                        ],
                      ),
                    );
                  }
                  final points = snapshot.data ?? const <TrendPoint>[];
                  return _TrendView(sacco: sacco, points: points, metric: _metric);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// The chart card and the written assessment for one SACCO and one metric.
class _TrendView extends StatelessWidget {
  const _TrendView({required this.sacco, required this.points, required this.metric});

  final SaccoRecord sacco;
  final List<TrendPoint> points;
  final TrendMetric metric;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const Panel(
        padding: EdgeInsets.all(28),
        child: Text('No figures are loaded for this SACCO yet.', textAlign: TextAlign.center),
      );
    }
    final years = [for (final p in points) p.year];
    final known = [for (final p in points) if (metric.valueOf(p) != null) p];
    final missing = [for (final p in points) if (metric.valueOf(p) == null) p.year];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(14, 16, 18, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${sacco.name} · ${metric.label}'.toUpperCase(),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      years.length == 1 ? '${years.first}' : '${years.first}–${years.last}',
                      style: const TextStyle(color: AppColors.highlight, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: known.isEmpty
                    ? const Center(
                        child: Text('No figures for this metric', style: TextStyle(color: AppColors.muted)),
                      )
                    : _AreaChart(points: points, metric: metric),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Panel(
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ANALYTICAL ASSESSMENT',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                trendAssessment(sacco.name, points, metric),
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'No ${metric.phrase} for ${missing.join(', ')}'
                  '${metric == TrendMetric.score ? ': the first year loaded has no growth figures, or too little was published to score it' : ': SASRA did not publish it'}. '
                  'The line is broken there rather than guessed.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                ),
              ],
              if (points.any((p) => p.dataStale)) ...[
                const SizedBox(height: 8),
                Text(
                  'SASRA marked the ${[for (final p in points) if (p.dataStale) p.year].join(', ')} figures with an '
                  'asterisk: they may be carried over from an earlier year.',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'Years currently loaded come from the SASRA reports in the database. Past results do not '
                'predict future performance and this is not financial advice.',
                style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A plain sentence describing the change, built only from the figures shown.
String trendAssessment(String name, List<TrendPoint> points, TrendMetric metric) {
  final known = [for (final p in points) if (metric.valueOf(p) != null) p];
  if (known.isEmpty) return 'There are no ${metric.phrase} figures for $name yet.';
  final first = known.first;
  final last = known.last;
  final start = metric.valueOf(first)!;
  final end = metric.valueOf(last)!;
  if (known.length == 1) {
    return "$name's ${metric.phrase} was ${metric.format(end)} in ${last.year}. "
        'Only one year has this figure, so there is no trend yet.';
  }
  final change = end - start;
  final direction = change.abs() < 0.05 ? 'stayed at' : (change > 0 ? 'rose to' : 'fell to');
  var sentence = "$name's ${metric.phrase} $direction ${metric.format(end)} in ${last.year}, "
      'from ${metric.format(start)} in ${first.year}';
  if (direction != 'stayed at') {
    final amount = metric.unit == '%'
        ? '${formatNumber(change.abs())} percentage points'
        : metric.unit == 'KES B'
            ? 'KES ${change.abs().toStringAsFixed(1)}B'
            : '${formatNumber(change.abs())} points';
    sentence += ' (${change > 0 ? 'up' : 'down'} $amount)';
  }
  sentence += '.';
  if (metric == TrendMetric.npl && direction != 'stayed at') {
    sentence += change < 0
        ? ' A falling NPL ratio means fewer loans are in arrears.'
        : ' A rising NPL ratio means more loans are in arrears.';
  }
  if (metric == TrendMetric.score && first.rating != null && last.rating != null) {
    sentence += first.rating == last.rating
        ? ' The rating stayed ${last.rating}.'
        : ' The rating moved from ${first.rating} to ${last.rating}.';
  }
  return sentence;
}

/// Line with a soft gradient underneath; a year with no figure breaks the line.
class _AreaChart extends StatelessWidget {
  const _AreaChart({required this.points, required this.metric});

  final List<TrendPoint> points;
  final TrendMetric metric;

  @override
  Widget build(BuildContext context) {
    final values = [for (final p in points) metric.valueOf(p)?.toDouble()];
    final present = values.whereType<double>().toList();
    final isScore = metric == TrendMetric.score;
    final top = isScore ? 100.0 : present.reduce((a, b) => a > b ? a : b) * 1.15;
    final bottom = isScore ? 0.0 : 0.0;
    final firstYear = points.first.year.toDouble();
    final lastYear = points.last.year.toDouble();

    return LineChart(
      LineChartData(
        minX: firstYear - 0.2,
        maxX: lastYear + 0.2,
        minY: bottom,
        maxY: top == 0 ? 1 : top,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.raised,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spot.x.round()}\n${metric.format(spot.y)}',
                  const TextStyle(color: AppColors.highlight, fontWeight: FontWeight.w700, fontSize: 12),
                ),
            ],
          ),
        ),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.line, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // Only label whole years that have a point.
                if (value != value.roundToDouble() || value < firstYear || value > lastYear) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('${value.round()}', style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min && value != 0) return const SizedBox.shrink();
                return Text(
                  isScore || metric.unit == '%' ? formatNumber(value) : value.toStringAsFixed(0),
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (final (index, point) in points.indexed)
                values[index] == null ? FlSpot.nullSpot : FlSpot(point.year.toDouble(), values[index]!),
            ],
            isCurved: false,
            color: AppColors.green,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.green.withValues(alpha: 0.35), AppColors.green.withValues(alpha: 0)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to choose which SACCO to chart.
class _SaccoPicker extends StatefulWidget {
  const _SaccoPicker({required this.searchLoader});

  final TrendsSearch searchLoader;

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
                  itemBuilder: (context, index) => ListTile(
                    title: Text(saccos[index].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(saccos[index].county ?? 'County not listed'),
                    onTap: () => Navigator.of(context).pop(saccos[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
