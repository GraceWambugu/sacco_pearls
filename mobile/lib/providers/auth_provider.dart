import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import '../services/api_service.dart';

/// Who is signed in, shared by every screen.
/// Signing in is optional: it is only needed to save SACCOs.
class AuthProvider extends ChangeNotifier {
  MemberAccount? _account;

  MemberAccount? get account => _account;
  bool get isSignedIn => _account != null;

  /// Called once at start-up: reuse a saved token if it is still valid.
  Future<void> restoreSession() async {
    try {
      _account = await ApiService.restoreSession();
    } catch (_) {
      _account = null; // e.g. server unreachable: carry on signed out
    }
    notifyListeners();
  }

  void signedIn(MemberAccount account) {
    _account = account;
    notifyListeners();
  }

  Future<void> signOut() async {
    await ApiService.logout();
    _account = null;
    notifyListeners();
  }

  /// The server rejected the token (401). The token is already deleted.
  void sessionExpired() {
    if (_account == null) return;
    _account = null;
    notifyListeners();
  }
}
