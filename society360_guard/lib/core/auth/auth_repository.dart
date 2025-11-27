import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

/// Authentication Repository
/// Handles PIN-based authentication and session management using secure storage
class AuthRepository {
  final FlutterSecureStorage _secureStorage;

  // Storage keys
  static const String _sessionTokenKey = 'session_token';
  static const String _guardIdKey = 'guard_id';

  // Hardcoded PIN for Stage 1 (production will use backend)
  static const String _validPin = '123456';

  AuthRepository({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Login with PIN
  /// Returns true if authentication is successful
  Future<bool> loginWithPin(String pin) async {
    try {
      // Simulate network delay
      await Future.delayed(const Duration(milliseconds: 500));

      // Validate PIN
      if (pin == _validPin) {
        // Generate a dummy session token (in production, this comes from backend)
        final sessionToken = 'dummy_token_${DateTime.now().millisecondsSinceEpoch}';
        final guardId = 'guard_001'; // Hardcoded for Stage 1

        // Save to secure storage
        await _secureStorage.write(key: _sessionTokenKey, value: sessionToken);
        await _secureStorage.write(key: _guardIdKey, value: guardId);

        return true;
      }

      return false;
    } catch (e) {
      // Log error (in production, use proper logging)
      print('Login error: $e');
      return false;
    }
  }

  /// Check if user has an active session
  /// Returns true if session token exists
  Future<bool> hasActiveSession() async {
    try {
      final token = await _secureStorage.read(key: _sessionTokenKey);
      return token != null && token.isNotEmpty;
    } catch (e) {
      print('Session check error: $e');
      return false;
    }
  }

  /// Get current session token
  Future<String?> getSessionToken() async {
    try {
      return await _secureStorage.read(key: _sessionTokenKey);
    } catch (e) {
      print('Get token error: $e');
      return null;
    }
  }

  /// Get current guard ID
  Future<String?> getGuardId() async {
    try {
      return await _secureStorage.read(key: _guardIdKey);
    } catch (e) {
      print('Get guard ID error: $e');
      return null;
    }
  }

  /// Logout
  /// Clears all session data from secure storage
  Future<void> logout() async {
    try {
      await _secureStorage.delete(key: _sessionTokenKey);
      await _secureStorage.delete(key: _guardIdKey);
    } catch (e) {
      print('Logout error: $e');
      // Even if there's an error, we want to clear local state
      rethrow;
    }
  }

  /// Clear all secure storage (for debugging/testing)
  Future<void> clearAll() async {
    try {
      await _secureStorage.deleteAll();
    } catch (e) {
      print('Clear all error: $e');
      rethrow;
    }
  }
}

/// Riverpod provider for AuthRepository
@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository();
}
