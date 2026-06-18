# Section 6 Collector verification

Date: 2026-06-19 JST

Purpose: verify the local Collector hands-on flow before producing Section 6 lecture videos.

## Environment

- Docker: 29.5.3
- Docker Compose: v5.1.4
- Collector image: `otel/opentelemetry-collector-contrib:0.102.1`
- Jaeger image: `jaegertracing/all-in-one:1.57`
- Prometheus image: `prom/prometheus:v2.53.0`
- Grafana image: `grafana/grafana:11.1.0`

## Commands

```powershell
cd local_lab
docker compose up --build -d
docker compose ps
Invoke-RestMethod http://localhost:13133/
Get-Content .\otel-collector-config.yaml
1..5 | ForEach-Object { Invoke-RestMethod http://localhost:8000/checkout }
curl.exe -i http://localhost:8000/error
docker compose logs --tail 120 otel-collector
Invoke-RestMethod "http://localhost:9090/api/v1/query?query=up"
Invoke-RestMethod "http://localhost:9090/api/v1/query?query=hello_requests_total"
Invoke-RestMethod "http://localhost:16686/api/services"
Invoke-RestMethod "http://localhost:16686/api/traces?service=hello-telemetry&limit=5"
```

## Result

- `docker compose ps` showed all local lab containers running.
- Collector health check returned `Server available`.
- Collector accepted OTLP HTTP and gRPC through `otlp` receiver.
- `memory_limiter`, `resource`, `attributes`, and `batch` processors were loaded in the trace pipeline.
- `memory_limiter`, `resource`, and `batch` processors were loaded in the metric pipeline.
- `debug` exporter logs showed trace and metric export activity.
- Prometheus `up` returned `otel-collector:8889 = 1` and `hello-telemetry:8000 = 1`.
- Prometheus `hello_requests_total` showed `/checkout` HTTP 200 and `/error` HTTP 500 data points.
- Jaeger service API returned `hello-telemetry`.
- Jaeger traces included `GET /checkout`, `checkout.create_order`, and `GET /error`.

Decision: pass for Section 6 video production.

## Screenshot Evidence

| File | Purpose |
| --- | --- |
| `01-collector-health.png` | Collector health check |
| `01b-collector-health-readable.png` | Readable rendering of the verified Collector health check response |
| `02-prometheus-targets.png` | Prometheus targets |
| `03-prometheus-query-hello-requests.png` | Prometheus metric query |
| `03b-prometheus-query-hello-requests-readable.png` | Readable rendering of the verified Prometheus API query result |
| `04-jaeger-search-hello-telemetry.png` | Jaeger service search |
| `04b-jaeger-checkout-traces.png` | Jaeger `/checkout` trace search |
| `05-collector-config-file.png` | Raw Collector config file in browser |
| `05b-collector-config-readable.png` | Readable rendering of the verified Collector config |
| `05c-collector-pipelines-readable.png` | Readable rendering of exporters and service pipelines |
| `05d-collector-service-pipelines-full.png` | Readable rendering of only the verified service pipelines block |

## Notes for video production

- Use the large readable config screenshot for learner-facing slides.
- Use `04b-jaeger-checkout-traces.png` when explaining trace exporter behavior.
- Use `03b-prometheus-query-hello-requests-readable.png` when explaining metric exporter behavior.
- The screenshots do not include credentials or cloud account information.
