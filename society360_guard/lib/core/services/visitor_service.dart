import 'package:flutter/foundation.dart';
import '../api/api_client.dart';

/// Visitor Service for Guard App
/// Handles all visitor-related API calls
class VisitorService {
  final ApiClient _apiClient;

  VisitorService(this._apiClient);

  /// Fetch all visitors (without status filter)
  Future<List<Map<String, dynamic>>> fetchVisitors({
    String? flatId,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (flatId != null) {
        queryParams['flat_id'] = flatId;
      }

      final response = await _apiClient.get(
        '/visitors',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        final data = responseData['data'] as List;
        return data.cast<Map<String, dynamic>>();
      }

      throw Exception('Failed to fetch visitors');
    } catch (e) {
      debugPrint('Error fetching visitors: $e');
      rethrow;
    }
  }

  /// Fetch visitors by status
  /// Status can be: accepted, denied, pending, checked_in, checked_out
  Future<List<Map<String, dynamic>>> fetchVisitorsByStatus(
    String status,
  ) async {
    try {
      final response = await _apiClient.get(
        '/visitors',
        queryParameters: {'status': status},
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        final data = responseData['data'] as List;
        return data.cast<Map<String, dynamic>>();
      }

      throw Exception('Failed to fetch visitors');
    } catch (e) {
      debugPrint('Error fetching visitors: $e');
      rethrow;
    }
  }

  /// Check in a visitor
  Future<Map<String, dynamic>> checkInVisitor({
    required String visitorId,
    required String guardId,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '/visits/checkin',
        data: {
          'visitor_id': visitorId,
          'guard_id': guardId,
          'checkin_method': 'manual',
          if (notes != null) 'notes': notes,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        debugPrint('✅ Visitor checked in successfully');
        return responseData['data'] as Map<String, dynamic>;
      }

      throw Exception(responseData['error'] ?? 'Failed to check in visitor');
    } catch (e) {
      debugPrint('❌ Error checking in visitor: $e');
      rethrow;
    }
  }

  /// Check out a visitor
  Future<Map<String, dynamic>> checkOutVisitor({
    required String visitId,
    String? guardId,
    String? notes,
  }) async {
    try {
      final response = await _apiClient.post(
        '/visits/checkout',
        data: {
          'visit_id': visitId,
          if (guardId != null) 'guard_id': guardId,
          if (notes != null) 'notes': notes,
        },
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        debugPrint('✅ Visitor checked out successfully');
        return responseData['data'] as Map<String, dynamic>;
      }

      throw Exception(responseData['error'] ?? 'Failed to check out visitor');
    } catch (e) {
      debugPrint('❌ Error checking out visitor: $e');
      rethrow;
    }
  }

  /// Clear all rejected visitors (soft delete)
  Future<Map<String, dynamic>> clearRejectedVisitors() async {
    try {
      final response = await _apiClient.delete('/visitors/rejected');

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        debugPrint('✅ Cleared ${responseData['deleted_count']} rejected visitors');
        return responseData;
      }

      throw Exception(responseData['error'] ?? 'Failed to clear rejected visitors');
    } catch (e) {
      debugPrint('❌ Error clearing rejected visitors: $e');
      rethrow;
    }
  }

  /// Fetch visit history
  Future<List<Map<String, dynamic>>> fetchVisitHistory({
    String? flatId,
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'limit': limit.toString(),
        if (flatId != null) 'flat_id': flatId,
        if (from != null) 'from': from.toIso8601String(),
        if (to != null) 'to': to.toIso8601String(),
      };

      final response = await _apiClient.get(
        '/visits',
        queryParameters: queryParams,
      );

      final responseData = response.data as Map<String, dynamic>;
      if (responseData['success'] == true) {
        final data = responseData['data'] as List;
        return data.cast<Map<String, dynamic>>();
      }

      throw Exception('Failed to fetch visit history');
    } catch (e) {
      debugPrint('Error fetching visit history: $e');
      rethrow;
    }
  }

  /// Register FCM token
  Future<void> registerFCMToken(String token, String userId) async {
    try {
      // TODO: Implement this endpoint in backend
      await _apiClient.post(
        '/guards/register-device',
        data: {
          'fcm_token': token,
          'user_id': userId,
          'device_info': {
            'platform': 'android', // or 'ios'
            'app_version': '1.0.0',
          },
        },
      );

      debugPrint('✅ FCM token registered successfully');
    } catch (e) {
      debugPrint('❌ Error registering FCM token: $e');
      // Don't rethrow - this is not critical
    }
  }
}
