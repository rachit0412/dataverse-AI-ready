# ============================================================================
# Docker Security Scanner
# ============================================================================
# Performs comprehensive security analysis of Docker containers and configuration
# 
# Usage: .\security-scan.ps1 [-ComposeFile docker-compose-secure.yml]
# ============================================================================

param(
    [string]$ComposeFile = "docker-compose-secure.yml",
    [switch]$Detailed = $false
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host " Docker Security Scanner" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Configuration
# ============================================================================

$SecurityChecks = @{
    Critical = @()
    High = @()
    Medium = @()
    Low = @()
    Info = @()
}

# ============================================================================
# Functions
# ============================================================================

function Add-SecurityFinding {
    param(
        [string]$Severity,
        [string]$Check,
        [string]$Result,
        [string]$Details = ""
    )
    
    $finding = @{
        Check = $Check
        Result = $Result
        Details = $Details
        Timestamp = Get-Date
    }
    
    $SecurityChecks[$Severity] += $finding
}

function Write-CheckHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host ("-" * 80) -ForegroundColor Gray
}

function Write-CheckResult {
    param(
        [string]$Check,
        [string]$Status,
        [string]$Message = ""
    )
    
    $icon = switch ($Status) {
        "PASS" { "✓"; $color = "Green" }
        "FAIL" { "✗"; $color = "Red" }
        "WARN" { "⚠"; $color = "Yellow" }
        "INFO" { "ℹ"; $color = "Cyan" }
        default { "•"; $color = "Gray" }
    }
    
    Write-Host "  $icon $Check" -ForegroundColor $color -NoNewline
    if ($Message) {
        Write-Host " - $Message" -ForegroundColor Gray
    }
    else {
        Write-Host ""
    }
}

# ============================================================================
# Check 1: Docker Installation
# ============================================================================

Write-CheckHeader "Check 1: Docker Installation & Configuration"

try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($dockerVersion) {
        Write-CheckResult "Docker Engine" "PASS" "Version $dockerVersion"
        Add-SecurityFinding -Severity "Info" -Check "Docker Engine" -Result "PASS" -Details "Version $dockerVersion"
    }
    else {
        Write-CheckResult "Docker Engine" "FAIL" "Docker is not running or not installed"
        Add-SecurityFinding -Severity "Critical" -Check "Docker Engine" -Result "FAIL" -Details "Docker is not running"
        return
    }
}
catch {
    Write-CheckResult "Docker Engine" "FAIL" "Cannot connect to Docker daemon"
    Add-SecurityFinding -Severity "Critical" -Check "Docker Engine" -Result "FAIL" -Details "Cannot connect to Docker daemon"
    return
}

# Check Docker Compose
try {
    $composeVersion = docker-compose version --short 2>$null
    if ($composeVersion) {
        Write-CheckResult "Docker Compose" "PASS" "Version $composeVersion"
        Add-SecurityFinding -Severity "Info" -Check "Docker Compose" -Result "PASS" -Details "Version $composeVersion"
    }
}
catch {
    Write-CheckResult "Docker Compose" "WARN" "Docker Compose not found"
    Add-SecurityFinding -Severity "Medium" -Check "Docker Compose" -Result "WARN" -Details "Docker Compose not installed"
}

# ============================================================================
# Check 2: Compose File Analysis
# ============================================================================

Write-CheckHeader "Check 2: Docker Compose Configuration Analysis"

if (-not (Test-Path $ComposeFile)) {
    Write-CheckResult "Compose File" "FAIL" "File not found: $ComposeFile"
    Add-SecurityFinding -Severity "Critical" -Check "Compose File" -Result "FAIL" -Details "File not found"
    return
}

Write-CheckResult "Compose File" "PASS" "Found: $ComposeFile"

# Parse YAML (basic parsing)
$composeContent = Get-Content $ComposeFile -Raw

# Check for secrets usage
if ($composeContent -match "secrets:") {
    Write-CheckResult "Docker Secrets" "PASS" "Configuration uses Docker secrets"
    Add-SecurityFinding -Severity "Info" -Check "Docker Secrets" -Result "PASS"
}
else {
    Write-CheckResult "Docker Secrets" "FAIL" "No Docker secrets configured"
    Add-SecurityFinding -Severity "Critical" -Check "Docker Secrets" -Result "FAIL" -Details "Credentials may be in plaintext"
}

# Check for network isolation
if ($composeContent -match "internal:\s*true") {
    Write-CheckResult "Network Isolation" "PASS" "Internal network detected"
    Add-SecurityFinding -Severity "Info" -Check "Network Isolation" -Result "PASS"
}
else {
    Write-CheckResult "Network Isolation" "WARN" "No internal networks found"
    Add-SecurityFinding -Severity "High" -Check "Network Isolation" -Result "WARN" -Details "Backend may be exposed"
}

# Check for resource limits
if ($composeContent -match "resources:\s*\n\s*limits:") {
    Write-CheckResult "Resource Limits" "PASS" "Resource limits configured"
    Add-SecurityFinding -Severity "Info" -Check "Resource Limits" -Result "PASS"
}
else {
    Write-CheckResult "Resource Limits" "FAIL" "No resource limits found"
    Add-SecurityFinding -Severity "Critical" -Check "Resource Limits" -Result "FAIL" -Details "DoS risk"
}

# Check for read-only filesystems
if ($composeContent -match "read_only:\s*true") {
    Write-CheckResult "Read-Only Filesystems" "PASS" "Read-only root filesystems configured"
    Add-SecurityFinding -Severity "Info" -Check "Read-Only Filesystems" -Result "PASS"
}
else {
    Write-CheckResult "Read-Only Filesystems" "FAIL" "Writable root filesystems detected"
    Add-SecurityFinding -Severity "Critical" -Check "Read-Only Filesystems" -Result "FAIL"
}

# Check for capability dropping
if ($composeContent -match "cap_drop:\s*\n\s*-\s*ALL") {
    Write-CheckResult "Capability Dropping" "PASS" "ALL capabilities dropped"
    Add-SecurityFinding -Severity "Info" -Check "Capability Dropping" -Result "PASS"
}
else {
    Write-CheckResult "Capability Dropping" "WARN" "Not all capabilities dropped"
    Add-SecurityFinding -Severity "High" -Check "Capability Dropping" -Result "WARN"
}

# Check for security options
if ($composeContent -match "no-new-privileges:true") {
    Write-CheckResult "No New Privileges" "PASS" "no-new-privileges configured"
    Add-SecurityFinding -Severity "Info" -Check "No New Privileges" -Result "PASS"
}
else {
    Write-CheckResult "No New Privileges" "WARN" "no-new-privileges not set"
    Add-SecurityFinding -Severity "Medium" -Check "No New Privileges" -Result "WARN"
}

# Check for non-root users
if ($composeContent -match "user:\s*\"") {
    Write-CheckResult "Non-Root Users" "PASS" "Non-root users configured"
    Add-SecurityFinding -Severity "Info" -Check "Non-Root Users" -Result "PASS"
}
else {
    Write-CheckResult "Non-Root Users" "WARN" "May be running as root"
    Add-SecurityFinding -Severity "High" -Check "Non-Root Users" -Result "WARN"
}

# ============================================================================
# Check 3: Secret Files
# ============================================================================

Write-CheckHeader "Check 3: Docker Secrets Files"

$secretFiles = @("postgres_user.txt", "postgres_password.txt", "dataverse_admin_password.txt")
$secretsDir = ".\secrets"

foreach ($secretFile in $secretFiles) {
    $secretPath = Join-Path $secretsDir $secretFile
    
    if (Test-Path $secretPath) {
        # Check file permissions
        try {
            $acl = Get-Acl $secretPath
            $accessRules = $acl.Access | Where-Object { $_.AccessControlType -eq "Allow" }
            
            if ($accessRules.Count -le 2) {
                Write-CheckResult $secretFile "PASS" "Restrictive permissions"
                Add-SecurityFinding -Severity "Info" -Check "Secret: $secretFile" -Result "PASS"
            }
            else {
                Write-CheckResult $secretFile "WARN" "Multiple access rules ($($accessRules.Count))"
                Add-SecurityFinding -Severity "Medium" -Check "Secret: $secretFile" -Result "WARN" -Details "Too many access rules"
            }
        }
        catch {
            Write-CheckResult $secretFile "INFO" "Unable to check permissions"
        }
    }
    else {
        Write-CheckResult $secretFile "FAIL" "File not found"
        Add-SecurityFinding -Severity "Critical" -Check "Secret: $secretFile" -Result "FAIL" -Details "Missing secret file"
    }
}

# ============================================================================
# Check 4: Running Containers (if any)
# ============================================================================

Write-CheckHeader "Check 4: Running Container Security"

try {
    $containers = docker ps --format "{{.Names}}" 2>$null
    
    if ($containers) {
        foreach ($container in $containers) {
            # Check if running as root
            $user = docker exec $container whoami 2>$null
            if ($user -eq "root") {
                Write-CheckResult "$container (User)" "FAIL" "Running as root"
                Add-SecurityFinding -Severity "High" -Check "Container: $container" -Result "FAIL" -Details "Running as root"
            }
            else {
                Write-CheckResult "$container (User)" "PASS" "Running as: $user"
                Add-SecurityFinding -Severity "Info" -Check "Container: $container" -Result "PASS" -Details "User: $user"
            }
            
            # Check capabilities
            if ($Detailed) {
                $caps = docker inspect $container --format='{{.HostConfig.CapDrop}}' 2>$null
                if ($caps -match "ALL") {
                    Write-CheckResult "$container (Caps)" "PASS" "Capabilities dropped"
                }
                else {
                    Write-CheckResult "$container (Caps)" "WARN" "Capabilities not fully dropped"
                }
            }
        }
    }
    else {
        Write-CheckResult "Running Containers" "INFO" "No running containers found"
    }
}
catch {
    Write-CheckResult "Running Containers" "INFO" "Unable to inspect running containers"
}

# ============================================================================
# Check 5: Image Security
# ============================================================================

Write-CheckHeader "Check 5: Image Security Analysis"

try {
    $images = docker images --format "{{.Repository}}:{{.Tag}}" | Select-String -Pattern "^dataverse|^postgres|^solr|^nginx"
    
    foreach ($image in $images) {
        # Check for latest tag
        if ($image -match ":latest") {
            Write-CheckResult "$image" "WARN" "Using 'latest' tag (not recommended)"
            Add-SecurityFinding -Severity "Low" -Check "Image: $image" -Result "WARN" -Details "Using 'latest' tag"
        }
        else {
            Write-CheckResult "$image" "PASS" "Pinned version"
            Add-SecurityFinding -Severity "Info" -Check "Image: $image" -Result "PASS"
        }
    }
}
catch {
    Write-CheckResult "Image Analysis" "INFO" "Unable to analyze images"
}

# ============================================================================
# Check 6: Network Configuration
# ============================================================================

Write-CheckHeader "Check 6: Network Security"

try {
    $networks = docker network ls --format "{{.Name}}" | Select-String -Pattern "dataverse"
    
    foreach ($network in $networks) {
        $netInfo = docker network inspect $network --format='{{.Internal}}' 2>$null
        
        if ($network -match "backend" -and $netInfo -eq "true") {
            Write-CheckResult "$network" "PASS" "Internal network (isolated)"
            Add-SecurityFinding -Severity "Info" -Check "Network: $network" -Result "PASS"
        }
        elseif ($network -match "backend") {
            Write-CheckResult "$network" "FAIL" "Backend network not internal"
            Add-SecurityFinding -Severity "High" -Check "Network: $network" -Result "FAIL" -Details "Backend exposed"
        }
        else {
            Write-CheckResult "$network" "INFO" "External network"
        }
    }
}
catch {
    Write-CheckResult "Network Analysis" "INFO" "Unable to analyze networks"
}

# ============================================================================
# Check 7: Host Security
# ============================================================================

Write-CheckHeader "Check 7: Host Security Configuration"

# Check Docker daemon configuration
try {
    $dockerInfo = docker info --format json 2>$null | ConvertFrom-Json
    
    if ($dockerInfo.SecurityOptions -match "apparmor") {
        Write-CheckResult "AppArmor" "PASS" "Enabled"
        Add-SecurityFinding -Severity "Info" -Check "AppArmor" -Result "PASS"
    }
    else {
        Write-CheckResult "AppArmor" "INFO" "Not available (Linux only)"
    }
    
    if ($dockerInfo.SecurityOptions -match "seccomp") {
        Write-CheckResult "Seccomp" "PASS" "Enabled"
        Add-SecurityFinding -Severity "Info" -Check "Seccomp" -Result "PASS"
    }
    else {
        Write-CheckResult "Seccomp" "WARN" "Not enabled"
        Add-SecurityFinding -Severity "Medium" -Check "Seccomp" -Result "WARN"
    }
}
catch {
    Write-CheckResult "Daemon Security" "INFO" "Unable to inspect Docker daemon"
}

# ============================================================================
# Check 8: .gitignore Check
# ============================================================================

Write-CheckHeader "Check 8: Version Control Security"

if (Test-Path ".gitignore") {
    $gitignore = Get-Content ".gitignore" -Raw
    
    if ($gitignore -match "secrets/") {
        Write-CheckResult ".gitignore (secrets)" "PASS" "Secrets directory ignored"
        Add-SecurityFinding -Severity "Info" -Check ".gitignore secrets" -Result "PASS"
    }
    else {
        Write-CheckResult ".gitignore (secrets)" "FAIL" "./secrets/ not in .gitignore"
        Add-SecurityFinding -Severity "Critical" -Check ".gitignore secrets" -Result "FAIL" -Details "Risk of credential leak"
    }
    
    if ($gitignore -match "\.env") {
        Write-CheckResult ".gitignore (.env)" "PASS" ".env file ignored"
        Add-SecurityFinding -Severity "Info" -Check ".gitignore .env" -Result "PASS"
    }
    else {
        Write-CheckResult ".gitignore (.env)" "WARN" ".env file not ignored"
        Add-SecurityFinding -Severity "High" -Check ".gitignore .env" -Result "WARN"
    }
}
else {
    Write-CheckResult ".gitignore" "WARN" ".gitignore file not found"
    Add-SecurityFinding -Severity "High" -Check ".gitignore" -Result "WARN" -Details "No .gitignore file"
}

# ============================================================================
# Security Score Calculation
# ============================================================================

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host " Security Scan Summary" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$criticalCount = $SecurityChecks.Critical.Count
$highCount = $SecurityChecks.High.Count
$mediumCount = $SecurityChecks.Medium.Count
$lowCount = $SecurityChecks.Low.Count
$passCount = $SecurityChecks.Info.Count

Write-Host "Findings by Severity:" -ForegroundColor White
Write-Host "  Critical: $criticalCount" -ForegroundColor Red
Write-Host "  High:     $highCount" -ForegroundColor Red
Write-Host "  Medium:   $mediumCount" -ForegroundColor Yellow
Write-Host "  Low:      $lowCount" -ForegroundColor Yellow
Write-Host "  Passed:   $passCount" -ForegroundColor Green

# Calculate security score
$totalChecks = $criticalCount + $highCount + $mediumCount + $lowCount + $passCount
$securityScore = 0

if ($totalChecks -gt 0) {
    $deductions = ($criticalCount * 25) + ($highCount * 10) + ($mediumCount * 5) + ($lowCount * 2)
    $securityScore = [Math]::Max(0, 100 - $deductions)
}

Write-Host ""
Write-Host "Security Score: $securityScore / 100" -ForegroundColor $(
    if ($securityScore -ge 80) { "Green" }
    elseif ($securityScore -ge 60) { "Yellow" }
    else { "Red" }
)

Write-Host ""
Write-Host "Recommendation: " -NoNewline
if ($criticalCount -eq 0 -and $highCount -eq 0) {
    Write-Host "Configuration meets security standards ✓" -ForegroundColor Green
}
elseif ($criticalCount -gt 0) {
    Write-Host "CRITICAL issues found - DO NOT deploy to production!" -ForegroundColor Red
}
else {
    Write-Host "Address HIGH priority issues before production deployment" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Detailed report generated: .\security-scan-report.txt" -ForegroundColor Cyan
Write-Host ""

# Generate detailed report
$report = @"
============================================================================
DOCKER SECURITY SCAN REPORT
============================================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Compose File: $ComposeFile

============================================================================
SUMMARY
============================================================================

Security Score: $securityScore / 100

Findings:
  Critical: $criticalCount
  High:     $highCount
  Medium:   $mediumCount
  Low:      $lowCount
  Passed:   $passCount

============================================================================
CRITICAL FINDINGS ($criticalCount)
============================================================================

"@

foreach ($finding in $SecurityChecks.Critical) {
    $report += "`n✗ $($finding.Check)"
    $report += "`n  Result: $($finding.Result)"
    if ($finding.Details) {
        $report += "`n  Details: $($finding.Details)"
    }
    $report += "`n"
}

$report += @"

============================================================================
HIGH PRIORITY FINDINGS ($highCount)
============================================================================

"@

foreach ($finding in $SecurityChecks.High) {
    $report += "`n⚠ $($finding.Check)"
    $report += "`n  Result: $($finding.Result)"
    if ($finding.Details) {
        $report += "`n  Details: $($finding.Details)"
    }
    $report += "`n"
}

$report += @"

============================================================================
MEDIUM PRIORITY FINDINGS ($mediumCount)
============================================================================

"@

foreach ($finding in $SecurityChecks.Medium) {
    $report += "`n⚠ $($finding.Check)"
    $report += "`n  Result: $($finding.Result)"
    if ($finding.Details) {
        $report += "`n  Details: $($finding.Details)"
    }
    $report += "`n"
}

$report += @"

============================================================================
END OF REPORT
============================================================================
"@

$report | Out-File -FilePath ".\security-scan-report.txt" -Encoding UTF8
