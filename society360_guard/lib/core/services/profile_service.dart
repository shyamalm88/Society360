import '../api/api_client.dart';
import 'package:flutter/foundation.dart';

/// Profile Service
/// Handles fetching and managing user profile data
class ProfileService {
  final ApiClient _apiClient;

  ProfileService(this._apiClient);

  /// Fetch current user profile
  /// Returns guard info including guard_id and society_id
  Future<Map<String, dynamic>> fetchProfile() async {
    try {
      debugPrint('📱 Fetching user profile...');

      final response = await _apiClient.get('/profile/me');
      final data = response.data as Map<String, dynamic>;

      if (data['success'] == true) {
        debugPrint('✅ Profile fetched successfully');
        return data['data'] as Map<String, dynamic>;
      } else {
        throw Exception(data['error'] ?? 'Failed to fetch profile');
      }
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      rethrow;
    }
  }
}
