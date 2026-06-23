param(
    [switch]$SkipStart
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$labDir = Join-Path $PSScriptRoot "local_lab"

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-CommandExists -Name "docker")) {
    $defaultDockerBin = "C:\Program Files\Docker\Docker\resources\bin"
    if (Test-Path (Join-Path $defaultDockerBin "docker.exe")) {
        $env:PATH = "$defaultDockerBin;$env:PATH"
    }
}

if (-not (Test-CommandExists -Name "docker")) {
    Write-Host "NOT-RUN: docker command was not found. Install and start Docker Desktop, then rerun this script."
    exit 2
}

function Invoke-JsonWithRetry {
    param(
        [string]$Uri,
        [int]$Attempts = 12,
        [int]$DelaySeconds = 2
    )

    $lastError = $null
    foreach ($attempt in 1..$Attempts) {
        try {
            return Invoke-RestMethod $Uri -TimeoutSec 10
        } catch {
            $lastError = $_
            if ($attempt -lt $Attempts) {
                Start-Sleep -Seconds $DelaySeconds
            }
        }
    }

    throw $lastError
}

function Invoke-PrometheusQueryWithRetry {
    param(
        [string]$Query,
        [int]$MinResults = 1,
        [int]$Attempts = 30,
        [int]$DelaySeconds = 2
    )

    $encodedQuery = [System.Uri]::EscapeDataString($Query)
    $uri = "http://localhost:9090/api/v1/query?query=$encodedQuery"
    $lastMessage = $null

    foreach ($attempt in 1..$Attempts) {
        try {
            $result = Invoke-RestMethod $uri -TimeoutSec 10
            if ($result.status -eq "success" -and $result.data.result.Count -ge $MinResults) {
                return $result
            }

            $lastMessage = "status=$($result.status), result_count=$($result.data.result.Count)"
        } catch {
            $lastMessage = $_.Exception.Message
        }

        if ($attempt -lt $Attempts) {
            Start-Sleep -Seconds $DelaySeconds
        }
    }

    throw "Prometheus query '$Query' did not return at least $MinResults result(s) after $Attempts attempts. Last result: $lastMessage"
}

Push-Location $labDir
try {
    docker --version
    docker compose version

    if (-not $SkipStart) {
        docker compose up --build -d
    }

    docker compose ps

    $health = Invoke-JsonWithRetry -Uri "http://localhost:8000/healthz"
    if ($health.status -ne "ok") {
        throw "healthz returned unexpected status: $($health | ConvertTo-Json -Compress)"
    }

    1..5 | ForEach-Object {
        $response = Invoke-JsonWithRetry -Uri "http://localhost:8000/checkout"
        if ($response.status -ne "accepted") {
            throw "checkout returned unexpected response: $($response | ConvertTo-Json -Compress)"
        }
    }

    $manualSpan = Invoke-JsonWithRetry -Uri "http://localhost:8000/manual-span"
    if ($manualSpan.status -ne "reserved") {
        throw "manual-span returned unexpected response: $($manualSpan | ConvertTo-Json -Compress)"
    }

    $frontend = Invoke-JsonWithRetry -Uri "http://localhost:8000/frontend"
    if ($frontend.status -ne "ok" -or [string]::IsNullOrWhiteSpace($frontend.traceparent_sent)) {
        throw "frontend did not propagate traceparent: $($frontend | ConvertTo-Json -Compress)"
    }

    $pythonAuto = Invoke-JsonWithRetry -Uri "http://localhost:8001/auto/checkout"
    if ($pythonAuto.status -ne "accepted") {
        throw "python zero-code app returned unexpected response: $($pythonAuto | ConvertTo-Json -Compress)"
    }

    $javaHello = Invoke-JsonWithRetry -Uri "http://localhost:8080/hello"
    if ($javaHello.status -ne "ok") {
        throw "java zero-code app returned unexpected response: $($javaHello | ConvertTo-Json -Compress)"
    }

    $javaCheckout = Invoke-JsonWithRetry -Uri "http://localhost:8080/checkout"
    if ($javaCheckout.status -ne "accepted") {
        throw "java checkout returned unexpected response: $($javaCheckout | ConvertTo-Json -Compress)"
    }

    try {
        $null = Invoke-WebRequest http://localhost:8000/error -TimeoutSec 10
        throw "error endpoint did not return an error"
    } catch {
        Write-Host "Expected error endpoint response observed."
    }

    $targets = Invoke-RestMethod http://localhost:9090/api/v1/targets -TimeoutSec 10
    if ($targets.status -ne "success") {
        throw "Prometheus targets API did not return success."
    }

    $query = Invoke-PrometheusQueryWithRetry -Query "hello_requests_total"

    Start-Sleep -Seconds 6

    $jaegerServices = Invoke-RestMethod http://localhost:16686/api/services -TimeoutSec 10
    foreach ($expectedService in @("hello-telemetry", "python-zero-code", "java-zero-code")) {
        if ($jaegerServices.data -notcontains $expectedService) {
            throw "Jaeger service list did not include $expectedService. Services: $($jaegerServices.data -join ', ')"
        }
    }

    foreach ($serviceName in @("hello-telemetry", "python-zero-code", "java-zero-code")) {
        $traceQuery = Invoke-RestMethod "http://localhost:16686/api/traces?service=$serviceName&limit=5" -TimeoutSec 10
        if ($traceQuery.data.Count -lt 1) {
            throw "Jaeger did not return traces for $serviceName."
        }
    }

    docker compose logs --tail 80 hello-telemetry
    docker compose logs --tail 80 python-zero-code
    docker compose logs --tail 80 java-zero-code
    docker compose logs --tail 80 otel-collector

    Write-Host "PASS: local lab verification completed."
} finally {
    Pop-Location
}
