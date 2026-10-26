import 'package:flutter/material.dart';

/// The app's colours, shared with the admin web pages (admin/admin.html)
/// so the whole system looks like one product.
class AppColors {
  static const paper = Color(0xFFF5F7F5); // page background
  static const surface = Color(0xFFFFFFFF); // cards and bars
  static const ink = Color(0xFF20302B); // main text
  static const muted = Color(0xFF66756E); // secondary text
  static const line = Color(0xFFDBE1DC); // borders and dividers
  static const forest = Color(0xFF235C48); // brand colour, buttons
  static const forestDark = Color(0xFF1A4536); // large header cards
  static const accent = Color(0xFFCFE6DA); // highlights on forest, selected tab
  static const accentSoft = Color(0xFFE6F0EB); // icon backgrounds

  // One colour per SACCO on the Compare screen. Deliberately NOT green/amber/red,
  // so a SACCO's line colour is never mistaken for its rating.
  static const compareSeries = [Color(0xFF235C48), Color(0xFF3B6EA8), Color(0xFF8A4FB0)];

  // Rating colours. Always shown with the words Green, Amber or Red, never alone.
  static const green = Color(0xFF2F8A5B);
  static const amber = Color(0xFFD09A2C);
  static const red = Color(0xFFC25446);
}
