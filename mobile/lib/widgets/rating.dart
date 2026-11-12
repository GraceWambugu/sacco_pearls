import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Colour for a band or rating word. Grey for anything unrated.
Color ratingColor(String? band) {
  switch (band?.toLowerCase()) {
    case 'green':
      return AppColors.green;
    case 'amber':
      return AppColors.amber;
    case 'red':
      return AppColors.red;
    default:
      return AppColors.muted;
  }
}

/// The same 75 / 50 cut-offs the backend uses for the composite,
/// applied to a 0-100 dimension score so its bar gets a matching colour.
String bandForScore(num score) => score >= 75 ? 'Green' : (score >= 50 ? 'Amber' : 'Red');

/// 85 -> "85", 71.66 -> "71.7".
String formatNumber(num number) {
  final value = number.toDouble();
  return value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
}

/// A coloured dot plus the WORD, so the rating never depends on colour alone.
class RatingChip extends StatelessWidget {
  const RatingChip({super.key, required this.rating, this.large = false});

  final String? rating;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final label = rating ?? 'Unrated';
    final color = ratingColor(rating);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: large ? 14 : 9, vertical: large ? 7 : 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: large ? 12 : 9,
            height: large ? 12 : 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: large ? 8 : 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.w800,
              fontSize: large ? 16 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
