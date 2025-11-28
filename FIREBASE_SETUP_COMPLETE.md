# ✅ Firebase Setup Complete - Guard App

## What Was Done

### 1. Firebase Config Files Placed ✅

**Android**:
- File: `google-services.json`
- Location: `society360_guard/android/app/google-services.json`
- Package: `com.society360.society360_guard`
- Size: 1.1KB
- ✅ Verified

**iOS**:
- File: `GoogleService-Info.plist`
- Location: `society360_guard/ios/Runner/GoogleService-Info.plist`
- Bundle ID: `com.society360.society360Guard`
- Size: 894B
- ✅ Verified

### 2. Firebase Initialized in Code ✅

Updated `lib/main.dart` to include:

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // ... rest of app initialization
}
```

### 3. Dependencies Installed ✅

```bash
✅ flutter clean
✅ flutter pub get
✅ pod install (iOS)
```

**Firebase Packages Installed**:
- `firebase_core: 3.15.2`
- `firebase_messaging: 15.2.10`
- `firebase_core_web: 2.24.1`
- `firebase_messaging_web: 3.10.10`
- `flutter_local_notifications: 18.0.1`

**iOS Pods Installed**:
- Firebase: 11.15.0
- FirebaseCore: 11.15.0
- FirebaseMessaging: 11.15.0
- 15 total pods installed

---

## 🧪 Testing the Setup

### Test 1: Verify Firebase Initialization

**Run the Guard app** and check the console logs:

```bash
flutter run
```

**Expected logs**:
```
✅ Firebase initialized successfully
✅ FCM token: f...xxxxx (long token string)
```

**If you see errors**:
- "FirebaseApp not initialized" → Config files in wrong location
- "No matching client found" → Package name mismatch in Firebase Console

---

### Test 2: Complete Notification Flow

#### Prerequisites:
1. ✅ Backend running: `cd society360_backend && npm run dev`
2. ✅ Resident app running on Device 1 (or Simulator 1)
3. ✅ Guard app running on Device 2 (or Simulator 2)

#### Test Steps:

**Step 1: Create Visitor Entry**
1. Open **Guard app**
2. Login as guard (e.g., guard@greenvalley.com / Test@123)
3. Tap **"New Entry"** button
4. Fill visitor details:
   - Name: John Doe
   - Phone: +91-9876543210
   - Flat: Select "Flat A-303"
   - Purpose: Meeting
5. Tap **"Submit"**

**Expected Result**:
- ✅ Visitor created successfully
- ✅ Resident receives **FCM notification**: "🔔 New Visitor Request"
- ✅ Resident receives **Socket.IO event**: `visitor_request`

---

**Step 2: Resident Approves Visitor**
1. Open **Resident app**
2. Tap the notification (or go to Approvals screen)
3. Tap **"Approve"** button

**Expected Result**:
- ✅ Guard receives **FCM notification**: "✅ Visitor Approved - John Doe approved by Rajesh Kumar"
- ✅ Guard receives **Socket.IO event**: `request_approved`
- ✅ Notification appears in Guard app's notification tray
- ✅ Tapping notification navigates to **Approvals screen**

---

**Step 3: Guard Checks In Visitor**
1. Open **Guard app**
2. Go to **Approvals** screen (tap notification or dashboard button)
3. Switch to **"Approved"** tab
4. You should see "John Doe" in the list
5. Tap **"Check In Visitor"** button

**Expected Result**:
- ✅ Visitor checked in successfully
- ✅ Resident receives **FCM notification**: "🚪 Visitor Checked In - John Doe has entered"
- ✅ Resident receives **Socket.IO event**: `visitor_checkin`
- ✅ John Doe removed from Guard app's "Approved" list

---

**Step 4: Test Rejection Flow**
1. Guard app → Create another visitor
2. Resident app → Receive notification → Tap **"Reject"**

**Expected Result**:
- ✅ Guard receives **FCM notification**: "❌ Visitor Rejected - [Name] rejected by [Resident]"
- ✅ Guard receives **Socket.IO event**: `request_approved` (with decision: "deny")
- ✅ Visitor appears in Guard app's **"Rejected"** tab

---

**Step 5: Test Auto-Rejection (Timeout)**
1. Guard app → Create another visitor
2. Wait 5 minutes (or whatever timeout is set in backend)
3. Don't approve or reject from Resident app

**Expected Result**:
- ✅ After timeout, Guard receives **FCM notification**: "⏱️ Request Timed Out - [Name] auto-rejected"
- ✅ Guard receives **Socket.IO event**: `visitor_timeout`
- ✅ Visitor appears in Guard app's **"Auto-Rejected"** tab

---

## 🔍 Debugging Tips

### Check FCM Token Registration

**In Guard App Logs**:
```
🔥 FCM Token: f...xxxxx
✅ FCM token registered with backend
```

**In Database**:
```sql
-- Check if guard's FCM token is stored
SELECT u.email, u.fcm_token, g.id as guard_id
FROM users u
JOIN guards g ON g.user_id = u.id
WHERE u.email = 'guard@greenvalley.com';
```

**Expected**:
- `fcm_token` should be a long string starting with `f...` or `c...`
- Not NULL

---

### Check Socket.IO Connection

**In Guard App Logs**:
```
🔌 Socket.IO connected to: http://localhost:3000
✅ Joined society room: society:1
```

**In Backend Logs**:
```
🔌 Client connected: abc123xyz
👤 User guard-user-id joined room: society:1
```

---

### Check Notification Delivery

**Backend Logs (when resident approves)**:
```
📤 Sending FCM notification to guard: guard-user-id
✅ FCM notification sent successfully
📡 Emitting to room: society:1
```

**Guard App Logs**:
```
📬 FCM notification received:
   Title: ✅ Visitor Approved
   Body: John Doe approved by Rajesh Kumar

🔔 Socket.IO event received: request_approved
   visitor_id: abc123
   decision: accept
```

---

## Common Issues & Solutions

### Issue 1: "FirebaseApp not initialized"

**Cause**: Firebase initialization failed

**Debug**:
1. Check `google-services.json` exists in `android/app/`
2. Check `GoogleService-Info.plist` exists in `ios/Runner/`
3. Verify `Firebase.initializeApp()` is called in `main.dart`
4. Run `flutter clean && flutter pub get`

---

### Issue 2: Guard Not Receiving Notifications

**Possible Causes**:

**A. FCM Token Not Registered**:
```sql
-- Check database
SELECT fcm_token FROM users WHERE email = 'guard@greenvalley.com';
```
If NULL → FCM service not initialized or token not saved

**B. Wrong Society Room**:
```javascript
// Backend should emit to correct society room
const roomName = `society:${visitor.society_id}`;
io.to(roomName).emit('request_approved', data);
```
Verify guard's society_id matches visitor's society_id

**C. Socket.IO Not Connected**:
Check Guard app logs for:
```
❌ Socket.IO connection failed
```
If disconnected → Check backend URL in `socket_service.dart`

---

### Issue 3: Notification Appears but Doesn't Navigate

**Cause**: Notification tap handler not set up correctly

**Fix**: Check `fcm_service.dart`:
```dart
// Handle notification tap (when app is in background/terminated)
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  debugPrint('Notification tapped!');
  if (onNotificationTap != null) {
    onNotificationTap!(message.data);
  }
});
```

---

### Issue 4: Different Package Name Error

**Error**: "The package name 'com.society360.society360_guard' does not match..."

**Fix**:
1. Verify in Firebase Console: Package name is exactly `com.society360.society360_guard`
2. Verify in `build.gradle.kts`: `applicationId = "com.society360.society360_guard"`
3. Re-download `google-services.json` if needed

---

## 📊 Expected Notification Counts

After completing all 5 tests:

**Guard App Should Have Received**:
- 3x "Visitor Approved" notifications (from Step 3)
- 1x "Visitor Rejected" notification (from Step 4)
- 1x "Visitor Timeout" notification (from Step 5)

**Resident App Should Have Received**:
- 5x "New Visitor Request" notifications (one for each visitor created)
- 1x "Visitor Checked In" notification (from Step 3)

---

## 🎯 Next Steps

1. ✅ Firebase config files placed
2. ✅ Firebase initialized in code
3. ✅ Dependencies installed
4. ⏳ **Run the app and test notification flow**
5. ⏳ Verify all 5 test scenarios work
6. ⏳ Check database for FCM token registration

---

## 📱 Running the App

### iOS Simulator:
```bash
flutter run -d "iPhone 15 Pro"
```

### Android Emulator:
```bash
flutter run -d emulator-5554
```

### Physical Device:
```bash
# List devices
flutter devices

# Run on specific device
flutter run -d <device-id>
```

---

## ✅ Success Criteria

You'll know everything is working when:

1. ✅ App launches without Firebase errors
2. ✅ FCM token appears in logs
3. ✅ Socket.IO connection established
4. ✅ Guard receives "Visitor Approved" notification from Resident app
5. ✅ Notification tap navigates to Approvals screen
6. ✅ Check-in button works and sends notification to Resident
7. ✅ All 3 tabs (Approved/Rejected/Auto-Rejected) work correctly

---

## 🚀 You're Ready!

All Firebase configuration is complete. The Guard app is now ready to:
- ✅ Receive FCM push notifications
- ✅ Listen to real-time Socket.IO events
- ✅ Show visitor approvals in categorized tabs
- ✅ Check in approved visitors
- ✅ Send check-in notifications to residents

**Run the app and start testing!** 🎉
