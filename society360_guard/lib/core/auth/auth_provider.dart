import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'auth_repository.dart';

part 'auth_provider.g.dart';

/// Authentication State
enum AuthState {
  initial,
  authenticated,
  unauthenticated,
  loading,
}

/// Auth State Notifier
/// Manages the global authentication state
@riverpod
class Auth extends _$Auth {
  @override
  AuthState build() {
    // Initial state
    return AuthState.initial;
  }

  /// Check if user has an active session on app start
  Future<void> checkSession() async {
    state = AuthState.loading;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final hasSession = await authRepo.hasActiveSession();

      if (hasSession) {
        state = AuthState.authenticated;
      } else {
        state = AuthState.unauthenticated;
      }
    } catch (e) {
      print('Session check error: $e');
      state = AuthState.unauthenticated;
    }
  }

  /// Login with PIN
  Future<bool> loginWithPin(String pin) async {
    state = AuthState.loading;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      final success = await authRepo.loginWithPin(pin);

      if (success) {
        state = AuthState.authenticated;
        return true;
      } else {
        state = AuthState.unauthenticated;
        return false;
      }
    } catch (e) {
      print('Login error: $e');
      state = AuthState.unauthenticated;
      return false;
    }
  }

  /// Logout
  Future<void> logout() async {
    state = AuthState.loading;

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.logout();
      state = AuthState.unauthenticated;
    } catch (e) {
      print('Logout error: $e');
      // Force unauthenticated state even if there's an error
      state = AuthState.unauthenticated;
    }
  }
}
