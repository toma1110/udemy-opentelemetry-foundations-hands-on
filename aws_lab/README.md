# AWS Integration Lab

このディレクトリは、Section 9 の AWS 連携ハンズオン用です。

## 対象

- `s9-l4`: Lambda + ADOT Layer
- `s9-l5`: ECS/Fargate + ADOT Collector sidecar

## 前提

- AWS CLI v2 がインストール済み
- `aws configure` で検証用アカウントとリージョンを設定済み
- この手順では `ap-northeast-1` を標準リージョンとして使います
- 実行後は必ず cleanup スクリプトを実行してください

## コスト注意

この手順は短時間の Lambda、CloudWatch Logs、X-Ray、ECS/Fargate タスクを使います。学習後に cleanup を実行すれば大きな課金にはなりにくい構成ですが、CloudWatch Logs と Fargate 実行時間には課金が発生し得ます。

## 実行順

```powershell
cd aws_lab

.\lambda_adot\deploy_lambda_adot.ps1
.\lambda_adot\cleanup_lambda_adot.ps1

.\ecs_adot_sidecar\deploy_ecs_adot_sidecar.ps1
.\ecs_adot_sidecar\cleanup_ecs_adot_sidecar.ps1
```

## 確認ポイント

- Lambda 関数に ADOT Layer が設定されている
- Lambda 関数を Invoke できる
- CloudWatch Logs に Lambda 実行ログが出る
- ECS タスク定義にアプリコンテナと ADOT Collector sidecar が含まれる
- Fargate タスクが起動し、アプリコンテナログと Collector ログが確認できる
- cleanup 後に Lambda、ECS cluster、task definition、IAM role、security group、log group が残っていない

