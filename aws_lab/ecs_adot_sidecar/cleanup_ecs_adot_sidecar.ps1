param(
    [string]$Region = "ap-northeast-1",
    [string]$Prefix = "otel-c008-ecs-adot"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$clusterName = $Prefix
$executionRoleName = "$Prefix-execution-role"
$taskRoleName = "$Prefix-task-role"
$securityGroupName = "$Prefix-sg"
$logGroupApp = "/aws/ecs/$Prefix/app"
$logGroupCollector = "/aws/ecs/$Prefix/collector"

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

$taskDefinitionArns = aws ecs list-task-definitions --region $Region --family-prefix $Prefix --status ACTIVE --query "taskDefinitionArns[]" --output text
if (-not [string]::IsNullOrWhiteSpace($taskDefinitionArns)) {
    foreach ($taskDefinitionArn in ($taskDefinitionArns -split "\s+")) {
        if (-not [string]::IsNullOrWhiteSpace($taskDefinitionArn)) {
            aws ecs deregister-task-definition --region $Region --task-definition $taskDefinitionArn | Out-Null
        }
    }
}

$existingCluster = aws ecs describe-clusters --region $Region --clusters $clusterName --query "clusters[?status=='ACTIVE'].clusterName" --output text
if (-not [string]::IsNullOrWhiteSpace($existingCluster)) {
    aws ecs delete-cluster --region $Region --cluster $clusterName | Out-Null
}

$securityGroupId = aws ec2 describe-security-groups `
    --region $Region `
    --filters Name=group-name,Values=$securityGroupName `
    --query "SecurityGroups[0].GroupId" `
    --output text 2>$null
if (-not [string]::IsNullOrWhiteSpace($securityGroupId) -and $securityGroupId -ne "None") {
    aws ec2 delete-security-group --region $Region --group-id $securityGroupId
}

foreach ($logGroupName in @($logGroupApp, $logGroupCollector)) {
    if (aws logs describe-log-groups --region $Region --log-group-name-prefix $logGroupName --query "logGroups[?logGroupName=='$logGroupName'].logGroupName" --output text) {
        aws logs delete-log-group --region $Region --log-group-name $logGroupName
    }
}

if (Test-AwsCommand { aws iam get-role --role-name $executionRoleName --query "Role.RoleName" --output text }) {
    aws iam detach-role-policy --role-name $executionRoleName --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" 2>$null
    aws iam delete-role --role-name $executionRoleName
}

if (Test-AwsCommand { aws iam get-role --role-name $taskRoleName --query "Role.RoleName" --output text }) {
    aws iam detach-role-policy --role-name $taskRoleName --policy-arn "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess" 2>$null
    aws iam delete-role --role-name $taskRoleName
}

Write-Host "Cleanup completed for $Prefix in $Region."
