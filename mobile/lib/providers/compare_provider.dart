import 'package:flutter/foundation.dart';

import '../models/sacco.dart';

/// The SACCOs picked for comparison (at most three), shared by Search,
/// Profile and the Compare tab so a pick made anywhere shows up everywhere.
class CompareProvider extends ChangeNotifier {
  static const maxSaccos = 3;

  final List<SaccoRecord> _selected = [];

  List<SaccoRecord> get selected => List.unmodifiable(_selected);
  int get count => _selected.length;
  bool get isFull => _selected.length >= maxSaccos;
  bool get canCompare => _selected.length >= 2;
  bool contains(int saccoId) => _selected.any((s) => s.id == saccoId);

  /// Returns false if three SACCOs are already picked.
  bool add(SaccoRecord sacco) {
    if (contains(sacco.id)) return true;
    if (isFull) return false;
    _selected.add(sacco);
    notifyListeners();
    return true;
  }

  void remove(int saccoId) {
    _selected.removeWhere((s) => s.id == saccoId);
    notifyListeners();
  }

  void clear() {
    _selected.clear();
    notifyListeners();
  }
}
