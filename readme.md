# Abhay Method Platform

This repo is now a real multi-app foundation for a multi-tenant gym coaching platform:

- `backend/`: FastAPI API, SQLite persistence, token auth, seeded demo data, and tenant-aware gym ownership
- `apps/admin_app/`: Flutter console used by both the platform super admin and gym-owner admins
- `apps/client_app/`: Flutter client app for workouts, nutrition, check-ins, messages, and billing, branded per gym
- `packages/coach_flow_core/`: shared Dart models, API client, session storage, and themes

## Stack

- backend: FastAPI + SQLAlchemy + SQLite
- frontend: Flutter for admin and client apps
- shared mobile/web logic: local Dart package

## Repo Layout

```text
backend/
  app/
    api/
    core/
    db/
    models/
    schemas/
    services/
  tests/
apps/
  admin_app/
  client_app/
packages/
  coach_flow_core/
```

## Run The Backend

Create the virtual environment dependencies if needed:

```bash
python3 -m venv .venv
.venv/bin/pip install -e ./backend
```

Run the API:

```bash
PYTHONPATH=backend .venv/bin/uvicorn app.main:app --reload --port 8000
```

Useful endpoints:

- `GET /api/health`
- `POST /api/auth/login`
- `POST /api/auth/client/activate`
- `GET /api/super-admin/dashboard`
- `POST /api/super-admin/admins`
- `GET /api/admin/dashboard`
- `GET /api/client/dashboard`

## Run Everything With Docker Compose

Build and start the backend plus both Flutter web apps:

```bash
docker compose up --build
```

Services:

- backend API: `http://localhost:8000`
- admin app: `http://localhost:8081`
- client app: `http://localhost:8082`

Notes:

- the compose setup serves the Flutter apps as web builds via Nginx
- the backend database is stored in the named volume `backend-data`
- if you need different frontend origins, update `APP_CORS_ORIGINS` in `compose.yml`

## Run The Flutter Apps

Admin app:

```bash
cd apps/admin_app
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Client app:

```bash
cd apps/client_app
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

For Android emulators, the default base URL fallback is already `http://10.0.2.2:8000`.

## Seeded Accounts

- super admin: `superadmin@platform.app` / `superadmin12345`
- gym owner admin: `admin@abhaymethod.app` / `admin12345`
- demo client: `maya@example.com` / `client12345`
- client activation invite: `ROHAN-START`

## What Works Now

- super admin login
- create branded gym-owner accounts with gym name and logo URL
- organization-scoped gym owner login
- client login and invite activation
- create multiple clients per gym owner
- view client detail
- publish a starter training program
- save nutrition targets
- send coach messages
- create invoices
- gym-branded client dashboard
- client training, nutrition, check-ins, messages, and billing views
- dynamic backend data persisted in SQLite

## Verification

- backend smoke tests: `PYTHONPATH=backend .venv/bin/python -m unittest discover -s backend/tests -v`
- Flutter analysis:
  - `packages/coach_flow_core`
  - `apps/admin_app`
  - `apps/client_app`

## Next Serious Build Steps

1. Replace the simple token table with refresh tokens and rotation.
2. Add media uploads for progress photos and form videos.
3. Add a true program builder with unlimited days/exercises in the admin UI.
4. Add Stripe billing and webhook reconciliation.
5. Add push notifications and app store deployment work.
