import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The four PEARLS dimensions that can be scored. P and L are left off the
/// radar on purpose: SASRA does not publish the figures they need.
const radarAxes = ['E', 'A', 'R', 'S'];
const _axisNames = {'E': 'Structure (E)', 'A': 'Assets (A)', 'R': 'Returns (R)', 'S': 'Growth (S)'};

/// One shape on the radar.
class RadarSeries {
  const RadarSeries({required this.color, required this.scores});

  final Color color;

  /// Dimension code -> 0-100 score, or null if that dimension was not scored.
  final Map<String, num?> scores;
}

/// A radar (spider) chart of E, A, R and S, one coloured shape per SACCO.
class PearlsRadar extends StatelessWidget {
  const PearlsRadar({super.key, required this.series});

  final List<RadarSeries> series;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            // Two invisible shapes at 0 and 100 fix the scale, so 50 is always halfway.
            _scaleSet(0),
            _scaleSet(100),
            for (final s in series)
              RadarDataSet(
                // A missing score is drawn at 0; the screen says which ones are missing.
                dataEntries: [for (final code in radarAxes) RadarEntry(value: (s.scores[code] ?? 0).toDouble())],
                fillColor: s.color.withValues(alpha: 0.15),
                borderColor: s.color,
                borderWidth: 2.5,
                entryRadius: 3,
              ),
          ],
          radarShape: RadarShape.polygon,
          tickCount: 4, // rings at 25, 50, 75, 100
          ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
          tickBorderData: const BorderSide(color: AppColors.line),
          gridBorderData: const BorderSide(color: AppColors.line),
          radarBorderData: const BorderSide(color: AppColors.muted),
          titlePositionPercentageOffset: 0.12,
          titleTextStyle: const TextStyle(color: AppColors.ink, fontSize: 12, fontWeight: FontWeight.w700),
          getTitle: (index, angle) => RadarChartTitle(text: _axisNames[radarAxes[index]]!),
          radarTouchData: RadarTouchData(enabled: false),
        ),
      ),
    );
  }

  RadarDataSet _scaleSet(double value) => RadarDataSet(
        dataEntries: [for (final _ in radarAxes) RadarEntry(value: value)],
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        borderWidth: 0,
        entryRadius: 0,
      );
}
