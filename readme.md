# Abhay Method Platform

This repo is now a real multi-app foundation for a personal coaching platform:

- `backend/`: FastAPI API, SQLite persistence, token auth, seeded demo data
- `apps/admin_app/`: Flutter admin console for managing clients and operations
- `apps/client_app/`: Flutter client app for workouts, nutrition, check-ins, messages, and billing
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
- `GET /api/admin/dashboard`
- `GET /api/client/dashboard`

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

- admin: `admin@abhaymethod.app` / `admin12345`
- demo client: `maya@example.com` / `client12345`
- client activation invite: `ROHAN-START`

## What Works Now

- admin login
- client login and invite activation
- create multiple clients
- view client detail
- publish a starter training program
- save nutrition targets
- send coach messages
- create invoices
- client dashboard
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
