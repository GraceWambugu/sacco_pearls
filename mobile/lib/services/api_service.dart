import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/auth_user.dart';
import '../models/sacco.dart';
import '../models/watchlist.dart';

class ApiService {
  static const String baseUrl = 'http://10.0.2.2:8000';
  static const Duration _timeout = Duration(seconds: 12);
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'saccolens_access_token';

  static Future<MemberAccount> registerMember({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _postJson('/auth/register', {
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
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          body: {'username': email.trim(), 'password': password},
        )
        .timeout(_timeout);
    final json = _decodeResponse(response);
    final token = (json as Map<String, dynamic>)['access_token'] as String;
    await _storage.write(key: _tokenKey, value: token);
    try {
      return await _currentAccount(token);
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      rethrow;
    }
  }

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
    await _postJson('/auth/forgot-password', {'email': email.trim()});
  }

  static Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    await _postJson('/auth/reset-password', {
      'token': token.trim(),
      'new_password': newPassword,
    });
  }

  static Future<List<SaccoRecord>> searchSaccos(String query) async {
    final json = await _getJson(
      '/saccos',
      queryParameters: {
        'limit': '200',
        if (query.trim().isNotEmpty) 'q': query.trim(),
      },
    );
    if (json is! List) {
      throw const FormatException('Unexpected SACCO list response');
    }
    return json
        .map((item) => SaccoRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<SaccoScore> getScore(int saccoId) async {
    final json = await _getJson('/saccos/$saccoId/score');
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected SACCO score response');
    }
    return SaccoScore.fromJson(json);
  }

  static Future<Map<String, dynamic>> compareSaccos(List<int> saccoIds) async {
    final json = await _getJson(
      '/compare',
      queryParameters: {'ids': saccoIds.join(',')},
    );
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected comparison response');
    }
    return json;
  }

  static Future<List<MemberWatchlist>> getWatchlists() async {
    final token = await _requiredToken();
    final json = await _getJson('/watchlists', token: token);
    if (json is! List) {
      throw const FormatException('Unexpected watchlist response');
    }
    return json
        .map((item) => MemberWatchlist.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList(growable: false);
  }

  static Future<void> setSaccoSaved(SaccoRecord sacco, {required bool saved}) async {
    final token = await _requiredToken();
    final lists = await getWatchlists();
    final myList = lists.where((list) => list.name == 'My SACCOs').firstOrNull;
    if (myList == null) {
      if (!saved) return;
      await _postJson(
        '/watchlists',
        {
          'name': 'My SACCOs',
          'sacco_ids': [sacco.id],
        },
        token: token,
      );
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
    await _putJson(
      '/watchlists/${myList.id}',
      {'sacco_ids': ids.toList()},
      token: token,
    );
  }

  static Future<String> _requiredToken() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) {
      throw const ApiException(statusCode: 401, message: 'Sign in to use saved SACCOs');
    }
    return token;
  }

  static Future<dynamic> _getJson(
    String path, {
    Map<String, String>? queryParameters,
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
    final response = await http.get(
      uri,
      headers: token == null ? null : {'Authorization': 'Bearer $token'},
    ).timeout(_timeout);
    return _decodeResponse(response);
  }

  static Future<dynamic> _postJson(
    String path,
    Map<String, dynamic> data, {
    String? token,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  static Future<dynamic> _putJson(
    String path,
    Map<String, dynamic> data, {
    required String token,
  }) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(data),
        )
        .timeout(_timeout);
    return _decodeResponse(response);
  }

  static Future<MemberAccount> _currentAccount(String token) async {
    final json = await _getJson('/users/me', token: token);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected account response');
    }
    return MemberAccount.fromJson(json);
  }

  static dynamic _decodeResponse(http.Response response) {
    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map<String, dynamic>
          ? _detailMessage(body['detail']) ?? response.reasonPhrase ?? 'Request failed'
          : response.reasonPhrase ?? 'Request failed';
      throw ApiException(statusCode: response.statusCode, message: message);
    }
    return body;
  }

  static String? _detailMessage(dynamic detail) {
    if (detail is List) {
      return detail
          .map((item) => item is Map ? item['msg']?.toString() : item.toString())
          .whereType<String>()
          .join('\n');
    }
    return detail?.toString();
  }
}

class ApiException implements Exception {
  const ApiException({required this.statusCode, required this.message});

  final int statusCode;
  final String message;

  @override
  String toString() => 'HTTP $statusCode: $message';
}