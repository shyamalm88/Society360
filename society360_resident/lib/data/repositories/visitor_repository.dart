import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/metadata_models.dart';
import '../../core/api/api_client.dart';
import '../../core/config/network_config.dart';

/// Visitor Repository
/// Handles visitor-related API calls for pending approvals
class VisitorRepository {
  final ApiClient _apiClient;

  VisitorRepository(this._apiClient);

  /// Fetch all pending visitor requests for current user's flats
  Future<List<Visitor>> getPendingVisitors() async {
    try {
      debugPrint('📥 Fetching pending visitors...');
      final response = await _apiClient.get('/visitors/pending');

      debugPrint('📥 Response: ${response.statusCode} - ${response.data}');

      if (response.data['success'] == true) {
        final List<dynamic> visitorsData = response.data['data'] ?? [];
        debugPrint('✅ Found ${visitorsData.length} pending visitors');

        return visitorsData.map((visitorData) {
          return Visitor.fromJson(visitorData as Map<String, dynamic>);
        }).toList();
      }

      debugPrint('⚠️ API returned success=false: ${response.data}');
      return [];
    } catch (e) {
      debugPrint('❌ Error fetching pending visitors: $e');
      // Rethrow so the stream can handle retry logic
      rethrow;
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

  /// Fetch today's visitors for a specific flat
  Future<List<Map<String, dynamic>>> getTodaysVisitors(String flatId) async {
    try {
      final response = await _apiClient.get('/visitors', queryParameters: {
        'flat_id': flatId,
      });

      if (response.data['success'] == true) {
        final List<dynamic> visitorsData = response.data['data'];
        final allVisitors = visitorsData.cast<Map<String, dynamic>>();

        // Filter for today's visitors
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        final todayEnd = todayStart.add(const Duration(days: 1));

        final todaysVisitors = allVisitors.where((visitor) {
          final expectedStart = visitor['expected_start'];
          if (expectedStart == null) return false;

          final visitDateTime = DateTime.parse(expectedStart);
          // Use >= and < comparison to include visitors at the start of the day
          return !visitDateTime.isBefore(todayStart) && visitDateTime.isBefore(todayEnd);
        }).toList();

        // Sort by expected time (latest first)
        todaysVisitors.sort((a, b) {
          final aTime = DateTime.parse(a['expected_start']);
          final bTime = DateTime.parse(b['expected_start']);
          return bTime.compareTo(aTime);
        });

        print('✅ Found ${todaysVisitors.length} visitors for today (Flat: $flatId)');
        return todaysVisitors;
      }

      return [];
    } catch (e) {
      print('❌ Error fetching today\'s visitors: $e');
      return [];
    }
  }
}

/// Riverpod Provider for Visitor Repository
final visitorRepositoryProvider = Provider<VisitorRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return VisitorRepository(apiClient);
});

/// Provider for pending visitors list with auto-refresh
/// Uses StreamProvider for safe periodic updates without timer leak issues
final pendingVisitorsProvider = StreamProvider<List<Visitor>>((ref) {
  final repo = ref.watch(visitorRepositoryProvider);

  // Create a stream that emits visitor data periodically
  return _createAutoRefreshStream<List<Visitor>>(
    fetchData: () => repo.getPendingVisitors(),
    interval: NetworkConfig.visitorRefreshInterval,
    name: 'pendingVisitors',
    fallbackValue: [], // Return empty list on error instead of failing
  );
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

/// Provider for today's visitors for the current flat with auto-refresh
final todaysVisitorsProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, flatId) {
  final repo = ref.watch(visitorRepositoryProvider);

  // Create a stream that emits visitor data periodically
  return _createAutoRefreshStream<List<Map<String, dynamic>>>(
    fetchData: () => repo.getTodaysVisitors(flatId),
    interval: NetworkConfig.visitorRefreshInterval,
    name: 'todaysVisitors',
    fallbackValue: [], // Return empty list on error instead of failing
  );
});

/// Helper function to create an auto-refreshing stream
/// Safely handles periodic data fetching without timer leaks
Stream<T> _createAutoRefreshStream<T>({
  required Future<T> Function() fetchData,
  required Duration interval,
  required String name,
  T? fallbackValue,
}) async* {
  const maxInitialRetries = 3;
  const retryDelay = Duration(seconds: 2);

  // Try initial fetch with retries
  T? initialData;
  Exception? lastError;

  for (int attempt = 0; attempt < maxInitialRetries; attempt++) {
    try {
      debugPrint('🔄 [$name] Initial fetch (attempt ${attempt + 1})...');
      initialData = await fetchData();
      debugPrint('✅ [$name] Initial fetch successful');
      break;
    } catch (e) {
      lastError = e is Exception ? e : Exception(e.toString());
      debugPrint('❌ [$name] Initial fetch error (attempt ${attempt + 1}): $e');

      if (attempt < maxInitialRetries - 1) {
        debugPrint('🔄 [$name] Retrying in ${retryDelay.inSeconds}s...');
        await Future.delayed(retryDelay);
      }
    }
  }

  // Emit initial data or throw if all retries failed
  if (initialData != null) {
    yield initialData;
  } else if (fallbackValue != null) {
    debugPrint('⚠️ [$name] Using fallback value after all retries failed');
    yield fallbackValue;
  } else if (lastError != null) {
    debugPrint('❌ [$name] All initial fetch retries failed, throwing error');
    throw lastError;
  }

  // Then emit periodically (continues even after errors)
  await for (final _ in Stream.periodic(interval)) {
    try {
      debugPrint('🔄 [$name] Refreshing...');
      final data = await fetchData();
      yield data;
    } catch (e) {
      debugPrint('❌ [$name] Refresh error: $e');
      // Continue the stream even on error - next tick will retry
    }
  }
}
