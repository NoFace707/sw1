from datetime import timedelta

from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import AccessToken, RefreshToken


class AuthenticationApiTests(APITestCase):
    register_url = "/api/auth/register/"
    login_url = "/api/auth/login/"

    def registration_payload(self, **overrides):
        payload = {
            "first_name": "Ana",
            "last_name": "Pérez",
            "email": "ANA@Example.COM",
            "password": "universidad-123",
        }
        payload.update(overrides)
        return payload

    def create_user(self):
        return get_user_model().objects.create_user(
            username="ana",
            first_name="Ana",
            last_name="Pérez",
            email="ana@example.com",
            password="universidad-123",
            is_active=True,
        )

    def test_registers_active_user_with_hashed_password_and_session(self):
        response = self.client.post(self.register_url, self.registration_payload(), format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(set(response.data), {"user", "access", "refresh"})
        self.assertNotIn("password", response.data["user"])
        user = get_user_model().objects.get(email="ana@example.com")
        self.assertTrue(user.is_active)
        self.assertTrue(user.check_password("universidad-123"))
        self.assertNotEqual(user.password, "universidad-123")

    def test_rejects_case_insensitive_duplicate_email(self):
        self.create_user()
        response = self.client.post(
            self.register_url,
            self.registration_payload(email="ANA@EXAMPLE.COM"),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("email", response.data)
        self.assertEqual(get_user_model().objects.count(), 1)

    def test_database_rejects_case_insensitive_duplicate_email(self):
        self.create_user()
        with self.assertRaises(IntegrityError), transaction.atomic():
            get_user_model().objects.create_user(
                username="ana-duplicate",
                email="ANA@EXAMPLE.COM",
                password="universidad-123",
            )

    def test_rejects_invalid_registration_fields(self):
        response = self.client.post(
            self.register_url,
            {"first_name": "", "last_name": "", "email": "bad", "password": "short"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(set(response.data), {"first_name", "last_name", "email", "password"})

    def test_login_accepts_email_case_insensitively(self):
        self.create_user()
        response = self.client.post(
            self.login_url,
            {"email": "ANA@EXAMPLE.COM", "password": "universidad-123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(set(response.data), {"user", "access", "refresh"})

    def test_login_uses_generic_invalid_credentials_error(self):
        response = self.client.post(
            self.login_url,
            {"email": "missing@example.com", "password": "wrong-password"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(response.data["detail"], "Credenciales inválidas.")

    def test_refresh_returns_new_access_and_me_requires_bearer(self):
        user = self.create_user()
        refresh = RefreshToken.for_user(user)
        response = self.client.post(
            "/api/auth/refresh/", {"refresh": str(refresh)}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(set(response.data), {"access"})

        anonymous = self.client.get("/api/auth/me/")
        self.assertEqual(anonymous.status_code, status.HTTP_401_UNAUTHORIZED)

        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
        authenticated = self.client.get("/api/auth/me/")
        self.assertEqual(authenticated.status_code, status.HTTP_200_OK)
        self.assertEqual(authenticated.data["email"], user.email)

    def test_expired_access_is_rejected_but_refresh_remains_valid(self):
        user = self.create_user()
        access = AccessToken.for_user(user)
        access.set_exp(lifetime=timedelta(seconds=-1))
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {access}")
        self.assertEqual(
            self.client.get("/api/auth/me/").status_code,
            status.HTTP_401_UNAUTHORIZED,
        )
        refresh = RefreshToken.for_user(user)
        self.client.credentials()
        self.assertEqual(
            self.client.post(
                "/api/auth/refresh/", {"refresh": str(refresh)}, format="json"
            ).status_code,
            status.HTTP_200_OK,
        )

    def test_invalid_refresh_and_logout_are_handled(self):
        invalid = self.client.post(
            "/api/auth/refresh/", {"refresh": "invalid"}, format="json"
        )
        self.assertEqual(invalid.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertEqual(
            self.client.post("/api/auth/logout/", {}, format="json").status_code,
            status.HTTP_200_OK,
        )
