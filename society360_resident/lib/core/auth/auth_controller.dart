import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'auth_service.dart';
import '../storage/storage_service.dart';
import '../../data/repositories/metadata_repository.dart';

part 'auth_controller.g.dart';

/// Authentication State
enum AuthState {
  initial,
  unauthenticated,
  phoneVerification, // Waiting for OTP
  authenticated,
  onboarding, // Authenticated but not onboarded
  complete, // Authenticated and onboarded
}

/// Auth Controller using Riverpod
@riverpod
class AuthController extends _$AuthController {
  late final AuthService _authService;
  late final StorageService _storage;
  bool _isHandlingAuth = false; // Prevent concurrent calls

  @override
  AuthState build() {
    print('🏗️ [AUTH BUILD] build() method called');
    _authService = ref.read(authServiceProvider);
    _storage = ref.read(storageServiceProvider);

    // Listen to Firebase auth state changes
    ref.listen(currentUserProvider, (previous, next) {
      print('🔔 [AUTH LISTENER] Firebase auth state changed');
      next.when(
        data: (user) {
          if (user == null) {
            print('🔔 [AUTH LISTENER] User is null, setting unauthenticated');
            state = AuthState.unauthenticated;
            _isHandlingAuth = false;
          } else if (!_isHandlingAuth) {
            print('🔔 [AUTH LISTENER] User exists and not handling, calling _handleAuthenticatedUser');
            // Only handle auth if not already in progress
            _handleAuthenticatedUser();
          } else {
            print('🔔 [AUTH LISTENER] User exists but already handling auth, skipping');
          }
        },
        loading: () {
          print('🔔 [AUTH LISTENER] Loading...');
        },
        error: (error, stack) {
          print('❌ [AUTH LISTENER] Auth state error: $error');
          state = AuthState.unauthenticated;
          _isHandlingAuth = false;
        },
      );
    });

    // Check if there's already a Firebase user (for hot reload support)
    // Use synchronous check instead of async stream
    final currentUser = _authService.currentUser;

    if (currentUser != null) {
      print('🔄 [AUTH BUILD] Existing Firebase user found: ${currentUser.uid}');
      final isOnboarded = _storage.isOnboarded;
      print('🔄 [AUTH BUILD] Local storage isOnboarded: $isOnboarded');

      // Schedule auth check after build completes
      Future.microtask(() {
        if (!_isHandlingAuth) {
          _handleAuthenticatedUser();
        }
      });

      // Return appropriate initial state based on onboarding status
      // This prevents navigation to login page during hot reload
      if (isOnboarded) {
        print('🏗️ [AUTH BUILD] Returning complete state (user logged in and onboarded)');
        return AuthState.complete;
      } else {
        print('🏗️ [AUTH BUILD] Returning onboarding state (user logged in but not onboarded)');
        return AuthState.onboarding;
      }
    }

    print('🏗️ [AUTH BUILD] No existing user, returning initial state');
    return AuthState.initial;
  }

  /// Check existing session on app start
  Future<void> checkSession() async {
    print('🔍 [CHECK SESSION] Starting session check...');

    final isSessionValid = await _authService.checkSession();

    if (!isSessionValid) {
      print('🔍 [CHECK SESSION] No valid session, setting unauthenticated');
      state = AuthState.unauthenticated;
      return;
    }

    print('🔍 [CHECK SESSION] Session valid, checking state...');
    await _handleAuthenticatedUser();
  }

  /// Handle authenticated user state
  Future<void> _handleAuthenticatedUser() async {
    if (_isHandlingAuth) {
      print('⏭️  [AUTH] Already handling auth, skipping duplicate call');
      return;
    }

    _isHandlingAuth = true;
    print('🔍 [AUTH] Checking authentication state...');

    try {
      // First check local storage (for offline support)
      final isOnboarded = _storage.isOnboarded;
      final storedFlatId = _storage.flatId;
      print('🔍 [AUTH] Local storage isOnboarded: $isOnboarded, flatId: $storedFlatId');

      final metadataRepo = ref.read(metadataRepositoryProvider);

      if (isOnboarded && storedFlatId != null) {
        print('🔍 [AUTH] User onboarded locally, checking backend sync...');

        // Check if backend has the occupancy record
        final userFlats = await metadataRepo.getMyFlats();
        print('🔍 [AUTH] Backend returned ${userFlats.length} flat(s)');

        if (userFlats.isEmpty) {
          // User has local data but no backend record - sync it!
          print('⚠️ [AUTH] Local data exists but no backend occupancy - syncing...');
          final synced = await metadataRepo.ensureOccupancy(flatId: storedFlatId);

          if (synced) {
            print('✅ [AUTH] Backend occupancy synced successfully');
          } else {
            print('⚠️ [AUTH] Failed to sync occupancy, continuing anyway');
          }
        } else {
          print('✅ [AUTH] Backend occupancy already exists');
        }

        print('📝 [AUTH STATE] Setting state = AuthState.complete (from local storage)');
        state = AuthState.complete;
        print('📝 [AUTH STATE] State is now: $state');
        return;
      }

      // If not onboarded locally, check backend for existing flat assignments
      print('🔍 [AUTH] Not onboarded locally, checking backend for existing flats...');

      final userFlats = await metadataRepo.getMyFlats();

      print('🔍 [AUTH] Backend returned ${userFlats.length} flat(s)');

      if (userFlats.isNotEmpty) {
        print('🔍 [AUTH] Flat data: $userFlats');

        // User has existing flat assignments - use primary flat
        final primaryFlat = userFlats.firstWhere(
          (flat) => flat['is_primary'] == true,
          orElse: () => userFlats.first,
        );

        print('🔍 [AUTH] Selected primary flat: ${primaryFlat['flat_number']}');

        // Save primary flat to local storage
        await _storage.saveOnboardingData(
          flatId: primaryFlat['flat_id'],
          flatNumber: primaryFlat['flat_number'],
          blockName: primaryFlat['block_name'],
          societyName: primaryFlat['society_name'],
          cityName: primaryFlat['city'],
        );

        print('✅ [AUTH] Loaded existing flat assignment: ${primaryFlat['flat_number']}');
        print('✅ [AUTH] Saved to local storage, going to complete state');
        print('📝 [AUTH STATE] Setting state = AuthState.complete (from backend flats)');
        state = AuthState.complete;
        print('📝 [AUTH STATE] State is now: $state');
      } else {
        // No flats assigned - need onboarding
        print('⚠️ [AUTH] No flats found in backend, going to onboarding');
        state = AuthState.onboarding;
      }
    } catch (e, stackTrace) {
      print('❌ [AUTH] Error checking user flats: $e');
      print('❌ [AUTH] Stack trace: $stackTrace');
      // Fallback to onboarding if API call fails
      state = AuthState.onboarding;
    } finally {
      _isHandlingAuth = false;
    }
  }

  /// Send OTP to phone number
  Future<bool> sendOtp(String phoneNumber) async {
    try {
      print('📝 [AUTH STATE] Setting state = AuthState.initial (from sendOtp)');
      state = AuthState.initial;
      print('📝 [AUTH STATE] State is now: $state');

      // Use Completer to properly wait for Firebase callbacks
      final completer = Completer<bool>();

      await _authService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          print('📝 [AUTH STATE] Setting state = AuthState.phoneVerification (onCodeSent)');
          state = AuthState.phoneVerification;
          print('📝 [AUTH STATE] State is now: $state');
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onError: (errorMessage) {
          state = AuthState.unauthenticated;
          if (!completer.isCompleted) {
            completer.completeError(Exception(errorMessage));
          }
        },
        onAutoVerify: (credential) async {
          // Auto-verification (instant verification)
          try {
            await _authService.signInWithCredential(credential);
            await _handleAuthenticatedUser();
            if (!completer.isCompleted) {
              completer.complete(true);
            }
          } catch (e) {
            state = AuthState.unauthenticated;
            if (!completer.isCompleted) {
              completer.completeError(e);
            }
          }
        },
      );

      // Wait for actual Firebase callback (with timeout)
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          state = AuthState.unauthenticated;
          throw Exception('Request timed out. Please try again.');
        },
      );
    } catch (e) {
      print('❌ Send OTP failed: $e');
      state = AuthState.unauthenticated;
      rethrow;
    }
  }

  /// Verify OTP
  Future<bool> verifyOtp(String otp) async {
    try {
      final userCredential = await _authService.verifyOtp(otp: otp);

      if (userCredential?.user != null) {
        await _handleAuthenticatedUser();
        return true;
      }

      return false;
    } catch (e) {
      print('❌ Verify OTP failed: $e');
      rethrow;
    }
  }

  /// Complete onboarding
  Future<void> completeOnboarding({
    required String flatId,
    required String flatNumber,
    required String blockName,
    required String societyName,
    required String cityName,
  }) async {
    try {
      // Submit resident request to backend
      final metadataRepo = ref.read(metadataRepositoryProvider);
      final success = await metadataRepo.submitResidentRequest(
        flatId: flatId,
        requestedRole: 'owner', // Default to owner, can be made configurable
        note: 'Resident registration from mobile app',
      );

      if (!success) {
        throw Exception('Failed to submit resident request to backend');
      }

      // Save onboarding data locally
      await _storage.saveOnboardingData(
        flatId: flatId,
        flatNumber: flatNumber,
        blockName: blockName,
        societyName: societyName,
        cityName: cityName,
      );

      state = AuthState.complete;
      print('✅ Resident request submitted and saved locally');
    } catch (e) {
      print('❌ Error completing onboarding: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    state = AuthState.unauthenticated;
  }
}
