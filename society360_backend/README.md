# Society360 Backend API

Production-grade Node.js backend for the Society360 Visitor Management System.

## Tech Stack

- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **Database:** PostgreSQL with `pg` (node-postgres)
- **Real-time:** Socket.io
- **Authentication:** Firebase Admin SDK
- **Logging:** Winston

## Project Structure

```
society360_backend/
├── src/
│   ├── config/
│   │   ├── database.js       # PostgreSQL connection pool
│   │   └── logger.js         # Winston logger configuration
│   ├── middleware/
│   │   └── auth.js           # Firebase token verification & role checks
│   ├── routes/
│   │   ├── auth.js           # POST /auth/firebase
│   │   ├── onboarding.js     # Cities, Societies, Complexes, Blocks, Flats
│   │   ├── visitors.js       # Visitor CRUD + Socket.io events
│   │   ├── visits.js         # Check-in/Check-out
│   │   ├── guards.js         # Guard device registration
│   │   ├── residents.js      # Resident requests
│   │   └── profile.js        # GET /profile/me
│   └── server.js             # Express + Socket.io server
├── migrations/
│   └── 004_final_postgres_schema.sql
├── logs/
├── .env.example
├── package.json
└── README.md
```

## Setup Instructions

### 1. Install Dependencies

```bash
cd society360_backend
npm install
```

### 2. Configure Environment

Copy `.env.example` to `.env` and configure:

```bash
cp .env.example .env
```

Edit `.env`:
```env
NODE_ENV=development
PORT=3000

# PostgreSQL
PGHOST=localhost
PGPORT=5432
PGDATABASE=society360_db
PGUSER=your_username
PGPASSWORD=your_password

# Firebase
FIREBASE_PROJECT_ID=your-firebase-project-id
FIREBASE_PRIVATE_KEY_PATH=./firebase-service-account.json
```

### 3. Setup PostgreSQL Database

Create the database:
```bash
createdb society360_db
```

Run migrations:
```bash
npm run db:migrate
# OR
psql society360_db < migrations/004_final_postgres_schema.sql
```

### 4. Add Firebase Service Account

1. Download your Firebase service account JSON from Firebase Console
2. Save it as `firebase-service-account.json` in the backend root directory
3. Update `FIREBASE_PRIVATE_KEY_PATH` in `.env` if needed

### 5. Start the Server

Development mode (with auto-reload):
```bash
npm run dev
```

Production mode:
```bash
npm start
```

The server will start on `http://localhost:3000`

## API Endpoints

### Authentication
- `POST /v1/auth/firebase` - Exchange Firebase ID token for user session

### Onboarding (Resident App)
- `GET /v1/cities` - List all cities
- `GET /v1/societies?city=Bengaluru` - List societies by city
- `GET /v1/complexes?society_id=<uuid>` - List complexes by society
- `GET /v1/blocks?complex_id=<uuid>` - List blocks by complex
- `GET /v1/flats?block_id=<uuid>` - List flats by block

### Visitors
- `POST /v1/visitors` - Create visitor entry (Guard)
- `GET /v1/visitors?flat_id=<uuid>&status=pending` - List visitors
- `POST /v1/visitors/:id/respond` - Approve/deny visitor (Resident)
- `POST /v1/visitors/:id/send-invite` - Send SMS/WhatsApp invite

### Visits (Check-in/Check-out)
- `POST /v1/visits/checkin` - Guard checks in visitor
- `POST /v1/visits/checkout` - Guard checks out visitor
- `GET /v1/visits?from=2025-11-01&to=2025-11-30` - Get visit history

### Guards
- `POST /v1/guards/register-device` - Register device for push notifications
- `GET /v1/society/:societyId/expected-visitors?date=2025-11-20` - Expected visitors

### Resident Requests
- `POST /v1/resident-requests` - Submit resident verification request
- `GET /v1/resident-requests?status=pending` - List requests
- `POST /v1/resident-requests/:id/approve` - Approve request (Admin)
- `POST /v1/resident-requests/:id/reject` - Reject request (Admin)

### Profile
- `GET /v1/profile/me` - Get current user profile with roles, flat, guard info

## Socket.io Events

### Rooms
- **Flat Room:** `flat:<flat_id>` - Residents of a specific flat
- **Society Room:** `society:<society_id>` - Guards of a specific society

### Client Events (Emit to Server)
```javascript
socket.emit('join_room', {
  room_type: 'flat',  // or 'society'
  room_id: '<uuid>',
  user_id: '<uuid>'
});

socket.emit('leave_room', {
  room_type: 'flat',
  room_id: '<uuid>'
});
```

### Server Events (Listen on Client)

**Resident App - Visitor Request:**
```javascript
socket.on('visitor_request', (data) => {
  // data: { visitor_id, visitor_name, phone, purpose, vehicle_no, ... }
  console.log('New visitor at gate:', data);
});
```

**Guard App - Request Approved:**
```javascript
socket.on('request_approved', (data) => {
  // data: { visitor_id, decision, status, approver_name, ... }
  console.log('Visitor request approved:', data);
});
```

## Real-Time Flow

### Visitor Entry Flow (Critical)

1. **Guard creates visitor entry** → `POST /v1/visitors`
   - Server saves to PostgreSQL
   - Server emits `visitor_request` to `flat:<flat_id>` room
   - Resident app (listening to flat room) receives real-time notification

2. **Resident approves/denies** → `POST /v1/visitors/:id/respond`
   - Server updates visitor status
   - Server emits `request_approved` to `society:<society_id>` room
   - Guard app (listening to society room) receives real-time response

3. **Guard checks in visitor** → `POST /v1/visits/checkin`
   - Creates visit record
   - Updates visitor status to "checked_in"

4. **Guard checks out visitor** → `POST /v1/visits/checkout`
   - Updates visit with checkout time
   - Updates visitor status to "checked_out"

## Authentication

All endpoints (except `/health` and `POST /auth/firebase`) require a Firebase ID token:

```
Authorization: Bearer <firebase_id_token>
```

The middleware:
1. Verifies the Firebase token
2. Creates/fetches user from database
3. Logs auth audit trail
4. Attaches `req.user` with user data

## Testing with Postman

Import the Postman collection:
```bash
# Collection is at: /Users/arghyamajumder/Downloads/Society360_Postman_Collection.json
```

1. Set `baseUrl` variable to `http://localhost:3000/v1`
2. Get Firebase ID token from your Flutter app
3. Set `bearerToken` variable
4. Test endpoints

## Logging

Logs are stored in:
- `logs/combined.log` - All logs
- `logs/error.log` - Error logs only

Log levels: `error`, `warn`, `info`, `http`, `verbose`, `debug`

## Health Check

```bash
curl http://localhost:3000/health
```

Response:
```json
{
  "status": "healthy",
  "timestamp": "2025-11-26T...",
  "database": "connected"
}
```

## Security Features

✅ **Helmet.js** - Security headers
✅ **CORS** - Cross-origin resource sharing
✅ **Rate Limiting** - 100 requests per 15 minutes
✅ **Firebase Auth** - Token verification
✅ **Role-Based Access Control** - `requireRole` middleware
✅ **Audit Logging** - All critical actions logged
✅ **SQL Injection Protection** - Parameterized queries

## Next Steps - Flutter Integration

See README sections in:
- [Guard App Integration](#guard-app-integration)
- [Resident App Integration](#resident-app-integration)

---

**Built with ❤️ for Society360**
