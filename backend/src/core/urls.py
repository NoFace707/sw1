from django.urls import path

from .views import health, login, logout, me, refresh_session, register


urlpatterns = [
    path("health/", health, name="health"),
    path("auth/register/", register, name="auth-register"),
    path("auth/login/", login, name="auth-login"),
    path("auth/refresh/", refresh_session, name="auth-refresh"),
    path("auth/me/", me, name="auth-me"),
    path("auth/logout/", logout, name="auth-logout"),
]
