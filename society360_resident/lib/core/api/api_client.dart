import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../config/network_config.dart';

/// API Client for Society360 Backend
/// Handles all HTTP requests with automatic Firebase authentication
class ApiClient {
  late final Dio _dio;
  final bool _requiresAuth;

  ApiClient({
    required String baseUrl,
    bool requiresAuth = true,
  }) : _requiresAuth = requiresAuth {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: NetworkConfig.connectTimeout,
      receiveTimeout: NetworkConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add auth interceptor if authentication is required
    if (_requiresAuth) {
      _dio.interceptors.add(_AuthInterceptor());
    }

    // Add logging interceptor (only in debug mode)
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ));
    }
  }

  /// GET request
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<Response> delete(String path, {dynamic data}) async {
    try {
      return await _dio.delete(path, data: data);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors and convert to user-friendly messages
  String _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final data = error.response?.data;
        String message = 'Unknown error occurred';

        if (data is Map) {
          message = data['error'] ?? data['message'] ?? message;
        }

        // Handle specific status codes
        if (statusCode == 401) {
          return 'Authentication failed. Please sign in again.';
        } else if (statusCode == 403) {
          return 'You do not have permission to perform this action.';
        } else if (statusCode == 404) {
          return 'Resource not found.';
        } else if (statusCode != null && statusCode >= 500) {
          return 'Server error. Please try again later.';
        }

        return 'Error $statusCode: $message';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      case DioExceptionType.connectionError:
        return 'Connection error. Please check your internet connection.';
      default:
        return 'Network error: ${error.message}';
    }
  }
}

/// Interceptor that automatically adds Firebase auth token to requests
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        // Get fresh ID token (force refresh if expired)
        final token = await user.getIdToken();

        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          debugPrint('🔐 Auth token attached to request: ${options.path}');
        }
      } else {
        debugPrint('⚠️ No authenticated user for request: ${options.path}');
      }
    } catch (e) {
      debugPrint('❌ Error getting auth token: $e');
      // Continue without token - let the server handle the 401
    }

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      debugPrint('🔒 Received 401 - Token may be expired or invalid');
      // Could trigger a sign-out or token refresh here if needed
    }
    handler.next(err);
  }
}

/// Main API client provider - automatically handles authentication
/// Use this for all authenticated API calls
final apiClientProvider = Provider<ApiClient>((ref) {
  debugPrint('🌐 API Base URL: ${NetworkConfig.apiBaseUrl}');

  return ApiClient(
    baseUrl: NetworkConfig.apiBaseUrl,
    requiresAuth: true,
  );
});

/// Unauthenticated API client provider
/// Use this only for endpoints that don't require authentication
final unauthenticatedApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: NetworkConfig.apiBaseUrl,
    requiresAuth: false,
  );
});
