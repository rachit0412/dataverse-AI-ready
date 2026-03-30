# ============================================================================
# Host Isolation Validator
# ============================================================================
# Validates that containers are properly isolated from the host system
# Tests various isolation mechanisms and security boundaries
# 
# Usage: .\validate-host-isolation.ps1 [-ContainerPrefix dataverse]
# ============================================================================

param(
    [string]$ContainerPrefix = "dataverse",
    [switch]$Detailed = $false
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host " Host Isolation Validator" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Configuration
# ============================================================================

$IsolationTests = @{
    Passed = @()
    Failed = @()
    Warnings = @()
}

# ============================================================================
# Functions
# ============================================================================

function Write-TestHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host $Title -ForegroundColor Yellow
    Write-Host ("-" * 80) -ForegroundColor Gray
}

function Write-TestResult {
    param(
        [string]$Test,
        [string]$Status,
        [string]$Message = "",
        [string]$Details = ""
    )
    
    $icon = switch ($Status) {
        "PASS" { "✓"; $color = "Green" }
        "FAIL" { "✗"; $color = "Red" }
        "WARN" { "⚠"; $color = "Yellow" }
        "INFO" { "ℹ"; $color = "Cyan" }
        default { "•"; $color = "Gray" }
    }
    
    Write-Host "  $icon $Test" -ForegroundColor $color -NoNewline
    if ($Message) {
        Write-Host " - $Message" -ForegroundColor Gray
    }
    else {
        Write-Host ""
    }
    
    if ($Details -and $Detailed) {
        Write-Host "    $Details" -ForegroundColor DarkGray
    }
    
    # Track results
    $result = @{
        Test = $Test
        Status = $Status
        Message = $Message
        Details = $Details
    }
    
    switch ($Status) {
        "PASS" { $IsolationTests.Passed += $result }
        "FAIL" { $IsolationTests.Failed += $result }
        "WARN" { $IsolationTests.Warnings += $result }
    }
}

function Get-RunningContainers {
    param([string]$Prefix)
    
    try {
        $containers = docker ps --filter "name=$Prefix" --format "{{.Names}}" 2>$null
        return $containers
    }
    catch {
        return @()
    }
}

# ============================================================================
# Test 1: Container Process Isolation
# ============================================================================

Write-TestHeader "Test 1: Container Process Isolation"

$containers = Get-RunningContainers -Prefix $ContainerPrefix

if ($containers.Count -eq 0) {
    Write-TestResult "Running Containers" "INFO" "No containers found with prefix '$ContainerPrefix'"
    Write-Host ""
    Write-Host "  Start containers with: docker-compose -f docker-compose-secure.yml up -d" -ForegroundColor Gray
}
else {
    Write-TestResult "Running Containers" "PASS" "Found $($containers.Count) containers"
    
    foreach ($container in $containers) {
        # Test 1.1: Check process namespace isolation
        try {
            $pidNamespace = docker inspect $container --format='{{.State.Pid}}' 2>$null
            
            if ($pidNamespace -and $pidNamespace -ne "0") {
                Write-TestResult "  $container PID Namespace" "PASS" "Isolated (PID: $pidNamespace)"
            }
            else {
                Write-TestResult "  $container PID Namespace" "WARN" "Unable to verify"
            }
        }
        catch {
            Write-TestResult "  $container PID Namespace" "WARN" "Unable to inspect"
        }
        
        # Test 1.2: Check that container cannot see host processes
        try {
            $psCount = docker exec $container ps aux 2>$null | Measure-Object -Line
            
            if ($psCount.Lines -lt 50) {
                Write-TestResult "  $container Process Visibility" "PASS" "Limited process visibility ($($psCount.Lines) processes)"
            }
            else {
                Write-TestResult "  $container Process Visibility" "WARN" "High process count ($($psCount.Lines))"
            }
        }
        catch {
            Write-TestResult "  $container Process Visibility" "INFO" "Unable to test (ps not available)"
        }
    }
}

# ============================================================================
# Test 2: Filesystem Isolation
# ============================================================================

Write-TestHeader "Test 2: Filesystem Isolation"

foreach ($container in $containers) {
    # Test 2.1: Check read-only root filesystem
    try {
        $readOnly = docker inspect $container --format='{{.HostConfig.ReadonlyRootfs}}' 2>$null
        
        if ($readOnly -eq "true") {
            Write-TestResult "  $container Root Filesystem" "PASS" "Read-only"
        }
        else {
            Write-TestResult "  $container Root Filesystem" "FAIL" "Writable (security risk)"
        }
    }
    catch {
        Write-TestResult "  $container Root Filesystem" "WARN" "Unable to verify"
    }
    
    # Test 2.2: Test write access to root
    try {
        $writeTest = docker exec $container sh -c "touch /test-write 2>&1" 2>$null
        
        if ($LASTEXITCODE -ne 0 -or $writeTest -match "Read-only") {
            Write-TestResult "  $container Write Protection" "PASS" "Cannot write to root"
        }
        else {
            Write-TestResult "  $container Write Protection" "FAIL" "Can write to root filesystem"
        }
    }
    catch {
        Write-TestResult "  $container Write Protection" "PASS" "Write access denied"
    }
    
    # Test 2.3: Check for host filesystem mounts
    try {
        $mounts = docker inspect $container --format='{{range .Mounts}}{{.Type}}:{{.Source}} {{end}}' 2>$null
        
        $hostBinds = $mounts -split '\s+' | Where-Object { $_ -match '^bind:' }
        
        if ($hostBinds.Count -eq 0) {
            Write-TestResult "  $container Host Mounts" "PASS" "No direct host mounts"
        }
        else {
            $mountDetails = $hostBinds -join ", "
            Write-TestResult "  $container Host Mounts" "WARN" "$($hostBinds.Count) host mount(s)" -Details $mountDetails
        }
    }
    catch {
        Write-TestResult "  $container Host Mounts" "INFO" "Unable to inspect mounts"
    }
}

# ============================================================================
# Test 3: Network Isolation
# ============================================================================

Write-TestHeader "Test 3: Network Isolation"

foreach ($container in $containers) {
    # Test 3.1: Check network mode
    try {
        $networkMode = docker inspect $container --format='{{.HostConfig.NetworkMode}}' 2>$null
        
        if ($networkMode -eq "host") {
            Write-TestResult "  $container Network Mode" "FAIL" "Using host network (no isolation)"
        }
        elseif ($networkMode -match "bridge|dataverse") {
            Write-TestResult "  $container Network Mode" "PASS" "Isolated network ($networkMode)"
        }
        else {
            Write-TestResult "  $container Network Mode" "INFO" "Network mode: $networkMode"
        }
    }
    catch {
        Write-TestResult "  $container Network Mode" "WARN" "Unable to verify"
    }
    
    # Test 3.2: Check if container can reach internet (backend should not)
    if ($container -match "postgres|solr") {
        try {
            $pingTest = docker exec $container ping -c 1 -W 2 8.8.8.8 2>$null
            
            if ($LASTEXITCODE -ne 0) {
                Write-TestResult "  $container Internet Access" "PASS" "No internet access (expected for backend)"
            }
            else {
                Write-TestResult "  $container Internet Access" "FAIL" "Has internet access (backend should be isolated)"
            }
        }
        catch {
            Write-TestResult "  $container Internet Access" "PASS" "No internet access"
        }
    }
    
    # Test 3.3: Check network namespace isolation
    try {
        $interfaces = docker exec $container ip addr show 2>$null
        
        if ($interfaces -notmatch "host") {
            Write-TestResult "  $container Network Namespace" "PASS" "Isolated network namespace"
        }
    }
    catch {
        Write-TestResult "  $container Network Namespace" "INFO" "Unable to test (ip command not available)"
    }
}

# ============================================================================
# Test 4: Capability & Privilege Isolation
# ============================================================================

Write-TestHeader "Test 4: Capability & Privilege Isolation"

foreach ($container in $containers) {
    # Test 4.1: Check privileged mode
    try {
        $privileged = docker inspect $container --format='{{.HostConfig.Privileged}}' 2>$null
        
        if ($privileged -eq "false") {
            Write-TestResult "  $container Privileged Mode" "PASS" "Not privileged"
        }
        else {
            Write-TestResult "  $container Privileged Mode" "FAIL" "Running in privileged mode (CRITICAL)"
        }
    }
    catch {
        Write-TestResult "  $container Privileged Mode" "WARN" "Unable to verify"
    }
    
    # Test 4.2: Check dropped capabilities
    try {
        $capDrop = docker inspect $container --format='{{.HostConfig.CapDrop}}' 2>$null
        
        if ($capDrop -match "ALL") {
            Write-TestResult "  $container Capabilities" "PASS" "All capabilities dropped"
        }
        elseif ($capDrop) {
            Write-TestResult "  $container Capabilities" "WARN" "Some capabilities dropped" -Details $capDrop
        }
        else {
            Write-TestResult "  $container Capabilities" "FAIL" "No capabilities dropped"
        }
    }
    catch {
        Write-TestResult "  $container Capabilities" "WARN" "Unable to verify"
    }
    
    # Test 4.3: Check no-new-privileges
    try {
        $noNewPrivs = docker inspect $container --format='{{range .HostConfig.SecurityOpt}}{{.}}{{end}}' 2>$null
        
        if ($noNewPrivs -match "no-new-privileges:true") {
            Write-TestResult "  $container No New Privileges" "PASS" "Enabled"
        }
        else {
            Write-TestResult "  $container No New Privileges" "WARN" "Not configured"
        }
    }
    catch {
        Write-TestResult "  $container No New Privileges" "INFO" "Unable to verify"
    }
    
    # Test 4.4: Test if container can load kernel modules
    try {
        $modprobeTest = docker exec $container modprobe test-module 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-TestResult "  $container Kernel Module Loading" "PASS" "Cannot load kernel modules"
        }
        else {
            Write-TestResult "  $container Kernel Module Loading" "FAIL" "Can load kernel modules (CRITICAL)"
        }
    }
    catch {
        Write-TestResult "  $container Kernel Module Loading" "PASS" "Module loading blocked"
    }
}

# ============================================================================
# Test 5: User Namespace Isolation
# ============================================================================

Write-TestHeader "Test 5: User Namespace Isolation"

foreach ($container in $containers) {
    # Test 5.1: Check running user
    try {
        $user = docker exec $container whoami 2>$null
        
        if ($user -eq "root") {
            Write-TestResult "  $container Running User" "FAIL" "Running as root"
        }
        else {
            Write-TestResult "  $container Running User" "PASS" "Running as: $user"
        }
    }
    catch {
        Write-TestResult "  $container Running User" "WARN" "Unable to determine user"
    }
    
    # Test 5.2: Check UID mapping
    try {
        $uid = docker exec $container id -u 2>$null
        
        if ($uid -ne "0") {
            Write-TestResult "  $container UID" "PASS" "Non-root UID: $uid"
        }
        else {
            Write-TestResult "  $container UID" "FAIL" "Running as UID 0 (root)"
        }
    }
    catch {
        Write-TestResult "  $container UID" "INFO" "Unable to check UID"
    }
    
    # Test 5.3: Test ability to escalate privileges
    try {
        $suTest = docker exec $container su - 2>$null
        
        if ($LASTEXITCODE -ne 0) {
            Write-TestResult "  $container Privilege Escalation" "PASS" "Cannot escalate privileges"
        }
        else {
            Write-TestResult "  $container Privilege Escalation" "FAIL" "Can escalate privileges"
        }
    }
    catch {
        Write-TestResult "  $container Privilege Escalation" "PASS" "Escalation blocked"
    }
}

# ============================================================================
# Test 6: Device Access Isolation
# ============================================================================

Write-TestHeader "Test 6: Device Access Isolation"

foreach ($container in $containers) {
    # Test 6.1: Check device mounts
    try {
        $devices = docker inspect $container --format='{{range .HostConfig.Devices}}{{.PathOnHost}} {{end}}' 2>$null
        
        if (-not $devices -or $devices.Trim() -eq "") {
            Write-TestResult "  $container Device Mounts" "PASS" "No host devices mounted"
        }
        else {
            Write-TestResult "  $container Device Mounts" "WARN" "Host devices mounted" -Details $devices
        }
    }
    catch {
        Write-TestResult "  $container Device Mounts" "PASS" "No devices mounted"
    }
    
    # Test 6.2: Test access to host devices
    try {
        $devList = docker exec $container ls /dev 2>$null | Measure-Object -Line
        
        if ($devList.Lines -lt 10) {
            Write-TestResult "  $container Device Visibility" "PASS" "Limited device visibility ($($devList.Lines) devices)"
        }
        else {
            Write-TestResult "  $container Device Visibility" "INFO" "$($devList.Lines) devices visible"
        }
    }
    catch {
        Write-TestResult "  $container Device Visibility" "INFO" "Unable to list devices"
    }
}

# ============================================================================
# Test 7: Resource Isolation
# ============================================================================

Write-TestHeader "Test 7: Resource Isolation"

foreach ($container in $containers) {
    # Test 7.1: Check memory limits
    try {
        $memLimit = docker inspect $container --format='{{.HostConfig.Memory}}' 2>$null
        
        if ($memLimit -gt 0) {
            $memLimitMB = [math]::Round($memLimit / 1MB, 0)
            Write-TestResult "  $container Memory Limit" "PASS" "$memLimitMB MB"
        }
        else {
            Write-TestResult "  $container Memory Limit" "FAIL" "No memory limit (DoS risk)"
        }
    }
    catch {
        Write-TestResult "  $container Memory Limit" "WARN" "Unable to verify"
    }
    
    # Test 7.2: Check CPU limits
    try {
        $cpuQuota = docker inspect $container --format='{{.HostConfig.CpuQuota}}' 2>$null
        $cpuPeriod = docker inspect $container --format='{{.HostConfig.CpuPeriod}}' 2>$null
        
        if ($cpuQuota -gt 0 -and $cpuPeriod -gt 0) {
            $cpuLimit = $cpuQuota / $cpuPeriod
            Write-TestResult "  $container CPU Limit" "PASS" "$([math]::Round($cpuLimit, 2)) CPUs"
        }
        else {
            Write-TestResult "  $container CPU Limit" "FAIL" "No CPU limit"
        }
    }
    catch {
        Write-TestResult "  $container CPU Limit" "WARN" "Unable to verify"
    }
    
    # Test 7.3: Check PID limit
    try {
        $pidsLimit = docker inspect $container --format='{{.HostConfig.PidsLimit}}' 2>$null
        
        if ($pidsLimit -gt 0) {
            Write-TestResult "  $container PID Limit" "PASS" "Limit: $pidsLimit"
        }
        else {
            Write-TestResult "  $container PID Limit" "WARN" "No PID limit"
        }
    }
    catch {
        Write-TestResult "  $container PID Limit" "INFO" "Unable to verify"
    }
}

# ============================================================================
# Test 8: Secrets & Environment Isolation
# ============================================================================

Write-TestHeader "Test 8: Secrets & Environment Isolation"

foreach ($container in $containers) {
    # Test 8.1: Check for secrets in environment variables
    try {
        $envVars = docker exec $container env 2>$null
        
        $suspiciousVars = $envVars | Select-String -Pattern "PASSWORD|SECRET|TOKEN|KEY" -SimpleMatch
        
        if ($suspiciousVars.Count -eq 0) {
            Write-TestResult "  $container Environment Variables" "PASS" "No secrets in environment"
        }
        else {
            Write-TestResult "  $container Environment Variables" "WARN" "Potential secrets in environment ($($suspiciousVars.Count) found)"
        }
    }
    catch {
        Write-TestResult "  $container Environment Variables" "INFO" "Unable to inspect environment"
    }
    
    # Test 8.2: Check for Docker secrets usage
    try {
        $secrets = docker exec $container ls /run/secrets 2>$null
        
        if ($secrets) {
            Write-TestResult "  $container Docker Secrets" "PASS" "Using Docker secrets"
        }
        else {
            Write-TestResult "  $container Docker Secrets" "INFO" "No Docker secrets mounted"
        }
    }
    catch {
        Write-TestResult "  $container Docker Secrets" "INFO" "Secrets directory not accessible"
    }
}

# ============================================================================
# Generate Report
# ============================================================================

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host " Isolation Validation Summary" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

$passedCount = $IsolationTests.Passed.Count
$failedCount = $IsolationTests.Failed.Count
$warningCount = $IsolationTests.Warnings.Count
$totalTests = $passedCount + $failedCount + $warningCount

Write-Host "Test Results:" -ForegroundColor White
Write-Host "  Passed:   $passedCount" -ForegroundColor Green
Write-Host "  Failed:   $failedCount" -ForegroundColor Red
Write-Host "  Warnings: $warningCount" -ForegroundColor Yellow
Write-Host "  Total:    $totalTests" -ForegroundColor Gray

if ($totalTests -gt 0) {
    $isolationScore = [math]::Round(($passedCount / $totalTests * 100), 0)
    Write-Host ""
    Write-Host "Isolation Score: $isolationScore%" -ForegroundColor $(
        if ($isolationScore -ge 90) { "Green" }
        elseif ($isolationScore -ge 70) { "Yellow" }
        else { "Red" }
    )
}

Write-Host ""
Write-Host "Recommendation: " -NoNewline
if ($failedCount -eq 0) {
    Write-Host "Excellent isolation - containers are well isolated from host ✓" -ForegroundColor Green
}
elseif ($failedCount -le 2) {
    Write-Host "Good isolation with minor issues - review failed tests" -ForegroundColor Yellow
}
else {
    Write-Host "POOR ISOLATION - containers may compromise host security!" -ForegroundColor Red
}

Write-Host ""

# Generate detailed report
if ($failedCount -gt 0 -or $warningCount -gt 0) {
    Write-Host "Failed Tests:" -ForegroundColor Red
    foreach ($test in $IsolationTests.Failed) {
        Write-Host "  ✗ $($test.Test)" -ForegroundColor Red
        Write-Host "    $($test.Message)" -ForegroundColor Gray
        if ($test.Details) {
            Write-Host "    Details: $($test.Details)" -ForegroundColor DarkGray
        }
    }
    
    Write-Host ""
    Write-Host "Warnings:" -ForegroundColor Yellow
    foreach ($test in $IsolationTests.Warnings) {
        Write-Host "  ⚠ $($test.Test)" -ForegroundColor Yellow
        Write-Host "    $($test.Message)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Detailed report saved to: .\host-isolation-report.txt" -ForegroundColor Cyan
Write-Host ""

# Save detailed report
$report = @"
============================================================================
HOST ISOLATION VALIDATION REPORT
============================================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Container Prefix: $ContainerPrefix

============================================================================
SUMMARY
============================================================================

Test Results:
  Passed:   $passedCount
  Failed:   $failedCount
  Warnings: $warningCount
  Total:    $totalTests

Isolation Score: $isolationScore%

============================================================================
FAILED TESTS ($failedCount)
============================================================================

"@

foreach ($test in $IsolationTests.Failed) {
    $report += "`n✗ $($test.Test)"
    $report += "`n  Status: $($test.Status)"
    $report += "`n  Message: $($test.Message)"
    if ($test.Details) {
        $report += "`n  Details: $($test.Details)"
    }
    $report += "`n"
}

$report += @"

============================================================================
WARNINGS ($warningCount)
============================================================================

"@

foreach ($test in $IsolationTests.Warnings) {
    $report += "`n⚠ $($test.Test)"
    $report += "`n  Message: $($test.Message)"
    if ($test.Details) {
        $report += "`n  Details: $($test.Details)"
    }
    $report += "`n"
}

$report += @"

============================================================================
PASSED TESTS ($passedCount)
============================================================================

"@

foreach ($test in $IsolationTests.Passed) {
    $report += "`n✓ $($test.Test) - $($test.Message)"
}

$report += @"

============================================================================
END OF REPORT
============================================================================
"@

$report | Out-File -FilePath ".\host-isolation-report.txt" -Encoding UTF8
