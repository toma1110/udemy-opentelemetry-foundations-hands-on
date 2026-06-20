param(
    [string]$Region = "ap-northeast-1",
    [string]$Prefix = "otel-c008-ecs-adot"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$buildDir = Join-Path $root ".aws-build"
$trustPath = Join-Path $buildDir "ecs-task-trust-policy.json"
$taskDefPath = Join-Path $buildDir "task-definition.json"
$clusterName = $Prefix
$executionRoleName = "$Prefix-execution-role"
$taskRoleName = "$Prefix-task-role"
$securityGroupName = "$Prefix-sg"
$logGroupApp = "/aws/ecs/$Prefix/app"
$logGroupCollector = "/aws/ecs/$Prefix/collector"
$collectorConfig = @"
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
processors:
  batch:
exporters:
  awsxray:
    region: $Region
  debug:
    verbosity: normal
service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [awsxray, debug]
"@

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
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@ | Set-Content -Encoding ascii -Path $trustPath

foreach ($roleName in @($executionRoleName, $taskRoleName)) {
    if (-not (Test-AwsCommand { aws iam get-role --role-name $roleName --query "Role.Arn" --output text })) {
        aws iam create-role --role-name $roleName --assume-role-policy-document "file://$trustPath" | Out-Null
    }
}

aws iam attach-role-policy --role-name $executionRoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
aws iam attach-role-policy --role-name $taskRoleName --policy-arn "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"

$executionRoleArn = aws iam get-role --role-name $executionRoleName --query "Role.Arn" --output text
$taskRoleArn = aws iam get-role --role-name $taskRoleName --query "Role.Arn" --output text

$existingAppLogGroup = aws logs describe-log-groups --region $Region --log-group-name-prefix $logGroupApp --query "logGroups[?logGroupName=='$logGroupApp'].logGroupName" --output text
if ([string]::IsNullOrWhiteSpace($existingAppLogGroup)) {
    aws logs create-log-group --region $Region --log-group-name $logGroupApp
}
$existingCollectorLogGroup = aws logs describe-log-groups --region $Region --log-group-name-prefix $logGroupCollector --query "logGroups[?logGroupName=='$logGroupCollector'].logGroupName" --output text
if ([string]::IsNullOrWhiteSpace($existingCollectorLogGroup)) {
    aws logs create-log-group --region $Region --log-group-name $logGroupCollector
}
aws logs put-retention-policy --region $Region --log-group-name $logGroupApp --retention-in-days 1
aws logs put-retention-policy --region $Region --log-group-name $logGroupCollector --retention-in-days 1

$existingCluster = aws ecs describe-clusters --region $Region --clusters $clusterName --query "clusters[?status=='ACTIVE'].clusterName" --output text
if ([string]::IsNullOrWhiteSpace($existingCluster)) {
    aws ecs create-cluster --region $Region --cluster-name $clusterName | Out-Null
}

$vpcId = aws ec2 describe-vpcs --region $Region --filters Name=is-default,Values=true --query "Vpcs[0].VpcId" --output text
if ([string]::IsNullOrWhiteSpace($vpcId) -or $vpcId -eq "None") {
    throw "Default VPC was not found in $Region."
}

$securityGroupId = aws ec2 describe-security-groups `
    --region $Region `
    --filters Name=group-name,Values=$securityGroupName Name=vpc-id,Values=$vpcId `
    --query "SecurityGroups[0].GroupId" `
    --output text 2>$null

if ([string]::IsNullOrWhiteSpace($securityGroupId) -or $securityGroupId -eq "None") {
    $securityGroupId = aws ec2 create-security-group `
        --region $Region `
        --group-name $securityGroupName `
        --description "OpenTelemetry lab ECS sidecar security group" `
        --vpc-id $vpcId `
        --query "GroupId" `
        --output text
}

$subnets = aws ec2 describe-subnets `
    --region $Region `
    --filters Name=default-for-az,Values=true `
    --query "Subnets[0:2].SubnetId" `
    --output text

if ([string]::IsNullOrWhiteSpace($subnets) -or $subnets -eq "None") {
    throw "Default public subnets were not found in $Region."
}

$taskDefinition = @{
    family = $Prefix
    networkMode = "awsvpc"
    requiresCompatibilities = @("FARGATE")
    cpu = "512"
    memory = "1024"
    executionRoleArn = $executionRoleArn
    taskRoleArn = $taskRoleArn
    containerDefinitions = @(
        @{
            name = "aws-otel-collector"
            image = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
            essential = $false
            command = @("--config=env:OTEL_CONFIG")
            environment = @(
                @{
                    name = "OTEL_CONFIG"
                    value = $collectorConfig
                }
            )
            logConfiguration = @{
                logDriver = "awslogs"
                options = @{
                    "awslogs-group" = $logGroupCollector
                    "awslogs-region" = $Region
                    "awslogs-stream-prefix" = "collector"
                }
            }
        },
        @{
            name = "application"
            image = "ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:latest"
            essential = $true
            command = @("traces", "--otlp-endpoint", "localhost:4317", "--otlp-insecure", "--duration", "20s", "--rate", "1")
            dependsOn = @(
                @{
                    containerName = "aws-otel-collector"
                    condition = "START"
                }
            )
            logConfiguration = @{
                logDriver = "awslogs"
                options = @{
                    "awslogs-group" = $logGroupApp
                    "awslogs-region" = $Region
                    "awslogs-stream-prefix" = "app"
                }
            }
        }
    )
}

$taskDefinition | ConvertTo-Json -Depth 20 | Set-Content -Encoding ascii -Path $taskDefPath
$taskDefArn = aws ecs register-task-definition --region $Region --cli-input-json "file://$taskDefPath" --query "taskDefinition.taskDefinitionArn" --output text

$subnetList = (($subnets -split "\s+") | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }) -join ","
$networkConfig = "awsvpcConfiguration={subnets=[$subnetList],securityGroups=[$securityGroupId],assignPublicIp=ENABLED}"
$taskArn = aws ecs run-task `
    --region $Region `
    --cluster $clusterName `
    --launch-type FARGATE `
    --task-definition $taskDefArn `
    --network-configuration $networkConfig `
    --query "tasks[0].taskArn" `
    --output text

if ([string]::IsNullOrWhiteSpace($taskArn) -or $taskArn -eq "None") {
    throw "Fargate task did not start."
}

aws ecs wait tasks-stopped --region $Region --cluster $clusterName --tasks $taskArn

$task = aws ecs describe-tasks `
    --region $Region `
    --cluster $clusterName `
    --tasks $taskArn `
    --query "tasks[0].{lastStatus:lastStatus,stopCode:stopCode,stoppedReason:stoppedReason,containers:containers[].{name:name,lastStatus:lastStatus,exitCode:exitCode,reason:reason}}" `
    --output json

Write-Host "Task definition ARN:"
Write-Host $taskDefArn
Write-Host "Task ARN:"
Write-Host $taskArn
Write-Host "Task result:"
Write-Host $task
Write-Host "App log group:"
Write-Host $logGroupApp
Write-Host "Collector log group:"
Write-Host $logGroupCollector
