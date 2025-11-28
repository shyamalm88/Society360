import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Socket.io Service for Guard App
/// Handles real-time communication for visitor approvals and updates
class SocketService {
  IO.Socket? _socket;
  bool _isConnected = false;

  // Store room info for auto-joining on connection/reconnection
  String? _pendingSocietyId;
  String? _pendingUserId;

  /// Multiple callbacks for visitor approval events
  final List<Function(Map<String, dynamic>)> _approvalListeners = [];

  /// Multiple callbacks for visitor timeout events
  final List<Function(Map<String, dynamic>)> _timeoutListeners = [];

  /// Multiple callbacks for rejected visitors cleared events
  final List<Function(Map<String, dynamic>)> _rejectedClearedListeners = [];

  /// Multiple callbacks for visitor check-in events
  final List<Function(Map<String, dynamic>)> _checkinListeners = [];

  /// Multiple callbacks for visitor checkout events
  final List<Function(Map<String, dynamic>)> _checkoutListeners = [];

  /// Legacy single callback for visitor approval events (deprecated)
  @Deprecated('Use addApprovalListener instead')
  Function(Map<String, dynamic>)? onVisitorApproval;

  /// Legacy single callback for visitor timeout events (deprecated)
  @Deprecated('Use addTimeoutListener instead')
  Function(Map<String, dynamic>)? onVisitorTimeout;

  /// Get socket instance
  IO.Socket? get socket => _socket;

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Add a listener for visitor approval events
  void addApprovalListener(Function(Map<String, dynamic>) listener) {
    if (!_approvalListeners.contains(listener)) {
      _approvalListeners.add(listener);
      debugPrint('✅ Added approval listener (total: ${_approvalListeners.length})');
    }
  }

  /// Remove a listener for visitor approval events
  void removeApprovalListener(Function(Map<String, dynamic>) listener) {
    _approvalListeners.remove(listener);
    debugPrint('🗑️ Removed approval listener (remaining: ${_approvalListeners.length})');
  }

  /// Add a listener for visitor timeout events
  void addTimeoutListener(Function(Map<String, dynamic>) listener) {
    if (!_timeoutListeners.contains(listener)) {
      _timeoutListeners.add(listener);
      debugPrint('✅ Added timeout listener (total: ${_timeoutListeners.length})');
    }
  }

  /// Remove a listener for visitor timeout events
  void removeTimeoutListener(Function(Map<String, dynamic>) listener) {
    _timeoutListeners.remove(listener);
    debugPrint('🗑️ Removed timeout listener (remaining: ${_timeoutListeners.length})');
  }

  /// Add a listener for rejected visitors cleared events
  void addRejectedClearedListener(Function(Map<String, dynamic>) listener) {
    if (!_rejectedClearedListeners.contains(listener)) {
      _rejectedClearedListeners.add(listener);
      debugPrint('✅ Added rejected cleared listener (total: ${_rejectedClearedListeners.length})');
    }
  }

  /// Remove a listener for rejected visitors cleared events
  void removeRejectedClearedListener(Function(Map<String, dynamic>) listener) {
    _rejectedClearedListeners.remove(listener);
    debugPrint('🗑️ Removed rejected cleared listener (remaining: ${_rejectedClearedListeners.length})');
  }

  /// Add a listener for visitor check-in events
  void addCheckinListener(Function(Map<String, dynamic>) listener) {
    if (!_checkinListeners.contains(listener)) {
      _checkinListeners.add(listener);
      debugPrint('✅ Added check-in listener (total: ${_checkinListeners.length})');
    }
  }

  /// Remove a listener for visitor check-in events
  void removeCheckinListener(Function(Map<String, dynamic>) listener) {
    _checkinListeners.remove(listener);
    debugPrint('🗑️ Removed check-in listener (remaining: ${_checkinListeners.length})');
  }

  /// Add a listener for visitor checkout events
  void addCheckoutListener(Function(Map<String, dynamic>) listener) {
    if (!_checkoutListeners.contains(listener)) {
      _checkoutListeners.add(listener);
      debugPrint('✅ Added checkout listener (total: ${_checkoutListeners.length})');
    }
  }

  /// Remove a listener for visitor checkout events
  void removeCheckoutListener(Function(Map<String, dynamic>) listener) {
    _checkoutListeners.remove(listener);
    debugPrint('🗑️ Removed checkout listener (remaining: ${_checkoutListeners.length})');
  }

  /// Connect to Socket.io server
  void connect() {
    try {
      // TODO: Replace with your backend URL
      // For Android emulator use: http://10.0.2.2:3000
      // For iOS simulator use: http://localhost:3000
      // For physical device use: http://YOUR_IP:3000
      const serverUrl = 'http://localhost:3000';

      debugPrint('📡 Connecting to Socket.io server: $serverUrl');

      _socket = IO.io(
        serverUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .setReconnectionAttempts(5)
            .setReconnectionDelay(1000)
            .build(),
      );

      _socket!.onConnect((_) {
        _isConnected = true;
        debugPrint('✅ Socket.io connected');

        // Auto-join pending room if available
        if (_pendingSocietyId != null && _pendingUserId != null) {
          _joinRoom(_pendingSocietyId!, _pendingUserId!);
        }
      });

      _socket!.onDisconnect((_) {
        _isConnected = false;
        debugPrint('⚠️ Socket.io disconnected');
      });

      _socket!.onConnectError((error) {
        debugPrint('❌ Socket.io connection error: $error');
      });

      _socket!.onError((error) {
        debugPrint('❌ Socket.io error: $error');
      });

      // Listen for visitor approval events
      _socket!.on('request_approved', (data) {
        debugPrint('📨 Visitor approval received: $data');
        debugPrint('🔍 Number of approval listeners: ${_approvalListeners.length}');
        final eventData = data as Map<String, dynamic>;

        // Call all registered listeners
        int callbackCount = 0;
        for (final listener in _approvalListeners) {
          try {
            debugPrint('🔔 Calling approval listener #${callbackCount + 1}');
            listener(eventData);
            callbackCount++;
            debugPrint('✅ Approval listener #$callbackCount executed successfully');
          } catch (e) {
            debugPrint('❌ Error in approval listener #${callbackCount + 1}: $e');
          }
        }
        debugPrint('📊 Total approval listeners called: $callbackCount');

        // Call legacy single callback for backward compatibility
        if (onVisitorApproval != null) {
          try {
            onVisitorApproval!(eventData);
          } catch (e) {
            debugPrint('❌ Error in legacy approval callback: $e');
          }
        }
      });

      // Listen for visitor timeout events
      _socket!.on('visitor_timeout', (data) {
        debugPrint('⏱️ Visitor timeout received: $data');
        final eventData = data as Map<String, dynamic>;

        // Call all registered listeners
        for (final listener in _timeoutListeners) {
          try {
            listener(eventData);
          } catch (e) {
            debugPrint('❌ Error in timeout listener: $e');
          }
        }

        // Call legacy single callback for backward compatibility
        if (onVisitorTimeout != null) {
          try {
            onVisitorTimeout!(eventData);
          } catch (e) {
            debugPrint('❌ Error in legacy timeout callback: $e');
          }
        }
      });

      // Listen for rejected visitors cleared events
      _socket!.on('rejected_visitors_cleared', (data) {
        debugPrint('🗑️ Rejected visitors cleared received: $data');
        final eventData = data as Map<String, dynamic>;

        // Call all registered listeners
        for (final listener in _rejectedClearedListeners) {
          try {
            listener(eventData);
          } catch (e) {
            debugPrint('❌ Error in rejected cleared listener: $e');
          }
        }
      });

      // Listen for visitor check-in events
      _socket!.on('visitor_checkin', (data) {
        debugPrint('🚪 Visitor check-in received: $data');
        final eventData = data as Map<String, dynamic>;

        // Call all registered listeners
        for (final listener in _checkinListeners) {
          try {
            listener(eventData);
          } catch (e) {
            debugPrint('❌ Error in check-in listener: $e');
          }
        }
      });

      // Listen for visitor checkout events
      _socket!.on('visitor_checkout', (data) {
        debugPrint('👋 Visitor checkout received: $data');
        final eventData = data as Map<String, dynamic>;

        // Call all registered listeners
        for (final listener in _checkoutListeners) {
          try {
            listener(eventData);
          } catch (e) {
            debugPrint('❌ Error in checkout listener: $e');
          }
        }
      });

      _socket!.connect();
    } catch (e) {
      debugPrint('❌ Socket connection error: $e');
    }
  }

  /// Join society room (for guards to receive approvals)
  /// Stores the room info and joins immediately if connected, or on next connection
  void joinSocietyRoom(String societyId, String userId) {
    _pendingSocietyId = societyId;
    _pendingUserId = userId;

    if (_socket != null && _isConnected) {
      _joinRoom(societyId, userId);
    } else {
      debugPrint('⏳ Socket not connected yet - will join room on connection');
    }
  }

  /// Internal method to actually join the room
  void _joinRoom(String societyId, String userId) {
    if (_socket != null) {
      final roomData = {
        'room_type': 'society',
        'room_id': societyId,
        'user_id': userId,
      };

      _socket!.emit('join_room', roomData);
      debugPrint('🚪 Joined society room: society:$societyId');
    }
  }

  /// Leave room
  void leaveRoom(String roomType, String roomId) {
    if (_socket != null && _isConnected) {
      final roomData = {
        'room_type': roomType,
        'room_id': roomId,
      };

      _socket!.emit('leave_room', roomData);
      debugPrint('🚪 Left room: $roomType:$roomId');
    }
  }

  /// Disconnect from Socket.io server
  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _isConnected = false;
      debugPrint('🔌 Socket.io disconnected');
    }
  }
}
