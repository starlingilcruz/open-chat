"""
Custom middleware for openchat
"""

from django.urls import set_script_prefix


class ScriptNameMiddleware:
    """
    Middleware to set SCRIPT_NAME from X-Script-Name header.

    This allows Django to properly handle subpath deployments when behind
    a reverse proxy that sets the X-Script-Name header.

    Calls set_script_prefix() to override FORCE_SCRIPT_NAME per-request so
    that reverse() and template {% url %} tags produce correct paths for both
    the subpath route (duckdns, with X-Script-Name header) and the subdomain
    route (rotbyte.com, no header).
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Get the script name from the header
        script_name = request.headers.get("X-Script-Name", "")

        if script_name:
            # Set SCRIPT_NAME in the request META
            request.META["SCRIPT_NAME"] = script_name
            # Override FORCE_SCRIPT_NAME-based prefix for this request so
            # reverse() returns paths with the correct prefix.
            set_script_prefix(script_name)

            # Update path_info to strip the script name prefix
            if request.path_info.startswith(script_name):
                request.path_info = request.path_info[len(script_name) :]
                # Ensure path_info starts with /
                if not request.path_info.startswith("/"):
                    request.path_info = "/" + request.path_info
        else:
            # No X-Script-Name header — this request comes in at the root path
            # (e.g. openchat.rotbyte.com). Reset the prefix so reverse() does
            # not prepend FORCE_SCRIPT_NAME ("/openchat") to generated URLs.
            set_script_prefix("")

        response = self.get_response(request)
        return response
