# 公式OpenTelemetry Demo参照手順

この手順は、`s2-l4` の「公式OpenTelemetry Demoを見る」で使う参照教材です。小さなローカルラボで基本を確認した後に、本番に近い複数サービス構成を観察する目的で使います。

## 公式情報

- OpenTelemetry Demo Docker deployment: https://opentelemetry.io/docs/demo/docker-deployment/
- OpenTelemetry Demo architecture: https://opentelemetry.io/docs/demo/architecture/
- OpenTelemetry Demo repository: https://github.com/open-telemetry/opentelemetry-demo

2026-06-15確認時点の公式Docker deploymentでは、Docker、Docker Compose v2、任意でMake、通常構成で約6ギガバイトのメモリ、約14ギガバイトのディスク容量が前提です。minimal modeではメモリ目安が約3ギガバイトになります。

## この講座での位置づけ

公式Demoは、標準ハンズオンの主教材ではありません。

- 小さなアプリ: まずTrace、Metric、Log、Collectorの流れを理解する
- 公式Demo: 複数サービスへ広げたときの見方を確認する

最初から公式Demoの全サービスを追うと、学習対象が広がりすぎます。Section 2では、起動、入口画面、Jaeger、Grafana、Load Generator UIの位置づけを確認するだけに留めます。

## 取得

作業用ディレクトリで公式リポジトリをcloneします。

```powershell
git clone https://github.com/open-telemetry/opentelemetry-demo.git
cd opentelemetry-demo
```

## 起動

通常構成:

```powershell
docker compose up --force-recreate --remove-orphans --detach
```

メモリが少ない場合はminimal modeを使います。

```powershell
docker compose -f docker-compose.minimal.yml up --force-recreate --remove-orphans --detach
```

## 見る画面

公式Docker deploymentで案内されている主な入口です。

| 画面 | URL | 見ること |
| --- | --- | --- |
| Web store | http://localhost:8080/ | 複数サービスで構成されたデモアプリ |
| Grafana | http://localhost:8080/grafana/ | メトリクスとダッシュボード |
| Load Generator UI | http://localhost:8080/loadgen/ | トラフィック生成の状態 |
| Jaeger UI | http://localhost:8080/jaeger/ui/ | サービスをまたぐTrace |

## 観察ポイント

1. Web storeを開き、どのようなアプリか確認する
2. Load Generator UIでトラフィックが発生していることを確認する
3. Jaeger UIでサービスをまたぐTraceを見る
4. Grafanaでサービス別の状態を見る
5. すべてのサービスを追わず、まず「入口、Collector、Backend、Dashboard」の対応だけを見る

## よくある注意

- 公式Demoは多くのコンテナを起動します。
- ポート8080が使われている場合は、公式手順に従って `ENVOY_PORT` を変更します。
- イメージ取得に時間がかかる場合があります。
- 会社ネットワークやプロキシ環境では、コンテナイメージ取得に失敗することがあります。

## 停止

通常構成:

```powershell
docker compose down
```

minimal mode:

```powershell
docker compose -f docker-compose.minimal.yml down
```

この講座では公式Demoを改変しません。詳しいCollector設定やサービス別実装は、後続セクションで必要な範囲に分けて扱います。
