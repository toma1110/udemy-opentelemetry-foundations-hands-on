# Section 7 Debugging hands-on

この手順では、Section 2 から使っているローカルラボで、Trace がつながる場合と分断される場合、Collector pipeline の確認方法を見ます。

対象講義:

| Lecture ID | 内容 |
| --- | --- |
| `s7-l2` | コンテキスト伝搬の失敗パターン |
| `s7-l3` | Collector pipeline debugging |

## 前提

ローカルラボを起動します。

```powershell
cd local_lab
docker compose up --build -d
docker compose ps
```

ヘルスチェックを確認します。

```powershell
Invoke-RestMethod http://localhost:8000/healthz
```

`status` が `ok` であれば、次へ進みます。

## Trace がつながるケース

`/frontend` は、アプリ内部で `traceparent` を作り、`/backend` へ渡します。

```powershell
Invoke-RestMethod http://localhost:8000/frontend
```

レスポンスで見るポイント:

- `traceparent_sent` に値が入っている
- `backend.received_traceparent` に同じ値が入っている

Jaeger を開きます。

```text
http://localhost:16686
```

Search 画面で次を指定します。

| 項目 | 値 |
| --- | --- |
| Service | `hello-telemetry` |
| Operation | `GET /frontend` |

期待する結果:

- `GET /frontend`
- `frontend.call_backend`
- `backend.handle_request`

上のように複数 Span が同じ Trace に並んでいれば、コンテキストはつながっています。

## Trace が分断されるケース

次に、`/backend` を直接呼びます。

```powershell
Invoke-RestMethod http://localhost:8000/backend
```

レスポンスで見るポイント:

- `received_traceparent` が空になる

Jaeger で次を検索します。

| 項目 | 値 |
| --- | --- |
| Service | `hello-telemetry` |
| Operation | `GET /backend` |

期待する結果:

- `GET /backend` の Span だけが単独で見える
- `frontend.call_backend` と `backend.handle_request` が同じ Trace に並ばない

これは、Backend が壊れているという意味ではありません。上流から `traceparent` が渡されていないため、Backend 側では新しい Trace として見えている状態です。

## Collector 設定を validate する

Collector 設定の構文を確認します。

```powershell
docker compose run --rm --entrypoint /otelcol-contrib otel-collector validate --config=/etc/otelcol-config.yaml
```

終了コードが `0` であれば、設定ファイルは読み込めています。

## debug exporter を見る

Collector が Trace や Metric を受け取っているか、ログで確認します。

```powershell
docker compose logs --tail 120 otel-collector
```

見るポイント:

- `TracesExporter`
- `MetricsExporter`
- `resource spans`
- `data points`
- exporter のエラーが繰り返し出ていないこと

## Collector 内部メトリクスを見る

このラボでは、Collector 自身の内部メトリクスを `8888` で公開し、Prometheus から scrape します。

Prometheus Targets を開きます。

```text
http://localhost:9090/targets
```

期待する target:

- `hello-telemetry`
- `otel-collector-exporter`
- `otel-collector-internal`

`otel-collector-internal` が `UP` であれば、Collector 自身の内部メトリクスを確認できます。

Prometheus の Graph で次を検索します。

```text
otelcol_exporter_sent_spans
otelcol_receiver_accepted_spans
otelcol_processor_dropped_spans
otelcol_exporter_queue_size
```

見るポイント:

- `otelcol_receiver_accepted_spans` が増えていれば、Collector は Trace を受け取っている
- `otelcol_exporter_sent_spans` が増えていれば、Exporter は Trace を送っている
- `otelcol_processor_dropped_spans` が増えていなければ、Processor で落としていない
- `otelcol_exporter_queue_size` が増え続ける場合は、送信先や backpressure を疑う

## 切り分け順

Trace が見えないときは、次の順に確認します。

1. アプリにリクエストが届いているか
2. アプリが `traceparent` を渡しているか
3. Collector が受け取っているか
4. Processor で drop していないか
5. Exporter が送れているか
6. Jaeger や Prometheus の見方が正しいか

左から順に見ると、原因の場所を狭めやすくなります。

## 講師検証証跡

Section 7 の講師検証証跡は次に保存しています。

```text
verification/2026-06-20-section7/
```

主な証跡:

- `10-jaeger-connected-frontend-trace.png`
- `12-jaeger-broken-backend-trace.png`
- `13-prometheus-targets.png`
- `14-prometheus-collector-sent-spans.png`
- `15-collector-config-validate.txt`

