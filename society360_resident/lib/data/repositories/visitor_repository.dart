import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/metadata_models.dart';
import '../../core/api/api_client.dart';

/// Visitor Repository
/// Handles visitor-related API calls for pending approvals
class VisitorRepository {
  final ApiClient _apiClient;

  VisitorRepository(this._apiClient);

  /// Fetch all pending visitor requests for current user's flats
  Future<List<Visitor>> getPendingVisitors() async {
    try {
      final response = await _apiClient.get('/visitors/pending');

      if (response.data['success'] == true) {
        final List<dynamic> visitorsData = response.data['data'];

        return visitorsData.map((visitorData) {
          return Visitor.fromJson(visitorData as Map<String, dynamic>);
        }).toList();
      }

      return [];
    } catch (e) {
      print('❌ Error fetching pending visitors: $e');
      return [];
    }
  }

  /// Approve a visitor request
  /// Returns true if successful, false otherwise
  Future<bool> approveVisitor(String visitorId, {String? note}) async {
    try {
      final response = await _apiClient.post(
        '/visitors/$visitorId/respond',
        data: {
          'decision': 'accept',
          'note': note,
        },
      );

      if (response.data['success'] == true) {
        print('✅ Visitor approved: $visitorId');
        return true;
      }

      print('❌ Failed to approve visitor: ${response.data['error']}');
      return false;
    } catch (e) {
      print('❌ Error approving visitor: $e');
      return false;
    }
  }

  /// Reject a visitor request
  /// Returns true if successful, false otherwise
  Future<bool> rejectVisitor(String visitorId, {String? note}) async {
    try {
      final response = await _apiClient.post(
        '/visitors/$visitorId/respond',
        data: {
          'decision': 'deny',
          'note': note,
        },
      );

      if (response.data['success'] == true) {
        print('✅ Visitor rejected: $visitorId');
        return true;
      }

      print('❌ Failed to reject visitor: ${response.data['error']}');
      return false;
    } catch (e) {
      print('❌ Error rejecting visitor: $e');
      return false;
    }
  }

  /// Get visitor details by ID
  Future<Visitor?> getVisitorById(String visitorId) async {
    try {
      final response = await _apiClient.get('/visitors/$visitorId');

      if (response.data['success'] == true) {
        return Visitor.fromJson(response.data['data'] as Map<String, dynamic>);
      }

      return null;
    } catch (e) {
      print('❌ Error fetching visitor details: $e');
      return null;
    }
  }
}

/// Riverpod Provider for Visitor Repository
final visitorRepositoryProvider = Provider<VisitorRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VisitorRepository(apiClient);
});

/// Provider for pending visitors list
/// This provider auto-invalidates every 30 seconds to refresh pending visitors
final pendingVisitorsProvider = FutureProvider<List<Visitor>>((ref) async {
  final repo = ref.watch(visitorRepositoryProvider);

  // Auto-refresh every 30 seconds
  final timer = Timer.periodic(const Duration(seconds: 30), (_) {
    ref.invalidateSelf();
  });

  // Cleanup timer when provider is disposed
  ref.onDispose(() => timer.cancel());

  return repo.getPendingVisitors();
});

/// Provider for pending visitors count
final pendingVisitorsCountProvider = Provider<int>((ref) {
  final pendingVisitors = ref.watch(pendingVisitorsProvider);

  return pendingVisitors.when(
    data: (visitors) => visitors.length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
