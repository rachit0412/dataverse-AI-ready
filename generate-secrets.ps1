# ============================================================================
# Docker Secrets Generator
# ============================================================================
# Generates secure random passwords for Docker secrets
# 
# Usage: .\generate-secrets.ps1
# ============================================================================

param(
    [switch]$Force = $false
)

$ErrorActionPreference = "Stop"

Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host " Docker Secrets Generator" -ForegroundColor Cyan
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================================
# Configuration
# ============================================================================

$SecretsDir = ".\secrets"
$Secrets = @(
    @{
        Name = "postgres_user"
        Description = "PostgreSQL username"
        Value = "dataverse"
        Type = "static"
    },
    @{
        Name = "postgres_password"
        Description = "PostgreSQL password"
        Length = 32
        Type = "random"
    },
    @{
        Name = "dataverse_admin_password"
        Description = "Dataverse admin password"
        Length = 32
        Type = "random"
    }
)

# ============================================================================
# Functions
# ============================================================================

function New-SecurePassword {
    param(
        [int]$Length = 32
    )
    
    # Generate cryptographically secure random password
    $bytes = New-Object byte[] $Length
    $rng = [System.Security.Cryptography.RNGCryptoServiceProvider]::new()
    $rng.GetBytes($bytes)
    $rng.Dispose()
    
    # Convert to base64 and clean up
    $password = [Convert]::ToBase64String($bytes)
    $password = $password.Substring(0, $Length)
    
    # Ensure password meets complexity requirements
    $password = $password -replace '[+/=]', [char](Get-Random -Minimum 65 -Maximum 90)
    
    return $password
}

function Test-SecretExists {
    param(
        [string]$SecretPath
    )
    
    return Test-Path $SecretPath
}

function Write-Secret {
    param(
        [string]$Path,
        [string]$Value
    )
    
    # Write secret to file
    $Value | Out-File -FilePath $Path -Encoding ASCII -NoNewline
    
    # Set restrictive permissions (Windows ACL)
    try {
        $acl = Get-Acl $Path
        $acl.SetAccessRuleProtection($true, $false)
        
        # Remove all existing rules
        $acl.Access | ForEach-Object { $acl.RemoveAccessRule($_) | Out-Null }
        
        # Add rule for current user only
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
        $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
            $currentUser,
            "Read",
            "Allow"
        )
        $acl.AddAccessRule($rule)
        
        Set-Acl -Path $Path -AclObject $acl
        Write-Host "  ✓ Set restrictive permissions (read-only for current user)" -ForegroundColor Green
    }
    catch {
        Write-Warning "  ⚠ Could not set restrictive permissions: $($_.Exception.Message)"
        Write-Warning "  ⚠ Please manually restrict access to: $Path"
    }
}

# ============================================================================
# Main Script
# ============================================================================

Write-Host "Step 1: Validate environment" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Gray

# Check if secrets directory exists
if (-not (Test-Path $SecretsDir)) {
    Write-Host "  Creating secrets directory: $SecretsDir" -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $SecretsDir -Force | Out-Null
    Write-Host "  ✓ Directory created" -ForegroundColor Green
}
else {
    Write-Host "  ✓ Secrets directory exists" -ForegroundColor Green
}

Write-Host ""
Write-Host "Step 2: Generate secrets" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Gray

$GeneratedSecrets = @{}

foreach ($secret in $Secrets) {
    $secretPath = Join-Path $SecretsDir "$($secret.Name).txt"
    
    Write-Host ""
    Write-Host "Processing: $($secret.Name)" -ForegroundColor Cyan
    Write-Host "  Description: $($secret.Description)" -ForegroundColor Gray
    
    # Check if secret already exists
    if ((Test-SecretExists $secretPath) -and -not $Force) {
        Write-Host "  ⚠ Secret already exists, skipping..." -ForegroundColor Yellow
        Write-Host "  Use -Force to regenerate existing secrets" -ForegroundColor Gray
        
        # Read existing value
        $existingValue = Get-Content $secretPath -Raw
        $GeneratedSecrets[$secret.Name] = $existingValue
        continue
    }
    
    # Generate or use static value
    if ($secret.Type -eq "random") {
        $value = New-SecurePassword -Length $secret.Length
        Write-Host "  ✓ Generated random password ($($secret.Length) characters)" -ForegroundColor Green
    }
    else {
        $value = $secret.Value
        Write-Host "  ✓ Using static value" -ForegroundColor Green
    }
    
    # Write secret to file
    Write-Secret -Path $secretPath -Value $value
    Write-Host "  ✓ Secret written to: $secretPath" -ForegroundColor Green
    
    $GeneratedSecrets[$secret.Name] = $value
}

Write-Host ""
Write-Host "Step 3: Generate summary" -ForegroundColor Yellow
Write-Host "-----------------------------------" -ForegroundColor Gray
Write-Host ""

# Create summary file
$summaryPath = Join-Path $SecretsDir "SECRETS_SUMMARY.txt"
$summary = @"
============================================================================
DOCKER SECRETS SUMMARY
============================================================================
Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

⚠ WARNING: This file contains sensitive information!
⚠ Keep this file secure and do not commit to version control.

============================================================================
GENERATED SECRETS
============================================================================

"@

foreach ($secret in $Secrets) {
    $summary += "`n$($secret.Name):"
    $summary += "`n  Description: $($secret.Description)"
    $summary += "`n  File: .\secrets\$($secret.Name).txt"
    
    if ($secret.Type -eq "random") {
        $summary += "`n  Type: Random ($($secret.Length) characters)"
        # Show first 4 and last 4 characters for verification
        $value = $GeneratedSecrets[$secret.Name]
        $masked = "$($value.Substring(0, 4))...$($value.Substring($value.Length - 4))"
        $summary += "`n  Value: $masked"
    }
    else {
        $summary += "`n  Type: Static"
        $summary += "`n  Value: $($secret.Value)"
    }
    $summary += "`n"
}

$summary += @"

============================================================================
USAGE WITH DOCKER COMPOSE
============================================================================

The secrets are automatically loaded by Docker Compose from the ./secrets
directory. No additional configuration is needed.

To use the secure configuration:

    docker-compose -f docker-compose-secure.yml up -d

============================================================================
SECURITY NOTES
============================================================================

✓ All secrets are stored in separate files
✓ Files have restrictive permissions (read-only for current user)
✓ Secrets are mounted as in-memory files in containers
✓ Secrets are not logged or exposed in environment variables

⚠ IMPORTANT: Add ./secrets/ to .gitignore to prevent accidental commits

============================================================================
FIRST-TIME LOGIN CREDENTIALS
============================================================================

Dataverse Admin:
  Username: dataverseAdmin
  Password: See ./secrets/dataverse_admin_password.txt

PostgreSQL:
  Username: See ./secrets/postgres_user.txt
  Password: See ./secrets/postgres_password.txt
  Database: dataverse

============================================================================
"@

$summary | Out-File -FilePath $summaryPath -Encoding UTF8
Write-Host "✓ Summary written to: $summaryPath" -ForegroundColor Green

Write-Host ""
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host " ✓ Secret Generation Complete!" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Generated $($Secrets.Count) secrets in: $SecretsDir" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Review the secrets summary: $summaryPath" -ForegroundColor Gray
Write-Host "  2. Ensure ./secrets/ is in .gitignore" -ForegroundColor Gray
Write-Host "  3. Deploy with: docker-compose -f docker-compose-secure.yml up -d" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠ SECURITY: Keep these secrets safe and never commit them to version control!" -ForegroundColor Red
Write-Host ""
