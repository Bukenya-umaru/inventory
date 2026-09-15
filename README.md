# Multi-Tenant Inventory Management System

A comprehensive multi-tenant inventory management system with three-tier hierarchy (Developer → Admin → Employee), password visibility, account lifecycle management, and complete data isolation.

## Features

### 🔐 Password Management
- AES-256 encrypted password storage
- Password visibility for Admins (their employees) and Developers (all users)
- Time-limited password reveal (30-60 seconds)
- All password views logged in audit trail

### 👥 Account Lifecycle
- Developer creates businesses with admin accounts
- Admin creates employees with granular permissions
- Developer can suspend, reactivate, and delete businesses
- Employee deletion via admin request

### 📊 Business Operations
- Product management with cost/selling prices
- Sales recording with automatic profit calculation
- Damage reporting with stock adjustment
- Daily, monthly, and yearly profit reports
- Inventory overview with low stock alerts

### 🎨 Business Branding
- Custom business logo, name, and contact info
- Displayed on login and dashboard

### 🔒 Data Isolation
- Complete tenant-based data separation
- Role-based access control
- Single login form — routes to correct dashboard by role

## Tech Stack

**Backend:**
- Node.js + Express.js
- MongoDB + Mongoose
- JWT Authentication
- AES-256 Password Encryption
- bcrypt for password hashing

**Frontend (Flutter/Dart):**
- Flutter 3.x
- Provider (state management)
- HTTP (API communication)
- Shared Preferences (token storage)

## Setup

### Prerequisites
- Node.js (v18+)
- MongoDB (running locally or Atlas URI)
- Flutter SDK (3.x+)

### Backend
```bash
cd backend
npm install
cp .env.example .env    # then fill in MONGODB_URI, JWT_SECRET, ENCRYPTION_KEY, seed passwords
npm run seed            # Create initial data
npm run dev             # Start development server on port 5000
```

### Frontend (Flutter)
```bash
cd frontend
flutter pub get
cp .env.example .env    # then set API_BASE_URL to your backend's URL
flutter run             # Run on connected device/emulator
```

> **Note:** API endpoints are configured in `frontend/.env` (`API_BASE_URL`, `API_BASE_URL_ANDROID`).
> The Android emulator automatically uses `API_BASE_URL_ANDROID` (e.g. `http://10.0.2.2:5000/api`).

> **Security:** `.env` files are gitignored — never commit them. `.env.example` files are committed templates.

### Login
**All roles use the SAME login form.** After login, the app automatically routes to the correct dashboard based on role.

Seed account passwords are set in `backend/.env` (`SEED_DEVELOPER_PASSWORD`, `SEED_ADMIN_PASSWORD`, `SEED_EMPLOYEE_PASSWORD`) — they are no longer hardcoded.

## Project Structure

```
├── backend/
│   ├── models/          # Mongoose models
│   ├── routes/          # Express API routes
│   ├── middleware/       # Auth, RBAC, upload
│   ├── utils/           # Encryption, audit logging
│   └── seeds/           # Database seeder
├── frontend/            # Flutter app
│   └── lib/
│       ├── models/      # Dart data models
│       ├── services/    # API service + Auth provider
│       ├── screens/     # UI screens by role
│       │   ├── auth/    # Login (shared)
│       │   ├── developer/  # Developer screens
│       │   ├── admin/      # Business Owner screens
│       │   └── employee/   # Employee screens
│       └── widgets/     # Shared UI components
└── README.md
```

## API Endpoints

### Authentication
- `POST /api/auth/login` - Login (all roles)
- `GET /api/auth/me` - Get current user
- `POST /api/auth/change-password` - Change password

### Tenants (Developer)
- `GET /api/tenants` - List businesses
- `GET /api/tenants/stats` - Dashboard stats
- `POST /api/tenants` - Create business
- `PUT /api/tenants/:id/suspend` - Suspend
- `PUT /api/tenants/:id/reactivate` - Reactivate
- `DELETE /api/tenants/:id` - Delete

### Users
- `GET /api/users` - List users
- `POST /api/users` - Create employee
- `PUT /api/users/:id/permissions` - Update permissions
- `DELETE /api/users/:id` - Delete user

### Products / Categories / Sales / Damages / Reports / Audit / Passwords
See backend routes for full API documentation.
