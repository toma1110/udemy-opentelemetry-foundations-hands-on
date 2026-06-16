import random
import time
from uuid import uuid4

from fastapi import FastAPI, HTTPException


app = FastAPI(title="Python Zero Code App")


@app.get("/")
def root():
    return {
        "service": "python-zero-code",
        "message": "This app has no OpenTelemetry SDK code in app.py.",
        "try": ["/auto/checkout", "/auto/error"],
    }


@app.get("/auto/checkout")
def checkout():
    sleep_ms = random.randint(20, 120)
    time.sleep(sleep_ms / 1000)
    return {
        "status": "accepted",
        "order_id": str(uuid4())[:8],
        "sleep_ms": sleep_ms,
    }


@app.get("/auto/error")
def error():
    raise HTTPException(status_code=500, detail="intentional zero-code demo error")
