import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/storage_service.dart';

/// Firebase Authentication Service with Phone Auth
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storage;

  String? _verificationId;
  int? _resendToken;

  AuthService(this._storage);

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Verify Phone Number (Step 1)
  /// Sends OTP to the provided phone number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),

        // Auto-verification (instant verification on some devices)
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('✅ Auto verification completed');
          onAutoVerify(credential);
        },

        // Verification failed
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Verification failed: ${e.code} - ${e.message}');

          String errorMessage;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMessage = 'Invalid phone number format';
              break;
            case 'too-many-requests':
              errorMessage = 'Too many requests. Please try again later';
              break;
            case 'quota-exceeded':
              errorMessage = 'SMS quota exceeded. Please try again later';
              break;
            default:
              errorMessage = 'Verification failed: ${e.message}';
          }

          onError(errorMessage);
        },

        // Code sent successfully
        codeSent: (String verificationId, int? resendToken) {
          print('✅ OTP sent to $phoneNumber');
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },

        // Code auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏱️ Auto retrieval timeout');
          _verificationId = verificationId;
        },

        // For resending OTP
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      print('❌ Error in verifyPhoneNumber: $e');
      onError('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verify OTP Code (Step 2)
  /// Verifies the OTP entered by user and signs in
  Future<UserCredential?> verifyOtp({
    required String otp,
    String? verificationId,
  }) async {
    try {
      final vid = verificationId ?? _verificationId;

      if (vid == null) {
        throw Exception('Verification ID not found');
      }

      // Create credential from OTP
      final credential = PhoneAuthProvider.credential(
        verificationId: vid,
        smsCode: otp,
      );

      // Sign in with credential
      final userCredential = await _auth.signInWithCredential(credential);

      print('✅ User signed in: ${userCredential.user?.uid}');

      // Save user data to local storage
      if (userCredential.user != null) {
        await _storage.setUserId(userCredential.user!.uid);
        await _storage.setPhoneNumber(userCredential.user!.phoneNumber ?? '');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print('❌ OTP verification failed: ${e.code} - ${e.message}');

      switch (e.code) {
        case 'invalid-verification-code':
          throw Exception('Invalid OTP code');
        case 'session-expired':
          throw Exception('OTP expired. Please request a new one');
        default:
          throw Exception('Verification failed: ${e.message}');
      }
    } catch (e) {
      print('❌ Error in verifyOtp: $e');
      rethrow;
    }
  }

  /// Sign in with PhoneAuthCredential (for auto-verify)
  Future<UserCredential?> signInWithCredential(
      PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);

      print('✅ User signed in with credential: ${userCredential.user?.uid}');

      // Save user data to local storage
      if (userCredential.user != null) {
        await _storage.setUserId(userCredential.user!.uid);
        await _storage.setPhoneNumber(userCredential.user!.phoneNumber ?? '');
      }

      return userCredential;
    } catch (e) {
      print('❌ Error in signInWithCredential: $e');
      rethrow;
    }
  }

  /// Resend OTP
  Future<void> resendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    await verifyPhoneNumber(
      phoneNumber: phoneNumber,
      onCodeSent: onCodeSent,
      onError: onError,
      onAutoVerify: (_) {},
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _storage.clearAll();
      print('✅ User signed out');
    } catch (e) {
      print('❌ Error signing out: $e');
      rethrow;
    }
  }

  /// Check session validity
  Future<bool> checkSession() async {
    try {
      final user = currentUser;
      if (user != null) {
        // Reload user data to check if token is still valid
        await user.reload();
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Session check failed: $e');
      return false;
    }
  }
}

/// Provider for AuthService
final authServiceProvider = Provider<AuthService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return AuthService(storage);
});

/// Provider for current Firebase User
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});
