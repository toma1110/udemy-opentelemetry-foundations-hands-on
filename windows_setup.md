# Windows環境準備

この手順では、Windows 11上でこのコースのローカルハンズオンを動かすために、Docker DesktopとWSL 2を準備します。

このコースのSection 2からSection 7のローカルラボは、AWSアカウントを使いません。クラウドリソースは作成しません。

## 対象

- Windows 11を使っている受講者
- PowerShellでコマンドを実行できる受講者
- Docker Desktopを使って、ローカルでコンテナを起動したい受講者

## 準備するもの

- Windows 11
- 管理者権限を使えるWindowsユーザー
- Docker Desktop
- WSL 2
- PowerShell
- ブラウザ
- 8GB以上のメモリを推奨
- 数GB以上の空きディスク容量

Docker DesktopのWindows要件とWSL 2 backendの説明は、Docker公式ドキュメントを確認してください。

- Docker Desktop for Windows install: https://docs.docker.com/desktop/setup/install/windows-install/
- Docker Desktop WSL 2 backend: https://docs.docker.com/desktop/features/wsl/
- Microsoft WSL containers guide: https://learn.microsoft.com/windows/wsl/tutorials/wsl-containers

## 1. WSLの状態を確認する

PowerShellを開き、次を実行します。

```powershell
wsl --status
wsl --version
```

`wsl --version` が使えない環境でも、次のコマンドでWSLディストリビューションの状態を確認できます。

```powershell
wsl -l -v
```

`VERSION` が `2` になっているディストリビューションがあれば、WSL 2を使えます。

WSLが未導入の場合は、PowerShellを管理者として開き、次を実行します。

```powershell
wsl --install
```

インストール後、Windowsの再起動を求められた場合は再起動してください。

## 2. Docker Desktopをインストールする

Docker Desktop for Windowsを公式サイトからインストールします。

```text
https://docs.docker.com/desktop/setup/install/windows-install/
```

インストール時にWSL 2 backendを使う選択肢が表示された場合は、有効にします。

インストール後、WindowsのスタートメニューからDocker Desktopを起動します。初回起動後、Docker Desktopが起動完了するまで待ちます。

## 3. Docker Desktopの設定を確認する

Docker Desktopを開き、次を確認します。

- Settings > Generalで、WSL 2 based engineを使う設定になっている
- Linux containers modeになっている
- Docker DesktopがRunning状態になっている

Docker DesktopがWSL 2をサポートする環境では、WSL 2 backendが既定で有効になっている場合があります。その場合、設定項目が表示されないことがあります。

## 4. PowerShellを開き直す

Docker Desktopをインストールまたは起動した後は、PowerShellを一度閉じて開き直します。

次を実行します。

```powershell
docker --version
docker compose version
```

期待する状態:

- `docker --version` がDockerのバージョンを表示する
- `docker compose version` がDocker Compose v2のバージョンを表示する

ここで失敗する場合は、Docker Desktopが起動しているか、PowerShellを開き直したかを確認します。

## 5. このコースのラボを起動する

公開リポジトリを取得した後、リポジトリ直下で次を実行します。

```powershell
cd local_lab
docker compose up --build -d
docker compose ps
```

起動後、ブラウザまたはPowerShellで確認します。

```powershell
Invoke-RestMethod http://localhost:8000/healthz
```

期待する状態:

- `hello-telemetry` が起動している
- `otel-collector` が起動している
- `jaeger` が起動している
- `prometheus` が起動している
- `grafana` が起動している
- `http://localhost:8000/healthz` が応答する

## 6. よくあるつまずき

### dockerコマンドが見つからない

確認します。

```powershell
docker --version
```

対処:

- Docker Desktopを起動する
- Docker DesktopがRunningになるまで待つ
- PowerShellを閉じて開き直す
- Windowsを再起動する

### Docker Desktopが起動しない

確認します。

```powershell
wsl --status
wsl -l -v
```

対処:

- WSL 2が有効か確認する
- Windowsの仮想化機能が有効か確認する
- Docker Desktopのインストーラーを再実行する
- 会社PCの場合は、管理者権限やセキュリティポリシーで制限されていないか確認する

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

他のアプリが同じポートを使っている場合は、そのアプリを停止してからラボを起動します。

## 7. ラボの停止

学習を終えたら、ラボのコンテナを停止します。

```powershell
docker compose down
```

通常はこれだけで十分です。Docker Desktop自体をアンインストールする必要はありません。

GrafanaやPrometheusのローカル状態も初期化したい場合だけ、ボリュームも削除します。

```powershell
docker compose down -v
```

`-v` を付けると、このラボ用のDockerボリュームが削除されます。学習用データを残したい場合は付けないでください。

## 8. Docker Desktopを終了したい場合

PCのリソースを空けたい場合は、Docker Desktopの画面またはタスクトレイからDocker Desktopを終了します。

Docker Desktopを削除する必要はありません。次回学習するときは、Docker Desktopを起動してから `docker compose up --build -d` を実行します。

## 9. この手順で扱わないこと

- Docker Desktopのアンインストール
- WSLディストリビューションの削除
- Windows機能の無効化
- AWSリソースの作成や削除
- Google Cloud、Azureなど外部クラウドの操作

このコースのローカルラボでは、クラウド課金は発生しません。ただし、Dockerイメージのダウンロードでネットワーク通信とディスク容量を使います。
