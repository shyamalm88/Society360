# Firebase Setup for Guard App

## Overview
Both the Resident app and Guard app can use the **same Firebase project** (Society360), but each app must be registered separately within that project.

---

## Step-by-Step Setup

### 1. Add Guard App to Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Open your **Society360** project
3. Click the **gear icon** → **Project settings**
4. Scroll down to "Your apps" section

You should see your existing Resident app listed. Now you'll add the Guard app:

---

### 2. Register Android Guard App

1. Click **"Add app"** → Select **Android** icon
2. Fill in the details:
   ```
   Android package name: com.society360.society360Guard
   App nickname (optional): Society360 Guard App
   Debug signing certificate SHA-1: (optional for now)
   ```
3. Click **"Register app"**
4. **Download `google-services.json`**
5. Place it in: `society360_guard/android/app/google-services.json`

**Important**: This is a DIFFERENT file from your Resident app's `google-services.json`

---

### 3. Register iOS Guard App

1. In the same Firebase project, click **"Add app"** → Select **iOS** icon
2. Fill in the details:
   ```
   iOS bundle ID: com.society360.society360Guard
   App nickname (optional): Society360 Guard App iOS
   App Store ID: (optional)
   ```
3. Click **"Register app"**
4. **Download `GoogleService-Info.plist`**
5. Place it in: `society360_guard/ios/Runner/GoogleService-Info.plist`

**Important**: This is a DIFFERENT file from your Resident app's `GoogleService-Info.plist`

---

### 4. Verify Firebase Configuration Files

After adding the files, your directory structure should look like:

```
society360_guard/
├── android/
│   └── app/
│       ├── google-services.json  ← Guard app Android config
│       └── build.gradle
├── ios/
│   └── Runner/
│       ├── GoogleService-Info.plist  ← Guard app iOS config
│       └── Info.plist
```

---

### 5. Initialize Firebase in Guard App

The code is already in place! Check [main.dart](society360_guard/lib/main.dart):

```dart
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  runApp(const MyApp());
}
```

---

### 6. Update Backend to Send Notifications to Guards

The backend already has this implemented! In `notification_service.js`:

```javascript
// Fetch all guards for this society
const guardsResult = await query(
  `SELECT g.*, u.fcm_token
   FROM guards g
   JOIN users u ON g.user_id = u.id
   WHERE g.society_id = $1 AND u.fcm_token IS NOT NULL`,
  [societyId]
);

// Send FCM notification to each guard
for (const guard of guards) {
  await sendFCMNotification(guard.fcm_token, {
    title: '✅ Visitor Approved',
    body: `${approvalData.visitor_name} approved by ${approvalData.approver_name}`,
    data: approvalData,
  });
}
```

---

### 7. Test the Setup

**Test Flow:**
1. Run Guard app on a device/simulator
2. Log in as a guard
3. The app will automatically request FCM token and register it
4. Create a visitor entry from Guard app
5. Approve it from Resident app
6. Guard app should receive notification!

**Check FCM Token Registration:**
```sql
-- Verify guard has FCM token
SELECT u.email, u.fcm_token, g.id as guard_id
FROM users u
JOIN guards g ON g.user_id = u.id
WHERE u.fcm_token IS NOT NULL;
```

---

## Firebase Project Structure

```
Firebase Project: Society360
├── Android Apps:
│   ├── com.society360.society360 (Resident App)
│   └── com.society360.society360Guard (Guard App)
└── iOS Apps:
    ├── com.society360.society360 (Resident App iOS)
    └── com.society360.society360Guard (Guard App iOS)
```

**Key Points:**
- ✅ Same Firebase project (Society360)
- ✅ Same Cloud Messaging service
- ✅ Separate app registrations
- ✅ Different config files for each app
- ✅ Shared FCM quota and analytics

---

## Common Issues & Solutions

### Issue 1: "Default FirebaseApp is not initialized"
**Solution**: Make sure you've called `await Firebase.initializeApp()` before `runApp()`

### Issue 2: "No matching client found for package name"
**Solution**:
1. Check that package name in `android/app/build.gradle` matches Firebase console
2. Verify `google-services.json` is in the correct location
3. Run `flutter clean` and rebuild

### Issue 3: Guard not receiving notifications
**Solution**:
1. Check FCM token is registered in database
2. Verify guard's `society_id` matches the visitor's `society_id`
3. Check backend logs for FCM send failures
4. Test with Firebase Console's "Cloud Messaging" → "Send test message"

---

## Architecture Benefits

**Why Same Firebase Project?**
- ✅ Centralized management
- ✅ Shared Cloud Messaging quota
- ✅ Unified analytics dashboard
- ✅ Single billing account
- ✅ Easier cross-app user tracking

**Why Separate App Registrations?**
- ✅ Different package names/bundle IDs
- ✅ Independent versioning
- ✅ Separate crash reporting
- ✅ Different user bases (guards vs residents)

---

## Next Steps

1. ✅ Register Guard app in Firebase Console (Android & iOS)
2. ✅ Download and add config files to Guard app
3. ✅ Build and run Guard app
4. ✅ Test notification flow end-to-end
5. ✅ Monitor FCM token registration in database

Once you complete these steps, the Guard app will start receiving notifications!
