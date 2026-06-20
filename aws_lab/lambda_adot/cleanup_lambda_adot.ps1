param(
    [string]$Region = "ap-northeast-1",
    [string]$Prefix = "otel-c008-lambda-adot"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

$functionName = $Prefix
$roleName = "$Prefix-role"
$logGroupName = "/aws/lambda/$functionName"

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

if (Test-AwsCommand { aws lambda get-function --region $Region --function-name $functionName --query "Configuration.FunctionName" --output text }) {
    aws lambda delete-function --region $Region --function-name $functionName
}

if (aws logs describe-log-groups --region $Region --log-group-name-prefix $logGroupName --query "logGroups[?logGroupName=='$logGroupName'].logGroupName" --output text) {
    aws logs delete-log-group --region $Region --log-group-name $logGroupName
}

if (Test-AwsCommand { aws iam get-role --role-name $roleName --query "Role.RoleName" --output text }) {
    aws iam detach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" 2>$null
    aws iam detach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess" 2>$null
    aws iam delete-role --role-name $roleName
}

Write-Host "Cleanup completed for $Prefix in $Region."
