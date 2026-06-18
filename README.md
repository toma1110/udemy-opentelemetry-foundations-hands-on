# OpenTelemetryローカルハンズオン

このリポジトリは、Udemy講座「OpenTelemetryハンズオン入門」で使うローカルハンズオン用リポジトリです。

このハンズオンでは、ローカルDocker環境で小さなアプリを動かし、OpenTelemetry Collectorを通してトレースとメトリクスを観察します。AWSアカウントは使いません。

## 対象講義

| Lecture ID | 使う内容 |
| --- | --- |
| `s2-l2` | Docker Composeで観測環境を起動する |
| `s2-l3` | Hello Telemetryアプリを見る |
| `s2-l4` | 公式OpenTelemetry Demoを見る |
| `s2-l5` | よくある起動失敗と確認コマンド |

## 目的

- 小さなアプリ、Collector、Backend、Dashboardの役割を分けて確認する
- アプリからTraceとMetricが出ることを確認する
- Collectorのログを見て、データが流れているか切り分ける
- 公式OpenTelemetry Demoを、本番に近い参照例として観察する

## 前提

- Docker Desktop
- Docker Compose v2
- PowerShell
- ブラウザ

Windowsで初めてDocker Desktopを使う場合は、先に次を確認してください。

```text
windows_setup.md
```

このハンズオンはローカル環境だけで完結します。AWS、Google Cloud、Azureなどのクラウドリソースは作成しません。

## ローカルラボの構成

```text
hello-telemetry app
  -> OpenTelemetry Collector
      -> Jaeger UI for traces
      -> Prometheus for metrics
      -> Grafana for dashboards
```

| 部品 | 役割 | URL |
| --- | --- | --- |
| Hello Telemetry app | 観測データを作る小さなアプリ | http://localhost:8000 |
| OpenTelemetry Collector | データを受け取り、整え、送る | http://localhost:13133 |
| Jaeger | Traceを見る | http://localhost:16686 |
| Prometheus | Metricを見る | http://localhost:9090 |
| Grafana | Dashboardを見る | http://localhost:3000 |

## 起動

PowerShellで、このリポジトリのルートディレクトリから実行します。

```powershell
cd local_lab
docker compose up --build -d
```

起動状態を確認します。

```powershell
docker compose ps
```

`hello-telemetry`、`otel-collector`、`jaeger`、`prometheus`、`grafana` が起動していれば、最初の確認に進みます。

## Hello Telemetryアプリを見る

ヘルスチェックを確認します。

```powershell
Invoke-RestMethod http://localhost:8000/healthz
```

通常リクエストを送ります。

```powershell
1..5 | ForEach-Object {
  Invoke-RestMethod http://localhost:8000/checkout
}
```

エラーに近い動きを作ります。

```powershell
curl.exe -i http://localhost:8000/error
```

期待する結果:

- `/checkout` は `status` と `order_id` を返す
- `/error` は意図的にHTTP 500を返す
- アプリのログに `trace_id` と `span_id` が出る
- Jaegerで `hello-telemetry` サービスのTraceが見える
- Prometheusで `hello_requests_total` や `hello_request_duration_seconds_count` が見える

## Traceを見る

ブラウザでJaegerを開きます。

```text
http://localhost:16686
```

確認すること:

- Serviceで `hello-telemetry` を選べる
- `/checkout` または `/error` のTraceが見える
- Spanの中にHTTPメソッド、パス、ステータスコードがある
- エラー時はSpanに例外情報またはエラー状態が記録される

## Metricを見る

ブラウザでPrometheusを開きます。

```text
http://localhost:9090
```

Query画面で次を確認します。

```text
hello_requests_total
hello_request_duration_seconds_count
```

確認すること:

- `/checkout` を実行するたびにリクエスト数が増える
- `/error` のHTTP 500もステータスコード別に見える
- PrometheusがアプリとCollectorの両方をscrapeしている

## Collectorのログを見る

Collectorがデータを受け取っているか確認します。

```powershell
docker compose logs --tail 80 otel-collector
```

確認すること:

- TraceまたはMetricの受信ログがある
- Collectorが起動失敗していない
- exporterのエラーが繰り返し出ていない

## Grafanaを見る

ブラウザでGrafanaを開きます。

```text
http://localhost:3000
```

初期ユーザー名とパスワード:

```text
admin / admin
```

このローカルラボでは、Prometheus datasourceを自動登録します。最初のSection 2では、Grafanaは「Dashboardを見る場所」として位置づけだけ確認します。詳しいDashboard作成は後続セクションで扱います。

## 公式OpenTelemetry Demoを見る

公式Demoは、小さなアプリで基本を確認した後に見る参照例です。手順は次のファイルに分けています。

```text
official_demo_reference.md
```

公式Demoは複数サービスで構成されるため、最初からすべてを追いません。Section 2では、Web store、Grafana、Jaeger、Load Generator UIの位置づけだけ確認します。

## よくある起動失敗

### dockerが見つからない

```powershell
docker --version
docker compose version
```

上のコマンドが失敗する場合は、Docker Desktopをインストールし、起動してからPowerShellを開き直します。Windowsでの準備手順は `windows_setup.md` を参照してください。

### ポートが競合している

このラボは次のポートを使います。

| Port | 用途 |
| ---: | --- |
| 8000 | Hello Telemetry app |
| 13133 | Collector health check |
| 16686 | Jaeger UI |
| 9090 | Prometheus |
| 3000 | Grafana |
| 4317 | OTLP gRPC |
| 4318 | OTLP HTTP |
| 8889 | Collector Prometheus exporter |

競合を確認します。

```powershell
Get-NetTCPConnection -LocalPort 8000,13133,16686,9090,3000,4317,4318,8889 -ErrorAction SilentlyContinue
```

### コンテナが落ちる

```powershell
docker compose ps
docker compose logs --tail 80 hello-telemetry
docker compose logs --tail 80 otel-collector
```

まず、アプリ、Collector、Backendのどこで止まっているかを分けて見ます。

### Traceが見えない

確認順:

1. `/checkout` を何度か実行したか
2. `docker compose logs --tail 80 hello-telemetry` にリクエストログがあるか
3. `docker compose logs --tail 80 otel-collector` に受信ログがあるか
4. Jaeger UIでServiceを `hello-telemetry` にしているか

### Metricが見えない

確認順:

1. `/checkout` を何度か実行したか
2. PrometheusのTargetsでCollector scrapeがUPか
3. Queryで `hello_requests_total` を検索しているか
4. CollectorログにMetric exporterのエラーがないか

## クリーンアップ

学習が終わったら、コンテナを停止します。

```powershell
docker compose down
```

ローカルのメトリクスやGrafana状態も初期化したい場合だけ、ボリュームも削除します。

```powershell
docker compose down -v
```

この操作はローカルDocker上の学習用コンテナとボリュームだけを対象にします。クラウドリソースは作成していません。

Docker Desktop自体のアンインストールは通常不要です。PCのリソースを空けたい場合は、Docker Desktopを終了してください。

## コスト注意

このローカルラボ自体にクラウド課金は発生しません。ただし、Dockerイメージのダウンロードでネットワーク通信とディスク容量を使います。公式OpenTelemetry Demoは必要メモリとディスク使用量が大きいため、`official_demo_reference.md` の前提を確認してから実行してください。

## 検証スクリプト

講師またはQA担当は、次のスクリプトで起動確認をまとめて実行できます。

```powershell
.\verify_local_lab.ps1
```

Dockerが使えない環境では、このスクリプトは未実行理由を表示して終了します。

## ライセンス

このリポジトリのサンプルコードとドキュメントはMIT Licenseで公開します。詳細は `LICENSE` を確認してください。

## Section 3-5 hands-on

Section 3、Section 4、Section 5のハンズオンでは、Section 2のローカルラボを拡張して使います。

追加で扱う内容:

- Java/Spring Boot zero-code instrumentation
- Python/FastAPI zero-code instrumentation
- 手動SpanとAttribute
- Metrics、Traces、Context propagation、Logsの確認
- SDK configurationの確認

手順は次を参照してください。

```text
section3_5_hands_on.md
```

Instructor verification evidence for the Section 3-5 hands-on flow is stored in:

```text
verification/2026-06-17-section3-5/
```

## Section 6 Collector hands-on

Section 6 では、同じローカルラボを使って OpenTelemetry Collector の設定を読みます。

扱う内容:

- Collector コンテナの起動とヘルスチェック
- receiver、processor、exporter、extension の役割
- traces と metrics の service pipelines
- memory_limiter、resource、batch processor の読み方
- Jaeger、Prometheus、debug exporter への出し分け

手順は次を参照してください。

```text
section6_collector_hands_on.md
```

Instructor verification evidence for the Section 6 Collector flow is stored in:

```text
verification/2026-06-19-section6/
```
