import 'package:flutter/material.dart';

import '../models/sacco.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class SaccoProfileScreen extends StatefulWidget {
  const SaccoProfileScreen({super.key, required this.sacco});

  final SaccoRecord sacco;

  @override
  State<SaccoProfileScreen> createState() => _SaccoProfileScreenState();
}

class _SaccoProfileScreenState extends State<SaccoProfileScreen> {
  late Future<SaccoScore> _score;
  bool _isSaved = false;
  bool _savedStateLoading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _score = ApiService.getScore(widget.sacco.id);
    _loadSavedState();
  }

  Future<void> _loadSavedState() async {
    try {
      final lists = await ApiService.getWatchlists();
      final saved = lists
          .where((list) => list.name == 'My SACCOs')
          .expand((list) => list.saccos)
          .any((sacco) => sacco.id == widget.sacco.id);
      if (mounted) setState(() => _isSaved = saved);
    } catch (_) {
      // Keep the score page usable if saved-list loading fails.
    } finally {
      if (mounted) setState(() => _savedStateLoading = false);
    }
  }

  Future<void> _toggleSaved() async {
    setState(() => _saving = true);
    try {
      await ApiService.setSaccoSaved(widget.sacco, saved: !_isSaved);
      if (!mounted) return;
      setState(() => _isSaved = !_isSaved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isSaved ? 'Added to saved SACCOs' : 'Removed from saved SACCOs')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _retry() {
    setState(() {
      _score = ApiService.getScore(widget.sacco.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SACCO profile'),
        backgroundColor: AppColors.canvas,
      ),
      body: FutureBuilder<SaccoScore>(
        future: _score,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            );
          }
          if (snapshot.hasError) {
            return _ProfileUnavailable(
              sacco: widget.sacco,
              message: snapshot.error.toString(),
              onRetry: _retry,
            );
          }
          return _ProfileContent(
            sacco: widget.sacco,
            score: snapshot.data!,
            isSaved: _isSaved,
            saving: _saving || _savedStateLoading,
            onToggleSaved: _toggleSaved,
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.sacco,
    required this.score,
    required this.isSaved,
    required this.saving,
    required this.onToggleSaved,
  });

  final SaccoRecord sacco;
  final SaccoScore score;
  final bool isSaved;
  final bool saving;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final scoredCount = score.dimensions.values.where((item) => item.scored).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text(
          sacco.name,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 27,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${sacco.county ?? 'County not listed'}  ·  SACCO ID ${sacco.id}',
          style: const TextStyle(color: AppColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 20),
        _ScoreSummary(score: score),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: saving ? null : onToggleSaved,
          icon: Icon(isSaved ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined),
          label: Text(isSaved ? 'Remove from saved' : 'Save SACCO'),
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Expanded(
              child: Text(
                'PEARLS breakdown',
                style: TextStyle(
                  color: Color(0xFF18312D),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '$scoredCount OF ${score.dimensions.length} SCORED',
              style: const TextStyle(
                color: Color(0xFF638078),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final dimension in score.dimensions.values)
          _DimensionTile(dimension: dimension),
      ],
    );
  }
}

class _ScoreSummary extends StatelessWidget {
  const _ScoreSummary({required this.score});

  final SaccoScore score;

  @override
  Widget build(BuildContext context) {
    final value = (score.composite ?? 0).toDouble();
    final progress = (value / 100).clamp(0.0, 1.0).toDouble();
    final ratingColor = _bandColor(score.rating);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 108,
            height: 108,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white24,
                  color: AppColors.lime,
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatNumber(value),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Text(
                        'OUT OF 100',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPOSITE RATING',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ratingColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    score.rating,
                    style: TextStyle(
                      color: ratingColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Financial year ${score.year}',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionTile extends StatelessWidget {
  const _DimensionTile({required this.dimension});

  final PearlsDimension dimension;

  @override
  Widget build(BuildContext context) {
    final scoreLabel = dimension.scored
        ? '${_formatNumber(dimension.score ?? 0)} points'
        : 'Not scored';
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.limeSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          dimension.code,
          style: const TextStyle(
            color: AppColors.forest,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      title: Text(
        dimension.name,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        scoreLabel,
        style: TextStyle(
          color: dimension.scored ? AppColors.muted : AppColors.amber,
          fontSize: 12,
        ),
      ),
      children: [
        if (dimension.reason != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                dimension.reason!,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
          ),
        for (final indicator in dimension.indicators)
          _IndicatorRow(indicator: indicator),
        if (dimension.reason == null && dimension.indicators.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 4, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No indicator data available.',
                style: TextStyle(color: Color(0xFF638078), fontSize: 13),
              ),
            ),
          ),
      ],
    );
  }
}

class _IndicatorRow extends StatelessWidget {
  const _IndicatorRow({required this.indicator});

  final PearlsIndicator indicator;

  @override
  Widget build(BuildContext context) {
    final band = indicator.band ?? 'Unrated';
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              indicator.label,
              style: const TextStyle(color: AppColors.ink, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _bandColor(band).withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  band,
                  style: TextStyle(
                    color: _bandColor(band),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                indicator.value == null
                    ? '—'
                    : '${_formatNumber(indicator.value!)}${indicator.unit ?? ''}',
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable({
    required this.sacco,
    required this.message,
    required this.onRetry,
  });

  final SaccoRecord sacco;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.query_stats_rounded,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: 14),
            Text(
              sacco.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A score is not available for this SACCO yet.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

Color _bandColor(String band) {
  switch (band.toLowerCase()) {
    case 'green':
      return AppColors.green;
    case 'amber':
      return AppColors.amber;
    case 'red':
      return AppColors.red;
    default:
      return const Color(0xFF6C7E79);
  }
}

String _formatNumber(num number) {
  final value = number.toDouble();
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}