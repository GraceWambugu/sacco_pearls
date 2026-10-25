import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api_client.dart';
import '../models/auth_user.dart';
import '../models/sacco.dart';
import '../models/watchlist.dart';

export '../core/api_client.dart' show ApiException;

/// One method per backend endpoint the app uses. HTTP details live in [ApiClient].
class ApiService {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'saccolens_access_token';
  static const String savedListName = 'My SACCOs';

  // ---- Account ----

  static Future<MemberAccount> registerMember({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await ApiClient.post('/auth/register', {
      'full_name': fullName.trim(),
      'email': email.trim(),
      'password': password,
    });
    return login(email: email, password: password);
  }

  static Future<MemberAccount> login({
    required String email,
    required String password,
  }) async {
    final json = await ApiClient.postForm(
      '/auth/login',
      {'username': email.trim(), 'password': password},
    );
    final token = (json as Map<String, dynamic>)['access_token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    try {
      return await _currentAccount(token);
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      rethrow;
    }
  }

  /// Signs the member back in at app start if a saved token is still valid.
  static Future<MemberAccount?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return null;
    try {
      return await _currentAccount(token);
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _storage.delete(key: _tokenKey);
        return null;
      }
      rethrow;
    }
  }

  static Future<void> logout() => _storage.delete(key: _tokenKey);

  static Future<void> requestPasswordReset(String email) async {
    await ApiClient.post('/auth/forgot-password', {'email': email.trim()});
  }

  static Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await ApiClient.post('/auth/reset-password', {
      'token': token.trim(),
      'new_password': newPassword,
    });
  }

  // ---- Public data (no sign-in needed) ----

  /// Name search, optionally limited to one county. 200 covers every DT-SACCO.
  static Future<List<SaccoRecord>> searchSaccos(String query, {String? county}) async {
    final json = await ApiClient.get('/saccos', query: {
      'limit': 200,
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'county': ?county, // the "?" leaves this key out when no county is chosen
    });
    if (json is! List) {
      throw const FormatException('Unexpected SACCO list response');
    }
    return json
        .map((item) => SaccoRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  /// One year's score. Without a year, the API uses the latest year with figures.
  static Future<SaccoScore> getScore(int saccoId, {int? year}) async {
    final json = await ApiClient.get('/saccos/$saccoId/score', query: {'year': ?year});
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected SACCO score response');
    }
    return SaccoScore.fromJson(json);
  }

  /// Every year that has figures, oldest first.
  static Future<List<TrendPoint>> getTrend(int saccoId) async {
    final json = await ApiClient.get('/saccos/$saccoId/trend');
    if (json is! List) {
      throw const FormatException('Unexpected trend response');
    }
    return json
        .map((item) => TrendPoint.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<Map<String, dynamic>> compareSaccos(List<int> saccoIds) async {
    final json = await ApiClient.get('/compare', query: {'ids': saccoIds.join(',')});
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected comparison response');
    }
    return json;
  }

  // ---- Saved SACCOs (needs sign-in) ----

  /// The SACCOs in the member's "My SACCOs" list (empty if the list does not exist yet).
  static Future<List<SaccoRecord>> getSavedSaccos() async {
    final myList = await _myList(await _requiredToken());
    return myList?.saccos ?? const [];
  }

  static Future<void> setSaccoSaved(SaccoRecord sacco, {required bool saved}) async {
    final token = await _requiredToken();
    final myList = await _myList(token);
    if (myList == null) {
      if (!saved) return;
      await _signedIn(() => ApiClient.post(
            '/watchlists',
            {'name': savedListName, 'sacco_ids': [sacco.id]},
            token: token,
          ));
      return;
    }

    final ids = myList.saccos.map((item) => item.id).toSet();
    if (saved) {
      if (!ids.contains(sacco.id) && ids.length >= 3) {
        throw const ApiException(
          statusCode: 422,
          message: 'A saved list can contain up to three SACCOs.',
        );
      }
      ids.add(sacco.id);
    } else {
      ids.remove(sacco.id);
    }
    await _signedIn(() => ApiClient.put(
          '/watchlists/${myList.id}',
          {'sacco_ids': ids.toList()},
          token: token,
        ));
  }

  static Future<MemberWatchlist?> _myList(String token) async {
    final json = await _signedIn(() => ApiClient.get('/watchlists', token: token));
    if (json is! List) {
      throw const FormatException('Unexpected watchlist response');
    }
    return json
        .map((item) => MemberWatchlist.fromJson(Map<String, dynamic>.from(item as Map)))
        .where((list) => list.name == savedListName)
        .firstOrNull;
  }

  static Future<String> _requiredToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) {
      throw const ApiException(statusCode: 401, message: 'Sign in to save SACCOs.');
    }
    return token;
  }

  /// Runs a signed-in request. If the token has expired (401), it is deleted
  /// so the app shows the member as signed out.
  static Future<dynamic> _signedIn(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException catch (error) {
      if (error.statusCode != 401) rethrow;
      await _storage.delete(key: _tokenKey);
      throw const ApiException(
        statusCode: 401,
        message: 'Your session has expired. Please sign in again.',
      );
    }
  }

  static Future<MemberAccount> _currentAccount(String token) async {
    final json = await ApiClient.get('/users/me', token: token);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected account response');
    }
    return MemberAccount.fromJson(json);
  }
}
