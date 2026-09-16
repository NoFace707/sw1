import os
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv


BASE_DIR = Path(__file__).resolve().parent.parent
ROOT_DIR = BASE_DIR.parent.parent

load_dotenv(ROOT_DIR / ".env")
load_dotenv(BASE_DIR.parent / ".env")

SECRET_KEY = os.getenv(
    "DJANGO_SECRET_KEY",
    "development-only-secret-key-change-before-production-2026",
)
DEBUG = os.getenv("DJANGO_DEBUG", "True").lower() == "true"
ALLOWED_HOSTS = [
    host.strip()
    for host in os.getenv("DJANGO_ALLOWED_HOSTS", "127.0.0.1,localhost").split(",")
    if host.strip()
]

INSTALLED_APPS = [
    "daphne",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "core",
    "modeling",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.common.CommonMiddleware",
]

ROOT_URLCONF = "config.urls"
TEMPLATES = []
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

CHANNEL_LAYER_BACKEND = os.getenv("CHANNEL_LAYERS_BACKEND", "channels.layers.InMemoryChannelLayer")
CHANNEL_LAYERS = {"default": {"BACKEND": CHANNEL_LAYER_BACKEND}}
if "RedisChannelLayer" in CHANNEL_LAYER_BACKEND:
    # RedisChannelLayer polls Redis with a blocking command. redis-py 8 defaults
    # socket_timeout to 5 seconds, the same interval used by channels_redis, so
    # leaving the default in place tears down otherwise healthy WebSockets.
    CHANNEL_LAYERS["default"]["CONFIG"] = {
        "hosts": [
            {
                "address": os.getenv("REDIS_URL", "redis://localhost:6379/0"),
                "socket_connect_timeout": float(
                    os.getenv("REDIS_SOCKET_CONNECT_TIMEOUT_SECONDS", "5")
                ),
                "socket_timeout": None,
                "health_check_interval": int(
                    os.getenv("REDIS_HEALTH_CHECK_INTERVAL_SECONDS", "30")
                ),
            }
        ]
    }

CACHES = {
    "default": {
        "BACKEND": os.getenv("DJANGO_CACHE_BACKEND", "django.core.cache.backends.locmem.LocMemCache"),
        "LOCATION": os.getenv("DJANGO_CACHE_LOCATION", "uml-modeler-cache"),
    }
}

if os.getenv("DJANGO_DATABASE_ENGINE", "postgresql").lower() == "sqlite":
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.getenv("POSTGRES_DB", "app_db"),
            "USER": os.getenv("POSTGRES_USER", "app_user"),
            "PASSWORD": os.getenv("POSTGRES_PASSWORD", "app_password"),
            "HOST": os.getenv("POSTGRES_HOST", "localhost"),
            "PORT": os.getenv("POSTGRES_PORT", "5432"),
        }
    }

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
]

LANGUAGE_CODE = "es-es"
TIME_ZONE = "America/La_Paz"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

CORS_ALLOWED_ORIGINS = [
    origin.strip()
    for origin in os.getenv(
        "CORS_ALLOWED_ORIGINS",
        "http://localhost:5173,http://localhost:5180",
    ).split(",")
    if origin.strip()
]
CORS_ALLOW_CREDENTIALS = False

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.AllowAny",
    ),
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(
        seconds=int(os.getenv("JWT_ACCESS_LIFETIME_SECONDS", "3600"))
    ),
    "REFRESH_TOKEN_LIFETIME": timedelta(
        seconds=int(os.getenv("JWT_REFRESH_LIFETIME_SECONDS", "604800"))
    ),
    "ROTATE_REFRESH_TOKENS": False,
    "BLACKLIST_AFTER_ROTATION": False,
}

AI_BASE_URL = os.getenv("AI_BASE_URL", "")
AI_API_KEY = os.getenv("AI_API_KEY", "")
AI_MODEL = os.getenv("AI_MODEL", "Qwen2.5-Coder-1.5B-Q4")
AI_TIMEOUT_SECONDS = int(os.getenv("AI_TIMEOUT_SECONDS", "20"))
AI_MAX_OPERATIONS = int(os.getenv("AI_MAX_OPERATIONS", "200"))
MODEL_SNAPSHOT_INTERVAL = int(os.getenv("MODEL_SNAPSHOT_INTERVAL", "50"))
XMI_MAX_BYTES = int(os.getenv("XMI_MAX_BYTES", str(10 * 1024 * 1024)))
MAX_PROJECT_ELEMENTS = int(os.getenv("MAX_PROJECT_ELEMENTS", "5000"))
MAX_PROJECT_RELATIONSHIPS = int(os.getenv("MAX_PROJECT_RELATIONSHIPS", "10000"))
MAX_COLLABORATORS = int(os.getenv("MAX_COLLABORATORS", "50"))
SNAPSHOT_RETENTION = int(os.getenv("SNAPSHOT_RETENTION", "20"))
