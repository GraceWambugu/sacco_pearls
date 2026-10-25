import 'package:dio/dio.dart';

import 'config.dart';

/// The one place the app talks HTTP. Every request goes through dio here,
/// and every failure comes back as an [ApiException] with a plain message.
class ApiClient {
  ApiClient._();

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: apiBase,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    String? token,
  }) {
    return _send(() => _dio.get(path, queryParameters: query, options: _auth(token)));
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body, {String? token}) {
    return _send(() => _dio.post(path, data: body, options: _auth(token)));
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body, {required String token}) {
    return _send(() => _dio.put(path, data: body, options: _auth(token)));
  }

  /// The login endpoint expects a form (username and password), not JSON.
  static Future<dynamic> postForm(String path, Map<String, dynamic> fields) {
    return _send(() => _dio.post(
          path,
          data: fields,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        ));
  }

  static Options? _auth(String? token) =>
      token == null ? null : Options(headers: {'Authorization': 'Bearer $token'});

  static Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data;
    } on DioException catch (error) {
      throw _toApiException(error);
    }
  }

  static ApiException _toApiException(DioException error) {
    final response = error.response;
    // No response at all: the server is off, the address is wrong, or there is no internet.
    if (response == null) {
      return const ApiException(
        statusCode: 0,
        message: 'Could not reach the server. Check your connection and try again.',
      );
    }
    final data = response.data;
    final detail = data is Map ? _detailMessage(data['detail']) : null;
    return ApiException(
      statusCode: response.statusCode ?? 0,
      message: detail ?? response.statusMessage ?? 'Request failed',
    );
  }

  /// FastAPI puts its error in "detail": either a sentence or a list of field errors.
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

  /// 0 means the server could not be reached.
  final int statusCode;
  final String message;

  bool get isUnreachable => statusCode == 0;

  @override
  String toString() => message;
}
