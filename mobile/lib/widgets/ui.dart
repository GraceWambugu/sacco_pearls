import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'rating.dart';

/// Building blocks shared by Home, Directory, Profile and Compare,
/// so every screen has the same cards, badges and figure strips.

/// A dark rounded card with a thin border.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.radius = 20});

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

/// "85/100" on the rating colour, with "Green rating" underneath.
/// The word is always printed, so the badge never relies on colour alone.
class ScoreBadge extends StatelessWidget {
  const ScoreBadge({super.key, required this.composite, required this.rating});

  final num? composite;
  final String? rating;

  @override
  Widget build(BuildContext context) {
    final value = composite;
    final rated = value != null && rating != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: rated ? ratingColor(rating) : AppColors.raised,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            rated ? '${formatNumber(value)}/100' : '—',
            style: TextStyle(
              color: rated ? AppColors.paper : AppColors.muted,
              fontWeight: FontWeight.w900,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          rated ? '$rating rating' : 'Not rated',
          style: const TextStyle(color: AppColors.muted, fontSize: 11),
        ),
      ],
    );
  }
}

/// One label/value pair in a [FigureStrip].
class Figure {
  const Figure(this.label, this.value, {this.emphasis = false});

  final String label;
  final String value;
  final bool emphasis;
}

/// The darker strip of headline figures inside a SACCO card.
class FigureStrip extends StatelessWidget {
  const FigureStrip({super.key, required this.figures});

  final List<Figure> figures;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          for (final figure in figures)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(figure.label, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    figure.value,
                    style: TextStyle(
                      color: figure.emphasis ? AppColors.highlight : AppColors.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
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

/// A square icon on a tinted background, as on the Home tiles.
class IconBox extends StatelessWidget {
  const IconBox({super.key, required this.icon, required this.color, this.size = 40});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

/// "Add to compare" / "In compare" toggle used on SACCO cards.
class CompareToggle extends StatelessWidget {
  const CompareToggle({super.key, required this.picked, required this.onPressed, this.compact = false});

  final bool picked;
  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: picked ? AppColors.highlight : AppColors.ink,
        backgroundColor: picked ? AppColors.accentSoft : AppColors.raised,
        side: BorderSide(color: picked ? AppColors.accent : AppColors.raised),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
      icon: Icon(picked ? Icons.check_rounded : Icons.add_rounded, size: 16),
      label: Text(
        picked ? (compact ? 'Compared' : 'In compare list') : (compact ? 'Compare' : 'Add to compare'),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Figures as members read them: "KES 59.8B", "2.4%", or a dash when SASRA gave none.
String kesBillions(num? value) => value == null ? '—' : 'KES ${value.toStringAsFixed(1)}B';
/// Below 1% we keep two decimals, so 0.04% is not shown as a misleading "0.0%".
String percent(num? value) =>
    value == null ? '—' : '${value.toStringAsFixed(value.abs() < 1 ? 2 : 1)}%';
