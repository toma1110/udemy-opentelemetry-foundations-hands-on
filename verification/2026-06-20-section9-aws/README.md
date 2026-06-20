# Section 9 AWS Integration Verification

Date: 2026-06-20

Region: `ap-northeast-1`

Account-specific values such as AWS account ID, IAM user name, task ARN, and request IDs are intentionally omitted or masked in this public evidence.

## Scope

- `s9-l4`: Lambda + ADOT Layer
- `s9-l5`: ECS/Fargate + ADOT Collector sidecar

## Lambda + ADOT Layer

Command:

```powershell
cd aws_lab
.\lambda_adot\deploy_lambda_adot.ps1
```

Observed configuration:

```text
FunctionName: otel-c008-lambda-adot
Runtime: python3.12
Handler: app.lambda_handler
Layer: arn:aws:lambda:ap-northeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:25
TracingConfig: Active
Environment:
  AWS_LAMBDA_EXEC_WRAPPER=/opt/otel-instrument
  OTEL_SERVICE_NAME=otel-c008-lambda-adot
```

Observed invoke response:

```json
{
  "statusCode": 200,
  "body": {
    "message": "hello from lambda adot lab",
    "service": "otel-c008-lambda-adot",
    "input": {
      "source": "udemy-opentelemetry-foundations-hands-on",
      "lecture": "s9-l4"
    }
  }
}
```

Observed logs:

```text
START / END / REPORT entries were created in CloudWatch Logs.
XRAY TraceId entries were emitted for sampled invocations.
```

Observed X-Ray summary:

```text
EntryPoint: otel-c008-lambda-adot
HasFault: false
HasError: false
Trace summaries observed: 3
```

Cleanup:

```powershell
.\lambda_adot\cleanup_lambda_adot.ps1
```

Cleanup result:

```text
Lambda function deleted: ok
Lambda IAM role deleted: ok
Lambda log group deleted: ok
```

## ECS/Fargate + ADOT Collector Sidecar

Command:

```powershell
cd aws_lab
.\ecs_adot_sidecar\deploy_ecs_adot_sidecar.ps1
```

Observed task definition:

```text
Launch type: FARGATE
Network mode: awsvpc
Containers:
  aws-otel-collector
    image: public.ecr.aws/aws-observability/aws-otel-collector:latest
    command: --config=env:OTEL_CONFIG
  application
    image: ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest
    command: traces --otlp-endpoint localhost:4317 --otlp-insecure --duration 20s --rate 1
```

Observed task result:

```text
Task lastStatus: STOPPED
Task stopCode: EssentialContainerExited
application exitCode: 0
aws-otel-collector exitCode: 0
```

Observed application log:

```text
Channel Connectivity change to READY
traces generated {"worker": 0, "traces": 11}
stopping the exporter
```

Observed Collector log:

```text
Starting aws-otel-collector...
Starting GRPC server endpoint [::]:4317
Starting HTTP server endpoint [::]:4318
Everything is ready. Begin running and processing data.
service.name=telemetrygen
otelcol.component.id=debug
otelcol.signal=traces
```

Observed X-Ray summary:

```text
EntryPoint: lets-go
HasFault: false
HasError: false
Trace summaries observed from telemetrygen
```

Cleanup:

```powershell
.\ecs_adot_sidecar\cleanup_ecs_adot_sidecar.ps1
```

Cleanup result:

```text
ECS cluster deleted: ok
Active task definitions: none
Execution role deleted: ok
Task role deleted: ok
Log groups deleted: ok
Security group deleted: ok
```

## Notes

- The lab uses short-lived resources and deletes them after verification.
- The ECS/Fargate lab uses a minimal Collector config passed through `OTEL_CONFIG`, because the instance-metrics config expects host paths that are not appropriate for this short Fargate task.
- Do not skip cleanup after running the AWS lab.
