# Socket.io Real-Time Events - Quick Reference

## Overview

The Society360 backend uses Socket.io for real-time visitor notifications. This eliminates the need for polling and provides instant updates to both Guard and Resident apps.

---

## Room Architecture

### Room Naming Convention

- **Flat Room:** `flat:<flat_id>` - For residents of a specific flat
- **Society Room:** `society:<society_id>` - For guards of a specific society

### Why Rooms?

Rooms allow targeted event emission. When a visitor arrives at Flat 101, only residents of Flat 101 receive the notification, not the entire building.

---

## Client Events (Flutter → Server)

### 1. Join Room

**When:** App starts, after user authentication

**Guard App:**
```javascript
socket.emit('join_room', {
  room_type: 'society',
  room_id: '<society_uuid>',
  user_id: '<guard_user_uuid>'
});
```

**Resident App:**
```javascript
socket.emit('join_room', {
  room_type: 'flat',
  room_id: '<flat_uuid>',
  user_id: '<resident_user_uuid>'
});
```

### 2. Leave Room

**When:** App goes to background or user logs out

```javascript
socket.emit('leave_room', {
  room_type: 'flat',  // or 'society'
  room_id: '<uuid>'
});
```

---

## Server Events (Server → Flutter)

### 1. visitor_request

**Emitted by:** `POST /v1/visitors` endpoint
**Sent to:** `flat:<flat_id>` room
**Receivers:** Residents of the specific flat

**Payload:**
```json
{
  "visitor_id": "uuid",
  "visitor_name": "Ramesh Kumar",
  "phone": "+9190XXXXXXX",
  "purpose": "delivery",
  "vehicle_no": "KA01AB1234",
  "flat_number": "101",
  "block_name": "Block A",
  "expected_start": "2025-11-26T10:00:00Z",
  "created_at": "2025-11-26T10:00:00Z",
  "status": "pending"
}
```

**Flutter Implementation (Resident App):**
```dart
_socketService.socket.on('visitor_request', (data) {
  print('🔔 New visitor at gate: ${data['visitor_name']}');

  // Show notification
  showDialog(
    context: context,
    builder: (context) => VisitorApprovalDialog(
      visitorName: data['visitor_name'],
      purpose: data['purpose'],
      onApprove: () => _approveVisitor(data['visitor_id']),
      onDeny: () => _denyVisitor(data['visitor_id']),
    ),
  );
});
```

### 2. request_approved

**Emitted by:** `POST /v1/visitors/:id/respond` endpoint
**Sent to:** `society:<society_id>` room
**Receivers:** Guards of the society

**Payload:**
```json
{
  "visitor_id": "uuid",
  "visitor_name": "Ramesh Kumar",
  "decision": "accept",  // or "deny"
  "status": "accepted",  // or "denied"
  "approver_name": "John Doe",
  "note": "Approved",
  "timestamp": "2025-11-26T10:05:00Z"
}
```

**Flutter Implementation (Guard App):**
```dart
_socketService.socket.on('request_approved', (data) {
  print('✅ Visitor ${data['decision']}: ${data['visitor_name']}');

  final color = data['decision'] == 'accept' ? Colors.green : Colors.red;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('${data['visitor_name']} ${data['decision']}ed by ${data['approver_name']}'),
      backgroundColor: color,
    ),
  );

  // Refresh visitor list
  _refreshVisitorList();
});
```

---

## Connection Management

### 1. Connect

```dart
void connect() {
  socket = IO.io(
    'http://localhost:3000',  // Change for production
    IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build(),
  );

  socket.onConnect((_) {
    print('✅ Socket connected: ${socket.id}');
    _onConnected();
  });

  socket.onDisconnect((_) {
    print('❌ Socket disconnected');
    _onDisconnected();
  });

  socket.onError((error) {
    print('Socket error: $error');
  });

  socket.connect();
}
```

### 2. Disconnect

```dart
void disconnect() {
  socket.disconnect();
}
```

### 3. Reconnection

Socket.io automatically handles reconnection. Listen to connection events:

```dart
socket.onConnect((_) {
  // Re-join rooms after reconnection
  _rejoinRooms();
});
```

---

## Complete Flutter Example

### SocketService Class

```dart
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter/foundation.dart';

class SocketService {
  static const String socketUrl = 'http://localhost:3000';

  late IO.Socket socket;
  bool _connected = false;

  bool get isConnected => _connected;

  void connect() {
    socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build(),
    );

    socket.onConnect((_) {
      debugPrint('✅ Socket connected: ${socket.id}');
      _connected = true;
    });

    socket.onDisconnect((_) {
      debugPrint('❌ Socket disconnected');
      _connected = false;
    });

    socket.onError((error) {
      debugPrint('Socket error: $error');
    });

    socket.connect();
  }

  void joinRoom(String roomType, String roomId, String userId) {
    if (!_connected) {
      debugPrint('⚠️ Socket not connected');
      return;
    }

    socket.emit('join_room', {
      'room_type': roomType,
      'room_id': roomId,
      'user_id': userId,
    });

    debugPrint('Joined room: $roomType:$roomId');
  }

  void leaveRoom(String roomType, String roomId) {
    socket.emit('leave_room', {
      'room_type': roomType,
      'room_id': roomId,
    });
  }

  void disconnect() {
    socket.disconnect();
    _connected = false;
  }
}
```

### Usage in StatefulWidget

```dart
class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SocketService _socketService = SocketService();

  @override
  void initState() {
    super.initState();
    _initSocket();
  }

  void _initSocket() {
    _socketService.connect();

    // Get user's flat ID from storage/state
    final flatId = 'user_flat_id_here';
    final userId = 'user_id_here';

    // Join flat room
    _socketService.joinRoom('flat', flatId, userId);

    // Listen for visitor requests
    _socketService.socket.on('visitor_request', _handleVisitorRequest);
  }

  void _handleVisitorRequest(dynamic data) {
    setState(() {
      // Update UI with new visitor
    });

    // Show dialog/bottom sheet
    _showVisitorDialog(data);
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Your UI here
  }
}
```

---

## Backend Implementation Reference

### Emitting Events (Backend)

**In routes/visitors.js:**

```javascript
// After saving visitor to database
const io = req.app.get('io');
const flatRoomName = `flat:${flat_id}`;

io.to(flatRoomName).emit('visitor_request', {
  visitor_id: visitor.id,
  visitor_name: visitor.visitor_name,
  phone: visitor.phone,
  purpose: visitor.purpose,
  // ... other fields
});
```

### Handling Room Join (Backend)

**In server.js:**

```javascript
io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}`);

  socket.on('join_room', (data) => {
    const { room_type, room_id, user_id } = data;
    const roomName = `${room_type}:${room_id}`;
    socket.join(roomName);
    console.log(`Socket ${socket.id} joined room: ${roomName}`);
  });

  socket.on('leave_room', (data) => {
    const { room_type, room_id } = data;
    const roomName = `${room_type}:${room_id}`;
    socket.leave(roomName);
    console.log(`Socket ${socket.id} left room: ${roomName}`);
  });

  socket.on('disconnect', () => {
    console.log(`Socket disconnected: ${socket.id}`);
  });
});
```

---

## Testing Socket Events

### Using Postman (WebSocket)

1. Create new WebSocket request
2. URL: `ws://localhost:3000`
3. Connect
4. Send: `{"room_type": "flat", "room_id": "uuid", "user_id": "uuid"}`

### Using Browser Console

```javascript
const socket = io('http://localhost:3000');

socket.on('connect', () => {
  console.log('Connected:', socket.id);

  socket.emit('join_room', {
    room_type: 'flat',
    room_id: 'test-flat-id',
    user_id: 'test-user-id'
  });
});

socket.on('visitor_request', (data) => {
  console.log('New visitor:', data);
});
```

---

## Troubleshooting

### Socket not connecting

**Check:**
1. Backend server is running (`npm run dev`)
2. Port 3000 is accessible
3. CORS is enabled in backend
4. WebSocket transport is allowed

**Flutter Debug:**
```dart
socket.onConnectError((error) {
  debugPrint('Connection error: $error');
});
```

### Events not received

**Check:**
1. Joined the correct room (`join_room` event sent)
2. Room ID matches the database record
3. Event listener registered before event emitted

**Backend Debug:**
```javascript
io.to(roomName).emit('visitor_request', data);
console.log(`Emitted to room: ${roomName}`, data);
console.log(`Room members:`, io.sockets.adapter.rooms.get(roomName));
```

### Duplicate events

**Issue:** Event listener registered multiple times

**Solution:**
```dart
// Remove old listeners before adding new
socket.off('visitor_request');
socket.on('visitor_request', _handleVisitor);
```

---

## Best Practices

1. **Connect once** - Initialize Socket in app startup, not per screen
2. **Join rooms on login** - Join appropriate rooms after authentication
3. **Leave rooms on logout** - Clean disconnect when user logs out
4. **Handle reconnection** - Re-join rooms after automatic reconnection
5. **Error handling** - Always handle connection errors gracefully
6. **Clean up** - Disconnect socket when app is closed

---

## Production Considerations

1. **SSL/TLS:** Use `wss://` instead of `ws://`
2. **Scaling:** Use Redis adapter for multi-server Socket.io
3. **Authentication:** Verify user permissions before joining rooms
4. **Rate Limiting:** Limit event emissions per second
5. **Monitoring:** Log all Socket events and connections

---

**Socket.io documentation:** https://socket.io/docs/v4/
**socket_io_client (Flutter):** https://pub.dev/packages/socket_io_client
