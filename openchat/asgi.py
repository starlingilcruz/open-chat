"""
ASGI config for openchat project.
"""

import os

from channels.auth import AuthMiddlewareStack
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.security.websocket import AllowedHostsOriginValidator
from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "openchat.settings.dev")

django_asgi_app = get_asgi_application()

from messaging.routing import websocket_urlpatterns  # noqa: E402


class ScriptNameMiddleware:
    """
    ASGI middleware to handle X-Script-Name header for WebSocket connections.
    Strips the script name prefix from the path.
    """

    def __init__(self, inner):
        self.inner = inner

    async def __call__(self, scope, receive, send):
        if scope["type"] == "websocket":
            # Ensure path starts with /
            if not scope["path"].startswith("/"):
                scope["path"] = "/" + scope["path"]

            # Get the script name from headers
            headers = dict(scope.get("headers", []))
            script_name = headers.get(b"x-script-name", b"").decode("utf-8")

            if script_name and scope["path"].startswith(script_name):
                # Strip the script name from the path
                scope["path"] = scope["path"][len(script_name) :]
                # Ensure path still starts with /
                if not scope["path"].startswith("/"):
                    scope["path"] = "/" + scope["path"]

        return await self.inner(scope, receive, send)


application = ProtocolTypeRouter(
    {
        "http": django_asgi_app,
        "websocket": ScriptNameMiddleware(
            AllowedHostsOriginValidator(AuthMiddlewareStack(URLRouter(websocket_urlpatterns)))
        ),
    }
)
