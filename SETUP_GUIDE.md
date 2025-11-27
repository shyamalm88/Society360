# Society360 Setup Guide - Next Steps

## Database Successfully Populated! ✅

The database now has:
- ✅ 1 Society: Green Valley Society
- ✅ 1 Complex: Main Complex
- ✅ 1 Block: Block A
- ✅ 5 Flats: A-301, A-302, A-303, A-304, A-305
- ✅ 3 Users: 1 Guard + 2 Residents
- ✅ 2 Residents assigned to Flat A-303

## Critical: Update Your Apps

### 1. **Guard App - Update Flat ID**

Your guard app is using a **hardcoded flat_id**: `flat_a_3_3`

**The correct flat_id for A-303 is:**
```
cceedf3a-61c7-497e-92b2-7e45fa14583d
```

**Action Required:**
- Open your Guard app code
- Find where you're setting `flat_id` to `flat_a_3_3`
- Replace it with: `cceedf3a-61c7-497e-92b2-7e45fa14583d`

OR better yet, fetch flats dynamically from the API:
```dart
GET /v1/flats?block_id=<block_id>
```

### 2. **Update Firebase UIDs**

The database has placeholder Firebase UIDs. You need to update them with **actual Firebase UIDs** from your logged-in users.

**Steps:**

1. **Login to Guard App** with phone `+911234567890`
2. **Get the Firebase UID** from the authentication response
3. **Update the database**:
   ```sql
   UPDATE users
   SET firebase_uid = '<actual_firebase_uid_from_guard_app>'
   WHERE phone = '+911234567890';
   ```

4. **Login to Resident App** with phone `+919876543210` or `+919876543211`
5. **Get the Firebase UID**
6. **Update the database**:
   ```sql
   UPDATE users
   SET firebase_uid = '<actual_firebase_uid_from_resident_app>'
   WHERE phone = '+919876543210';
   ```

### 3. **Register FCM Tokens**

For push notifications to work, your apps must register FCM tokens in the `devices` table.

**Expected behavior:**
When a user logs in, the app should call:
```
POST /v1/devices/register
{
  "fcm_token": "<device_fcm_token>",
  "device_info": { ... }
}
```

**Check if FCM registration endpoint exists:**
```bash
grep -r "devices/register" society360_backend/src/routes/
```

If it doesn't exist, you'll need to create it.

## Testing the Complete Flow

Once you've updated the above:

### Step 1: Start Backend
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

### Step 2: Create Visitor from Guard App

Use the **correct flat_id** in your payload:
```json
{
  "visitor_name": "Dilip",
  "phone": "+911234567890",
  "purpose": "delivery",
  "flat_id": "cceedf3a-61c7-497e-92b2-7e45fa14583d",
  "expected_start": "2025-11-26T14:00:00",
  "expected_end": "2025-11-26T16:00:00"
}
```

### Step 3: Verify Notification Delivery

**Check backend logs:**
```bash
tail -f society360_backend/logs/combined.log
```

Look for:
- `POST /v1/visitors` request logged
- Socket.io event emitted to `flat:cceedf3a-61c7-497e-92b2-7e45fa14583d`
- FCM notification sent (if tokens are registered)

**Check database:**
```sql
-- Verify visitor was created
SELECT * FROM visitors WHERE visitor_name = 'Dilip';

-- Check if notification was logged
SELECT * FROM notification_logs ORDER BY created_at DESC LIMIT 5;

-- Check if FCM tokens exist
SELECT u.name, u.phone, d.fcm_token
FROM users u
LEFT JOIN devices d ON u.id = d.user_id
WHERE u.phone IN ('+919876543210', '+919876543211');
```

## Common Issues & Fixes

### Issue 1: Visitor Creation Fails with "flat_id does not exist"
**Cause:** Guard app using wrong flat_id
**Fix:** Use `cceedf3a-61c7-497e-92b2-7e45fa14583d` instead of `flat_a_3_3`

### Issue 2: No Push Notifications Received
**Possible causes:**
1. FCM tokens not registered in `devices` table → Check if registration endpoint exists
2. Firebase credentials invalid → Check if `firebase-service-account.json` is correct
3. Resident app not subscribed to FCM → Check FCM setup in Flutter app

### Issue 3: Socket.io Events Not Received
**Possible causes:**
1. App not connected to Socket.io server
2. App not joined to correct room (`flat:cceedf3a-61c7-497e-92b2-7e45fa14583d`)
3. Backend not emitting events

## Verification Checklist

- [ ] Backend server running on port 3000
- [ ] Firebase Admin SDK initialized successfully
- [ ] Guard app updated with correct flat_id
- [ ] Firebase UIDs updated in database
- [ ] FCM tokens registered in devices table (if using push notifications)
- [ ] Resident app joined to Socket.io room
- [ ] Test visitor creation - visitor appears in database
- [ ] Resident receives notification (FCM or Socket.io)
- [ ] Resident can approve/deny visitor
- [ ] Guard receives approval response

## Need Help?

Run these diagnostic queries:

```sql
-- Check all data
SELECT 'Societies' as table_name, COUNT(*) FROM societies
UNION ALL SELECT 'Flats', COUNT(*) FROM flats
UNION ALL SELECT 'Users', COUNT(*) FROM users
UNION ALL SELECT 'Flat Occupancies', COUNT(*) FROM flat_occupancies
UNION ALL SELECT 'Visitors', COUNT(*) FROM visitors;

-- Get flat_id for A-303 (use this in Guard app!)
SELECT id, flat_number FROM flats WHERE flat_number = 'A-303';

-- Check residents of A-303
SELECT u.id, u.name, u.phone, u.firebase_uid, fo.role
FROM flat_occupancies fo
JOIN users u ON fo.user_id = u.id
WHERE fo.flat_id = (SELECT id FROM flats WHERE flat_number = 'A-303');

-- Check if FCM tokens registered
SELECT u.name, u.phone, d.fcm_token IS NOT NULL as has_token
FROM users u
LEFT JOIN devices d ON u.id = d.user_id;
```

---

**Next: Update your Guard app with the correct flat_id and try creating a visitor again!**
