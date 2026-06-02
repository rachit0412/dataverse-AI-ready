<#
.SYNOPSIS
Starts Dataverse containers and waits for the application to be fully ready.

.DESCRIPTION
Enterprise startup script that:
1. Validates prerequisites (Docker, compose file, ports)
2. Builds the solr-init image (ensures Solr collection1 with Dataverse schema)
3. Starts all containers with dependency ordering
4. Polls the Dataverse API until the WAR deployment completes
5. Verifies Solr collection health
6. Opens the browser when ready

.PARAMETER NoBrowser
Skip opening the browser after Dataverse is ready.

.PARAMETER Timeout
Maximum seconds to wait for Dataverse to become ready. Default: 420 (7 minutes).

.PARAMETER Build
Force rebuild of custom images (solr-init). Default: $false.

.EXAMPLE
.\start.ps1
Starts containers, waits for readiness, opens browser.

.EXAMPLE
.\start.ps1 -NoBrowser -Timeout 600 -Build
Rebuilds images, starts containers, waits up to 10 minutes.
#>

[CmdletBinding()]
param(
    [switch]$NoBrowser,
    [int]$Timeout = 420,
    [switch]$Build
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ComposeDir = Join-Path $PSScriptRoot "..\configs"
$ComposeFile = Join-Path $ComposeDir "compose.yml"
$DataverseUrl = "http://localhost:${env:DATAVERSE_PORT:-8080}"
if ($DataverseUrl -match ':-') { $DataverseUrl = "http://localhost:8080" }
$ApiVersionUrl = "$DataverseUrl/api/info/version"

# --- Validate prerequisites ---
Write-Host "`n=== Dataverse Enterprise Startup ===" -ForegroundColor Cyan

if (-not (Test-Path $ComposeFile)) {
    Write-Error "compose.yml not found at $ComposeFile"
    exit 1
}

try {
    docker version | Out-Null
} catch {
    Write-Error "Docker is not running. Please start Docker Desktop first."
    exit 1
}

# Check if port 8080 is available (unless containers already running)
$existingContainer = docker ps --filter "name=dataverse" --format "{{.Names}}" 2>$null
if (-not $existingContainer) {
    $portCheck = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue
    if ($portCheck) {
        Write-Warning "Port 8080 is already in use. Set DATAVERSE_PORT in .env to use a different port."
    }
}

# --- Build solr-init if needed ---
Write-Host "`n[1/4] Building solr-init image..." -ForegroundColor Yellow
Push-Location $ComposeDir
try {
    $buildArgs = @("compose", "build", "solr-init")
    if ($Build) { $buildArgs += "--no-cache" }
    
    & docker @buildArgs 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build solr-init image"
        exit 1
    }
    Write-Host "  solr-init image ready." -ForegroundColor Green
} catch {
    Write-Error "Failed to build images: $_"
    exit 1
}

# --- Start containers ---
Write-Host "`n[2/4] Starting containers..." -ForegroundColor Yellow
try {
    docker compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Error "docker compose up failed with exit code $LASTEXITCODE"
        exit 1
    }
} finally {
    Pop-Location
}

# --- Wait for solr-init to complete ---
Write-Host "`n[3/4] Waiting for Solr initialization..." -ForegroundColor Yellow
$solrInitElapsed = 0
while ($solrInitElapsed -lt 120) {
    $solrInitStatus = docker inspect solr-init --format "{{.State.Status}}" 2>$null
    if ($solrInitStatus -eq "exited") {
        $exitCode = docker inspect solr-init --format "{{.State.ExitCode}}" 2>$null
        if ($exitCode -eq "0") {
            Write-Host "  Solr collection1 initialized successfully." -ForegroundColor Green
            break
        } else {
            Write-Host "  WARNING: solr-init exited with code $exitCode. Checking logs..." -ForegroundColor Red
            docker logs solr-init --tail 10 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
            break
        }
    }
    Start-Sleep -Seconds 5
    $solrInitElapsed += 5
}

# --- Wait for Dataverse API to be ready ---
Write-Host "`n[4/4] Waiting for Dataverse WAR deployment..." -ForegroundColor Yellow

$elapsed = 0
$interval = 10
$ready = $false

while ($elapsed -lt $Timeout) {
    try {
        $response = Invoke-WebRequest -Uri $ApiVersionUrl -UseBasicParsing -TimeoutSec 5 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $version = ($response.Content | ConvertFrom-Json).data.version
            $ready = $true
            break
        }
    } catch {
        # Not ready yet
    }

    $remaining = $Timeout - $elapsed
    Write-Host "  Waiting... ($elapsed`s elapsed, ${remaining}s remaining)" -ForegroundColor DarkGray
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

if (-not $ready) {
    Write-Host "`n[FAIL] Dataverse did not become ready within $Timeout seconds." -ForegroundColor Red
    Write-Host "  Run: docker compose -f configs/compose.yml logs dataverse" -ForegroundColor Yellow
    exit 1
}

# --- Verify Solr health ---
$solrOk = $false
try {
    $solrPing = docker exec solr curl -sf "http://localhost:8983/solr/collection1/admin/ping" 2>$null
    if ($solrPing -match '"status":"OK"') { $solrOk = $true }
} catch {}

# --- Success ---
Write-Host "`n=== Dataverse is ready ===" -ForegroundColor Green
Write-Host "  Version:  v$version (started in ~$elapsed`s)" -ForegroundColor Cyan
Write-Host "  URL:      $DataverseUrl" -ForegroundColor Cyan
Write-Host "  Login:    dataverseAdmin / admin1" -ForegroundColor Cyan
Write-Host "  Solr:     $(if ($solrOk) { 'collection1 healthy' } else { 'check status' })" -ForegroundColor Cyan
Write-Host "  Mail UI:  http://localhost:8025" -ForegroundColor Cyan

if (-not $NoBrowser) {
    Start-Process $DataverseUrl
}
