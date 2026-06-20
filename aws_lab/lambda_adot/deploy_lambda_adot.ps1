param(
    [string]$Region = "ap-northeast-1",
    [string]$Prefix = "otel-c008-lambda-adot",
    [string]$LayerVersionArn = "arn:aws:lambda:ap-northeast-1:615299751070:layer:AWSOpenTelemetryDistroPython:25"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildDir = Join-Path $root ".aws-build"
$functionName = $Prefix
$roleName = "$Prefix-role"
$zipPath = Join-Path $buildDir "function.zip"
$trustPath = Join-Path $buildDir "lambda-trust-policy.json"
$payloadPath = Join-Path $buildDir "payload.json"
$responsePath = Join-Path $buildDir "response.json"

New-Item -ItemType Directory -Force -Path $buildDir | Out-Null

function Test-AwsCommand {
    param([scriptblock]$Command)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        & $Command 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $previousPreference
    }
}

@'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@ | Set-Content -Encoding ascii -Path $trustPath

@'
{"source":"udemy-opentelemetry-foundations-hands-on","lecture":"s9-l4"}
'@ | Set-Content -Encoding ascii -Path $payloadPath

if (-not (Test-AwsCommand { aws iam get-role --role-name $roleName --query "Role.Arn" --output text })) {
    aws iam create-role --role-name $roleName --assume-role-policy-document "file://$trustPath" | Out-Null
}

aws iam attach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
aws iam attach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"

$roleArn = aws iam get-role --role-name $roleName --query "Role.Arn" --output text
Start-Sleep -Seconds 12

if (Test-Path $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}
Compress-Archive -Path (Join-Path $root "app.py") -DestinationPath $zipPath -Force

if (Test-AwsCommand { aws lambda get-function --region $Region --function-name $functionName --query "Configuration.FunctionName" --output text }) {
    aws lambda update-function-code --region $Region --function-name $functionName --zip-file "fileb://$zipPath" | Out-Null
    aws lambda update-function-configuration `
        --region $Region `
        --function-name $functionName `
        --runtime python3.12 `
        --handler app.lambda_handler `
        --role $roleArn `
        --timeout 10 `
        --memory-size 256 `
        --layers $LayerVersionArn `
        --tracing-config Mode=Active `
        --environment "Variables={AWS_LAMBDA_EXEC_WRAPPER=/opt/otel-instrument,OTEL_SERVICE_NAME=$functionName}" | Out-Null
} else {
    aws lambda create-function `
        --region $Region `
        --function-name $functionName `
        --runtime python3.12 `
        --handler app.lambda_handler `
        --role $roleArn `
        --timeout 10 `
        --memory-size 256 `
        --zip-file "fileb://$zipPath" `
        --layers $LayerVersionArn `
        --tracing-config Mode=Active `
        --environment "Variables={AWS_LAMBDA_EXEC_WRAPPER=/opt/otel-instrument,OTEL_SERVICE_NAME=$functionName}" | Out-Null
}

aws lambda wait function-active --region $Region --function-name $functionName

1..3 | ForEach-Object {
    aws lambda invoke --region $Region --function-name $functionName --payload "fileb://$payloadPath" $responsePath | Out-Null
    Start-Sleep -Seconds 2
}

$config = aws lambda get-function-configuration `
    --region $Region `
    --function-name $functionName `
    --query "{FunctionName:FunctionName,Runtime:Runtime,Handler:Handler,Layers:Layers[].Arn,TracingConfig:TracingConfig,Environment:Environment.Variables,LastModified:LastModified}" `
    --output json

$logGroupName = "/aws/lambda/$functionName"
$logs = aws logs describe-log-streams `
    --region $Region `
    --log-group-name $logGroupName `
    --order-by LastEventTime `
    --descending `
    --max-items 1 `
    --query "logStreams[0].logStreamName" `
    --output text

Write-Host "Lambda function configuration:"
Write-Host $config
Write-Host "Latest Lambda log stream:"
Write-Host $logs
Write-Host "Lambda invoke response file:"
Write-Host $responsePath
