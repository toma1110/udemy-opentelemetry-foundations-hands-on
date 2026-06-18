# Section 6: OpenTelemetry Collector hands-on

この手順では、Section 2 から使っているローカルラボを使って、OpenTelemetry Collector の設定を読みます。AWS などのクラウドリソースは使いません。

## 対象講義

| Lecture ID | 確認すること |
| --- | --- |
| `s6-l2` | Collector コンテナの起動、ヘルスチェック、公開ポート |
| `s6-l3` | receiver、processor、exporter、extension の設定ブロック |
| `s6-l4` | traces と metrics の service pipelines |
| `s6-l5` | memory_limiter、resource、attributes、batch processor の役割 |
| `s6-l6` | Jaeger、Prometheus、debug exporter への出し分け |

## 1. ローカルラボを起動する

```powershell
cd local_lab
docker compose up --build -d
docker compose ps
```

`otel-collector`、`hello-telemetry`、`jaeger`、`prometheus` が起動していれば、Collector の確認に進めます。

## 2. Collector のヘルスチェックを見る

```powershell
Invoke-RestMethod http://localhost:13133/
```

期待する結果は `Server available` です。これは `extensions.health_check` が有効で、Collector が起動していることを示します。

## 3. Collector 設定を読む

```powershell
Get-Content .\otel-collector-config.yaml
```

このラボでは、次の流れでデータを扱います。

```text
application
  -> receiver: otlp
  -> processor: memory_limiter, resource, attributes, batch
  -> exporter: otlp/jaeger, prometheus, debug
```

主なブロック:

- `receivers.otlp`: アプリから OTLP gRPC と OTLP HTTP を受け取る入口
- `processors.memory_limiter`: Collector のメモリ使用量が増えすぎる前に保護する処理
- `processors.resource`: テレメトリに共通のリソース属性を付ける処理
- `processors.attributes`: Span などの属性をルールで追加、更新、削除する処理
- `processors.batch`: 小さなデータをまとめて送る処理
- `exporters.otlp/jaeger`: Trace を Jaeger に送る出口
- `exporters.prometheus`: Metric を Prometheus から取得できる形で公開する出口
- `exporters.debug`: Collector のログで流れを確認するための出口
- `extensions.health_check`: Collector 自体の起動状態を確認するための補助機能

## 4. service pipelines を確認する

`service.pipelines` では、signal ごとに通る部品をつなぎます。

```yaml
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, resource, attributes, batch]
      exporters: [otlp/jaeger, debug]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, resource, batch]
      exporters: [prometheus, debug]
```

`traces` と `metrics` は入口と processor を共有していますが、出口は異なります。Trace は Jaeger、Metric は Prometheus に向かいます。

## 5. テレメトリを流す

```powershell
1..5 | ForEach-Object {
  Invoke-RestMethod http://localhost:8000/checkout
}

curl.exe -i http://localhost:8000/error
```

その後、Collector のログを確認します。

```powershell
docker compose logs --tail 120 otel-collector
```

`debug` exporter のログに、Trace や Metric が出力されます。ログ量が多い場合は、エラーが繰り返されていないかを先に確認してください。

## 6. exporter の出力先を確認する

Jaeger:

```text
http://localhost:16686
```

`hello-telemetry`、`python-zero-code`、`java-zero-code` などのサービスを選び、Trace が表示されることを確認します。

Prometheus:

```text
http://localhost:9090
```

Query 画面で次を確認します。

```text
hello_requests_total
hello_request_duration_seconds_count
up
```

## 7. exporter を切り替えるときの考え方

このラボでは、Trace を Jaeger に送り、Metric を Prometheus から取得できる形で公開しています。本番環境では、出口を CloudWatch、X-Ray、Grafana Cloud、Datadog、New Relic などに変えることがあります。

切り替えるときは、アプリ側をすべて変更する前に、まず Collector の exporter と pipeline を差し替えます。アプリは OTLP の送信先を Collector に固定し、送信先サービスの違いを Collector 側で吸収するのが基本です。

## 8. 終了

```powershell
docker compose down
```

ラボの状態を完全に初期化したい場合だけ、ボリュームも削除します。

```powershell
docker compose down -v
```
