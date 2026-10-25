import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sacco.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';

/// The member's saved SACCOs, shared by the Profile bookmark and the Saved tab.
///
/// Before this, each screen loaded the list on its own, so saving on a Profile
/// did not show up on the Saved tab until it was refreshed by hand.
class SavedProvider extends ChangeNotifier {
  AuthProvider? _auth;
  int? _accountId;
  List<SaccoRecord> _saccos = const [];
  bool _loading = false;
  String? _error;

  List<SaccoRecord> get saccos => _saccos;
  bool get loading => _loading;
  String? get error => _error;
  bool isSaved(int saccoId) => _saccos.any((s) => s.id == saccoId);

  /// Called by the provider tree whenever sign-in changes:
  /// load the list after sign-in, empty it after sign-out.
  void updateAuth(AuthProvider auth) {
    _auth = auth;
    final accountId = auth.account?.id;
    if (accountId == _accountId) return;
    _accountId = accountId;
    _saccos = const [];
    _error = null;
    // Run after the current build finishes; listeners must not be notified mid-build.
    scheduleMicrotask(accountId == null ? notifyListeners : load);
  }

  Future<void> load() async {
    if (_accountId == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _saccos = await ApiService.getSavedSaccos();
    } on ApiException catch (error) {
      _error = error.message;
      if (error.statusCode == 401) _auth?.sessionExpired();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Saves or un-saves one SACCO. Throws [ApiException] so the screen can show the reason.
  Future<void> toggle(SaccoRecord sacco) async {
    final wasSaved = isSaved(sacco.id);
    try {
      await ApiService.setSaccoSaved(sacco, saved: !wasSaved);
    } on ApiException catch (error) {
      if (error.statusCode == 401) _auth?.sessionExpired();
      rethrow;
    }
    _saccos = wasSaved
        ? _saccos.where((s) => s.id != sacco.id).toList()
        : [..._saccos, sacco];
    notifyListeners();
  }
}
