import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_endpoints.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(_AuthInterceptor());
    // Parse every response.data into Map<String, dynamic> safely
    _dio.interceptors.add(_ResponseParserInterceptor());
    _dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, error: true),
    );
  }

  Dio get dio => _dio;

  void setToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  void clearToken() {
    _dio.options.headers.remove('Authorization');
  }

  // GET
  Future<Response> get(String path, {Map<String, dynamic>? queryParams}) {
    return _dio.get(path, queryParameters: queryParams);
  }

  // POST
  Future<Response> post(String path, {dynamic data}) {
    return _dio.post(path, data: data);
  }

  // PUT
  Future<Response> put(String path, {dynamic data}) {
    return _dio.put(path, data: data);
  }

  // DELETE
  Future<Response> delete(String path, {dynamic data}) {
    return _dio.delete(path, data: data);
  }

  // UPLOAD FILE (multipart form)
  Future<Response> uploadFile(
    String path,
    String filePath, {
    String field = 'file',
  }) {
    final formData = FormData.fromMap({
      field: MultipartFile.fromFileSync(filePath),
    });
    return _dio.post(path, data: formData);
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      // TODO: Handle token refresh in Phase 2
    }
    handler.next(err);
  }
}

/// Ensures response.data is always a Map<String, dynamic>.
/// Handles cases where Dio returns a raw JSON string instead of a parsed Map.
class _ResponseParserInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    response.data = _ensureMap(response.data);
    handler.next(response);
  }

  dynamic _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (e) {
        debugPrint('⚠️ Failed to parse response string as JSON: $e');
      }
    }
    // Return data as-is if it's a List or other type (some endpoints return lists)
    return data;
  }
}
