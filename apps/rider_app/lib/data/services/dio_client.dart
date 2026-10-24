library rider_app.data.services.dio_client;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/app_constants.dart';
import './secure_storage_service.dart';

/// Unified API error matching the v1 error contract:
/// { "error": { "code", "message_ar", "message_en", "request_id" } }
class ApiException implements Exception {
  final int? statusCode;
  final String code;
  final String messageAr;
  final String messageEn;
  final String? requestId;
  final dynamic original;

  ApiException({
    this.statusCode,
    required this.code,
    required this.messageAr,
    required this.messageEn,
    this.requestId,
    this.original,
  });

  @override
  String toString() =>
      'ApiException(code: $code, statusCode: $statusCode, messageAr: $messageAr, '
      'messageEn: $messageEn, requestId: $requestId)';
}

/// Dio HTTP client with:
///   - baseUrl from environment variable
///   - automatic Authorization: Bearer <access token> injection
///   - Idempotency-Key support on write requests
///   - unified error handling
class DioClient {
  DioClient(this._storage, {Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(BaseOptions(
          baseUrl: baseUrl ?? AppConstants.apiBaseUrl,
          connectTimeout: AppConstants.connectTimeout,
          receiveTimeout: AppConstants.receiveTimeout,
          headers: {
            'Accept-Language': 'ar',
            'Content-Type': 'application/json',
          },
        )) {
    _dio.interceptors.add(_AuthInterceptor(_storage));
    _dio.interceptors.add(_IdempotencyInterceptor());
    _dio.interceptors.add(LogInterceptor(
      request: AppConstants.apiBaseUrl.contains('localhost') ||
          AppConstants.apiBaseUrl.contains('10.0.2.2'),
      response: false,
    ));
  }

  final Dio _dio;
  final SecureStorageService _storage;

  Future<T> get<T>(String path, {Map<String, dynamic>? queryParameters, Options? options}) async {
    final response = await _dio.get(path, queryParameters: queryParameters, options: options);
    return _mapData<T>(response);
  }

  Future<T> post<T>(String path,
      {dynamic data,
      Map<String, dynamic>? queryParameters,
      Options? options,
      String? idempotencyKey}) async {
    final headers = <String, dynamic>{};
    if (options?.headers != null) headers.addAll(options!.headers!);
    if (idempotencyKey != null && idempotencyKey.isNotEmpty) {
      headers['Idempotency-Key'] = idempotencyKey;
    }
    final requestOptions = options?.copyWith(headers: headers) ?? Options(headers: headers);
    final response = await _dio.post(path, data: data, queryParameters: queryParameters, options: requestOptions);
    return _mapData<T>(response);
  }

  Future<T> put<T>(String path, {dynamic data, Options? options}) async {
    final response = await _dio.put(path, data: data, options: options);
    return _mapData<T>(response);
  }

  Future<T> delete<T>(String path, {Options? options}) async {
    final response = await _dio.delete(path, options: options);
    return _mapData<T>(response);
  }

  T _mapData<T>(Response<dynamic> response) {
    if (response.data == null) {
      throw ApiException(
        statusCode: response.statusCode,
        code: 'EMPTY_RESPONSE',
        messageAr: 'استجابة فارغة من الخادم',
        messageEn: 'Empty response from server',
        requestId: _extractRequestId(response.headers),
      );
    }
    return response.data as T;
  }

  String? _extractRequestId(Map<String, String> headers) {
    return headers['x-request-id'] ?? headers['request-id'];
  }
}

/// Injects Authorization: Bearer <access token> on every request.
class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);
  final SecureStorageService _storage;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.readAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  }

  @override
  Future onError(DioException err, ErrorInterceptorHandler handler) async {
    // 401: refresh-token rotation handled by auth repository; surface as-is here.
    return handler.reject(err);
  }
}

/// Ensures idempotent-write safety: Idempotency-Key is supplied by the caller
/// per-request; this interceptor makes no client-generated keys (caller owns
/// idempotency semantics per the v1 contract).
class _IdempotencyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    return handler.next(options);
  }
}

final dioClientProvider = Provider((ref) => DioClient(ref.read(secureStorageProvider)));
