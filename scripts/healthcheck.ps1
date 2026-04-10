<#
.SYNOPSIS
Performs health checks on Dataverse deployment.

.DESCRIPTION
Checks the health of all Dataverse containers, services, and resources.
Useful for monitoring, troubleshooting, and automated health checks.

.PARAMETER Detailed
Show detailed health information including logs and metrics.

.PARAMETER Json
Output results in JSON format for automated processing.

.EXAMPLE
.\healthcheck.ps1
Runs standard health checks.

.EXAMPLE
.\healthcheck.ps1 -Detailed
Runs detailed health checks with additional diagnostics.

.EXAMPLE
.\healthcheck.ps1 -Json
Outputs health status in JSON format.

.NOTES
Returns exit code 0 if all healthy, 1 if any issues detected.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$Detailed,
    
    [Parameter()]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Constants
$ComposeFile = "configs\compose.yml"

# Health check results
$healthResults = @{
    timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    overall_status = "healthy"
    checks = @{}
}

# Functions
function Write-HealthLog {
    param([string]$Message, [string]$Status = "INFO")
    
    if (-not $Json) {
        $icon = switch ($Status) {
            "OK" { "✅" }
            "WARNING" { "⚠️ " }
            "ERROR" { "❌" }
            default { "ℹ️ " }
        }
        Write-Output "$icon $Message"
    }
}

function Test-DockerAvailable {
    $checkName = "docker_available"
    
    try {
        docker version | Out-Null
        $healthResults.checks[$checkName] = @{
            status = "healthy"
            message = "Docker is available"
        }
        Write-HealthLog "Docker is available" "OK"
        return $true
    } catch {
        $healthResults.checks[$checkName] = @{
            status = "unhealthy"
            message = "Docker is not available or not running"
            error = $_.Exception.Message
        }
        $healthResults.overall_status = "unhealthy"
        Write-HealthLog "Docker is not available or not running" "ERROR"
        return $false
    }
}

function Test-ContainersRunning {
    $checkName = "containers_running"
    
    try {
        $containers = docker compose -f $ComposeFile ps --format json 2>$null | ConvertFrom-Json
        
        if (-not $containers) {
            $healthResults.checks[$checkName] = @{
                status = "unhealthy"
                message = "No containers are running"
            }
            $healthResults.overall_status = "unhealthy"
            Write-HealthLog "No containers are running" "ERROR"
            return $false
        }
        
        $runningCount = ($containers | Where-Object { $_.State -eq "running" }).Count
        $totalCount = $containers.Count
        
        $containerStatus = @{}
        foreach ($container in $containers) {
            $containerStatus[$container.Name] = @{
                state = $container.State
                status = $container.Status
                health = $container.Health
            }
        }
        
        $healthResults.checks[$checkName] = @{
            status = "healthy"
            message = "$runningCount/$totalCount containers running"
            containers = $containerStatus
        }
        
        Write-HealthLog "$runningCount/$totalCount containers running" "OK"
        
        if ($Detailed) {
            foreach ($container in $containers) {
                $icon = if ($container.State -eq "running") { "  ✓" } else { "  ✗" }
                Write-HealthLog "$icon $($container.Name): $($container.State) ($($container.Health))"
            }
        }
        
        return $true
    } catch {
        $healthResults.checks[$checkName] = @{
            status = "unhealthy"
            message = "Failed to check containers"
            error = $_.Exception.Message
        }
        $healthResults.overall_status = "unhealthy"
        Write-HealthLog "Failed to check containers: $_" "ERROR"
        return $false
    }
}

function Test-ContainerHealth {
    $checkName = "container_health"
    
    try {
        $containers = docker compose -f $ComposeFile ps --format json 2>$null | ConvertFrom-Json
        $unhealthyContainers = $containers | Where-Object { 
            $_.Health -ne "healthy" -and $_.Health -ne "" -and $_.Name -ne "bootstrap" 
        }
        
        if ($unhealthyContainers) {
            $healthResults.checks[$checkName] = @{
                status = "degraded"
                message = "Some containers are not healthy"
                unhealthy = @($unhealthyContainers | ForEach-Object { 
                    @{
                        name = $_.Name
                        health = $_.Health
                        status = $_.Status
                    }
                })
            }
            $healthResults.overall_status = "degraded"
            Write-HealthLog "Some containers are not healthy:" "WARNING"
            foreach ($container in $unhealthyContainers) {
                Write-HealthLog "  - $($container.Name): $($container.Health)" "WARNING"
            }
            return $false
        } else {
            $healthResults.checks[$checkName] = @{
                status = "healthy"
                message = "All containers are healthy"
            }
            Write-HealthLog "All containers are healthy" "OK"
            return $true
        }
    } catch {
        $healthResults.checks[$checkName] = @{
            status = "unknown"
            message = "Failed to check container health"
            error = $_.Exception.Message
        }
        Write-HealthLog "Failed to check container health: $_" "WARNING"
        return $false
    }
}

function Test-DataverseAPI {
    $checkName = "dataverse_api"
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8080/api/info/version" -TimeoutSec 5 -ErrorAction Stop
        
        $healthResults.checks[$checkName] = @{
            status = "healthy"
            message = "Dataverse API is responding"
            version = $response.data.version
            build = $response.data.build
        }
        
        Write-HealthLog "Dataverse API is responding (v$($response.data.version))" "OK"
        return $true
    } catch {
        $healthResults.checks[$checkName] = @{
            status = "unhealthy"
            message = "Dataverse API is not responding"
            error = $_.Exception.Message
        }
        $healthResults.overall_status = "unhealthy"
        Write-HealthLog "Dataverse API is not responding" "ERROR"
        return $false
    }
}

function Test-DatabaseConnection {
    $checkName = "database_connection"
    
    try {
        $result = docker compose -f $ComposeFile exec -T postgres pg_isready -U dataverse 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            $healthResults.checks[$checkName] = @{
                status = "healthy"
                message = "PostgreSQL is accepting connections"
            }
            Write-HealthLog "PostgreSQL is accepting connections" "OK"
            return $true
        } else {
            $healthResults.checks[$checkName] = @{
                status = "unhealthy"
                message = "PostgreSQL is not accepting connections"
            }
            $healthResults.overall_status = "unhealthy"
            Write-HealthLog "PostgreSQL is not accepting connections" "ERROR"
            return $false
        }
    } catch {
        $healthResults.checks[$checkName] = @{
            status = "unhealthy"
            message = "Failed to check database"
            error = $_.Exception.Message
        }
        $healthResults.overall_status = "unhealthy"
        Write-HealthLog "Failed to check database: $_" "ERROR"
        return $false
    }
}

function Test-DiskSpace {
    $checkName = "disk_space"
    
    try {
        $drive = Get-PSDrive C
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
        $usedSpaceGB = [math]::Round($drive.Used / 1GB, 2)
        $totalSpaceGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
        $percentFree = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 1)
        
        $status = "healthy"
        $level = "OK"
        
        if ($freeSpaceGB -lt 5) {
            $status = "critical"
            $level = "ERROR"
            $healthResults.overall_status = "unhealthy"
        } elseif ($freeSpaceGB -lt 10) {
            $status = "warning"
            $level = "WARNING"
            if ($healthResults.overall_status -eq "healthy") {
                $healthResults.overall_status = "degraded"
            }
        }
        
        $healthResults.checks[$checkName] = @{
            status = $status
            message = "$freeSpaceGB GB free ($percentFree%)"
            free_gb = $freeSpaceGB
            used_gb = $usedSpaceGB
            total_gb = $totalSpaceGB
            percent_free = $percentFree
        }
        
        Write-HealthLog "Disk space: $freeSpaceGB GB free ($percentFree% of $totalSpaceGB GB)" $level
        return $status -eq "healthy"
    } catch {
        $healthResults.checks[$checkName] = @{
            status = "unknown"
            message = "Failed to check disk space"
            error = $_.Exception.Message
        }
        Write-HealthLog "Failed to check disk space: $_" "WARNING"
        return $false
    }
}

function Test-MemoryUsage {
    $checkName = "memory_usage"
    
    try {
        $stats = docker stats --no-stream --format "{{.Name}},{{.MemUsage}}" 2>$null
        
        if ($stats) {
            $containerMemory = @{}
            foreach ($line in $stats) {
                $parts = $line -split ","
                if ($parts.Count -eq 2) {
                    $containerMemory[$parts[0]] = $parts[1]
                }
            }
            
            $healthResults.checks[$checkName] = @{
                status = "healthy"
                message = "Memory usage monitored"
                containers = $containerMemory
            }
            
            Write-HealthLog "Memory usage monitored" "OK"
            
            if ($Detailed) {
                foreach ($container in $containerMemory.Keys) {
                    Write-HealthLog "  - $container: $($containerMemory[$container])"
                }
            }
            
            return $true
        } else {
            $healthResults.checks[$checkName] = @{
                status = "unknown"
                message = "Could not retrieve memory usage"
            }
            Write-HealthLog "Could not retrieve memory usage" "WARNING"
            return $false
        }
    } catch {
        $healthResults.checks[$checkName] = @{
            status = "unknown"
            message = "Failed to check memory usage"
            error = $_.Exception.Message
        }
        Write-HealthLog "Failed to check memory usage: $_" "WARNING"
        return $false
    }
}

# Main execution
try {
    if (-not $Json) {
        Write-Output ""
        Write-Output "===================================="
        Write-Output "Dataverse Health Check"
        Write-Output "===================================="
        Write-Output ""
    }
    
    $allHealthy = $true
    
    # Run all checks
    $allHealthy = (Test-DockerAvailable) -and $allHealthy
    $allHealthy = (Test-ContainersRunning) -and $allHealthy
    $allHealthy = (Test-ContainerHealth) -and $allHealthy
    $allHealthy = (Test-DataverseAPI) -and $allHealthy
    $allHealthy = (Test-DatabaseConnection) -and $allHealthy
    $allHealthy = (Test-DiskSpace) -and $allHealthy
    $allHealthy = (Test-MemoryUsage) -and $allHealthy
    
    if ($Json) {
        $healthResults | ConvertTo-Json -Depth 10
    } else {
        Write-Output ""
        Write-Output "===================================="
        if ($healthResults.overall_status -eq "healthy") {
            Write-Output "✅ Overall Status: HEALTHY"
            $exitCode = 0
        } elseif ($healthResults.overall_status -eq "degraded") {
            Write-Output "⚠️  Overall Status: DEGRADED"
            $exitCode = 1
        } else {
            Write-Output "❌ Overall Status: UNHEALTHY"
            $exitCode = 1
        }
        Write-Output "===================================="
        Write-Output ""
    }
    
    exit $exitCode
    
} catch {
    if ($Json) {
        $healthResults.overall_status = "error"
        $healthResults.error = $_.Exception.Message
        $healthResults | ConvertTo-Json -Depth 10
    } else {
        Write-Output ""
        Write-Output "❌ Health check failed: $_"
    }
    exit 1
}
