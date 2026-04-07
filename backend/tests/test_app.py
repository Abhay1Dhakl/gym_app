from __future__ import annotations

import unittest

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


if __name__ == "__main__":
    unittest.main()
