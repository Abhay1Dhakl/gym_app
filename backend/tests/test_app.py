from __future__ import annotations

import unittest
from uuid import uuid4

from fastapi.testclient import TestClient

from app.db.session import engine
from app.main import app


class AppSmokeTests(unittest.TestCase):
    @classmethod
    def tearDownClass(cls) -> None:
        engine.dispose()

    def test_healthcheck(self) -> None:
        with TestClient(app) as client:
            response = client.get("/api/health")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["status"], "ok")

    def test_admin_login(self) -> None:
        with TestClient(app) as client:
            response = client.post(
                "/api/auth/login",
                json={"email": "admin@abhaymethod.app", "password": "admin12345"},
            )
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["role"], "admin")

    def test_super_admin_can_create_gym_admin(self) -> None:
        unique_id = uuid4().hex[:8]
        with TestClient(app) as client:
            login_response = client.post(
                "/api/auth/login",
                json={"email": "superadmin@platform.app", "password": "superadmin12345"},
            )
            self.assertEqual(login_response.status_code, 200)
            self.assertEqual(login_response.json()["role"], "super_admin")

            token = login_response.json()["access_token"]
            create_response = client.post(
                "/api/super-admin/admins",
                headers={"Authorization": f"Bearer {token}"},
                json={
                    "full_name": "Gym Owner Demo",
                    "email": f"owner-{unique_id}@gym.app",
                    "password": "owner12345",
                    "gym_name": f"Demo Gym {unique_id}",
                    "gym_logo_url": "https://placehold.co/200x200/111827/F8FAFC?text=GYM",
                },
            )
            self.assertEqual(create_response.status_code, 201)
            self.assertEqual(create_response.json()["gym_name"], f"Demo Gym {unique_id}")
            self.assertEqual(create_response.json()["invited_clients"], 0)
            self.assertEqual(create_response.json()["active_clients"], 0)


if __name__ == "__main__":
    unittest.main()
