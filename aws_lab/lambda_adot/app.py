import json
import os
import time


def lambda_handler(event, context):
    payload = {
        "message": "hello from lambda adot lab",
        "service": os.environ.get("OTEL_SERVICE_NAME", "unknown"),
        "timestamp": int(time.time()),
        "input": event,
    }
    print(json.dumps(payload, ensure_ascii=False))
    return {
        "statusCode": 200,
        "body": json.dumps(payload, ensure_ascii=False),
    }

