# Dataverse Implementation Guide

A step-by-step guide to deploy and configure Dataverse using Docker containers.

## 📋 Implementation Checklist

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

## 🛠️ Phase 7: Troubleshooting

### Common Issues & Solutions

#### Issue: Bootstrap Takes Too Long

**Symptom:** Bootstrap runs for >15 minutes

**Solution:**
1. Check bootstrap logs: `docker compose logs bootstrap`
2. Increase timeout in compose.yml:
```yaml
bootstrap:
  environment:
    - TIMEOUT=10m
```
3. Restart: `docker compose restart bootstrap`

#### Issue: Cannot Access Web Interface

**Symptom:** Browser shows "Connection refused" at localhost:8080

**Checklist:**
```powershell
# 1. Check if dataverse container is running
docker compose ps dataverse

# 2. Check if port is exposed
docker compose port dataverse 8080

# 3. Check dataverse logs
docker compose logs dataverse | Select-String -Pattern "ERROR"

# 4. Check if port is in use by another application
netstat -ano | Select-String ":8080"
```

#### Issue: Database Connection Errors

**Symptom:** Dataverse logs show database connection errors

**Solution:**
```powershell
# 1. Verify PostgreSQL is healthy
docker compose ps postgres

# 2. Check PostgreSQL logs
docker compose logs postgres

# 3. Test database connection
docker compose exec postgres psql -U dataverse -d dataverse -c "SELECT version();"

# 4. Restart database
docker compose restart postgres
```

#### Issue: Search Not Working

**Symptom:** Search returns no results or errors

**Solution:**
```powershell
# 1. Check Solr health
curl http://localhost:8983/solr/admin/cores?action=STATUS

# 2. Reindex all content
curl http://localhost:8080/api/admin/index

# 3. Restart Solr
docker compose restart solr
```

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
