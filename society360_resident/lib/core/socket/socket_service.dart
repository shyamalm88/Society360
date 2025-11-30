import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/network_config.dart';

/// Socket.io Service for real-time communication
/// Connects to backend Socket.io server and handles events
class SocketService {
  IO.Socket? _socket;
  bool _isConnected = false;
  Map<String, dynamic>? _pendingRoom;

  // Callback for visitor requests
  Function(Map<String, dynamic>)? onVisitorRequest;

  /// Get socket connection status
  bool get isConnected => _isConnected;

  /// Connect to Socket.io server
  void connect() {
    if (_socket != null && _isConnected) {
      debugPrint('🔌 Socket already connected');
      return;
    }

    final baseUrl = NetworkConfig.socketBaseUrl;
    debugPrint('🔌 Connecting to Socket.io server: $baseUrl');

    _socket = IO.io(
      baseUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setReconnectionAttempts(5)
          .setReconnectionDelay(1000)
          .build(),
    );

    _socket!.onConnect((_) {
      _isConnected = true;
      debugPrint('✅ Socket connected: ${_socket!.id}');

      // Join pending room if exists
      if (_pendingRoom != null) {
        debugPrint('🚪 Joining pending room: ${_pendingRoom!['room_type']}:${_pendingRoom!['room_id']}');
        _socket!.emit('join_room', _pendingRoom);
        _pendingRoom = null;
      }
    });

    _socket!.onDisconnect((_) {
      _isConnected = false;
      debugPrint('❌ Socket disconnected');
    });

    _socket!.onConnectError((error) {
      debugPrint('❌ Socket connection error: $error');
    });

    _socket!.onError((error) {
      debugPrint('❌ Socket error: $error');
    });

    // Listen for visitor requests
    _socket!.on('visitor_request', (data) {
      debugPrint('🔔 Visitor request received: $data');
      if (onVisitorRequest != null && data is Map<String, dynamic>) {
        onVisitorRequest!(data);
      }
    });

    _socket!.connect();
  }

  /// Join a room (typically flat:{flat_id})
  void joinRoom(String roomType, String roomId) {
    if (_socket == null) {
      debugPrint('❌ Cannot join room: Socket not initialized');
      return;
    }

    if (!_isConnected) {
      debugPrint('⏳ Socket not connected yet, will join room after connection');
      // Store room info to join after connection
      _pendingRoom = {'room_type': roomType, 'room_id': roomId};
      return;
    }

    debugPrint('🚪 Joining room: $roomType:$roomId');
    _socket!.emit('join_room', {
      'room_type': roomType,
      'room_id': roomId,
    });
    _pendingRoom = null;
  }

  /// Leave a room
  void leaveRoom(String roomType, String roomId) {
    if (_socket == null || !_isConnected) {
      return;
    }

    debugPrint('🚪 Leaving room: $roomType:$roomId');
    _socket!.emit('leave_room', {
      'room_type': roomType,
      'room_id': roomId,
    });
  }

  /// Disconnect from Socket.io server
  void disconnect() {
    if (_socket != null) {
      debugPrint('🔌 Disconnecting socket');
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
    }
  }

}

/// Riverpod Provider for SocketService
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();

  // Clean up when provider is disposed
  ref.onDispose(() {
    service.disconnect();
  });

  return service;
});
