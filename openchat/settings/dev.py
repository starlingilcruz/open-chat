"""
Development settings
"""

from .base import *  # noqa: F403

DEBUG = True

CORS_ALLOWED_ORIGINS = [
    "https://rocketbyte.duckdns.org",
    "http://rocketbyte.duckdns.org",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]

CSRF_COOKIE_SECURE = False
SESSION_COOKIE_SECURE = False
