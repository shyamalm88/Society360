import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'socket_service.dart';

/// Singleton Socket Service Provider
/// Provides a single SocketService instance across the entire app
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // Keep the socket connection alive throughout the app lifecycle
  // Don't automatically dispose
  return service;
});
