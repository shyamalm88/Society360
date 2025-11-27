# PROJECT: Society360 (Visitor Management System)

## CORE OBJECTIVE

Production-grade Visitor Management System with real-time notifications.

1. **Guard App (Flutter):** Accessibility-focused. PIN-based login. Tied to a specific Gate.
2. **Resident App (Flutter):** Premium Corporate UI. Real Firebase Phone Auth. Includes onboarding (City -> Flat selection).
3. **Backend (Node.js/Express + PostgreSQL):** ✅ **COMPLETE** - Real-time API with Socket.io integration.

## TECH STACK

### Frontend (Flutter)
- **Mobile Framework:** Flutter (latest stable)
- **Language:** Dart
- **State Management:** Riverpod (Code Generation `@riverpod`)
- **Navigation:** GoRouter
- **Storage:** `flutter_secure_storage` (session tokens) & `shared_preferences` (flags)
- **Auth:** `firebase_auth` (Real Phone OTP) for Residents
- **API Client:** Dio + Socket.io Client

### Backend (Node.js)
- **Runtime:** Node.js 18+
- **Framework:** Express.js
- **Database:** PostgreSQL with `pg` (node-postgres)
- **Real-time:** Socket.io (WebSockets)
- **Authentication:** Firebase Admin SDK
- **Logging:** Winston
- **Security:** Helmet, CORS, Rate Limiting

## PROJECT STRUCTURE

```
Society360/
├── society360_guard/          # Guard Flutter App
├── society360_resident/       # Resident Flutter App
└── society360_backend/        # Node.js Backend API
    ├── src/
    │   ├── config/           # Database, Logger
    │   ├── middleware/       # Auth, RBAC
    │   ├── routes/           # API Routes
    │   └── server.js         # Express + Socket.io
    ├── migrations/           # PostgreSQL Schema
    ├── README.md
    └── INTEGRATION.md        # Flutter Integration Guide
```

## DESIGN PHILOSOPHY

- **Visual Style:** "Cyber-Corporate" / Deep Dark Mode
  - Background: `#0F172A` (Midnight Slate)
  - Surface: `#1E293B` (Lighter Slate)
  - Primary: `#3B82F6` (Electric Blue)
- **Code Style:** Clean Architecture. Strict separation of UI, Domain (Models), and Data (Repositories)
- **Real-time First:** Socket.io for instant visitor notifications (NO polling)

## QUICK START

### 1. Backend Setup

```bash
cd society360_backend
npm install
cp .env.example .env
# Edit .env with your PostgreSQL credentials
createdb society360_db
npm run db:migrate
npm run dev
```

Server runs on: `http://localhost:3000`

**Detailed Backend Guide:** See [society360_backend/README.md](society360_backend/README.md)

### 2. Guard App

```bash
cd society360_guard
flutter pub get
flutter run
```

**Login PIN:** `123456`

### 3. Resident App

```bash
cd society360_resident
flutter pub get
flutter run
```

**Auth:** Real Firebase Phone OTP

### 4. Integration

Follow the complete integration guide: [society360_backend/INTEGRATION.md](society360_backend/INTEGRATION.md)

## CORE FEATURES

### Guard App ✅
- PIN-based authentication with secure storage
- 4-step visitor entry wizard (Details → Purpose → Destination → Submit)
- Real-time approval notifications via Socket.io
- Check-in/Check-out functionality
- Recent visitors list

### Resident App ✅
- Firebase Phone OTP authentication
- Intro carousel for first-time users
- Dynamic onboarding (City → Society → Complex → Block → Flat selection)
- Real-time visitor request notifications
- Approve/Deny visitors with one tap
- Guest pass management (QR codes)

### Backend API ✅
- Firebase token authentication
- RESTful API endpoints (20+ routes)
- Socket.io real-time events
- PostgreSQL with audit logging
- Role-based access control (RBAC)
- Rate limiting & security headers

## REAL-TIME FLOW

1. **Guard creates visitor** → API saves to PostgreSQL → Emits Socket event to Flat Room
2. **Resident receives notification** → Real-time via Socket.io (NO polling)
3. **Resident approves/denies** → API updates status → Emits Socket event to Society Room
4. **Guard receives approval** → Real-time confirmation
5. **Guard checks in visitor** → Updates database and visit log

## API DOCUMENTATION

**Base URL:** `http://localhost:3000/v1`

**Key Endpoints:**
- `POST /auth/firebase` - Exchange Firebase token
- `GET /cities`, `/societies`, `/blocks`, `/flats` - Onboarding metadata
- `POST /visitors` - Create visitor (Guard)
- `POST /visitors/:id/respond` - Approve/deny (Resident)
- `POST /visits/checkin` - Check-in visitor
- `GET /profile/me` - User profile with roles

**Import Postman Collection:** `/Users/arghyamajumder/Downloads/Society360_Postman_Collection.json`

## DATABASE SCHEMA

**PostgreSQL Schema:** [society360_backend/migrations/004_final_postgres_schema.sql](society360_backend/migrations/004_final_postgres_schema.sql)

**Key Tables:**
- `users` - Firebase UID mapping
- `societies`, `complexes`, `blocks`, `flats` - Hierarchy
- `visitors` - Visitor requests (pending/accepted/denied)
- `visits` - Check-in/out audit trail (partitioned by month)
- `role_assignments` - RBAC permissions
- `audit_logs` - All critical actions

## DEVELOPMENT GUIDES

- [guardapp.md](guardapp.md) - Guard app requirements & implementation
- [residentapp.md](residentapp.md) - Resident app requirements & implementation
- [society360_backend/README.md](society360_backend/README.md) - Backend setup & API docs
- [society360_backend/INTEGRATION.md](society360_backend/INTEGRATION.md) - Flutter-Backend integration
