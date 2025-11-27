import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';

/// API Client for Society360 Backend
class ApiClient {
  final Dio _dio;
  final String? authToken;

  ApiClient({
    required String baseUrl,
    this.authToken,
  }) : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
          headers: {
            'Content-Type': 'application/json',
            if (authToken != null) 'Authorization': 'Bearer $authToken',
          },
        )) {
    // Add interceptors for logging
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
    ));
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
      debugPrint('🌐 [ApiClient POST] URL: ${_dio.options.baseUrl}$path');
      debugPrint('📦 [ApiClient POST] Data: $data');
      debugPrint('🔑 [ApiClient POST] Headers: ${_dio.options.headers}');

      final response = await _dio.post(path, data: data);

      debugPrint('✅ [ApiClient POST] Response: ${response.statusCode}');
      return response;
    } on DioException catch (e) {
      debugPrint('❌ [ApiClient POST] DioException: ${e.type}');
      debugPrint('❌ [ApiClient POST] Status: ${e.response?.statusCode}');
      debugPrint('❌ [ApiClient POST] Response data: ${e.response?.data}');
      debugPrint('❌ [ApiClient POST] Error message: ${e.message}');
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
  Future<Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle Dio errors
  String _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message = error.response?.data['error'] ?? 'Unknown error occurred';
        return 'Error $statusCode: $message';
      case DioExceptionType.cancel:
        return 'Request cancelled';
      default:
        return 'Network error: ${error.message}';
    }
  }
}

/// Get the appropriate base URL based on platform
String _getBaseUrl() {
  // For production, use environment variable or const
  const productionUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '', // Empty means use development URLs
  );

  if (productionUrl.isNotEmpty) {
    return productionUrl;
  }

  // Development mode - auto-detect platform
  // TODO: Update LOCAL_NETWORK_IP with your machine's IP for physical device testing
  const localNetworkIp = '192.168.1.4'; // Your machine's IP on local network

  if (kIsWeb) {
    // Web - use localhost
    return 'http://localhost:3000/v1';
  } else if (Platform.isAndroid) {
    // Android emulator uses 10.0.2.2 to access host machine
    return 'http://10.0.2.2:3000/v1';

    // For physical Android device, uncomment the line below:
    // return 'http://$localNetworkIp:3000/v1';
  } else if (Platform.isIOS) {
    // iOS simulator can use localhost
    return 'http://localhost:3000/v1';

    // For physical iOS device, uncomment the line below:
    // return 'http://$localNetworkIp:3000/v1';
  } else {
    // Default fallback
    return 'http://localhost:3000/v1';
  }
}

/// Riverpod provider for ApiClient
final apiClientProvider = Provider<ApiClient>((ref) {
  // TODO: Add Firebase authentication token when Firebase is integrated
  // For now, PIN-based auth doesn't require a token for API calls
  final authState = ref.watch(authProvider);

  // Token will be added when Firebase auth is implemented
  // For development, the backend should handle requests without strict auth
  final token = null; // Will be Firebase UID once Firebase is integrated

  final baseUrl = _getBaseUrl();

  // Log the base URL for debugging
  debugPrint('🌐 API Base URL: $baseUrl');
  if (authState == AuthState.authenticated) {
    debugPrint('✅ User authenticated (PIN-based)');
  }

  return ApiClient(
    baseUrl: baseUrl,
    authToken: token,
  );
});
