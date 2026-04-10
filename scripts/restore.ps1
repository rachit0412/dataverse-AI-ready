<#
.SYNOPSIS
Restores Dataverse from a backup.

.DESCRIPTION
Restores PostgreSQL database and/or file storage from a backup created by backup.ps1.
⚠️ WARNING: This will overwrite existing data. Containers will be stopped during restore.

.PARAMETER BackupPath
Path to the backup directory to restore from.

.PARAMETER RestoreDatabase
Restore the database. Default: $true

.PARAMETER RestoreFiles
Restore file storage. Default: $true

.PARAMETER Force
Skip confirmation prompts. Default: $false

.EXAMPLE
.\restore.ps1 -BackupPath ".\backups\dataverse-backup-20260410-120000"
Restores both database and files from the specified backup.

.EXAMPLE
.\restore.ps1 -BackupPath ".\backups\dataverse-backup-20260410-120000" -RestoreDatabase $true -RestoreFiles $false
Restores database only.

.NOTES
Requires Docker Compose.
Will stop containers, restore data, and restart containers.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$BackupPath,
    
    [Parameter()]
    [bool]$RestoreDatabase = $true,
    
    [Parameter()]
    [bool]$RestoreFiles = $true,
    
    [Parameter()]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Constants
$ComposeFile = "configs\compose.yml"

# Functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Level] $Message"
}

function Test-BackupPath {
    Write-Log "Validating backup path..."
    
    if (!(Test-Path $BackupPath)) {
        Write-Log "❌ Backup path does not exist: $BackupPath" "ERROR"
        exit 1
    }
    
    # Check for manifest
    $manifestPath = Join-Path $BackupPath "manifest.json"
    if (Test-Path $manifestPath) {
        $manifest = Get-Content $manifestPath | ConvertFrom-Json
        Write-Log "✅ Found backup manifest"
        Write-Log "   Timestamp: $($manifest.timestamp)"
        Write-Log "   Dataverse version: $($manifest.dataverse_version)"
        return $manifest
    } else {
        Write-Log "⚠️  No manifest found (may be an old backup)" "WARNING"
        return $null
    }
}

function Confirm-Restore {
    if ($Force) {
        return $true
    }
    
    Write-Log ""
    Write-Log "⚠️  WARNING: This will overwrite existing data!" "WARNING"
    Write-Log "   - Containers will be stopped"
    if ($RestoreDatabase) { Write-Log "   - Database will be replaced" }
    if ($RestoreFiles) { Write-Log "   - File storage will be replaced" }
    Write-Log ""
    
    $response = Read-Host "Do you want to continue? (yes/no)"
    return $response -eq "yes"
}

function Stop-Containers {
    Write-Log "Stopping Dataverse containers..."
    
    docker compose -f $ComposeFile down
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "❌ Failed to stop containers" "ERROR"
        exit 1
    }
    
    Write-Log "✅ Containers stopped"
}

function Restore-Database {
    param([string]$BackupDir)
    
    if (-not $RestoreDatabase) {
        Write-Log "Skipping database restore (RestoreDatabase = false)"
        return $true
    }
    
    Write-Log "Starting database restore..."
    
    # Find database backup file (may be compressed or not)
    $dbBackupFile = Get-ChildItem -Path $BackupDir -Filter "database.sql*" | Select-Object -First 1
    
    if (-not $dbBackupFile) {
        Write-Log "❌ No database backup found in: $BackupDir" "ERROR"
        return $false
    }
    
    $dbFile = $dbBackupFile.FullName
    Write-Log "Found database backup: $($dbBackupFile.Name)"
    
    try {
        # If compressed, decompress first
        if ($dbFile -match "\.zip$") {
            Write-Log "Decompressing database backup..."
            $tempFile = Join-Path $env:TEMP "dataverse-restore-db.sql"
            Expand-Archive -Path $dbFile -DestinationPath (Split-Path $tempFile) -Force
            $dbFile = $tempFile
        }
        
        # Start only postgres to restore database
        Write-Log "Starting PostgreSQL container..."
        docker compose -f $ComposeFile up -d postgres
        
        Start-Sleep -Seconds 10  # Wait for postgres to be ready
        
        # Drop existing database and recreate
        Write-Log "Dropping existing database..."
        docker compose -f $ComposeFile exec -T postgres psql -U dataverse -c "DROP DATABASE IF EXISTS dataverse WITH (FORCE);"
        
        Write-Log "Creating new database..."
        docker compose -f $ComposeFile exec -T postgres psql -U dataverse -c "CREATE DATABASE dataverse;"
        
        # Restore from backup
        Write-Log "Restoring database from backup..."
        Get-Content $dbFile | docker compose -f $ComposeFile exec -T postgres psql -U dataverse dataverse
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Database restore failed" "ERROR"
            return $false
        }
        
        Write-Log "✅ Database restored successfully"
        
        # Cleanup temp file if created
        if ($tempFile -and (Test-Path $tempFile)) {
            Remove-Item $tempFile
        }
        
        return $true
    } catch {
        Write-Log "❌ Database restore failed: $_" "ERROR"
        return $false
    }
}

function Restore-Files {
    param([string]$BackupDir)
    
    if (-not $RestoreFiles) {
        Write-Log "Skipping file storage restore (RestoreFiles = false)"
        return $true
    }
    
    Write-Log "Starting file storage restore..."
    
    $filesBackup = Join-Path $BackupDir "files.tar.gz"
    
    if (!(Test-Path $filesBackup)) {
        Write-Log "❌ No file storage backup found: $filesBackup" "ERROR"
        return $false
    }
    
    try {
        # Get volume name
        $volumeName = "configs_dataverse-data"
        
        Write-Log "Restoring files to Docker volume..."
        
        # Remove existing volume content and restore
        docker run --rm -v ${volumeName}:/target alpine sh -c "rm -rf /target/* && tar xzf /backup/files.tar.gz -C /target" -v ${BackupDir}:/backup
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ File storage restore failed" "ERROR"
            return $false
        }
        
        Write-Log "✅ File storage restored successfully"
        return $true
    } catch {
        Write-Log "❌ File storage restore failed: $_" "ERROR"
        return $false
    }
}

function Start-Containers {
    Write-Log "Starting all containers..."
    
    docker compose -f $ComposeFile up -d
    
    if ($LASTEXITCODE -ne 0) {
        Write-Log "❌ Failed to start containers" "ERROR"
        exit 1
    }
    
    Write-Log "✅ Containers started"
    Write-Log "   Waiting for services to become healthy..."
    
    Start-Sleep -Seconds 30
}

function Test-Restore {
    Write-Log "Verifying restore..."
    
    # Check container status
    $containers = docker compose -f $ComposeFile ps --format json | ConvertFrom-Json
    $unhealthy = $containers | Where-Object { $_.Health -ne "healthy" -and $_.Health -ne "" }
    
    if ($unhealthy) {
        Write-Log "⚠️  Some containers are not healthy yet:" "WARNING"
        foreach ($container in $unhealthy) {
            Write-Log "   - $($container.Name): $($container.Health)"
        }
        Write-Log "   Run 'docker compose -f $ComposeFile ps' to check status"
    } else {
        Write-Log "✅ All containers are healthy"
    }
    
    # Try to access API
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8080/api/info/version" -TimeoutSec 10 -ErrorAction SilentlyContinue
        Write-Log "✅ Dataverse API is responding"
        Write-Log "   Version: $($response.data.version)"
    } catch {
        Write-Log "⚠️  Dataverse API not responding yet (may still be starting)" "WARNING"
        Write-Log "   Check logs: docker compose -f $ComposeFile logs -f dataverse"
    }
}

# Main execution
try {
    Write-Log "==================================="
    Write-Log "Dataverse Restore Script"
    Write-Log "==================================="
    Write-Log ""
    
    $manifest = Test-BackupPath
    
    if (-not (Confirm-Restore)) {
        Write-Log "Restore cancelled by user."
        exit 0
    }
    
    Write-Log ""
    Stop-Containers
    Write-Log ""
    
    $dbSuccess = Restore-Database -BackupDir $BackupPath
    $filesSuccess = Restore-Files -BackupDir $BackupPath
    
    Write-Log ""
    Start-Containers
    Write-Log ""
    
    Test-Restore
    
    Write-Log ""
    Write-Log "==================================="
    if ($dbSuccess -and $filesSuccess) {
        Write-Log "✅ Restore completed successfully!"
    } elseif ($dbSuccess -or $filesSuccess) {
        Write-Log "⚠️  Restore partially completed" "WARNING"
    } else {
        Write-Log "❌ Restore failed" "ERROR"
        exit 1
    }
    Write-Log "==================================="
    Write-Log ""
    Write-Log "Access Dataverse at: http://localhost:8080"
    Write-Log "Default credentials: dataverseAdmin / admin1"
    Write-Log ""
    
    exit 0
    
} catch {
    Write-Log "❌ Unexpected error: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    exit 1
}
