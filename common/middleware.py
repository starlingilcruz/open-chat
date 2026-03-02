"""
Custom middleware for openchat
"""


class ScriptNameMiddleware:
    """
    Middleware to set SCRIPT_NAME from X-Script-Name header.

    This allows Django to properly handle subpath deployments when behind
    a reverse proxy that sets the X-Script-Name header.
    """

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        # Get the script name from the header
        script_name = request.headers.get("X-Script-Name", "")

        if script_name:
            # Set SCRIPT_NAME in the request META
            request.META["SCRIPT_NAME"] = script_name

            # Update path_info to strip the script name prefix
            if request.path_info.startswith(script_name):
                request.path_info = request.path_info[len(script_name) :]
                # Ensure path_info starts with /
                if not request.path_info.startswith("/"):
                    request.path_info = "/" + request.path_info

        response = self.get_response(request)
        return response
