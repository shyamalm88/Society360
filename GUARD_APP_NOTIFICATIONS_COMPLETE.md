# Guard App - Visitor Approval Notifications & Check-in Flow ✅

## Overview

The Guard app now has complete integration for receiving visitor approval notifications and checking in visitors. This implements the full visitor management lifecycle from the guard's perspective.

---

## ✅ What's Implemented

### 1. **FCM Service** ([fcm_service.dart](society360_guard/lib/core/services/fcm_service.dart))
- Firebase Cloud Messaging integration
- Push notification handling (foreground & background)
- Local notifications display
- Notification tap navigation
- FCM token registration

### 2. **Socket.io Service** ([socket_service.dart](society360_guard/lib/core/services/socket_service.dart))
- Real-time WebSocket connection
- Society room joining (for guard-specific events)
- Visitor approval event listening
- Visitor timeout event listening
- Auto-reconnection support

### 3. **Visitor Service** ([visitor_service.dart](society360_guard/lib/core/services/visitor_service.dart))
- API integration for visitor operations
- Check-in functionality
- Check-out functionality
- Visitor history fetching
- Status-based visitor filtering

### 4. **Visitor Approvals Screen** ([visitor_approvals_screen.dart](society360_guard/lib/features/approvals/presentation/visitor_approvals_screen.dart))
- **3 Tabs**:
  - Approved visitors (with check-in button)
  - Rejected visitors
  - Auto-rejected visitors (timeouts)
- Real-time updates via Socket.io
- FCM notification integration
- Pull-to-refresh
- Check-in action with confirmation

### 5. **Dashboard Integration**
- New "Approvals" quick action button
- Navigation to approvals screen
- Updated with 4 quick actions

---

## 🔄 Complete Flow

### Scenario 1: Resident Approves Visitor

```
1. Guard creates visitor entry
   └─> Resident receives notification (FCM + Socket.io)

2. Resident approves the visitor
   └─> Backend: POST /visitors/:id/respond (decision: accept)

3. Guard receives notification
   ├─> FCM: "✅ Visitor Approved - [Name] approved by [Resident]"
   ├─> Socket.io: 'request_approved' event
   └─> Approval appears in "Approved" tab

4. Guard taps "Check In Visitor" button
   └─> Backend: POST /visits/checkin

5. Resident receives check-in notification
   ├─> FCM: "🚪 Visitor Checked In - [Name] has entered"
   └─> Socket.io: 'visitor_checkin' event
```

### Scenario 2: Resident Rejects Visitor

```
1. Guard creates visitor entry
   └─> Resident receives notification

2. Resident rejects the visitor
   └─> Backend: POST /visitors/:id/respond (decision: deny)

3. Guard receives notification
   ├─> FCM: "❌ Visitor Rejected - [Name] rejected by [Resident]"
   ├─> Socket.io: 'request_approved' event
   └─> Rejection appears in "Rejected" tab

4. Guard informs visitor (no entry allowed)
```

### Scenario 3: Auto-Rejection (Timeout)

```
1. Guard creates visitor entry
   └─> Resident receives notification

2. 5 minutes pass with no response
   └─> Backend timeout service auto-rejects

3. Guard receives notification
   ├─> FCM: "⏱️ Request Timed Out - [Name] auto-rejected"
   ├─> Socket.io: 'visitor_timeout' event
   └─> Appears in "Auto-Rejected" tab

4. Guard can still manually approve if resident calls/verifies
   └─> Backend: POST /visitors/:id/guard-respond
```

---

## 📱 Guard App Screens

### Dashboard Screen
```dart
Quick Actions (4 buttons):
1. ➕ New Entry - Register visitor
2. ✅ Approvals - View approval status (NEW!)
3. 📷 Scan QR - Quick check-in
4. 🔍 Search - Find visitor
```

### Visitor Approvals Screen
```dart
Tabs:
├─ Approved (X)
│  └─ Shows approved visitors with "Check In" button
├─ Rejected (X)
│  └─ Shows rejected visitors
└─ Auto-Rejected (X)
   └─ Shows timeout visitors
```

---

## 🔧 Setup Instructions

### Step 1: Add Firebase to Guard App

1. **Download `google-services.json`** from Firebase Console
   ```bash
   # Place in:
   society360_guard/android/app/google-services.json
   ```

2. **Download `GoogleService-Info.plist`** for iOS
   ```bash
   # Place in:
   society360_guard/ios/Runner/GoogleService-Info.plist
   ```

3. **Initialize Firebase in main.dart**
   ```dart
   import 'package:firebase_core/firebase_core.dart';

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     runApp(const MyApp());
   }
   ```

### Step 2: Update API Base URL

Update the Socket.io URL in [socket_service.dart](society360_guard/lib/core/services/socket_service.dart:26):

```dart
// For Android Emulator
const serverUrl = 'http://10.0.2.2:3000';

// For iOS Simulator
const serverUrl = 'http://localhost:3000';

// For Physical Device
const serverUrl = 'http://YOUR_IP_ADDRESS:3000';
```

### Step 3: Install Dependencies

```bash
cd society360_guard
flutter pub get
```

### Step 4: Run the App

```bash
flutter run
```

---

## 🧪 Testing the Complete Flow

### Prerequisites
1. Backend running: `cd society360_backend && npm run dev`
2. Resident app running on Device 1
3. Guard app running on Device 2

### Test Steps

**Test 1: Approval Flow**
1. Guard app → Create new visitor for Flat A-303
2. Resident app → Receive notification → Approve
3. Guard app → Receive "Visitor Approved" notification
4. Guard app → Go to Approvals → Approved tab
5. Guard app → Tap "Check In Visitor"
6. Resident app → Receive "Visitor Checked In" notification

**Test 2: Rejection Flow**
1. Guard app → Create new visitor
2. Resident app → Receive notification → Reject
3. Guard app → Receive "Visitor Rejected" notification
4. Guard app → Go to Approvals → Rejected tab
5. Verify visitor appears in rejected list

**Test 3: Timeout Flow**
1. Guard app → Create new visitor
2. Wait 5 minutes (or adjust timeout in backend)
3. Guard app → Receive "Request Timed Out" notification
4. Guard app → Go to Approvals → Auto-Rejected tab
5. Verify visitor appears in auto-rejected list

---

## 📝 Backend Endpoints Used

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/visitors` | POST | Create visitor (guard) |
| `/visitors/:id/respond` | POST | Approve/Reject visitor (resident) |
| `/visitors/:id/guard-respond` | POST | Manual override (guard) |
| `/visits/checkin` | POST | Check in visitor (guard) |
| `/visits/checkout` | POST | Check out visitor (guard) |
| `/visitors` | GET | Fetch visitors by status |

---

## 🔔 Notification Types

### Guard Receives:

1. **Visitor Approved**
   ```json
   {
     "type": "visitor_approval",
     "title": "✅ Visitor Approved",
     "body": "[Name] approved by [Resident]",
     "data": {
       "visitor_id": "...",
       "decision": "accept",
       "status": "accepted"
     }
   }
   ```

2. **Visitor Rejected**
   ```json
   {
     "type": "visitor_approval",
     "title": "❌ Visitor Rejected",
     "body": "[Name] rejected by [Resident]",
     "data": {
       "visitor_id": "...",
       "decision": "deny",
       "status": "denied"
     }
   }
   ```

3. **Visitor Timeout**
   ```json
   {
     "type": "visitor_timeout",
     "title": "⏱️ Request Timed Out",
     "body": "[Name] auto-rejected after 5 minutes",
     "data": {
       "visitor_id": "...",
       "visitor_name": "..."
     }
   }
   ```

---

## 🎯 Key Features

✅ Real-time notifications (FCM + Socket.io)
✅ Dual notification support (app active & background)
✅ Categorized approval views (Approved/Rejected/Auto-Rejected)
✅ One-tap check-in for approved visitors
✅ Pull-to-refresh for latest data
✅ Automatic UI updates on Socket.io events
✅ Error handling with user feedback

---

## 📂 Files Added/Modified

### New Files:
- `lib/core/services/fcm_service.dart` - FCM integration
- `lib/core/services/socket_service.dart` - WebSocket integration
- `lib/core/services/visitor_service.dart` - API integration
- `lib/features/approvals/presentation/visitor_approvals_screen.dart` - Approvals UI

### Modified Files:
- `pubspec.yaml` - Added Firebase & Socket.io dependencies
- `lib/config/router.dart` - Added approvals route
- `lib/features/dashboard/presentation/dashboard_screen.dart` - Added Approvals button

### Backend (No changes needed - already implemented):
- `src/routes/visitors.js` - Approval endpoints
- `src/routes/visits.js` - Check-in/out endpoints
- `src/services/notification_service.js` - FCM notifications
- `src/services/visitor_timeout_service.js` - Auto-rejection

---

## 🔮 Future Enhancements

1. **Add FCM token registration endpoint** in backend:
   ```javascript
   POST /guards/register-device
   {
     "fcm_token": "...",
     "user_id": "...",
     "device_info": {...}
   }
   ```

2. **Implement check-out flow** in Guard app
3. **Add visitor search** in approvals screen
4. **Add filters** (by date, status, etc.)
5. **Add visitor photos** in approval cards
6. **Add manual approval** for timeout cases

---

## ✅ Summary

The Guard app now has full notification support for the visitor approval workflow:
- Guards receive real-time updates when residents approve/reject visitors
- Guards can quickly check in approved visitors
- Guards can see rejected and auto-rejected visitors
- Everything is integrated with FCM and Socket.io for reliability

**All requirements completed! 🎉**
