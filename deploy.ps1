# ========================================
# Dataverse Docker Deployment Script
# ========================================
# This script helps you deploy Dataverse containers

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('start', 'stop', 'restart', 'status', 'logs', 'clean', 'validate')]
    [string]$Action = 'start',
    
    [Parameter(Mandatory=$false)]
    [switch]$Pull = $false
)

$ErrorActionPreference = "Stop"

# Colors for output
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Info { Write-Host $args -ForegroundColor Cyan }
function Write-Warning { Write-Host $args -ForegroundColor Yellow }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }

Write-Info "╔══════════════════════════════════════════════════════════╗"
Write-Info "║                                                          ║"
Write-Info "║          Dataverse Container Deployment Script          ║"
Write-Info "║                                                          ║"
Write-Info "╚══════════════════════════════════════════════════════════╝"
Write-Host ""

# Check if Docker is running
Write-Info "Checking Docker status..."
try {
    docker info | Out-Null
    Write-Success "✓ Docker is running"
} catch {
    Write-Error-Custom "✗ Docker is not running!"
    Write-Host "  Please start Docker Desktop and try again."
    exit 1
}

# Check if docker-compose.yml exists
if (-not (Test-Path "docker-compose.yml")) {
    Write-Error-Custom "✗ docker-compose.yml not found!"
    Write-Host "  Please run this script from the project directory."
    exit 1
}

# Validate configuration
function Validate-Config {
    Write-Info "Validating Docker Compose configuration..."
    $result = docker compose config --quiet 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Configuration is valid"
        return $true
    } else {
        Write-Error-Custom "✗ Configuration validation failed:"
        Write-Host $result
        return $false
    }
}

# Start services
function Start-Services {
    Write-Info "Starting Dataverse services..."
    
    if ($Pull) {
        Write-Info "Pulling latest images..."
        docker compose pull
    }
    
    Write-Info "Starting containers..."
    docker compose up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Services started successfully"
        Write-Host ""
        Write-Info "Monitoring bootstrap process..."
        Write-Host "(Press Ctrl+C to stop viewing logs when bootstrap completes)"
        Write-Host ""
        Start-Sleep -Seconds 3
        docker compose logs -f bootstrap
        
        Write-Host ""
        Write-Success "╔══════════════════════════════════════════════════════════╗"
        Write-Success "║                                                          ║"
        Write-Success "║              Dataverse is starting up!                   ║"
        Write-Success "║                                                          ║"
        Write-Success "║  Access your instance at: http://localhost:8080          ║"
        Write-Success "║                                                          ║"
        Write-Success "║  Login credentials:                                      ║"
        Write-Success "║    Username: dataverseAdmin                              ║"
        Write-Success "║    Password: admin1                                      ║"
        Write-Success "║                                                          ║"
        Write-Success "║  Other services:                                         ║"
        Write-Success "║    MailDev UI: http://localhost:1080                     ║"
        Write-Success "║    Solr Admin: http://localhost:8983                     ║"
        Write-Success "║    Payara Admin: http://localhost:4949                   ║"
        Write-Success "║                                                          ║"
        Write-Success "╚══════════════════════════════════════════════════════════╝"
    } else {
        Write-Error-Custom "✗ Failed to start services"
        exit 1
    }
}

# Stop services
function Stop-Services {
    Write-Info "Stopping Dataverse services..."
    docker compose stop
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Services stopped successfully"
    } else {
        Write-Error-Custom "✗ Failed to stop services"
        exit 1
    }
}

# Restart services
function Restart-Services {
    Write-Info "Restarting Dataverse services..."
    docker compose restart
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "✓ Services restarted successfully"
    } else {
        Write-Error-Custom "✗ Failed to restart services"
        exit 1
    }
}

# Show status
function Show-Status {
    Write-Info "Service Status:"
    Write-Host ""
    docker compose ps
    Write-Host ""
    
    Write-Info "Resource Usage:"
    Write-Host ""
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" (docker compose ps -q)
}

# Show logs
function Show-Logs {
    Write-Info "Showing logs (Press Ctrl+C to stop)..."
    docker compose logs -f
}

# Clean everything
function Clean-All {
    Write-Warning "⚠️  WARNING: This will delete all data including databases and uploaded files!"
    $confirm = Read-Host "Are you sure you want to continue? (yes/no)"
    
    if ($confirm -eq "yes") {
        Write-Info "Stopping and removing all containers, networks, and volumes..."
        docker compose down -v
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "✓ Cleanup completed successfully"
        } else {
            Write-Error-Custom "✗ Cleanup failed"
            exit 1
        }
    } else {
        Write-Info "Cleanup cancelled"
    }
}

# Execute action
switch ($Action) {
    'start' {
        if (Validate-Config) {
            Start-Services
        }
    }
    'stop' {
        Stop-Services
    }
    'restart' {
        Restart-Services
    }
    'status' {
        Show-Status
    }
    'logs' {
        Show-Logs
    }
    'clean' {
        Clean-All
    }
    'validate' {
        Validate-Config
    }
    default {
        Write-Error-Custom "Unknown action: $Action"
        Write-Host ""
        Write-Host "Usage: .\deploy.ps1 [-Action <action>] [-Pull]"
        Write-Host ""
        Write-Host "Actions:"
        Write-Host "  start     - Start all services (default)"
        Write-Host "  stop      - Stop all services"
        Write-Host "  restart   - Restart all services"
        Write-Host "  status    - Show service status"
        Write-Host "  logs      - Show service logs"
        Write-Host "  clean     - Remove all containers and data"
        Write-Host "  validate  - Validate configuration"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -Pull     - Pull latest images before starting"
        Write-Host ""
        Write-Host "Examples:"
        Write-Host "  .\deploy.ps1 -Action start -Pull"
        Write-Host "  .\deploy.ps1 -Action status"
        Write-Host "  .\deploy.ps1 -Action logs"
        exit 1
    }
}
