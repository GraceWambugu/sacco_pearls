import 'package:flutter/material.dart';

/// The app's colours: a dark slate background with emerald accents.
/// Every screen uses these names, so the whole look changes here in one place.
class AppColors {
  static const paper = Color(0xFF020617); // page background (slate 950)
  static const surface = Color(0xFF0F172A); // cards and bars (slate 900)
  static const raised = Color(0xFF1E293B); // inputs and inner boxes (slate 800)
  static const ink = Color(0xFFF1F5F9); // main text (slate 100)
  static const muted = Color(0xFF94A3B8); // secondary text (slate 400)
  static const line = Color(0xFF1E293B); // borders and dividers (slate 800)
  static const forest = Color(0xFF059669); // buttons and brand (emerald 600)
  static const forestDark = Color(0xFF0B2B26); // large header cards (deep emerald)
  static const accent = Color(0xFF134E3F); // selected tab and chip (dark emerald)
  static const accentSoft = Color(0xFF0D2723); // icon backgrounds (emerald tint)
  static const highlight = Color(0xFF34D399); // emerald text and icons on dark (emerald 400)

  // One colour per SACCO on the Compare screen. Deliberately NOT green/amber/red,
  // so a SACCO's line colour is never mistaken for its rating.
  static const compareSeries = [Color(0xFF38BDF8), Color(0xFFA78BFA), Color(0xFFF472B6)];

  // Rating colours. Always shown with the words Green, Amber or Red, never alone.
  static const green = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFF43F5E);
}
