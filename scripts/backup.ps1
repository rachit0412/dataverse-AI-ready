<#
.SYNOPSIS
Backs up Dataverse PostgreSQL database and uploaded files.

.DESCRIPTION
Creates timestamped backups of the Dataverse database and file storage.
Stores backups in the specified directory with automatic cleanup of old backups.

.PARAMETER BackupPath
Path to store backup files. Defaults to .\backups

.PARAMETER RetentionDays
Number of days to retain backups. Older backups are automatically deleted. Default: 7 days.

.PARAMETER Compress
Compress backup files using gzip. Default: $true

.PARAMETER SkipDatabase
Skip database backup (files only). Default: $false

.PARAMETER SkipFiles
Skip file storage backup (database only). Default: $false

.EXAMPLE
.\backup.ps1
Creates backup in .\backups directory with default retention.

.EXAMPLE
.\backup.ps1 -BackupPath "C:\Backups\Dataverse" -RetentionDays 30
Creates backup in custom location with 30-day retention.

.EXAMPLE
.\backup.ps1 -SkipFiles
Backs up database only, skips file storage.

.NOTES
Requires Docker Compose and running Dataverse containers.
Backup files are compressed by default to save space.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$BackupPath = ".\backups",
    
    [Parameter()]
    [int]$RetentionDays = 7,
    
    [Parameter()]
    [bool]$Compress = $true,
    
    [Parameter()]
    [bool]$SkipDatabase = $false,
    
    [Parameter()]
    [bool]$SkipFiles = $false
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Constants
$ComposeFile = "configs\compose.yml"
$Timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupName = "dataverse-backup-$Timestamp"

# Functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "[$timestamp] [$Level] $Message"
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    # Check Docker Compose
    try {
        docker compose version | Out-Null
        Write-Log "✅ Docker Compose is available"
    } catch {
        Write-Log "❌ Docker Compose not found. Please install Docker Desktop." "ERROR"
        exit 1
    }
    
    # Check if containers are running
    $containers = docker compose -f $ComposeFile ps --format json 2>$null | ConvertFrom-Json
    if (-not $containers) {
        Write-Log "❌ No Dataverse containers are running. Start them first with: docker compose -f $ComposeFile up -d" "ERROR"
        exit 1
    }
    
    # Check if postgres is healthy
    $postgresStatus = docker compose -f $ComposeFile ps postgres --format json 2>$null | ConvertFrom-Json
    if ($postgresStatus.Health -ne "healthy") {
        Write-Log "⚠️  PostgreSQL container is not healthy. Backup may fail." "WARNING"
    }
    
    Write-Log "✅ Prerequisites check passed"
}

function New-BackupDirectory {
    Write-Log "Creating backup directory: $BackupPath\$BackupName"
    
    if (!(Test-Path $BackupPath)) {
        New-Item -ItemType Directory -Force -Path $BackupPath | Out-Null
    }
    
    $fullBackupPath = Join-Path $BackupPath $BackupName
    New-Item -ItemType Directory -Force -Path $fullBackupPath | Out-Null
    
    return $fullBackupPath
}

function Backup-Database {
    param([string]$DestinationPath)
    
    if ($SkipDatabase) {
        Write-Log "Skipping database backup (SkipDatabase = true)"
        return $true
    }
    
    Write-Log "Starting database backup..."
    
    $dbBackupFile = Join-Path $DestinationPath "database.sql"
    
    try {
        # Execute pg_dump inside the postgres container
        $pgDumpCmd = "pg_dump -U dataverse dataverse"
        docker compose -f $ComposeFile exec -T postgres $pgDumpCmd > $dbBackupFile
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ Database backup failed with exit code $LASTEXITCODE" "ERROR"
            return $false
        }
        
        $fileSize = (Get-Item $dbBackupFile).Length / 1MB
        Write-Log "✅ Database backed up successfully ($([math]::Round($fileSize, 2)) MB)"
        
        # Compress if requested
        if ($Compress) {
            Write-Log "Compressing database backup..."
            Compress-Archive -Path $dbBackupFile -DestinationPath "$dbBackupFile.zip" -CompressionLevel Optimal
            Remove-Item $dbBackupFile
            
            $compressedSize = (Get-Item "$dbBackupFile.zip").Length / 1MB
            Write-Log "✅ Compressed to $([math]::Round($compressedSize, 2)) MB"
        }
        
        return $true
    } catch {
        Write-Log "❌ Database backup failed: $_" "ERROR"
        return $false
    }
}

function Backup-Files {
    param([string]$DestinationPath)
    
    if ($SkipFiles) {
        Write-Log "Skipping file storage backup (SkipFiles = true)"
        return $true
    }
    
    Write-Log "Starting file storage backup..."
    
    $filesBackupPath = Join-Path $DestinationPath "files"
    
    try {
        # Get volume name for dataverse data
        $volumeName = "configs_dataverse-data"
        
        # Create temp container to copy files from volume
        Write-Log "Copying files from Docker volume..."
        docker run --rm -v ${volumeName}:/source -v ${DestinationPath}:/backup alpine tar czf /backup/files.tar.gz -C /source .
        
        if ($LASTEXITCODE -ne 0) {
            Write-Log "❌ File storage backup failed with exit code $LASTEXITCODE" "ERROR"
            return $false
        }
        
        $fileSize = (Get-Item (Join-Path $DestinationPath "files.tar.gz")).Length / 1MB
        Write-Log "✅ File storage backed up successfully ($([math]::Round($fileSize, 2)) MB)"
        
        return $true
    } catch {
        Write-Log "❌ File storage backup failed: $_" "ERROR"
        return $false
    }
}

function Remove-OldBackups {
    param([string]$BackupDir, [int]$RetentionDays)
    
    Write-Log "Cleaning up backups older than $RetentionDays days..."
    
    $cutoffDate = (Get-Date).AddDays(-$RetentionDays)
    $oldBackups = Get-ChildItem -Path $BackupDir -Directory | Where-Object {
        $_.Name -match "dataverse-backup-\d{8}-\d{6}" -and $_.CreationTime -lt $cutoffDate
    }
    
    if ($oldBackups) {
        foreach ($backup in $oldBackups) {
            Write-Log "Removing old backup: $($backup.Name)"
            Remove-Item -Path $backup.FullName -Recurse -Force
        }
        Write-Log "✅ Removed $($oldBackups.Count) old backup(s)"
    } else {
        Write-Log "No old backups to remove"
    }
}

function New-BackupManifest {
    param([string]$BackupDir)
    
    $manifest = @{
        timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        dataverse_version = "unknown"
        backup_path = $BackupDir
        database_backup = !(Get-Item "$BackupDir\database.sql*" -ErrorAction SilentlyContinue) -eq $null
        files_backup = Test-Path "$BackupDir\files.tar.gz"
        compressed = $Compress
    }
    
    # Try to get Dataverse version
    try {
        $version = Invoke-RestMethod -Uri "http://localhost:8080/api/info/version" -TimeoutSec 5 -ErrorAction SilentlyContinue
        $manifest.dataverse_version = $version.data.version
    } catch {
        Write-Log "Could not retrieve Dataverse version (container may not be running)" "WARNING"
    }
    
    $manifestPath = Join-Path $BackupDir "manifest.json"
    $manifest | ConvertTo-Json | Set-Content $manifestPath
    
    Write-Log "✅ Backup manifest created"
}

# Main execution
try {
    Write-Log "==================================="
    Write-Log "Dataverse Backup Script"
    Write-Log "==================================="
    Write-Log ""
    
    Test-Prerequisites
    
    $backupDir = New-BackupDirectory
    
    Write-Log ""
    Write-Log "Backup location: $backupDir"
    Write-Log ""
    
    $dbSuccess = Backup-Database -DestinationPath $backupDir
    $filesSuccess = Backup-Files -DestinationPath $backupDir
    
    if ($dbSuccess -or $filesSuccess) {
        New-BackupManifest -BackupDir $backupDir
        Remove-OldBackups -BackupDir $BackupPath -RetentionDays $RetentionDays
        
        Write-Log ""
        Write-Log "==================================="
        Write-Log "✅ Backup completed successfully!"
        Write-Log "==================================="
        Write-Log "Backup location: $backupDir"
        
        # Calculate total backup size
        $totalSize = (Get-ChildItem -Path $backupDir -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
        Write-Log "Total size: $([math]::Round($totalSize, 2)) MB"
        Write-Log ""
        
        exit 0
    } else {
        Write-Log ""
        Write-Log "❌ Backup failed. Check errors above." "ERROR"
        exit 1
    }
    
} catch {
    Write-Log "❌ Unexpected error: $_" "ERROR"
    Write-Log $_.ScriptStackTrace "ERROR"
    exit 1
}
