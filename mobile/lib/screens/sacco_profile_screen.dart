import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/auth_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/saved_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/pearls_radar.dart';
import '../widgets/rating.dart';
import '../widgets/summary.dart';
import '../widgets/ui.dart';
import 'app_shell.dart';

typedef ScoreLoader = Future<SaccoScore> Function(int saccoId, {int? year});
typedef TrendLoader = Future<List<TrendPoint>> Function(int saccoId);

/// One SACCO's health profile: header with the score, a plain summary, the
/// radar, every SASRA ratio used, the six PEARLS rows, notes and the disclaimer.
class SaccoProfileScreen extends StatefulWidget {
  const SaccoProfileScreen({
    super.key,
    required this.sacco,
    this.scoreLoader = ApiService.getScore,
    this.trendLoader = ApiService.getTrend,
  });

  final SaccoRecord sacco;

  /// Tests pass fake loaders; the app uses the real API.
  final ScoreLoader scoreLoader;
  final TrendLoader trendLoader;

  @override
  State<SaccoProfileScreen> createState() => _SaccoProfileScreenState();
}

class _SaccoProfileScreenState extends State<SaccoProfileScreen> {
  late Future<SaccoScore> _score;
  List<int> _years = const []; // years with figures, for the year selector
  int? _year; // null means "latest"
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _score = widget.scoreLoader(widget.sacco.id);
    _loadYears();
  }

  Future<void> _loadYears() async {
    try {
      final trend = await widget.trendLoader(widget.sacco.id);
      if (mounted) setState(() => _years = trend.map((p) => p.year).toList());
    } catch (_) {
      // Without the year list the screen still shows the latest year.
    }
  }

  void _selectYear(int year) {
    setState(() {
      _year = year;
      _score = widget.scoreLoader(widget.sacco.id, year: year);
    });
  }

  void _retry() {
    setState(() {
      _score = widget.scoreLoader(widget.sacco.id, year: _year);
    });
    if (_years.isEmpty) _loadYears();
  }

  Future<void> _toggleSaved() async {
    // Saving needs an account; viewing does not.
    if (!context.read<AuthProvider>().isSignedIn) {
      await openAccount(context);
      return;
    }
    final saved = context.read<SavedProvider>();
    setState(() => _saving = true);
    try {
      await saved.toggle(widget.sacco);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(saved.isSaved(widget.sacco.id) ? 'Added to saved SACCOs' : 'Removed from saved SACCOs'),
      ));
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleCompare() {
    final picks = context.read<CompareProvider>();
    final String message;
    if (picks.contains(widget.sacco.id)) {
      picks.remove(widget.sacco.id);
      message = 'Removed from compare';
    } else if (picks.add(widget.sacco)) {
      message = 'Added to compare (${picks.count} of ${CompareProvider.maxSaccos}). '
          'Open the Compare tab to see them side by side.';
    } else {
      message = 'Compare already has three SACCOs. Remove one first.';
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<SaccoScore>(
          future: _score,
          builder: (context, snapshot) {
            final back = Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(foregroundColor: AppColors.muted),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back'),
              ),
            );
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Column(children: [back, const Expanded(child: Center(child: CircularProgressIndicator()))]);
            }
            if (snapshot.hasError) {
              return Column(children: [
                back,
                Expanded(child: _ProfileUnavailable(sacco: widget.sacco, error: snapshot.error, onRetry: _retry)),
              ]);
            }
            final score = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                back,
                _HeaderCard(
                  sacco: widget.sacco,
                  score: score,
                  years: _years,
                  onSelectYear: _selectYear,
                ),
                const SizedBox(height: 12),
                _Actions(
                  inCompare: context.watch<CompareProvider>().contains(widget.sacco.id),
                  isSaved: context.watch<SavedProvider>().isSaved(widget.sacco.id),
                  saving: _saving,
                  onToggleCompare: _toggleCompare,
                  onToggleSaved: _toggleSaved,
                ),
                if (score.overrides.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Notice(
                    icon: Icons.gavel_rounded,
                    color: ratingColor(score.rating),
                    title: 'Rating adjusted',
                    lines: score.overrides,
                  ),
                ],
                const SizedBox(height: 16),
                _RadarCard(score: score),
                const SizedBox(height: 16),
                _RatiosCard(score: score),
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'PEARLS breakdown',
                  trailing: '${score.dimensionsScored} OF ${score.dimensionsTotal} SCORED',
                ),
                const Text(
                  'Tap a row to see the figures and how each one is rated.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
                const SizedBox(height: 6),
                for (final dimension in score.dimensions.values) _DimensionRow(dimension: dimension),
                if (score.flags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _Notice(
                    icon: Icons.info_outline_rounded,
                    color: AppColors.muted,
                    title: 'Notes on the data',
                    lines: [for (final flag in score.flags) _flagText(flag)],
                  ),
                ],
                const SizedBox(height: 24),
                const _Disclaimer(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Plain-language meaning of each data flag the API can send.
String _flagText(String flag) {
  switch (flag) {
    case 'stale':
      return 'SASRA marked these figures with an asterisk: they may be carried over from an earlier year.';
    case 'anomaly':
      return "SASRA's table shows total assets below gross loans, which is not possible, so some figures may be wrong.";
    case 'limited':
      return 'Fewer than four PEARLS dimensions could be scored, so this rating rests on less evidence.';
    default:
      return flag;
  }
}

/// Name, county, the score box with the rating word, the year chips and the summary.
class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.sacco, required this.score, required this.years, required this.onSelectYear});

  final SaccoRecord sacco;
  final SaccoScore score;
  final List<int> years;
  final ValueChanged<int> onSelectYear;

  @override
  Widget build(BuildContext context) {
    final composite = score.composite;
    final rated = composite != null;
    return Panel(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.green.withValues(alpha: 0.2)),
            ),
            child: const Text(
              'DEPOSIT-TAKING SACCO',
              style: TextStyle(color: AppColors.highlight, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(height: 6),
          Text(sacco.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.15)),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.place_outlined, size: 14, color: AppColors.muted),
              const SizedBox(width: 3),
              Text(
                sacco.county == null ? 'County not listed' : '${sacco.county} County',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const Text('  •  Licensed by SASRA', style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          // The score box: big composite, "/100", and the rating word on its colour.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                            text: rated ? composite.toDouble().toStringAsFixed(1) : '—',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, height: 1),
                          ),
                          const TextSpan(text: ' /100', style: TextStyle(color: AppColors.muted, fontSize: 14)),
                        ])),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PEARLS composite · ${score.year}',
                        style: const TextStyle(color: AppColors.highlight, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: rated ? ratingColor(score.rating) : AppColors.raised,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    rated ? '${score.rating} rating' : 'Not rated',
                    style: TextStyle(
                      color: rated ? AppColors.paper : AppColors.muted,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (years.length > 1) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Year', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
                for (final year in years.reversed) // newest first
                  ChoiceChip(
                    label: Text('$year'),
                    selected: year == score.year,
                    onSelected: (_) => onSelectYear(year),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Plain-language summary',
                  style: TextStyle(color: AppColors.highlight, fontWeight: FontWeight.w800, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  plainSummary(sacco.name, score),
                  style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.inCompare,
    required this.isSaved,
    required this.saving,
    required this.onToggleCompare,
    required this.onToggleSaved,
  });

  final bool inCompare;
  final bool isSaved;
  final bool saving;
  final VoidCallback onToggleCompare;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: CompareToggle(picked: inCompare, onPressed: onToggleCompare)),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving ? null : onToggleSaved,
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
            icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined, size: 18),
            label: Text(isSaved ? 'Saved' : 'Save SACCO', style: const TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}

/// "PEARLS dimension radar" card: one shape for this SACCO on the four scored axes.
class _RadarCard extends StatelessWidget {
  const _RadarCard({required this.score});

  final SaccoScore score;

  @override
  Widget build(BuildContext context) {
    return Panel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('PEARLS dimension radar'),
          const SizedBox(height: 8),
          PearlsRadar(series: [
            RadarSeries(
              color: AppColors.highlight,
              scores: {for (final code in radarAxes) code: score.dimensions[code]?.score},
            ),
          ]),
          const SizedBox(height: 6),
          const Text(
            'Further out is healthier. Protection (P) and Liquidity (L) are not on the chart because '
            'SASRA does not publish the figures they need for each SACCO.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// "SASRA financial ratios": every figure the score used, with its band word.
class _RatiosCard extends StatelessWidget {
  const _RatiosCard({required this.score});

  final SaccoScore score;

  @override
  Widget build(BuildContext context) {
    final indicators = [
      for (final code in const ['E', 'A', 'R', 'S']) ...?score.dimensions[code]?.indicators,
    ];
    return Panel(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle('SASRA financial ratios · ${score.year}'),
          const SizedBox(height: 10),
          if (indicators.isEmpty)
            const Text('No figures were published for this year.', style: TextStyle(color: AppColors.muted)),
          for (final indicator in indicators)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(indicator.label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    indicator.value == null ? 'Missing' : '${formatNumber(indicator.value!)}${indicator.unit ?? ''}',
                    style: TextStyle(
                      color: indicator.band == null ? AppColors.muted : ratingColor(indicator.band),
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 46,
                    child: Text(
                      indicator.band ?? '—',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800))),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w800),
          ),
      ],
    );
  }
}

/// One PEARLS dimension: a score bar, or "Not available" with the reason.
class _DimensionRow extends StatelessWidget {
  const _DimensionRow({required this.dimension});

  final PearlsDimension dimension;

  @override
  Widget build(BuildContext context) {
    final score = dimension.score;
    final scored = dimension.scored && score != null;
    final band = scored ? bandForScore(score) : null;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedIconColor: AppColors.muted,
        iconColor: AppColors.highlight,
        tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scored ? AppColors.accentSoft : AppColors.paper,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dimension.code,
            style: TextStyle(
              color: scored ? AppColors.highlight : AppColors.muted,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(dimension.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: scored
              ? Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (score / 100).clamp(0.0, 1.0).toDouble(),
                          minHeight: 8,
                          backgroundColor: AppColors.raised,
                          color: ratingColor(band),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text('${formatNumber(score)} · $band', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                )
              : const Text(
                  'Not available',
                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13),
                ),
        ),
        children: [
          if (dimension.reason != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                scored ? dimension.reason! : 'Why: ${dimension.reason!}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
              ),
            ),
          for (final indicator in dimension.indicators) _IndicatorRow(indicator: indicator),
        ],
      ),
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({required this.indicator});

  final PearlsIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final value = indicator.value;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(indicator.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              Text(
                value == null ? 'Missing' : '${formatNumber(value)}${indicator.unit ?? ''}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 8),
              RatingChip(rating: indicator.band),
            ],
          ),
          if (indicator.rule != null) ...[
            const SizedBox(height: 4),
            Text(
              'How it is rated: ${indicator.rule}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }
}

/// A boxed list of sentences, used for rating adjustments and data notes.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.title, required this.lines});

  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('• $line', style: const TextStyle(fontSize: 13, height: 1.35)),
            ),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Ratings describe the figures SASRA published for this year. They do not predict '
      'whether a SACCO will fail and are not financial advice. Protection and Liquidity are '
      'not scored because SASRA does not publish the figures they need for each SACCO.',
      style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({required this.sacco, required this.error, required this.onRetry});

  final SaccoRecord sacco;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final unreachable = error is ApiException && (error as ApiException).isUnreachable;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(unreachable ? Icons.wifi_off_rounded : Icons.query_stats_rounded, size: 40, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              unreachable ? 'Could not reach the server' : sacco.name,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              unreachable
                  ? 'Check your internet connection, then try again.'
                  : 'No score is available for this SACCO yet. $error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
