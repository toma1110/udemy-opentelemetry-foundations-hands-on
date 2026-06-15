import logging
import os
import random
import time
from uuid import uuid4

from fastapi import FastAPI, HTTPException, Request
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.trace import Status, StatusCode
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest
from starlette.responses import Response


SERVICE_NAME = os.getenv("OTEL_SERVICE_NAME", "hello-telemetry")
OTLP_ENDPOINT = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318").rstrip("/")


class TraceContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        span = trace.get_current_span()
        context = span.get_span_context()
        if context and context.is_valid:
            record.trace_id = f"{context.trace_id:032x}"
            record.span_id = f"{context.span_id:016x}"
        else:
            record.trace_id = "-"
            record.span_id = "-"
        return True


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s trace_id=%(trace_id)s span_id=%(span_id)s %(message)s",
)
for handler in logging.getLogger().handlers:
    handler.addFilter(TraceContextFilter())

logger = logging.getLogger("hello-telemetry")


resource = Resource.create(
    {
        "service.name": SERVICE_NAME,
        "service.version": "0.1.0",
    }
)

trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{OTLP_ENDPOINT}/v1/traces"))
)
trace.set_tracer_provider(trace_provider)
tracer = trace.get_tracer(__name__)

metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=f"{OTLP_ENDPOINT}/v1/metrics"),
    export_interval_millis=3000,
)
metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=[metric_reader]))
meter = metrics.get_meter(__name__)

request_counter = meter.create_counter(
    "hello_requests_total",
    unit="1",
    description="Total number of requests handled by the hello telemetry app.",
)
request_duration = meter.create_histogram(
    "hello_request_duration_ms",
    unit="ms",
    description="Request duration for the hello telemetry app.",
)

prom_request_counter = Counter(
    "hello_requests_total",
    "Total number of requests handled by the hello telemetry app.",
    ["method", "path", "status_code"],
)
prom_request_duration = Histogram(
    "hello_request_duration_seconds",
    "Request duration for the hello telemetry app.",
    ["method", "path", "status_code"],
)

app = FastAPI(title="Hello Telemetry")


@app.middleware("http")
async def telemetry_middleware(request: Request, call_next) -> Response:
    start = time.perf_counter()
    path = request.url.path
    method = request.method
    status_code = 500
    with tracer.start_as_current_span(f"{method} {path}") as span:
        span.set_attribute("http.request.method", method)
        span.set_attribute("url.path", path)
        try:
            response = await call_next(request)
            status_code = response.status_code
            span.set_attribute("http.response.status_code", status_code)
            if status_code >= 500:
                span.set_status(Status(StatusCode.ERROR))
            return response
        except Exception as exc:
            span.record_exception(exc)
            span.set_status(Status(StatusCode.ERROR, str(exc)))
            logger.exception("request failed path=%s", path)
            raise
        finally:
            duration_ms = (time.perf_counter() - start) * 1000
            attributes = {
                "http.request.method": method,
                "url.path": path,
                "http.response.status_code": status_code,
            }
            request_counter.add(1, attributes)
            request_duration.record(duration_ms, attributes)
            prom_request_counter.labels(method=method, path=path, status_code=str(status_code)).inc()
            prom_request_duration.labels(method=method, path=path, status_code=str(status_code)).observe(duration_ms / 1000)
            logger.info("request handled path=%s status=%s duration_ms=%.2f", path, status_code, duration_ms)


@app.get("/")
def root():
    return {
        "service": SERVICE_NAME,
        "message": "Hello Telemetry",
        "try": ["/healthz", "/checkout", "/error"],
    }


@app.get("/healthz")
def healthz():
    return {"status": "ok", "service": SERVICE_NAME}


@app.get("/metrics")
def prometheus_metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/checkout")
def checkout():
    with tracer.start_as_current_span("checkout.create_order") as span:
        order_id = str(uuid4())[:8]
        sleep_ms = random.randint(30, 180)
        span.set_attribute("app.order_id", order_id)
        span.set_attribute("app.sleep_ms", sleep_ms)
        time.sleep(sleep_ms / 1000)
        logger.info("checkout completed order_id=%s sleep_ms=%s", order_id, sleep_ms)
        return {
            "status": "accepted",
            "order_id": order_id,
            "sleep_ms": sleep_ms,
        }


@app.get("/error")
def error():
    with tracer.start_as_current_span("checkout.payment_error") as span:
        span.set_attribute("app.failure_type", "demo_payment_error")
        span.set_status(Status(StatusCode.ERROR, "intentional demo error"))
        logger.warning("intentional demo error")
        raise HTTPException(status_code=500, detail="intentional demo error")
