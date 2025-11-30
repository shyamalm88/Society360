import 'dart:io';
import 'package:flutter/foundation.dart';

/// Centralized network configuration
/// Single source of truth for all API and Socket URLs
class NetworkConfig {
  NetworkConfig._();

  // Environment variable keys
  static const String _apiBaseUrlEnvKey = 'API_BASE_URL';
  static const String _socketBaseUrlEnvKey = 'SOCKET_BASE_URL';

  // Development settings
  static const int _apiPort = 3000;

  /// Local network IP for physical device testing
  /// Update this with your machine's IP address when testing on physical devices
  /// Usage: Uncomment the physical device URLs in _getHostUrl()
  static const String localNetworkIp = '192.168.1.4';
  static const String _apiVersion = 'v1';

  /// Get the API base URL (includes /v1 prefix)
  static String get apiBaseUrl {
    // Check for production URL from environment
    const productionUrl = String.fromEnvironment(
      _apiBaseUrlEnvKey,
      defaultValue: '',
    );

    if (productionUrl.isNotEmpty) {
      return productionUrl;
    }

    // Development mode - auto-detect platform
    return '${_getHostUrl()}/$_apiVersion';
  }

  /// Get the Socket.io server URL (no path prefix)
  static String get socketBaseUrl {
    // Check for production URL from environment
    const productionUrl = String.fromEnvironment(
      _socketBaseUrlEnvKey,
      defaultValue: '',
    );

    if (productionUrl.isNotEmpty) {
      return productionUrl;
    }

    // Development mode - use same host as API
    return _getHostUrl();
  }

  /// Get the host URL based on platform
  static String _getHostUrl() {
    if (kIsWeb) {
      // Web - use localhost
      return 'http://localhost:$_apiPort';
    } else if (Platform.isAndroid) {
      // Android emulator uses 10.0.2.2 to access host machine
      // For physical Android device, uncomment the line below:
      return 'http://10.0.2.2:$_apiPort';
      // return 'http://$localNetworkIp:$_apiPort';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost
      // For physical iOS device, uncomment the line below:
      return 'http://localhost:$_apiPort';
      // return 'http://$localNetworkIp:$_apiPort';
    } else {
      // Default fallback
      return 'http://localhost:$_apiPort';
    }
  }

  /// API timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// Auto-refresh intervals
  static const Duration visitorRefreshInterval = Duration(seconds: 30);

  /// OTP/Auth timeouts
  static const Duration otpTimeout = Duration(seconds: 60);

  /// Emergency button hold duration
  static const Duration emergencyHoldDuration = Duration(seconds: 3);
}
