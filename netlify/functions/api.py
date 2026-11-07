import sys
import os

# Add project root directory to sys.path so 'backend.*' imports resolve cleanly
root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
if root_dir not in sys.path:
    sys.path.insert(0, root_dir)

from mangum import Mangum
from backend.main import app

# Initialize Mangum ASGI adapter with lifespan="off" for serverless execution
_mangum_handler = Mangum(app, lifespan="off")

def handler(event, context):
    """
    Netlify Serverless Function Handler for FastAPI.
    Supports API calls under /api/*, /safety/*, /docs, and root /.
    """
    # Normalize path if Netlify function prefix is included
    if "path" in event and event["path"].startswith("/.netlify/functions/api"):
        event["path"] = event["path"][len("/.netlify/functions/api"):] or "/"

    # Populate AWS API Gateway requestContext if invoked directly from Netlify
    if "requestContext" not in event:
        event["requestContext"] = {
            "resourcePath": "/{proxy+}",
            "httpMethod": event.get("httpMethod", "GET"),
            "path": event.get("path", "/"),
        }
    elif "path" in event["requestContext"] and event["requestContext"]["path"].startswith("/.netlify/functions/api"):
        event["requestContext"]["path"] = event["requestContext"]["path"][len("/.netlify/functions/api"):] or "/"

    if "resource" not in event:
        event["resource"] = "/{proxy+}"

    return _mangum_handler(event, context)
