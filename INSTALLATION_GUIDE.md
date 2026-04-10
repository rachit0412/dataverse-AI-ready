# Dataverse Implementation Guide

A step-by-step guide to deploy and configure Dataverse using Docker containers.

## � Current Deployment Status

✅ **Deployment Status**: See [DEPLOYMENT_STATUS.md](../DEPLOYMENT_STATUS.md) for current system status  
🐛 **Known Issues**: See [docs/ERRORS_AND_SOLUTIONS.md](../docs/ERRORS_AND_SOLUTIONS.md) for troubleshooting  
📚 **Quick Ref**: All commands and solutions are indexed in documentation

---

## �📋 Implementation Checklist

- [ ] Verify system requirements
- [ ] Install Docker and Docker Compose
- [ ] Download configuration files
- [ ] Configure environment variables
- [ ] Start Dataverse containers
- [ ] Verify deployment
- [ ] Perform initial configuration
- [ ] Test functionality
- [ ] Set up backups (recommended)

## 🎯 Phase 1: Pre-Installation

### Step 1.1: Verify System Requirements

**Check Hardware:**
```powershell
# Check RAM
Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | ForEach-Object {"{0:N2} GB" -f ($_.Sum / 1GB)}

# Check available disk space
Get-PSDrive C | Select-Object Used,Free
```

**Minimum Requirements:**
- RAM: 8 GB minimum, 16 GB recommended
- Disk: 20 GB minimum, 50 GB recommended
- CPU: 2 cores minimum, 4 cores recommended

### Step 1.2: Install Docker Desktop

1. Download Docker Desktop from https://www.docker.com/products/docker-desktop
2. Run the installer
3. Enable WSL2 backend (Windows) or Hypervisor Framework (Mac)
4. Configure resources in Docker Desktop Settings:
   - Memory: 8 GB minimum
   - CPUs: 2 minimum
   - Disk: 50 GB minimum

5. Verify installation:
```powershell
docker --version
docker compose version
```

Expected output:
```
Docker version 24.x.x
Docker Compose version v2.x.x
```

## 🚀 Phase 2: Installation

### Step 2.1: Download Compose Configuration

Download the official compose file:
```powershell
Invoke-WebRequest -Uri "https://guides.dataverse.org/en/latest/_downloads/f08d721f1b85dd424dff557bf65fdc5c/compose.yml" -OutFile "compose.yml"
```

Or use the compose.yml file provided in this repository.

### Step 2.2: Create Directory Structure

```powershell
# Create directories for persistent data
New-Item -ItemType Directory -Force -Path "data"
New-Item -ItemType Directory -Force -Path "data/postgres"
New-Item -ItemType Directory -Force -Path "data/solr"
New-Item -ItemType Directory -Force -Path "data/dataverse"
New-Item -ItemType Directory -Force -Path "data/secrets"
```

### Step 2.3: Configure Environment (Optional)

Create a `.env` file for custom configuration:

```powershell
@"
# Dataverse Configuration
DATAVERSE_VERSION=latest
POSTGRES_VERSION=13
SOLR_VERSION=9.3.0

# Database Configuration
POSTGRES_USER=dataverse
POSTGRES_PASSWORD=ChangeThisSecurePassword123!
POSTGRES_DATABASE=dataverse

# Application Settings
DATAVERSE_URL=http://localhost:8080
"@ | Out-File -FilePath ".env" -Encoding ASCII
```

### Step 2.4: Pull Docker Images

Pre-download all required images (optional but recommended):
```powershell
docker compose pull
```

This downloads:
- `gdcc/dataverse:latest` (~1.5 GB)
- `postgres:13` (~314 MB)
- `solr:9.3.0` (~577 MB)
- `gdcc/configbaker:latest` (small)

### Step 2.5: Start Dataverse

**Option A: Foreground Mode** (see all logs):
```powershell
docker compose up
```

**Option B: Background Mode** (detached):
```powershell
docker compose up -d
```

**What happens during startup:**
1. PostgreSQL starts and initializes database (1-2 minutes)
2. Solr starts and creates search core (30 seconds)
3. Dataverse application starts (2-3 minutes)
4. Bootstrap container configures Dataverse (5-10 minutes)

**Total time:** 10-15 minutes on first run

### Step 2.6: Monitor Bootstrap Progress

Watch the bootstrap logs:
```powershell
docker compose logs -f bootstrap
```

**Success indicators:**
- Look for: "Successfully completed bootstrap"
- No ERROR messages
- Bootstrap container exits with code 0

Press `Ctrl+C` to stop viewing logs.

### Step 2.7: Verify All Containers are Running

```powershell
docker compose ps
```

Expected output:
```
NAME         IMAGE                  STATUS         PORTS
dataverse    gdcc/dataverse:latest  Up (healthy)   0.0.0.0:8080->8080/tcp
postgres     postgres:13            Up (healthy)   5432/tcp
solr         solr:9.3.0             Up             8983/tcp
smtp         mailhog/mailhog        Up             25/tcp, 8025/tcp
```

## ✅ Phase 3: Verification

### Step 3.1: Access Dataverse Web Interface

1. Open browser to: http://localhost:8080
2. You should see the Dataverse homepage

### Step 3.2: Log In as Administrator

**Credentials:**
- Username: `dataverseAdmin`
- Password: `admin1`

Click "Log In" in the top right → Enter credentials → Click "Sign In"

### Step 3.3: Publish Root Collection

Before creating datasets, publish the root dataverse:

1. Click on "Root" dataverse name
2. Click "Publish" button
3. Confirm publication

### Step 3.4: Run Smoke Tests

Perform these basic operations to verify functionality:

**Test 1: Create Collection**
1. Click "Add Data" → "New Dataverse Collection"
2. Fill in:
   - Name: "Test Collection"
   - Identifier: "test"
   - Category: "Research Projects"
3. Click "Create Dataverse Collection"
4. ✅ Success: Collection created

**Test 2: Create Dataset**
1. In your collection, click "Add Data" → "New Dataset"
2. Fill required fields:
   - Title: "Test Dataset"
   - Author: Your name
   - Contact: Your email
   - Description: "Testing Dataverse"
   - Subject: "Computer and Information Science"
3. Click "Save Dataset"
4. ✅ Success: Dataset created

**Test 3: Upload File**
1. In your dataset, click "Files" tab
2. Click "Upload Files" → "Select Files to Add"
3. Select any small file (e.g., text file, CSV)
4. Click "Upload"
5. ✅ Success: File uploaded

**Test 4: Publish Dataset**
1. Click "Publish" → "Publish Dataset"
2. Confirm publication
3. ✅ Success: Dataset published with DOI

**Test 5: Search**
1. Enter your dataset title in search box
2. Press Enter
3. ✅ Success: Dataset appears in results

**All tests passed?** Your Dataverse installation is working correctly!

## ⚙️ Phase 4: Initial Configuration

### Step 4.1: Change Admin Password

1. Log in as `dataverseAdmin`
2. Click profile name (top right) → "Account Information"
3. Enter current password: `admin1`
4. Enter new secure password (twice)
5. Click "Save Changes"

### Step 4.2: Configure System Settings

**Set Organization Name:**
```powershell
curl -X PUT -d "Your Organization Name" "http://localhost:8080/api/admin/settings/:FooterCopyright"
```

**Set Installation Name:**
```powershell
curl -X PUT -d "My Dataverse Repository" "http://localhost:8080/api/admin/settings/:InstallationName"
```

**Configure Email:**
```powershell
# System email address
curl -X PUT -d "dataverse@yourdomain.org" "http://localhost:8080/api/admin/settings/:SystemEmail"
```

### Step 4.3: Create Additional Users (Optional)

**Via Web Interface:**
1. Log out
2. Click "Sign Up"
3. Fill registration form
4. Check email (MailHog at http://localhost:8025)
5. Verify account

**Via API:**
```powershell
$user = @{
    firstName = "Jane"
    lastName = "Doe"
    userName = "jdoe"
    email = "jdoe@example.org"
    affiliation = "Your Organization"
} | ConvertTo-Json

curl -X POST "http://localhost:8080/api/builtin-users?key=secret&password=changeme" -H "Content-Type: application/json" -d $user
```

### Step 4.4: Configure Authentication (Optional)

Dataverse supports multiple authentication methods:

**Enable Institutional Login (Shibboleth):**
See: https://guides.dataverse.org/en/latest/installation/shibboleth.html

**Enable OAuth (ORCID, GitHub, Google):**
See: https://guides.dataverse.org/en/latest/installation/oauth2.html

## 🔒 Phase 5: Security Hardening (Production)

### Step 5.1: Switch to Demo Mode

This requires an unblock key for admin operations.

1. Create demo directory:
```powershell
New-Item -ItemType Directory -Force -Path "demo"
```

2. Download demo init script:
```powershell
Invoke-WebRequest -Uri "https://guides.dataverse.org/en/latest/_downloads/eb8531ea999e2174f849eb4af6f4340a/init.sh" -OutFile "demo\init.sh"
```

3. Edit `demo\init.sh` and change unblock key:
```bash
# Change this line:
UNBLOCK_KEY="unblockme"

# To a secure random string:
UNBLOCK_KEY="$(openssl rand -hex 32)"
```

4. Update `compose.yml`:
```yaml
bootstrap:
  command:
    - bootstrap.sh
    - demo  # Changed from 'dev'
  volumes:
    - ./demo:/scripts/bootstrap/demo
```

5. Restart:
```powershell
docker compose down
docker compose up -d
```

### Step 5.2: Use Strong Passwords

Update database password in `.env`:
```properties
POSTGRES_PASSWORD=UseAVeryStrongRandomPassword123!@#
```

Restart database:
```powershell
docker compose down
docker compose up -d
```

### Step 5.3: Limit Network Exposure

Modify `compose.yml` to only expose necessary ports:

```yaml
services:
  dataverse:
    ports:
      - "127.0.0.1:8080:8080"  # Only localhost access
```

### Step 5.4: Enable HTTPS (Production)

For production, use a reverse proxy (nginx/Caddy) with SSL:

1. Install Caddy/nginx on host
2. Configure SSL certificate (Let's Encrypt)
3. Proxy to http://localhost:8080
4. Update DATAVERSE_URL setting

## 📊 Phase 6: Monitoring & Maintenance

### Step 6.1: Monitor Container Health

```powershell
# Check container status
docker compose ps

# View resource usage
docker stats

# Check logs
docker compose logs -f dataverse
```

### Step 6.2: Set Up Backups

**Database Backup:**
```powershell
# Create backup
docker compose exec postgres pg_dump -U dataverse dataverse > backup_$(Get-Date -Format 'yyyyMMdd').sql

# Restore backup
Get-Content backup_20260410.sql | docker compose exec -T postgres psql -U dataverse dataverse
```

**File Storage Backup:**
```powershell
# Backup data directory
Compress-Archive -Path "data\dataverse" -DestinationPath "dataverse_files_$(Get-Date -Format 'yyyyMMdd').zip"
```

**Automated Backup Script:**
```powershell
# backup.ps1
$date = Get-Date -Format 'yyyyMMdd'
$backupDir = "backups\$date"
New-Item -ItemType Directory -Force -Path $backupDir

# Database
docker compose exec postgres pg_dump -U dataverse dataverse > "$backupDir\database.sql"

# Files
Copy-Item -Path "data\dataverse" -Destination "$backupDir\files" -Recurse

# Compress
Compress-Archive -Path $backupDir -DestinationPath "backups\backup_$date.zip"
Remove-Item -Path $backupDir -Recurse
```

Schedule with Windows Task Scheduler.

### Step 6.3: Update Dataverse

```powershell
# Pull latest images
docker compose pull

# Recreate containers
docker compose up -d

# Check logs
docker compose logs -f bootstrap
```

## 🛠️ Phase 7: Troubleshooting & Error Resolution

### 📚 Comprehensive Error Documentation

All known errors and their solutions are documented in: **[docs/ERRORS_AND_SOLUTIONS.md](../docs/ERRORS_AND_SOLUTIONS.md)**

| Error ID | Issue | Documentation |
|----------|-------|-----------------|
| ERR-DB-001 | PostgreSQL auth errors | [postgres.md](../docs/errors/postgres.md) |
| ERR-DATAVERSE-001 | Application deployment failure | [dataverse-app.md](../docs/errors/dataverse-app.md) |
| ERR-DATAVERSE-002 | Bootstrap timeout | [bootstrap-timeout.md](../docs/errors/bootstrap-timeout.md) |
| ERR-FRONTEND-001 | Payara page instead of Dataverse | [frontend-ui.md](../docs/errors/frontend-ui.md) |
| ERR-FRONTEND-002 | Browser favicon/tracking warnings | [browser-resources.md](../docs/errors/browser-resources.md) |
| ERR-COMPOSE-001/002 | Docker configuration issues | [docker-compose.md](../docs/errors/docker-compose.md) |

**Recommended**: Check the comprehensive error index first before troubleshooting.

### Quick Diagnostic Tool

```powershell
# Run full system health check
Write-Host "🔍 Dataverse System Diagnostics" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# 1. Container Status
Write-Host "`n1️⃣  Container Status:"
$containers = docker-compose -f compose.yml ps --format json | ConvertFrom-Json
foreach ($container in $containers) {
    if ($container.Status -match "Up") {
        Write-Host "✅ $($container.Names): Running"
    } else {
        Write-Host "❌ $($container.Names): $($container.Status)"
    }
}

# 2. API Health
Write-Host "`n2️⃣  Dataverse API:"
try {
    $api = Invoke-RestMethod http://localhost:8080/api/info/version -TimeoutSec 5 -ErrorAction Stop
    Write-Host "✅ API Responding (v$($api.data.version))"
} catch {
    Write-Host "❌ API Not Responding"
}

# 3. Database
Write-Host "`n3️⃣  PostgreSQL Database:"
try {
    docker exec compose-postgres-1 pg_isready -U dataverse > $null 2>&1
    Write-Host "✅ Database Healthy"
} catch {
    Write-Host "❌ Database Unavailable"
}

# 4. Search
Write-Host "`n4️⃣  Solr Search:"
try {
    $solr = Invoke-WebRequest http://localhost:8983/solr/admin/ping -TimeoutSec 5 -ErrorAction Stop
    if ($solr.StatusCode -eq 200) { Write-Host "✅ Solr Healthy" }
} catch {
    Write-Host "❌ Solr Unavailable"
}
```

### Common Issues & Solutions

#### Issue: See Payara Welcome Page Instead of Dataverse

**Reference:** [ERR-FRONTEND-001](../docs/errors/frontend-ui.md)

**Solution:**
```powershell
# Application is still deploying. Wait 10-30 minutes on first run.

# Monitor deployment progress:
docker-compose -f compose.yml logs -f dataverse | Select-String "deployed|ready" -Context 1

# Check API when ready:
Invoke-RestMethod http://localhost:8080/api/info/version
```

#### Issue: Database Connection Refused

**Reference:** [ERR-DB-001](../docs/errors/postgres.md)

**Solution:**
```powershell
# Quick fix (WARNING: deletes all data):
docker-compose -f compose.yml down -v
docker-compose -f compose.yml up -d

# Or preserve data - see ERR-DB-001 for detailed recovery steps
```

#### Issue: Bootstrap Timeout

**Reference:** [ERR-DATAVERSE-002](../docs/errors/bootstrap-timeout.md)

**Solution:**
```powershell
# This is NORMAL on first deployment. Bootstrap timeout does NOT mean failure.
# Application continues deploying in background.

# Just wait and check periodically:
docker-compose -f compose.yml logs dataverse | tail -20
```

#### Issue: Cannot Access localhost:8080

**Symptom:** Browser shows "Connection refused"

**Checklist:**
```powershell
# 1. Check if container is running
docker compose ps dataverse

# 2. Check if port 8080 is actually open
netstat -ano | Select-String ":8080"

# 3. Check for errors in dataverse logs
docker compose logs dataverse | Select-String "ERROR|Exception|crash" -Context 2

# 4. If port in use elsewhere, free it or use different port in compose.yml
```

#### Issue: Out of Memory / Container Crashes

**Solution:**
1. Stop Dataverse: `docker compose down`
2. Increase Docker Desktop memory:
   - Open Docker Desktop → Settings → Resources
   - Set Memory to 8-16 GB
   - Apply & Restart
3. Start again: `docker compose up -d`

#### Issue: Out of Disk Space

**Solution:**
```powershell
# Check disk usage
docker system df

# Clean up unused Docker resources
docker system prune -a

# Move data directory to larger disk if needed
# (See Phase 6 backup/restore procedures)
```

### Viewing and Interpreting Logs

#### Real-Time Monitoring

```powershell
# Follow all logs
docker compose -f compose.yml logs -f

# Follow specific service
docker compose -f compose.yml logs -f dataverse

# Last 100 lines
docker compose -f compose.yml logs --tail 100 dataverse

# With timestamps
docker compose -f compose.yml logs --timestamps --tail 50
```

#### Search for Specific Errors

```powershell
# Find ERROR messages
docker compose logs | Select-String "ERROR"

# Find database connection errors
docker compose logs | Select-String "connect|connection|refused" -Context 2

# Find deployment status
docker compose logs dataverse | Select-String "deployment|deploy"
```

#### Export Logs for Analysis

```powershell
# Save all logs to file
docker compose logs > dataverse_logs_$(Get-Date -Format yyyyMMdd_HHmmss).txt

# Just dataverse container
docker compose logs dataverse > dataverse_container.txt

# Share with support (before redacting sensitive data!)
```

### Advanced Diagnostics

#### Check Docker Version Compatibility

```powershell
docker --version
docker compose version

# Should show:
# Docker version 20.x or later
# Docker Compose version 2.x or later
```

#### Inspect Container Details

```powershell
# Get container ID
$container_id = docker ps --format "{{.ID}}" -f "name=compose-dataverse"

# View container details
docker inspect $container_id

# Check resource limits
docker inspect $container_id | Select-String -Pattern "Memory|CpuShares"
```

#### Manual Database Testing

```powershell
# Connect directly to database
docker exec -it compose-postgres-1 psql -U dataverse -d dataverse

# Once connected (psql prompt), try:
# SELECT COUNT(*) FROM dvobject;  -- Count objects
# SELECT version();               -- Check version
# \dt                             -- List tables
# \q                              -- Quit
```

### When to Check Error Documentation

**Check [docs/ERRORS_AND_SOLUTIONS.md](../docs/ERRORS_AND_SOLUTIONS.md) if you see:**
- ❌ Application won't start
- ❌ Database connection errors
- ❌ Bootstrap failures
- ❌ API returning errors
- ❌ UI not showing correctly
- ❌ Any persistent issues after basic troubleshooting

### Getting Help

**Before contacting support, gather:**

```powershell
# System information
Write-Host "Operating System: $(Get-ComputerInfo -Property OsName | Select -ExpandProperty OsName)"
Write-Host "Docker Version: $(docker --version)"
Write-Host "Available Memory: $(Get-WmiObject -Class win32_operatingsystem | Select -ExpandProperty TotalVisibleMemorySize)"

# Container status
docker compose ps > container_status.txt

# Recent logs (last 200 lines from each service)
docker compose logs --tail 200 dataverse > logs_dataverse.txt
docker compose logs --tail 200 postgres > logs_postgres.txt
docker compose logs --tail 200 solr > logs_solr.txt

# Error summary
docker compose logs dataverse | Select-String "ERROR|Exception" | Out-File errors_summary.txt
```

Then share these files (with sensitive data redacted) with support team.

## 📚 Phase 8: Advanced Features

### Enable File Previewers

Dataverse can preview many file types in the browser.

**Check available previewers:**
```powershell
curl http://localhost:8080/api/admin/externalTools
```

**Configure specific previewers in compose.yml:**
```yaml
services:
  dataverse:
    environment:
      - PREVIEWERS=text,html,pdf,csv,image,spreadsheet
```

### Configure Handle/DOI Registration

For persistent identifiers:

**DataCite (recommended):**
1. Get DataCite account
2. Configure in Dataverse:
```powershell
curl -X PUT -d "datacite" http://localhost:8080/api/admin/settings/:Protocol
curl -X PUT -d "your-doi-prefix" http://localhost:8080/api/admin/settings/:Shoulder
curl -X PUT -d "username" http://localhost:8080/api/admin/settings/:DataCiteUser
curl -X PUT -d "password" http://localhost:8080/api/admin/settings/:DataCitePassword
```

### Enable Guestbook

Require users to fill form before downloading:

1. Create guestbook in UI: Settings → Guestbooks
2. Enable for dataset
3. Users must agree before downloading

### Configure Metadata Blocks

Add custom metadata schemas:

```powershell
# Upload custom metadata block
curl -X POST "http://localhost:8080/api/admin/datasetfield/load" -H "Content-type: text/tab-separated-values" --upload-file custom-metadata.tsv
```

## 🎓 Next Steps

1. **Read the User Guide:** https://guides.dataverse.org/en/latest/user/
2. **Explore the API:** https://guides.dataverse.org/en/latest/api/
3. **Join the Community:** https://dataverse.org/community
4. **Customize Your Instance:** Brand it, add custom metadata, configure workflows
5. **Plan for Production:** SSL, monitoring, backups, scaling

## 📞 Support

- **Documentation:** https://guides.dataverse.org
- **Community Forum:** https://groups.google.com/g/dataverse-community
- **GitHub Issues:** https://github.com/IQSS/dataverse/issues
- **Slack:** https://dataverse.org/slack

---

**Congratulations!** You now have a fully functional Dataverse repository. Start sharing and preserving research data!
