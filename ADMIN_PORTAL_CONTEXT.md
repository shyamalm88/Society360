# Society360 Admin Portal - Development Context

> This document tracks the development progress and technical decisions for the Admin Portal (Stage 3).

## Project Overview

Building a **Web Admin Portal** for the Society360 ecosystem using:
- **Frontend:** Vite + React + Tailwind CSS + Shadcn/UI
- **Backend:** Extending existing Node.js/Express API
- **Database:** PostgreSQL (existing schema + new migrations)
- **Real-time:** Socket.io (existing infrastructure)

## Architecture Decisions

### Authentication Strategy
- **Residents (Mobile Apps):** Firebase Phone OTP (existing)
- **Admin Portal Users:** Email/Password with JWT tokens (NEW)
  - Separate auth flow from Firebase
  - JWT stored in localStorage
  - Refresh token rotation for security
  - Account lockout after 5 failed attempts

### Role-Based Access Control (RBAC)
| Role | Access Level | Default Route |
|------|--------------|---------------|
| `super_admin` | Full system access | `/saas-dashboard` |
| `society_admin` | Society-level management | `/society-dashboard` |
| `guard` | Gate logs & visitor management | `/gate-logs` |

### Project Structure
```
Society360/
├── society360_backend/      # Node.js/Express API (extended)
│   ├── src/
│   │   ├── middleware/
│   │   │   ├── auth.js          # Firebase auth (existing)
│   │   │   └── adminAuth.js     # JWT auth (NEW)
│   │   └── routes/
│   │       ├── adminAuth.js     # Admin auth endpoints (NEW)
│   │       ├── adminSocieties.js # Society management (NEW)
│   │       ├── adminDashboard.js # Dashboard APIs (NEW)
│   │       ├── notices.js       # Notices CRUD (NEW)
│   │       └── complaints.js    # Complaints CRUD (NEW)
│   └── migrations/
│       └── 008_notices_complaints_admin_auth.sql (NEW)
│
├── society360_guard/        # Existing Flutter app
├── society360_resident/     # Existing Flutter app
│
└── society360_admin/        # NEW - React Admin Portal
    ├── src/
    │   ├── components/
    │   │   ├── ui/              # Shadcn components
    │   │   │   ├── button.jsx
    │   │   │   ├── card.jsx
    │   │   │   ├── input.jsx
    │   │   │   ├── label.jsx
    │   │   │   ├── badge.jsx
    │   │   │   ├── avatar.jsx
    │   │   │   ├── table.jsx
    │   │   │   ├── sheet.jsx
    │   │   │   └── dropdown-menu.jsx
    │   │   └── layout/
    │   │       ├── Layout.jsx   # Main layout with responsive sidebar
    │   │       └── Sidebar.jsx  # Navigation sidebar
    │   ├── pages/
    │   │   ├── Login.jsx
    │   │   ├── SaasDashboard.jsx
    │   │   ├── SocietyDashboard.jsx
    │   │   ├── Societies.jsx
    │   │   ├── SocietyOnboarding.jsx
    │   │   ├── Residents.jsx
    │   │   ├── Notices.jsx
    │   │   ├── Complaints.jsx
    │   │   ├── GateLogs.jsx
    │   │   └── Emergencies.jsx
    │   ├── lib/
    │   │   ├── api.js           # Axios API client
    │   │   └── utils.js         # Utility functions
    │   ├── stores/
    │   │   └── authStore.js     # Zustand auth store
    │   └── styles/
    │       └── globals.css      # Tailwind + custom styles
    ├── App.jsx                  # Routing configuration
    └── main.jsx                 # Entry point
```

## Implementation Progress

### Phase 1: Backend Core ✅ COMPLETED
- [x] Review existing schema
- [x] Create migration 008 (notices, complaints, admin_users, admin_sessions)
- [x] Add JWT authentication middleware
- [x] Add admin auth routes (login, logout, refresh, register, change-password)
- [x] Add society management routes
- [x] Add dashboard API routes
- [x] Add notices CRUD routes
- [x] Add complaints CRUD routes
- [x] Create super admin seed script

### Phase 2: Frontend Setup ✅ COMPLETED
- [x] Initialize Vite + React project
- [x] Configure Tailwind CSS with custom theme
- [x] Create Shadcn/UI components
- [x] Set up React Query
- [x] Set up Zustand for state management
- [x] Configure axios API client with interceptors

### Phase 3: Layout & Navigation ✅ COMPLETED
- [x] Responsive sidebar (desktop: fixed, mobile: drawer)
- [x] Role-based navigation items
- [x] Role-based route guards
- [x] Authentication flow with token refresh
- [x] Society selector for society admins

### Phase 4: Feature Pages ✅ COMPLETED
- [x] Login page with error handling
- [x] Super Admin Dashboard (SaaS overview)
- [x] Society Onboarding Wizard (3-step)
- [x] Societies list view
- [x] Society Admin Dashboard with live widgets
- [x] Residents directory
- [x] Notice Board (CRUD with priorities)
- [x] Complaints management (status workflow)
- [x] Gate Logs with date filtering
- [x] Emergencies with panic alert display

### Phase 5: Real-time Integration ✅ COMPLETED
- [x] Socket.io client setup
- [x] Live gate feed widget (auto-refresh)
- [x] Panic alert notifications
- [x] Real-time visitor updates

## API Endpoints (New)

### Admin Authentication
```
POST /v1/admin/auth/login          - Email/password login
POST /v1/admin/auth/register       - Register new admin (super_admin only)
POST /v1/admin/auth/refresh        - Refresh JWT token
POST /v1/admin/auth/logout         - Invalidate session
GET  /v1/admin/auth/me             - Get current admin profile
POST /v1/admin/auth/change-password - Change password
```

### Society Management (Super Admin)
```
GET    /v1/admin/societies              - List all societies
POST   /v1/admin/societies              - Create new society
GET    /v1/admin/societies/:id          - Get society details
PUT    /v1/admin/societies/:id          - Update society
POST   /v1/admin/societies/:id/structure - Bulk create blocks/flats
PUT    /v1/admin/societies/:id/policies - Update feature toggles
GET    /v1/admin/societies/:id/residents - List residents
GET    /v1/admin/societies/:id/pending-requests - Pending approvals
```

### Dashboard APIs
```
GET /v1/admin/dashboard/saas           - Super admin dashboard data
GET /v1/admin/dashboard/society/:id    - Society admin dashboard data
GET /v1/admin/dashboard/gate-logs/:id  - Gate logs for society
```

### Notices
```
GET    /v1/notices           - List notices (society-scoped)
GET    /v1/notices/:id       - Get notice with read stats
POST   /v1/notices           - Create notice
PUT    /v1/notices/:id       - Update notice
DELETE /v1/notices/:id       - Delete notice
```

### Complaints
```
GET    /v1/complaints           - List complaints (with status filter)
GET    /v1/complaints/:id       - Get complaint with comments
POST   /v1/complaints           - Create complaint
PUT    /v1/complaints/:id       - Update status/assignment
DELETE /v1/complaints/:id       - Delete complaint
POST   /v1/complaints/:id/comments - Add comment
```

## Database Schema (Migration 008)

### New Tables
- `admin_users` - Admin portal user accounts
- `admin_sessions` - JWT session tracking
- `notices` - Society announcements
- `notice_reads` - Read tracking
- `complaints` - Helpdesk tickets
- `complaint_comments` - Comment threads

### New Enums
- `notice_priority` - low, medium, high, critical
- `ticket_status` - open, in_progress, resolved, closed
- `ticket_category` - maintenance, security, amenities, billing, noise, parking, other

## Getting Started

### Backend Setup
```bash
cd society360_backend
npm install
# Run migration
psql $DATABASE_URL -f migrations/008_notices_complaints_admin_auth.sql
# Seed super admin
npm run seed:admin
# Start server
npm run dev
```

### Admin Portal Setup
```bash
cd society360_admin
npm install
cp .env.example .env
npm run dev
# Access at http://localhost:5173
```

### Default Super Admin Credentials
```
Email: admin@society360.com
Password: Admin@123
```

## UI/UX Guidelines

### Design System
- **Style:** Corporate, Classy, Flat Design
- **Colors:** Professional blue primary with teal accent
- **Touch Targets:** Minimum 40-48px for mobile compatibility
- **Typography:** Inter font family

### Responsive Breakpoints
| Breakpoint | Behavior |
|------------|----------|
| `< 768px` (mobile) | Hamburger menu → Sheet drawer |
| `≥ 768px` (tablet) | Collapsible sidebar |
| `≥ 1024px` (desktop) | Permanent sidebar |

### Data Presentation
- **Desktop:** Standard tables with sorting/filtering
- **Mobile:** Card-based layout with stacked key-value pairs

## Notes & Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-11-30 | Separate JWT auth for admin portal | Keep Firebase for mobile apps, JWT is simpler for web SPA |
| 2025-11-30 | Use existing `policies` table | Already supports key-value config per society |
| 2025-11-30 | Guard role = Security Supervisor | No need for new role enum |
| 2025-11-30 | Zustand for state management | Lightweight, simple API, works well with React Query |
| 2025-11-30 | Account lockout after 5 attempts | Security best practice |

---
*Last updated: 2025-11-30*
*Status: IMPLEMENTATION COMPLETE*
