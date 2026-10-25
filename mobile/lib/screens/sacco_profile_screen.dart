import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sacco.dart';
import '../providers/auth_provider.dart';
import '../providers/compare_provider.dart';
import '../providers/saved_provider.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/rating.dart';
import 'app_shell.dart';

typedef ScoreLoader = Future<SaccoScore> Function(int saccoId, {int? year});
typedef TrendLoader = Future<List<TrendPoint>> Function(int saccoId);

/// One SACCO's health score: the composite, the six PEARLS rows,
/// anything that changed the rating, data notes, and the disclaimer.
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
        content: Text(saved.isSaved(widget.sacco.id)
            ? 'Added to saved SACCOs'
            : 'Removed from saved SACCOs'),
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
      appBar: AppBar(title: const Text('SACCO profile')),
      body: FutureBuilder<SaccoScore>(
        future: _score,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.forest));
          }
          if (snapshot.hasError) {
            return _ProfileUnavailable(sacco: widget.sacco, error: snapshot.error, onRetry: _retry);
          }
          final score = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                widget.sacco.name,
                style: const TextStyle(color: AppColors.ink, fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                widget.sacco.county ?? 'County not listed',
                style: const TextStyle(color: AppColors.muted, fontSize: 14),
              ),
              if (_years.length > 1) ...[
                const SizedBox(height: 14),
                _YearSelector(years: _years, selected: score.year, onSelected: _selectYear),
              ],
              const SizedBox(height: 16),
              _ScoreCard(score: score),
              const SizedBox(height: 12),
              _Actions(
                inCompare: context.watch<CompareProvider>().contains(widget.sacco.id),
                isSaved: context.watch<SavedProvider>().isSaved(widget.sacco.id),
                saving: _saving,
                onToggleCompare: _toggleCompare,
                onToggleSaved: _toggleSaved,
              ),
              if (score.overrides.isNotEmpty) ...[
                const SizedBox(height: 22),
                _Notice(
                  icon: Icons.gavel_rounded,
                  color: ratingColor(score.rating),
                  title: 'Rating adjusted',
                  lines: score.overrides,
                ),
              ],
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
                const SizedBox(height: 18),
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

class _YearSelector extends StatelessWidget {
  const _YearSelector({required this.years, required this.selected, required this.onSelected});

  final List<int> years;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('Year', style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
        for (final year in years.reversed) // newest first
          ChoiceChip(
            label: Text('$year'),
            selected: year == selected,
            onSelected: (_) => onSelected(year),
            selectedColor: AppColors.accent,
            side: const BorderSide(color: AppColors.line),
          ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final SaccoScore score;

  @override
  Widget build(BuildContext context) {
    final composite = score.composite;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.forestDark,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'HEALTH SCORE · ${score.year}',
            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // FittedBox shrinks the big number on narrow phones or large system fonts
              // instead of letting it push the rating chip off the screen.
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        composite == null ? '—' : composite.toDouble().toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          height: 1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 6, bottom: 6),
                        child: Text('/ 100', style: TextStyle(color: Colors.white70, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              RatingChip(rating: composite == null ? null : score.rating, large: true),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ((composite ?? 0) / 100).clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              backgroundColor: Colors.white24,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            composite == null
                ? 'Not rated: none of the PEARLS dimensions could be scored for ${score.year}.'
                : 'Based on ${score.dimensionsScored} of ${score.dimensionsTotal} PEARLS dimensions. '
                    'Green is 75 or more, Amber 50 to 74.9, Red below 50.',
            style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
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
        Expanded(
          child: FilledButton.icon(
            onPressed: onToggleCompare,
            icon: Icon(inCompare ? Icons.check_rounded : Icons.compare_arrows_rounded),
            label: Text(inCompare ? 'In compare' : 'Add to compare'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: saving ? null : onToggleSaved,
            icon: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_add_outlined),
            label: Text(isSaved ? 'Saved' : 'Save SACCO'),
          ),
        ),
      ],
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
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
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        tilePadding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scored ? AppColors.accentSoft : AppColors.paper,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            dimension.code,
            style: TextStyle(
              color: scored ? AppColors.forest : AppColors.muted,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(
          dimension.name,
          style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 14),
        ),
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
                          backgroundColor: AppColors.line,
                          color: ratingColor(band),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${formatNumber(score)} · $band',
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                )
              : const Text(
                  'Not available',
                  style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700, fontSize: 13),
                ),
        ),
        children: [
          if (dimension.reason != null)
            _DetailText(scored ? dimension.reason! : 'Why: ${dimension.reason!}'),
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
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  indicator.label,
                  style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                value == null ? 'Missing' : '${formatNumber(value)}${indicator.unit ?? ''}',
                style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800),
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

class _DetailText extends StatelessWidget {
  const _DetailText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800)),
            ],
          ),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('• $line', style: const TextStyle(color: AppColors.ink, fontSize: 13, height: 1.35)),
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
            Icon(
              unreachable ? Icons.wifi_off_rounded : Icons.query_stats_rounded,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              unreachable ? 'Could not reach the server' : sacco.name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.w800),
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
