import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  final baseUrl = _getBaseUrl();

  // Log the base URL for debugging
  debugPrint('🌐 API Base URL: $baseUrl');

  // Get Firebase auth token if user is logged in
  final firebaseUser = FirebaseAuth.instance.currentUser;
  String? token;

  if (firebaseUser != null) {
    // Note: Firebase ID token needs to be refreshed regularly
    // This is a simplified version. In production, you should handle token refresh
    debugPrint('✅ Firebase user authenticated: ${firebaseUser.uid}');
    // Token will be fetched asynchronously when needed
  } else {
    debugPrint('⚠️ No Firebase user authenticated');
  }

  return ApiClient(
    baseUrl: baseUrl,
    authToken: token, // Will be null for now, tokens fetched per request
  );
});

/// Provider for API client with auth token
/// This provider fetches the current Firebase ID token and creates an ApiClient with it
final apiClientWithTokenProvider = FutureProvider<ApiClient>((ref) async {
  final baseUrl = _getBaseUrl();
  final firebaseUser = FirebaseAuth.instance.currentUser;

  String? token;
  if (firebaseUser != null) {
    try {
      // Get fresh ID token - force refresh to avoid using expired cached tokens
      token = await firebaseUser.getIdToken(true);
      debugPrint('🔐 Firebase token fetched successfully');
    } catch (e) {
      debugPrint('❌ Failed to get Firebase token: $e');
    }
  }

  return ApiClient(
    baseUrl: baseUrl,
    authToken: token,
  );
});
