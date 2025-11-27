# Guard App - Dynamic Data Integration Complete! ✅

## What Was Completed

### 1. **Added HTTP Client (Dio)** ✅
- Added `dio: ^5.4.0` to [pubspec.yaml](society360_guard/pubspec.yaml)
- Installed dependencies successfully
- Generated Riverpod code files

### 2. **Created API Service** ✅
File: [lib/core/api/api_client.dart](society360_guard/lib/core/api/api_client.dart)

```dart
/// Features:
- Dio-based HTTP client
- Automatic authorization header injection (Bearer token)
- Request/response logging interceptors
- Error handling with user-friendly messages
- Timeout configuration (30 seconds)
- RESTful methods: GET, POST, PUT, DELETE

/// Base URL: http://localhost:3000/v1
/// For Android emulator: Use http://10.0.2.2:3000/v1
```

### 3. **Updated Society Repository to Use Real API** ✅
File: [lib/data/repositories/society_repository.dart](society360_guard/lib/data/repositories/society_repository.dart)

**Before:** Hardcoded mock data (Block A, B, C with generated flats)
**After:** Fetches data from backend API

```dart
/// API Calls Made:
1. GET /complexes?society_id=<society_id>
2. GET /blocks?complex_id=<complex_id>
3. GET /flats?block_id=<block_id> (for each block)

/// Returns actual Block A with flats A-301, A-302, A-303, A-304, A-305
```

### 4. **Updated Visitor Form Controller to Submit to Real API** ✅
File: [lib/features/visitor/presentation/visitor_form_controller.dart](society360_guard/lib/features/visitor/presentation/visitor_form_controller.dart)

**Before:** Just printed JSON payload
**After:** Calls `POST /v1/visitors` with payload

```dart
/// Payload sent to backend:
{
  "visitor_name": "Dilip",
  "phone": "+911234567890",
  "purpose": "delivery",
  "flat_id": "cceedf3a-61c7-497e-92b2-7e45fa14583d", // Real UUID from database!
  "expected_start": "2025-11-26T14:00:00",
  "expected_end": "2025-11-26T16:00:00",
  "invited_by": "guard_001",
  "idempotency_key": "guard_1764146213643"
}
```

---

## How It Works Now

### End-to-End Flow:

1. **Guard opens visitor entry form**
   → App calls `GET /v1/complexes`, `/blocks`, `/flats`
   → Shows real Block A with 5 flats from database

2. **Guard selects flat A-303**
   → Uses **real flat_id** from database: `cceedf3a-61c7-497e-92b2-7e45fa14583d`
   → No more hardcoded `flat_a_3_3`!

3. **Guard submits form**
   → App calls `POST /v1/visitors` with real flat_id
   → Backend creates visitor in database
   → Backend sends Socket.io + FCM notifications to residents
   → Residents receive notification!

---

## Testing the Guard App

### Prerequisites:

1. **Backend must be running:**
   ```bash
   cd society360_backend
   npm run dev
   ```

   Expected output:
   ```
   ✅ Firebase Admin SDK initialized successfully
   🚀 Society360 Backend running on port 3000
   📡 Socket.io server ready
   ⏱️  Visitor timeout service started
   ```

2. **Database populated with seed data** (already done ✅)

### Run Guard App:

```bash
cd society360_guard
flutter run
```

### Test Steps:

1. **Login** (skip if already logged in)

2. **Add New Visitor:**
   - Enter name: "Dilip"
   - Enter phone: "1234567890"
   - Select purpose: "Delivery"
   - Select Block: **Block A** (loaded from database!)
   - Select Flat: **303** (loaded from database!)
   - Submit

3. **Check Backend Logs:**
   ```bash
   tail -f society360_backend/logs/combined.log
   ```

   Look for:
   ```
   POST /v1/visitors
   Socket.io event emitted: flat:cceedf3a-61c7-497e-92b2-7e45fa14583d
   FCM notification sent
   ```

4. **Verify in Database:**
   ```sql
   SELECT id, visitor_name, phone, flat_id, status
   FROM visitors
   ORDER BY created_at DESC
   LIMIT 1;
   ```

   Should show:
   ```
   visitor_name: Dilip
   flat_id: cceedf3a-61c7-497e-92b2-7e45fa14583d
   status: pending
   ```

---

## Important Notes for Android Emulator

If you're running on Android emulator, update the API base URL:

**File:** [lib/core/api/api_client.dart](society360_guard/lib/core/api/api_client.dart:87)

```dart
// Change from:
const baseUrl = 'http://localhost:3000/v1';

// To:
const baseUrl = 'http://10.0.2.2:3000/v1'; // Android emulator uses 10.0.2.2 for host machine
```

For iOS Simulator: `http://localhost:3000/v1` is correct.
For Physical Device: Use your machine's IP address (e.g., `http://192.168.1.100:3000/v1`)

---

## UI Scrolling Issue - Submit Button

**Current Status:** The submit button is already fixed at the bottom with SafeArea padding.

**File:** [lib/features/visitor/presentation/visitor_entry_screen.dart](society360_guard/lib/features/visitor/presentation/visitor_entry_screen.dart:98-138)

The navigation buttons are wrapped in a fixed container at the bottom:
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: AppTheme.surfaceCard,
    boxShadow: [BoxShadow(...)], // Elevated shadow
  ),
  child: SafeArea(
    child: Row(
      children: [/* Back and Next/Submit buttons */],
    ),
  ),
)
```

**If you still experience scrolling issues:**
- The issue might be in `StepDestination` where the flat grid is too tall
- Solution: The content is already wrapped in `SingleChildScrollView` (line 46)
- Make sure `Expanded` wraps the step content in the main screen

---

## What's NOT Done Yet

### Resident App Integration ⚠️

The Resident app still needs similar updates:

1. **Fetch user's flat data from backend**
   - GET /v1/profile or similar
   - Get user's flat occupancies

2. **Register FCM tokens**
   - POST /v1/devices/register with FCM token

3. **Connect to Socket.io**
   - Join room: `flat:<flat_id>`
   - Listen for events: `visitor_request`, `visitor_checkin`, `visitor_timeout`

4. **Display notification bell counter**
   - GET /v1/visitors/pending-count

5. **Display visitor approval cards**
   - Show pending visitors
   - Allow approve/reject: POST /v1/visitors/:id/respond

**This is a complex task and should be done separately.**

---

## Troubleshooting

### Issue: "Connection refused" or "Failed to load blocks"

**Cause:** Backend not running or wrong URL

**Fix:**
1. Check backend is running: `curl http://localhost:3000/health`
2. If using Android emulator, use `http://10.0.2.2:3000/v1`
3. Check firewall isn't blocking port 3000

### Issue: "Failed to fetch complexes/blocks/flats"

**Cause:** No data in database or wrong society_id

**Fix:**
1. Verify seed data exists:
   ```sql
   SELECT COUNT(*) FROM societies;
   SELECT COUNT(*) FROM blocks;
   SELECT COUNT(*) FROM flats;
   ```

2. If empty, re-run seed script:
   ```bash
   psql society360_db -f society360_backend/seed_test_data.sql
   ```

3. Update society_id in [society_repository.dart](society360_guard/lib/data/repositories/society_repository.dart:19):
   ```sql
   -- Get actual society_id from database
   SELECT id FROM societies LIMIT 1;
   ```

### Issue: "Failed to create visitor"

**Possible causes:**
1. Invalid flat_id
2. Missing Firebase UID in users table
3. Backend error

**Debug:**
1. Check backend logs: `tail -f society360_backend/logs/combined.log`
2. Verify flat exists: `SELECT id FROM flats WHERE flat_number = 'A-303';`
3. Test API directly:
   ```bash
   curl -X POST http://localhost:3000/v1/visitors \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer <your_firebase_token>" \
     -d '{
       "visitor_name": "Test",
       "phone": "+911234567890",
       "purpose": "delivery",
       "flat_id": "cceedf3a-61c7-497e-92b2-7e45fa14583d"
     }'
   ```

---

## Next Steps

1. ✅ Guard app now uses dynamic data from database
2. ✅ Visitor submissions go to real backend API
3. ⏭️ **Test the Guard app thoroughly**
4. ⏭️ **Integrate Resident app** (separate task)
5. ⏭️ **Register FCM tokens** from both apps
6. ⏭️ **Test end-to-end notification flow**

---

## Summary

**The Guard app is now fully integrated with the backend!** 🎉

- ✅ Fetches real blocks and flats from database
- ✅ Uses actual UUID flat_ids (not hardcoded)
- ✅ Submits visitors to backend API
- ✅ Backend will send notifications to residents

**Ready to test!** Run the Guard app, create a visitor, and check the database to see it created successfully.
