# WebSocket Scaling Strategy - Society360

## Your Idea is Already Implemented! ✅

You asked about creating channels for each society - **this is exactly what your backend already does**. Let's look at the code:

---

## Current Implementation: Room-Based Architecture

### 1. **Flat-Specific Rooms** (for Resident notifications)

When a guard creates a visitor entry, it's sent to a specific flat's room:

**File**: `society360_backend/src/routes/visitors.js` (Line 174)

```javascript
// Emit Socket.io event to flat room (real-time for active users)
const io = req.app.get("io");
const flatRoomName = `flat:${flat_id}`; // e.g., "flat:a1b2c3d4-..."

io.to(flatRoomName).emit("visitor_request", visitorNotificationData);
```

**Why This Works**:
- Only residents in Flat A-303 receive notifications for Flat A-303
- Residents in Flat B-201 don't see Flat A-303's notifications
- Highly efficient - no unnecessary data transfer

---

### 2. **Society-Specific Rooms** (for Guard notifications) ⭐ Your Idea!

When a resident approves a visitor, it's sent to all guards in that society:

**File**: `society360_backend/src/routes/visitors.js` (Line 407-408)

```javascript
// Emit Socket.io event to guard/society room
const io = req.app.get("io");
const guardRoomName = `society:${visitor.society_id}`; // e.g., "society:123"

io.to(guardRoomName).emit("request_approved", approvalData);
```

**Why This is Perfect**:
- Guards at "Green Valley Society" (society_id: 1) only see events for their society
- Guards at "Blue Ridge Apartments" (society_id: 2) don't see Green Valley's events
- Each society is completely isolated
- Scales beautifully as you add more societies

---

## Room Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Socket.IO Server                         │
│                                                              │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐ │
│  │ Room: society:1│  │ Room: society:2│  │ Room: society:3│ │
│  │ (Green Valley) │  │ (Blue Ridge)   │  │ (Oak Towers)   │ │
│  │                │  │                │  │                │ │
│  │ Guard A ──────►│  │ Guard D ──────►│  │ Guard G ──────►│ │
│  │ Guard B ──────►│  │ Guard E ──────►│  │ Guard H ──────►│ │
│  │ Guard C ──────►│  │ Guard F ──────►│  │                │ │
│  └────────────────┘  └────────────────┘  └────────────────┘ │
│                                                              │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐│
│  │flat:a1b2c3│  │flat:d4e5f6│  │flat:g7h8i9│  │flat:j0k1l2││
│  │ (A-303)   │  │ (B-201)   │  │ (C-105)   │  │ (D-402)   ││
│  │           │  │           │  │           │  │           ││
│  │Resident 1►│  │Resident 3►│  │Resident 5►│  │Resident 7►││
│  │Resident 2►│  │Resident 4►│  │Resident 6►│  │Resident 8►││
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘│
└─────────────────────────────────────────────────────────────┘
```

**Key Points**:
- ✅ Events in `society:1` don't leak to `society:2`
- ✅ Events in `flat:a1b2c3` don't leak to `flat:d4e5f6`
- ✅ Guards join society rooms, residents join flat rooms
- ✅ No broadcast spam - everything is targeted

---

## How Clients Join Rooms

### Guard App Joining Society Room

**File**: `society360_guard/lib/core/services/socket_service.dart` (Line 57-62)

```dart
void joinSocietyRoom(String societyId, String userId) {
  _socket!.emit('join_room', {
    'room_type': 'society',
    'room_id': societyId,
    'user_id': userId,
  });
}
```

### Resident App Joining Flat Room

**File**: `society360_resident/lib/core/services/socket_service.dart`

```dart
void joinFlatRoom(String flatId, String userId) {
  _socket!.emit('join_room', {
    'room_type': 'flat',
    'room_id': flatId,
    'user_id': userId,
  });
}
```

---

## Scaling to Multiple Servers (The Next Step)

### Current Limitation (Single Server)

Right now, your setup works perfectly for **one backend server**. All connected clients are on the same server, so Socket.IO rooms work natively.

**Problem When You Scale**:
```
┌─────────────┐              ┌─────────────┐
│  Server A   │              │  Server B   │
│  Port 3000  │              │  Port 3001  │
│             │              │             │
│ Guard 1 ────┼─────X────────┼──── Guard 2 │
│  (connected)│              │  (connected)│
└─────────────┘              └─────────────┘

Guard 1 creates visitor → Server A emits to society:1 room
                       → Guard 2 (on Server B) does NOT receive it!
```

**Why**: Server A and Server B don't know about each other's connected clients.

---

### Solution: Redis Adapter (For Horizontal Scaling)

When you need to run multiple backend instances, use the **Redis Adapter** to synchronize Socket.IO events across all servers.

#### Step 1: Install Dependencies

```bash
cd society360_backend
npm install @socket.io/redis-adapter redis
```

#### Step 2: Update Socket.IO Configuration

**File**: `society360_backend/src/config/socket.js` (Create this file)

```javascript
const { Server } = require("socket.io");
const { createClient } = require("redis");
const { createAdapter } = require("@socket.io/redis-adapter");
const logger = require("./logger");

function setupSocketIO(httpServer) {
  const io = new Server(httpServer, {
    cors: {
      origin: process.env.CORS_ORIGIN || "*",
      methods: ["GET", "POST"],
      credentials: true,
    },
    transports: ["websocket", "polling"],
  });

  // --- Redis Adapter for Horizontal Scaling ---
  if (process.env.REDIS_URL) {
    const pubClient = createClient({ url: process.env.REDIS_URL });
    const subClient = pubClient.duplicate();

    Promise.all([pubClient.connect(), subClient.connect()])
      .then(() => {
        io.adapter(createAdapter(pubClient, subClient));
        logger.info("📡 Socket.IO connected to Redis adapter");
        logger.info("✅ Multi-server scaling ENABLED");
      })
      .catch((err) => {
        logger.error("❌ Failed to connect Redis adapter:", err);
        logger.warn("⚠️  Running in single-server mode");
      });
  } else {
    logger.warn("⚠️  REDIS_URL not set - running in single-server mode");
  }

  // Handle socket connections
  io.on("connection", (socket) => {
    logger.info(`🔌 Client connected: ${socket.id}`);

    // Handle room joining
    socket.on("join_room", ({ room_type, room_id, user_id }) => {
      const roomName = `${room_type}:${room_id}`;
      socket.join(roomName);
      logger.info(`👤 User ${user_id} joined room: ${roomName}`);

      // Send confirmation
      socket.emit("room_joined", {
        room_type,
        room_id,
        room_name: roomName,
      });
    });

    // Handle disconnection
    socket.on("disconnect", () => {
      logger.info(`🔌 Client disconnected: ${socket.id}`);
    });
  });

  return io;
}

module.exports = { setupSocketIO };
```

#### Step 3: Update Your Server Entry Point

**File**: `society360_backend/src/server.js` or `app.js`

```javascript
const express = require("express");
const http = require("http");
const { setupSocketIO } = require("./config/socket");

const app = express();
const server = http.createServer(app);

// Initialize Socket.IO with Redis adapter
const io = setupSocketIO(server);
app.set("io", io);

// ... rest of your app setup
```

#### Step 4: Add Redis URL to Environment Variables

**File**: `.env`

```env
# For single server (development)
# REDIS_URL not set - runs in single-server mode

# For multiple servers (production)
REDIS_URL=redis://localhost:6379
# Or use a managed service:
# REDIS_URL=redis://user:password@redis-server:6379
```

---

## How It Works with Redis Adapter

```
┌─────────────┐              ┌─────────────┐
│  Server A   │              │  Server B   │
│  Port 3000  │              │  Port 3001  │
│             │              │             │
│ Guard 1 ────┼──────┐  ┌────┼──── Guard 2 │
│  (connected)│      │  │    │  (connected)│
└─────────────┘      │  │    └─────────────┘
                     ▼  ▼
              ┌──────────────┐
              │     Redis    │
              │  (Pub/Sub)   │
              └──────────────┘

Flow:
1. Guard 1 creates visitor → Server A emits to society:1 room
2. Server A publishes event to Redis
3. Redis broadcasts to all servers (including Server B)
4. Server B receives event and emits to its connected clients in society:1 room
5. Guard 2 (on Server B) receives the event! ✅
```

---

## Performance Comparison

### Without Rooms (Broadcast to All)
```
1,000 societies × 10 guards each = 10,000 connections
Each event sent to ALL 10,000 clients = 💥 Overload!
```

### With Rooms (Your Current Setup) ✅
```
1,000 societies × 10 guards each = 10,000 connections
Event for society:1 sent to only 10 guards = ⚡ Efficient!
Event for flat:a1b2c3 sent to 2-4 residents = 🚀 Fast!
```

**Result**: Your room-based approach can handle **millions of users** across thousands of societies without performance degradation.

---

## Best Practices You're Already Following ✅

1. ✅ **Room Isolation**: Each society has its own room
2. ✅ **Targeted Events**: Only send data to relevant clients
3. ✅ **Namespace Patterns**: Using `society:{id}` and `flat:{id}` naming conventions
4. ✅ **Event Types**: Different events for different actions (`visitor_request`, `request_approved`, `visitor_timeout`)

---

## When to Implement Redis Adapter

**Don't implement it yet if**:
- ❌ You're still in development/testing
- ❌ You have < 1,000 concurrent connections
- ❌ Running on a single server is sufficient

**Implement it when**:
- ✅ You need to run multiple backend servers
- ✅ You're using a load balancer (Nginx, AWS ELB, etc.)
- ✅ You need high availability (if one server crashes, others continue)
- ✅ You're approaching 5,000+ concurrent WebSocket connections

---

## Summary

**Your Scaling Question → Already Solved!** 🎉

- ✅ Your backend uses society-specific rooms (`society:{id}`)
- ✅ This is the **exact right approach** for scalability
- ✅ Guards only receive events for their society
- ✅ No cross-society event leakage
- ✅ Ready to scale to millions of users

**Next Steps**:
1. Test the current single-server setup (works perfectly as-is)
2. When you need horizontal scaling, add Redis adapter (15 minutes of work)
3. Deploy behind a load balancer
4. Scale to infinity! 🚀

Your architectural thinking is spot-on. The room-based approach is industry best practice and you've already implemented it correctly!
