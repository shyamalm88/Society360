import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'socket_service_provider.dart';
import 'profile_service.dart';
import 'fcm_service.dart';
import '../api/api_client.dart';
import '../auth/auth_repository.dart';

/// App Initialization Service
/// Initializes Socket.io and FCM when the app starts (after authentication)
class AppInitializationService {
  final Ref ref;

  String? _guardId;
  String? _societyId;
  String? _userId;
  bool _isInitialized = false;

  AppInitializationService(this.ref);

  /// Initialize app services (Socket.io, FCM, Profile)
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ App already initialized, skipping...');
      return;
    }

    try {
      debugPrint('🚀 App Initialization: Starting...');

      // Fetch profile to get guard_id, society_id, user_id
      await _fetchProfile();

      // Initialize Socket.io
      await _initializeSocket();

      // Initialize FCM
      await _initializeFCM();

      _isInitialized = true;
      debugPrint('✅ App Initialization: Complete');
    } catch (e) {
      debugPrint('❌ App Initialization: Error: $e');
      // Don't throw - allow app to continue even if initialization fails
    }
  }

  /// Fetch user profile and save IDs
  Future<void> _fetchProfile() async {
    try {
      debugPrint('📋 Fetching user profile...');

      final apiClient = ref.read(apiClientProvider);
      final profileService = ProfileService(apiClient);
      final profile = await profileService.fetchProfile();

      final guard = profile['guard'] as Map<String, dynamic>?;
      final user = profile['user'] as Map<String, dynamic>?;

      if (guard != null && user != null) {
        _guardId = guard['guard_id'] as String?;
        _societyId = guard['society_id'] as String?;
        _userId = user['id'] as String?;

        debugPrint('✅ Profile loaded: guardId=$_guardId, societyId=$_societyId, userId=$_userId');

        // Save to auth repository for future use
        final authRepo = ref.read(authRepositoryProvider);
        if (_userId != null && _guardId != null && _societyId != null) {
          await authRepo.saveProfileData(
            userId: _userId!,
            guardId: _guardId!,
            societyId: _societyId!,
          );
        }
      } else {
        debugPrint('⚠️ Profile incomplete - guard or user data missing');
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      rethrow;
    }
  }

  /// Initialize Socket.io connection
  Future<void> _initializeSocket() async {
    try {
      debugPrint('🔌 Initializing Socket.io...');

      // Get singleton Socket.io service
      final socketService = ref.read(socketServiceProvider);

      // Connect to Socket.io server
      socketService.connect();

      // Join society room if we have the IDs
      if (_societyId != null && _userId != null) {
        socketService.joinSocietyRoom(_societyId!, _userId!);
        debugPrint('✅ Socket.io initialized and joined room: society:$_societyId');
      } else {
        debugPrint('⚠️ Cannot join society room - missing IDs');
      }
    } catch (e) {
      debugPrint('❌ Error initializing Socket.io: $e');
      rethrow;
    }
  }

  /// Initialize FCM
  Future<void> _initializeFCM() async {
    try {
      debugPrint('📱 Initializing FCM...');

      final apiClient = ref.read(apiClientProvider);
      final fcmService = FCMService(apiClient: apiClient);

      await fcmService.initialize();
      await fcmService.registerToken();

      debugPrint('✅ FCM initialized');
    } catch (e) {
      debugPrint('❌ Error initializing FCM: $e');
      // Don't rethrow - FCM is not critical for app to function
    }
  }

  /// Reset initialization state (for logout)
  void reset() {
    _isInitialized = false;
    _guardId = null;
    _societyId = null;
    _userId = null;
    debugPrint('🔄 App initialization state reset');
  }

  /// Get profile data
  Map<String, String?> getProfileData() {
    return {
      'guardId': _guardId,
      'societyId': _societyId,
      'userId': _userId,
    };
  }
}

/// Provider for App Initialization Service
final appInitializationServiceProvider = Provider<AppInitializationService>((ref) {
  return AppInitializationService(ref);
});
