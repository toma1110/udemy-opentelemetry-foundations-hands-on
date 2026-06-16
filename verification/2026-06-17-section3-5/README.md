# Section 3-5 hands-on verification

Verification date: 2026-06-17 JST

Issue: udemy3 #52

This evidence records the local Docker hands-on verification used for the skipped Section 3, Section 4, and Section 5 hands-on lectures.

## Scope

Verified lecture coverage:

- S3-L4: Java zero-code instrumentation
- S3-L5: Python zero-code instrumentation
- S3-L7: instrumentation choice points
- S4-L2: Span and Attribute
- S4-L4: Metrics
- S4-L5: Traces
- S4-L7: Context propagation
- S4-L9: Logs
- S5-L2: SDK configuration

## Environment

- Windows 11 local machine
- Docker Desktop
- Docker Engine: 29.5.3
- Docker Compose: v5.1.4
- Local-only lab. No cloud resources were created.

## Verification command

From this repository root:

```powershell
.\verify_local_lab.ps1 -SkipStart
```

Result:

```text
PASS: local lab verification completed.
```

The full command output is saved in:

```text
verification-output.txt
```

## Verified signals

- All expected containers were running.
- `hello-telemetry` exposed `/healthz`, `/checkout`, `/manual-span`, `/frontend`, `/backend`, and `/error`.
- `python-zero-code` generated traces without OpenTelemetry SDK code in the application.
- `java-zero-code` generated traces through the OpenTelemetry Java agent.
- Jaeger listed `hello-telemetry`, `python-zero-code`, and `java-zero-code`.
- Manual span `inventory.reserve` appeared under the `/manual-span` trace.
- Context propagation connected `/frontend`, `frontend.call_backend`, and `backend.handle_request` in one trace.
- Prometheus returned `hello_requests_total` with successful, not found, and error status-code examples.
- Application logs included `trace_id` and `span_id`.

## Screen evidence

| File | Evidence |
| --- | --- |
| `screenshots/01-app-root.png` | Local app routes and OTLP endpoint |
| `screenshots/02-context-propagation-json.png` | `traceparent` injection and extraction result |
| `screenshots/03-jaeger-services-api.png` | Jaeger services include the three demo services |
| `screenshots/04-prometheus-hello-requests.png` | Prometheus query result for `hello_requests_total` |
| `screenshots/05-jaeger-manual-span-trace.png` | Jaeger trace containing `inventory.reserve` |
| `screenshots/06-jaeger-context-propagation-trace.png` | Jaeger trace showing frontend to backend propagation |
| `screenshots/07-jaeger-python-zero-code-trace.png` | Python zero-code instrumentation trace |
| `screenshots/08-jaeger-java-zero-code-trace.png` | Java zero-code instrumentation trace |

## Screenshot SHA256

```text
CFFF28588AA3EB5E5BDFD01DC00FD1692B58207924E2BFE40B0C63BF82A4D617  01-app-root.png
7A30FB1E587DDE1CF8B1A7503DE646E8640B449895B615911BD072F10AFB1815  02-context-propagation-json.png
58DB424476EA8CBE1823275EC9963823423E388AE2D647049DE1A8D66913CE7F  03-jaeger-services-api.png
0A70DB369D916A4FC70B6E1ECD9CF1EE592AD0C8084C0FE5C267C6C7B9187E48  04-prometheus-hello-requests.png
53B5CB5421C40B0594760E957D6E4396942DA4534D442BA390A77120B4445E42  05-jaeger-manual-span-trace.png
5BCD827FB9394FA06985EB02499C3A3861BEA274ABCE0B528C402163CA9328BA  06-jaeger-context-propagation-trace.png
2CB76FBD0225329F7715C34EC09A2B8540FF9D1D4303C3E764126BA2C781536B  07-jaeger-python-zero-code-trace.png
2CCCB8E6E9201E56F29760B71ED6EC213AE6FF5A94EC70C88B71E8DC64833DCB  08-jaeger-java-zero-code-trace.png
```

## Notes

- The lab uses local Docker containers only.
- The evidence does not contain credentials, tokens, cloud account identifiers, or personal data.
- Cleanup is optional for learners and is documented in the repository README.
