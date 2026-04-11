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

    def _login(self, client: TestClient, email: str, password: str) -> dict[str, object]:
        response = client.post(
            "/api/auth/login",
            json={"email": email, "password": password},
        )
        self.assertEqual(response.status_code, 200)
        return response.json()

    def _auth_headers(self, token: str) -> dict[str, str]:
        return {"Authorization": f"Bearer {token}"}

    def test_healthcheck(self) -> None:
        with TestClient(app) as client:
            response = client.get("/api/health")
            self.assertEqual(response.status_code, 200)
            self.assertEqual(response.json()["status"], "ok")

    def test_admin_login(self) -> None:
        with TestClient(app) as client:
            payload = self._login(client, "admin@abhaymethod.app", "admin12345")
            self.assertEqual(payload["role"], "admin")

    def test_super_admin_can_create_gym_admin(self) -> None:
        unique_id = uuid4().hex[:8]
        with TestClient(app) as client:
            login_payload = self._login(
                client,
                "superadmin@platform.app",
                "superadmin12345",
            )
            self.assertEqual(login_payload["role"], "super_admin")

            token = login_payload["access_token"]
            create_response = client.post(
                "/api/super-admin/admins",
                headers=self._auth_headers(str(token)),
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

    def test_realtime_message_stream_receives_new_messages(self) -> None:
        unique_id = uuid4().hex[:8]
        with TestClient(app) as client:
            admin_token = self._login(
                client,
                "admin@abhaymethod.app",
                "admin12345",
            )["access_token"]
            client_token = self._login(
                client,
                "maya@example.com",
                "client12345",
            )["access_token"]

            me_response = client.get(
                "/api/auth/me",
                headers=self._auth_headers(str(client_token)),
            )
            self.assertEqual(me_response.status_code, 200)
            client_id = me_response.json()["client_id"]
            body = f"Realtime hello {unique_id}"

            with client.websocket_connect(
                f"/api/realtime/messages/{client_id}?access_token={admin_token}"
            ) as websocket:
                send_response = client.post(
                    "/api/client/messages",
                    headers=self._auth_headers(str(client_token)),
                    json={"body": body},
                )
                self.assertEqual(send_response.status_code, 201)

                payload = websocket.receive_json()
                self.assertEqual(payload["body"], body)
                self.assertEqual(payload["sender_role"], "client")

    def test_client_dashboard_exposes_subscription_metrics_reports_and_challenge(self) -> None:
        with TestClient(app) as client:
            client_token = self._login(
                client,
                "maya@example.com",
                "client12345",
            )["access_token"]

            dashboard_response = client.get(
                "/api/client/dashboard",
                headers=self._auth_headers(str(client_token)),
            )
            self.assertEqual(dashboard_response.status_code, 200)

            payload = dashboard_response.json()
            self.assertEqual(payload["client_name"], "Maya Singh")
            self.assertIsNotNone(payload["subscription"])
            self.assertEqual(payload["subscription"]["status"], "active")
            self.assertIsNotNone(payload["latest_metric"])
            self.assertIsNotNone(payload["monthly_progress_report"])
            self.assertGreaterEqual(payload["unread_notifications"], 0)
            self.assertGreaterEqual(len(payload["recent_form_checks"]), 1)
            self.assertIsNotNone(payload["active_challenge"])
            self.assertGreaterEqual(len(payload["active_challenge"]["leaderboard"]), 1)

    def test_admin_endpoints_expose_templates_challenge_and_extended_client_detail(self) -> None:
        with TestClient(app) as client:
            admin_token = self._login(
                client,
                "admin@abhaymethod.app",
                "admin12345",
            )["access_token"]
            headers = self._auth_headers(str(admin_token))

            clients_response = client.get("/api/admin/clients", headers=headers)
            self.assertEqual(clients_response.status_code, 200)
            clients_payload = clients_response.json()
            maya_payload = next(
                item for item in clients_payload if item["full_name"] == "Maya Singh"
            )
            self.assertEqual(maya_payload["subscription_status"], "active")

            detail_response = client.get(
                f"/api/admin/clients/{maya_payload['id']}",
                headers=headers,
            )
            self.assertEqual(detail_response.status_code, 200)
            detail_payload = detail_response.json()
            self.assertIsNotNone(detail_payload["subscription"])
            self.assertGreaterEqual(len(detail_payload["metrics"]), 1)
            self.assertIsNotNone(detail_payload["latest_progress_report"])
            self.assertGreaterEqual(len(detail_payload["form_checks"]), 1)

            templates_response = client.get("/api/admin/templates", headers=headers)
            self.assertEqual(templates_response.status_code, 200)
            self.assertGreaterEqual(len(templates_response.json()), 1)

            challenge_response = client.get("/api/admin/challenge", headers=headers)
            self.assertEqual(challenge_response.status_code, 200)
            challenge_payload = challenge_response.json()
            self.assertIsNotNone(challenge_payload)
            self.assertGreaterEqual(len(challenge_payload["leaderboard"]), 1)


if __name__ == "__main__":
    unittest.main()
