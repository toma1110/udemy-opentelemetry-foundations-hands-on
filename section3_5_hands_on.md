# Section 3-5 ハンズオン

このファイルは、Section 3、Section 4、Section 5で扱うローカルハンズオンの対応表です。Section 2で起動した `local_lab` をそのまま使います。

## 対象講義

| Lecture ID | 確認すること | 主に使う画面 |
| --- | --- | --- |
| `s3-l4` | Java/Spring BootをOpenTelemetry Java agentでzero-code計装する | Java app、Jaeger |
| `s3-l5` | Python/FastAPIを `opentelemetry-instrument` でzero-code計装する | Python app、Jaeger |
| `s3-l7` | 手動SpanとAttributeを追加してTraceに出ることを見る | Hello app、Jaeger |
| `s4-l2` | request count、latency、error rateをMetricとして見る | Prometheus |
| `s4-l4` | 1リクエストがTraceとして見えることを確認する | Jaeger |
| `s4-l5` | `traceparent` によるContext propagationを確認する | Hello app、Jaeger |
| `s4-l7` | ログに `trace_id` と `span_id` が入ることを確認する | Docker logs |
| `s4-l9` | MetricからTrace、Logへ進む調査順を確認する | Prometheus、Jaeger、Docker logs |
| `s5-l2` | service name、OTLP endpoint、resource attributesなどSDK設定の反映を見る | App response、Compose、Jaeger |

## 起動

```powershell
cd local_lab
docker compose up --build -d
docker compose ps
```

## Java zero-code instrumentation

Spring Bootアプリ自体にはOpenTelemetry SDKコードを書いていません。DockerfileでOpenTelemetry Java agentを追加し、環境変数で送信先を指定しています。

```powershell
Invoke-RestMethod http://localhost:8080/hello
Invoke-RestMethod http://localhost:8080/checkout
```

Jaegerで `java-zero-code` serviceを選び、`GET /checkout` のTraceが見えれば成功です。

## Python zero-code instrumentation

FastAPIアプリ自体にはOpenTelemetry SDKコードを書いていません。起動コマンドで `opentelemetry-instrument` を使っています。

```powershell
Invoke-RestMethod http://localhost:8001/auto/checkout
```

Jaegerで `python-zero-code` serviceを選び、`GET /auto/checkout` のTraceが見えれば成功です。

## SpanとAttribute

```powershell
Invoke-RestMethod http://localhost:8000/manual-span
```

Jaegerで `hello-telemetry` serviceを選び、`inventory.reserve` spanと `app.item_id`、`app.quantity` attributeが見えれば成功です。

## Metrics

リクエストを複数回発生させます。

```powershell
1..5 | ForEach-Object { Invoke-RestMethod http://localhost:8000/checkout }
curl.exe -i http://localhost:8000/error
```

Prometheusで次を検索します。

```text
hello_requests_total
hello_request_duration_seconds_count
```

`path`、`status_code` などのlabelごとに値が見えれば成功です。

## Trace

Jaegerで `hello-telemetry` serviceを選びます。`GET /checkout`、`checkout.create_order`、`GET /error` などが見えれば成功です。

## Context propagation

```powershell
Invoke-RestMethod http://localhost:8000/frontend
```

Responseの `traceparent_sent` が空でなく、Jaegerで `frontend.call_backend` と `backend.handle_request` が同じTrace上につながっていれば成功です。

## Logs

```powershell
docker compose logs --tail 80 hello-telemetry
```

`trace_id=` と `span_id=` がログ行に入っていれば成功です。

## SDK configuration

`docker-compose.yml` の各サービスで、次を確認します。

- `OTEL_SERVICE_NAME`
- `OTEL_EXPORTER_OTLP_ENDPOINT`
- `OTEL_EXPORTER_OTLP_PROTOCOL`
- `OTEL_RESOURCE_ATTRIBUTES`

アプリの `/` endpointやJaegerのservice名に、設定したservice nameが反映されていれば成功です。

## まとめ検証

講師またはQA担当は、次のスクリプトでSection 3-5の主要確認をまとめて実行できます。

```powershell
.\verify_local_lab.ps1
```

検証結果と画面キャプチャは `verification/` に記録します。
