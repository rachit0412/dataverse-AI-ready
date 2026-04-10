# Dataverse Local Docker Deployment - Execution Plan

**Document Version:** 1.0  
**Last Updated:** 2026-04-10  
**Based On:** Repository README.md and INSTALLATION_GUIDE.md

---

## 1. Purpose & Scope

### What This Setup Is For

This execution plan provides a **deterministic, reproducible procedure** to run Dataverse locally using Docker for:

- **Demo/Evaluation**: Testing and evaluating Dataverse features
- **Development**: Local development and customization
- **Testing**: Smoke testing functionality before deploying elsewhere

### What This Setup Is NOT Suitable For

- ❌ **Production deployments** (lacks security hardening, HTTPS, high availability)
- ❌ **Internet-facing deployments** (uses dev mode with open admin APIs by default)
- ❌ **Multi-user production workloads** (single-instance, no load balancing)
- ❌ **Long-term data storage without backups** (data loss risk without backup strategy)

**Default Mode:** Dev mode (admin APIs open, no authentication) - explicitly documented as "Less Secure" and "DO NOT use in production"

---

## 2. Prerequisites

### Required Software

| Tool | Version | How to Verify |
|------|---------|---------------|
| **Docker Desktop** or **Docker Engine** | Latest version | `docker --version` |
| **Docker Compose** | v2.0+ (bundled with Docker Desktop) | `docker compose version` |

**Installation Source:** https://www.docker.com/products/docker-desktop

### Operating System Support

Per documentation:
- ✅ **macOS**: Fully supported
- ✅ **Linux**: Fully supported
- ⚠️ **Windows 10/11 with WSL2**: Experimental support

### Hardware Requirements

**Minimum:**
- **RAM**: 8 GB
- **CPU**: 2 cores
- **Disk**: 20 GB free space

**Recommended:**
- **RAM**: 16 GB
- **CPU**: 4 cores
- **Disk**: 50 GB free space

**Docker Desktop Configuration Required:**
1. Open Docker Desktop Settings
2. Navigate to Resources → Memory
3. Set Memory to at least 8 GB
4. Set CPUs to at least 2
5. Set Disk to at least 50 GB
6. Click "Apply & Restart"

### Network Requirements

**Ports Required:**
- **8080**: Dataverse web UI/API (must be free)
- **5432**: PostgreSQL (internal Docker network only)
- **8983**: Solr (internal Docker network only)
- **25**: SMTP (internal Docker network only)

**Verification:**
```powershell
# Windows: Check if port 8080 is in use
netstat -ano | Select-String ":8080"

# Should return nothing (port is free)
```

---

## 3. Folder & File Setup

### Expected Directory Structure

Per documentation, the working directory will contain:

```
<working-directory>/
├── compose.yml          # Required: Docker Compose configuration
├── .env                 # Optional: Environment variable overrides
├── demo/                # Optional: For demo mode configuration
│   └── init.sh
└── data/                # Created automatically: Persistent storage
    ├── postgres/        # PostgreSQL database files
    ├── solr/            # Solr search index
    ├── dataverse/       # Uploaded dataset files
    └── secrets/         # Configuration secrets
```

### Required Files

**Mandatory:**
- `compose.yml` - Docker Compose configuration file

**Obtain Method:**
Download from official Dataverse guides:
```powershell
Invoke-WebRequest -Uri "https://guides.dataverse.org/en/latest/_downloads/f08d721f1b85dd424dff557bf65fdc5c/compose.yml" -OutFile "compose.yml"
```

**Alternative:** Documentation states "Or use the compose.yml file provided in this repository" (implies repository will contain this file in future)

### Optional Files

**`.env` file** - For custom configuration:

Per INSTALLATION_GUIDE.md, create with:
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

**Note:** This step is explicitly marked "Optional" in documentation.

### Data Persistence

Per README.md:
> "All data is stored in a `data` directory that Docker Compose creates automatically"

**Data Directory Contents:**
- `data/postgres` - Database files
- `data/solr` - Search index
- `data/dataverse` - Uploaded files
- `data/secrets` - Config secrets

**Behavior:** "Your data persists even when containers are stopped"

**Note:** Documentation states Docker Compose creates this automatically; manual creation is optional.

---

## 4. Step-by-Step Execution Plan

### Pre-Flight Verification

**Step 0: Verify Prerequisites**

```powershell
# Verify Docker is installed and running
docker --version
# Expected: Docker version 24.x.x or higher

docker compose version
# Expected: Docker Compose version v2.x.x or higher

# Verify Docker daemon is running
docker ps
# Expected: No errors, may show running containers or empty list
```

**Windows-specific check:**
```powershell
# Check RAM (should be 8 GB+)
Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | ForEach-Object {"{0:N2} GB" -f ($_.Sum / 1GB)}

# Check disk space (should have 20+ GB free)
Get-PSDrive C | Select-Object Used,Free
```

---

### Main Execution Steps

**Step 1: Download Docker Compose File**

```powershell
Invoke-WebRequest -Uri "https://guides.dataverse.org/en/latest/_downloads/f08d721f1b85dd424dff557bf65fdc5c/compose.yml" -OutFile "compose.yml"
```

**What this does:** Downloads official Dataverse Docker Compose configuration  
**Expected output:** File `compose.yml` created in current directory  
**Validation:** `Test-Path compose.yml` should return `True`

---

**Step 2: (Optional) Pre-download Docker Images**

Per INSTALLATION_GUIDE.md, this step is "optional but recommended":

```powershell
docker compose pull
```

**What this does:** Downloads all required container images before starting  
**Expected output:**
- Downloading `gdcc/dataverse:latest` (~1.5 GB)
- Downloading `postgres:13` (~314 MB)
- Downloading `solr:9.3.0` (~577 MB)
- Downloading `gdcc/configbaker:latest` (small)

**Duration:** Varies by internet speed (5-15 minutes typical)  
**Note:** If skipped, images will download during first `docker compose up`

---

**Step 3: Start Dataverse**

**Option A - Foreground Mode (See All Logs):**
```powershell
docker compose up
```

**Option B - Background Mode (Detached):**
```powershell
docker compose up -d
```

**What happens during startup:**

Per documentation:
1. PostgreSQL starts and initializes database (1-2 minutes)
2. Solr starts and creates search core (30 seconds)
3. Dataverse application starts (2-3 minutes)
4. Bootstrap container configures Dataverse (5-10 minutes)

**Total expected time:** 10-15 minutes on first run

**Expected outputs:**
- Multiple containers will be pulled (if not pre-downloaded)
- Container status messages
- Bootstrap process logs
- Look for: "Successfully completed bootstrap" message
- Bootstrap container exits with code 0

---

**Step 4: Monitor Bootstrap Progress**

If running in background mode (`-d`), monitor with:

```powershell
docker compose logs -f bootstrap
```

**Success indicators:**
- Message: "Successfully completed bootstrap"
- No ERROR messages
- Bootstrap container exits with code 0

**To stop viewing logs:** Press `Ctrl+C` (does not stop containers)

---

**Step 5: Verify All Containers Running**

```powershell
docker compose ps
```

**Expected output:**
```
NAME         IMAGE                  STATUS         PORTS
dataverse    gdcc/dataverse:latest  Up (healthy)   0.0.0.0:8080->8080/tcp
postgres     postgres:13            Up (healthy)   5432/tcp
solr         solr:9.3.0             Up             8983/tcp
smtp         mailhog/mailhog        Up             25/tcp, 8025/tcp
```

**Note:** Bootstrap container will show as "Exited (0)" - this is expected and correct.

---

## 5. Access & Validation

### Access Dataverse Web Interface

**URL:** http://localhost:8080

**Expected behavior:** Dataverse homepage loads in browser

---

### Default Credentials

Per README.md:

- **Username:** `dataverseAdmin`
- **Password:** `admin1`

**Login location:** Click "Log In" button in top right corner

---

### Smoke Test Validation

Per README.md section "🧪 Smoke Testing", perform these operations to verify functionality:

1. ✅ Log in as `dataverseAdmin` (password: `admin1`)
2. ✅ Publish the root collection (dataverse)
3. ✅ Create a new collection
4. ✅ Create a dataset
5. ✅ Upload a data file
6. ✅ Publish the dataset
7. ✅ Search for your dataset

**Per documentation:** "If all tests pass, your Dataverse installation is working correctly!"

---

### Container Health Verification

```powershell
# View all container logs
docker compose logs -f

# View specific container logs
docker compose logs -f dataverse
docker compose logs -f postgres
docker compose logs -f solr

# Check container status
docker compose ps
```

---

## 6. Start / Stop / Reset Procedures

### Stop Containers

**Method 1 - If running in foreground:**
Press `Ctrl+C` in the terminal

**Method 2 - If running in background or after Ctrl+C:**
```powershell
docker compose stop
```

**What this does:** Stops all containers, preserves all data in `data/` directory

**Note:** Per documentation: "Your data persists even when containers are stopped"

---

### Restart with Preserved State

**Start after stopping:**
```powershell
docker compose up
```

Or in background mode:
```powershell
docker compose up -d
```

**What this does:** Restarts containers with existing data intact

**Expected behavior:** Much faster than first startup (no bootstrap needed), data and configurations preserved

---

### Complete Reset (Start Fresh)

Per README.md section "### Starting Fresh":

**Step 1 - Stop all containers:**
```powershell
docker compose down
```

**Step 2 - Delete data directory:**
```powershell
Remove-Item -Path data -Recurse -Force
```

**Step 3 - Start again:**
```powershell
docker compose up
```

**⚠️ Warning from documentation:** "This deletes ALL data including database, files, and configurations!"

**When to use:** 
- Corrupted installation
- Want to test fresh deployment
- Need to change fundamental configurations

---

### Additional Operations

**View logs:**
```powershell
# All containers
docker compose logs -f

# Specific container
docker compose logs -f dataverse
docker compose logs -f postgres
docker compose logs -f solr
docker compose logs -f bootstrap
```

**Check container status:**
```powershell
docker compose ps
```

**Restart specific container:**
```powershell
docker compose restart <container-name>
# Example: docker compose restart postgres
```

---

## 7. Known Limitations

### Deployment Mode

**Default:** Dev Mode (as documented in README.md "Configuration Options")

**Dev Mode Characteristics:**
- Admin APIs are **open** (no authentication required)
- Explicitly marked as "Less Secure"
- Documentation states: **"DO NOT use in production"**
- Security level: **Low**

**Alternative:** Demo Mode (requires additional configuration not covered in Quick Start)

---

### Bootstrap Behavior

**Bootstrap Container:**
- Runs once at startup
- Configures initial Dataverse settings via API
- **Expected to exit after completion** (not an error)
- Documented expected state: "Bootstrap container exits with code 0"

**Default Timeout:** 3 minutes (can be increased if needed)

---

### Port Exposure

**Externally accessible:**
- Port 8080: Dataverse web UI/API

**Internal only (Docker network):**
- Port 5432: PostgreSQL
- Port 8983: Solr
- Port 25: SMTP

---

### Operating System Support

**Windows:**
- Requires WSL2
- Documented as "experimental support"
- May have compatibility issues not present on macOS/Linux

---

### Data Persistence

**Automatic persistence:**
- Data stored in `data/` directory
- Survives container stop/restart

**No automatic backups:**
- User responsible for backup strategy
- Loss risk without backups

---

### Resource Requirements

**Minimum specs are truly minimum:**
- 8 GB RAM may cause slow performance
- 2 CPU cores may cause slow startup
- 20 GB disk may fill quickly with datasets

**Recommended specs advised for better experience**

---

## 8. Troubleshooting Pointers

### Where to Find Logs

**All containers:**
```powershell
docker compose logs -f
```

**Specific container:**
```powershell
docker compose logs -f <container-name>
```

Valid container names: `dataverse`, `postgres`, `solr`, `bootstrap`, `smtp`

---

### Common Issues from Documentation

#### Issue 1: Port Already in Use

**Error message:** `Bind for 0.0.0.0:8080 failed: port is already allocated`

**Cause:** Another service using port 8080

**Solutions:**
1. Stop the conflicting service, OR
2. Change port in `compose.yml`:
   ```yaml
   dataverse:
     ports:
       - "8081:8080"  # Change 8080 to 8081
   ```

---

#### Issue 2: Out of Memory

**Symptoms:** Containers crash or become unresponsive

**Solution:**
1. Open Docker Desktop Settings
2. Go to Resources → Memory
3. Increase to at least 8 GB
4. Click "Apply & Restart"

---

#### Issue 3: Bootstrap Timeout

**Error:** Bootstrap container exits with timeout error

**Solution:** Increase timeout in `compose.yml`:
```yaml
bootstrap:
  environment:
    - TIMEOUT=10m  # Increase from 3m to 10m
```

Then restart:
```powershell
docker compose down
docker compose up
```

---

#### Issue 4: Cannot Connect to Database

**Error messages:** `Connection refused` or database errors in logs

**Diagnostic steps:**
```powershell
# Check if PostgreSQL is running
docker compose ps postgres

# View PostgreSQL logs
docker compose logs postgres

# Restart PostgreSQL
docker compose restart postgres
```

---

### General Troubleshooting Workflow

Per README.md "Getting Help" section:

1. **Check logs:** `docker compose logs -f` to see error messages
2. **Verify requirements:** Ensure minimum hardware/software met
3. **Community Support:**
   - Dataverse Community: https://dataverse.org/community
   - GitHub Issues: https://github.com/IQSS/dataverse/issues
   - Google Group: https://groups.google.com/g/dataverse-community

---

### Verification Commands

**Check Docker is running:**
```powershell
docker ps
```

**Check compose file is valid:**
```powershell
docker compose config
```

**Check port availability:**
```powershell
netstat -ano | Select-String ":8080"
# Should return nothing if port is free
```

---

## Ambiguities & Missing Information

### Items Not Explicitly Documented

1. **compose.yml content:** Documentation references downloading it but doesn't show the full file structure in README or INSTALLATION_GUIDE
   - **Impact:** Users must download from external URL or wait for repo to include it

2. **Demo mode exact steps:** README mentions demo mode exists but Quick Start uses dev mode by default
   - **Impact:** Users get less secure setup unless they read advanced sections

3. **SMTP configuration:** Documentation mentions SMTP container but not how to access test emails
   - **Possible inference:** MailHog likely provides web UI, but port not documented in Quick Start

4. **Windows WSL2 specific issues:** Documented as "experimental" but no specific known issues listed
   - **Impact:** Windows users may encounter undocumented problems

5. **Exact bootstrap completion message:** Documentation says to look for "success message" but doesn't quote exact text
   - **Impact:** Users may be unsure if bootstrap truly completed

---

## References

**Primary Sources:**
- Repository README.md (Dataverse Docker Container Setup)
- Repository INSTALLATION_GUIDE.md (Dataverse Implementation Guide)

**External References from Documentation:**
- Official Dataverse Guides: https://guides.dataverse.org/
- Docker Download: https://www.docker.com/products/docker-desktop
- Community Support: https://dataverse.org/community
- GitHub Issues: https://github.com/IQSS/dataverse/issues
- Google Group: https://groups.google.com/g/dataverse-community

---

**END OF EXECUTION PLAN**

*This plan is based strictly on documented information as of 2026-04-10. For production deployments, consult additional security and operational documentation.*
