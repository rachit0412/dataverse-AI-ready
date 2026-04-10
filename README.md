# Dataverse Docker Container Setup

A complete Docker-based setup for running Dataverse, the open-source research data repository platform developed at Harvard's Institute for Quantitative Social Science.

## � Status & Documentation

| Item | Link | Description |
|------|------|-------------|
| **Navigation Hub** | [DOCUMENTATION_INDEX.md](DOCUMENTATION_INDEX.md) | Complete documentation map & navigation |
| **Deployment Status** | [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) | Current system status, access info, health checks |
| **Error Reference** | [docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md) | Comprehensive error index with troubleshooting |
| **Installation** | [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) | Step-by-step setup procedure |
| **Operations** | [docs/OPERATIONS.md](docs/OPERATIONS.md) | Daily operations & maintenance |
| **Security** | [docs/SECURITY.md](docs/SECURITY.md) | Security guidelines & best practices |

---

## 📋 Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration Options](#configuration-options)
- [Usage Guide](#usage-guide)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)
- [Contributing](#contributing)

## 🎯 Overview

This repository provides a Docker Compose configuration for running Dataverse in containers for:
- **Demo/Evaluation** - Testing and evaluating Dataverse features
- **Development** - Local development and customization
- **Production** - Scalable deployment (with additional configuration)

**What is Dataverse?**
Dataverse is an open-source web application to share, preserve, cite, explore, and analyze research data. It facilitates making data available to others and allows you to replicate others' work more easily.

## 🔧 Prerequisites

### Hardware Requirements
- **Minimum**: 8 GB RAM, 2 CPU cores, 20 GB disk space
- **Recommended**: 16 GB RAM, 4 CPU cores, 50 GB disk space

### Software Requirements
- **Docker Desktop** or **Docker Engine** (latest version)
  - Download: https://www.docker.com/products/docker-desktop
- **Docker Compose** v2.0+ (bundled with Docker Desktop)
- **Operating System**: 
  - macOS (fully supported)
  - Linux (fully supported)
  - Windows 10/11 with WSL2 (experimental support)

### Verify Installation
```powershell
docker --version
docker compose version
```

## 🚀 Quick Start

### Step 1: Download Docker Compose File

Download the official compose file:
```powershell
Invoke-WebRequest -Uri "https://guides.dataverse.org/en/latest/_downloads/f08d721f1b85dd424dff557bf65fdc5c/compose.yml" -OutFile "compose.yml"
```

Or create it manually (see [compose.yml structure](#compose-yml-structure) below).

### Step 2: Start Dataverse

```powershell
docker compose up
```

**Expected Output:**
- Multiple containers will be pulled and started
- PostgreSQL database will initialize
- Solr search engine will start
- Bootstrap process will configure Dataverse (5-10 minutes on first run)
- Look for success message from the bootstrap container

### Step 3: Access Dataverse

Once bootstrap completes, open your browser to:
- **URL**: http://localhost:8080
- **Username**: `dataverseAdmin`
- **Password**: `admin1`

**Success!** If you can log in, Dataverse is running successfully.

## ⚙️ Configuration Options

### Running Modes

Dataverse supports two personas for different use cases:

#### 1. **Dev Mode** (Default - Less Secure)
- Admin APIs are open (no authentication required)
- Best for: Quick testing, development
- **Security**: Low - DO NOT use in production

#### 2. **Demo Mode** (Recommended)
- Admin APIs are protected with an unblock key
- Best for: Demos, evaluations, staging
- **Security**: Medium - Better for non-production

### Switching to Demo Mode

1. Create a `demo` directory:
```powershell
mkdir demo
```

2. Download the demo init script:
```powershell
Invoke-WebRequest -Uri "https://guides.dataverse.org/en/latest/_downloads/eb8531ea999e2174f849eb4af6f4340a/init.sh" -OutFile "demo\init.sh"
```

3. Edit `init.sh` and change the unblock key from `unblockme` to your secret key.

4. Edit `compose.yml` and make these changes:
```yaml
bootstrap:
  container_name: "bootstrap"
  image: gdcc/configbaker:latest
  restart: "no"
  environment:
    - TIMEOUT=3m
  command:
    - bootstrap.sh
    #- dev          # Comment out dev
    - demo          # Uncomment demo
  volumes:
    - ./demo:/scripts/bootstrap/demo  # Uncomment this line
  networks:
    - dataverse
```

5. Restart Dataverse:
```powershell
docker compose down
docker compose up
```

## 📖 Usage Guide

### Basic Operations

#### Start Dataverse
```powershell
docker compose up
```

Or run in detached mode (background):
```powershell
docker compose up -d
```

#### Stop Dataverse
Press `Ctrl+C` in the terminal, or:
```powershell
docker compose stop
```

#### View Logs
```powershell
# All containers
docker compose logs -f

# Specific container
docker compose logs -f dataverse
docker compose logs -f postgres
docker compose logs -f solr
docker compose logs -f bootstrap
```

#### Check Container Status
```powershell
docker compose ps
```

### Data Persistence

All data is stored in a `data` directory that Docker Compose creates automatically:
- **Database**: `data/postgres`
- **Search Index**: `data/solr`  
- **Uploaded Files**: `data/dataverse`
- **Config**: `data/secrets`

Your data persists even when containers are stopped.

### Starting Fresh

To completely reset your Dataverse installation:

1. Stop all containers:
```powershell
docker compose down
```

2. Delete the data directory:
```powershell
Remove-Item -Path data -Recurse -Force
```

3. Start again:
```powershell
docker compose up
```

⚠️ **Warning**: This deletes ALL data including database, files, and configurations!

## 🧪 Smoke Testing

After installation, verify these basic operations work:

1. ✅ Log in as `dataverseAdmin` (password: `admin1`)
2. ✅ Publish the root collection (dataverse)
3. ✅ Create a new collection
4. ✅ Create a dataset
5. ✅ Upload a data file
6. ✅ Publish the dataset
7. ✅ Search for your dataset

If all tests pass, your Dataverse installation is working correctly!

## 🔍 Troubleshooting & Support

### ⚡ Quick Reference: Common Issues

| Issue | Likely Cause | Documentation |
|-------|-------------|-----------------|
| Payara page instead of Dataverse | Application still deploying | [ERR-FRONTEND-001](docs/errors/frontend-ui.md) |
| Database connection refused | PostgreSQL auth error | [ERR-DB-001](docs/errors/postgres.md) |
| Bootstrap times out | Normal on first deployment | [ERR-DATAVERSE-002](docs/errors/bootstrap-timeout.md) |
| Can't access localhost:8080 | Port in use or app crashed | [ERR-DATAVERSE-001](docs/errors/dataverse-app.md) |
| Browser favicon/tracking warnings | Cosmetic only, no impact | [ERR-FRONTEND-002](docs/errors/browser-resources.md) |

### 📚 Comprehensive Error Documentation

**Full Error Index**: See [docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md)

This includes detailed troubleshooting guides for:
- PostgreSQL database errors
- Dataverse application deployment
- Bootstrap and startup issues
- Frontend/UI problems
- Docker configuration errors
- Browser-related warnings

Each error includes:
- Root cause analysis
- Step-by-step fixes
- Prevention strategies
- Validation procedures

### Common Issues & Solutions

#### Issue: Port Already in Use
**Error**: `Bind for 0.0.0.0:8080 failed: port is already allocated`

**Solution**: Find and stop the service using port 8080:
```powershell
# Find what's using port 8080
netstat -ano | Select-String ":8080"

# Kill the process (replace PID with actual PID from above)
Stop-Process -Id <PID> -Force

# Or change Docker port in compose.yml
# Uncomment/modify the ports section:
# ports:
#   - "8081:8080"  # Use 8081 instead
```

#### Issue: Out of Memory / Container Crashes
**Error**: Containers repeatedly crash or become unresponsive

**Solution**: Increase Docker Desktop memory:
1. Open Docker Desktop Settings
2. Go to **Resources → Memory**
3. Increase to at least **8 GB** (16 GB recommended)
4. Click **Apply & Restart**
5. Restart Dataverse: `docker compose up -d`

#### Issue: Bootstrap Timeout
**Error**: Bootstrap container exits with timeout after ~5 minutes

**Solution**: This is **normal on first deployment**. See [ERR-DATAVERSE-002](docs/errors/bootstrap-timeout.md)

```powershell
# Just wait! Application continues to deploy
docker compose logs -f dataverse | Select-String "deployed|ready|initialized"
```

#### Issue: Cannot Connect to Database
**Error**: `Connection refused` or `FATAL: no pg_hba.conf entry`

**Solution**: See [ERR-DB-001](docs/errors/postgres.md) for detailed fix

```powershell
# Quick fix: Reset database (DELETES ALL DATA)
docker compose down -v
docker compose up -d
```

#### Issue: See Payara Welcome Page Instead of Dataverse
**Error**: Browser shows "Welcome to Payara Server"

**Solution**: Application is still deploying. See [ERR-FRONTEND-001](docs/errors/frontend-ui.md)

**What to do**:
1. Wait 10-30 more minutes for deployment to complete
2. Refresh browser: F5 or Ctrl+R
3. Monitor logs: `docker compose logs -f dataverse`
4. Check API: `curl http://localhost:8080/api/info/version`

#### Issue: Favicon 404 & Tracking Protection Warnings
**Error**: Browser console shows favicon and tracking warnings

**Solution**: These are cosmetic and harmless. See [ERR-FRONTEND-002](docs/errors/browser-resources.md)

```
This indicates:
✅ Browser security features working   
✅ No impact on functionality
✅ No action required
```

### Advanced Troubleshooting

#### View Detailed Logs

```powershell
# Stream logs for specific service
docker compose logs -f dataverse --tail 100

# Search for errors
docker compose logs dataverse | Select-String "ERROR|Exception|FATAL"

# Full audit trail
docker compose logs --timestamps > logs_$(Get-Date -Format yyyyMMdd_HHmmss).txt
```

#### Health Check Verification

```powershell
# Check all containers
docker compose ps

# Check container resource usage
docker stats

# Check disk space
docker system df

# Verify specific service health
docker compose ps dataverse
```

#### Database Diagnostics

```powershell
# Test PostgreSQL connection
docker exec compose-postgres-1 pg_isready -U dataverse

# Check database tables
docker exec compose-postgres-1 psql -U dataverse -d dataverse -c "\dt"

# View PostgreSQL logs
docker compose logs postgres --tail 50
```

#### API Diagnosis

```powershell
# Test API endpoint
$response = Invoke-WebRequest http://localhost:8080/api/info/version -ErrorAction SilentlyContinue
"Status Code: $($response.StatusCode)"
"Content: $($response.Content | ConvertFrom-Json | ConvertTo-Json)"

# Check homepage
Invoke-WebRequest http://localhost:8080/ | Select-Object -ExpandProperty Content | Select-String "Dataverse" | Select-Object -First 5
```

### Still Having Issues?

**Step 1**: Check the error documentation - start with [docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md)

**Step 2**: Enable debug logging:
```powershell
$DebugPreference = "Continue"
docker compose logs -f --timestamps
```

**Step 3**: Community support:
- Dataverse Community: https://dataverse.org/community
- GitHub Issues: https://github.com/IQSS/dataverse/issues
- Google Group: https://groups.google.com/g/dataverse-community

**Step 4**: When reporting issues, include:
- `docker compose ps` output
- `docker compose logs --tail 100` from all services
- Your system specs (RAM, disk, OS)
- Steps to reproduce

## 🎨 Advanced Configuration

### Environment Variables

Create a `.env` file to customize settings:

```properties
# Dataverse version
DATAVERSE_VERSION=latest

# Database settings
POSTGRES_VERSION=13
POSTGRES_USER=dataverse
POSTGRES_PASSWORD=your_secure_password
POSTGRES_DATABASE=dataverse

# Solr settings
SOLR_VERSION=9.3.0

# Application settings
DATAVERSE_URL=http://localhost:8080
```

### Database Configuration

After Dataverse starts, configure settings via API:

**Dev Mode** (no authentication needed):
```powershell
curl -X PUT -d "My Organization" "http://localhost:8080/api/admin/settings/:FooterCopyright"
```

**Demo Mode** (requires unblock key):
```powershell
curl -X PUT -d "My Organization" "http://localhost:8080/api/admin/settings/:FooterCopyright?unblock-key=your_key_here"
```

### Customize Root Collection

Before first startup, customize the root collection:

1. Create config directory:
```powershell
mkdir demo\config
```

2. Download template:
```powershell
Invoke-WebRequest -Uri "https://guides.dataverse.org/en/latest/_downloads/78ade9231d6876a7c9fa1ff095c446bd/dataverse-complete.json" -OutFile "demo\config\dataverse-complete.json"
```

3. Edit `dataverse-complete.json` to customize name, description, etc.

4. Start Dataverse - it will use your custom settings.

### File Previewers

Dataverse includes previews for various file types:
- Text files
- HTML
- PDF
- Images
- CSV/TSV
- And more...

To limit available previewers, edit `compose.yml`:
```yaml
file_previewers:
  environment:
    - INCLUDE_PREVIEWERS=text,html,pdf,csv
```

### Multiple Languages

To enable language selection (e.g., English/French):

1. Configure language directory in `compose.yml`:
```yaml
dataverse:
  environment:
    - JVM_ARGS=-Ddataverse.lang.directory=/dv/lang
```

2. Upload language files:
```powershell
curl "http://localhost:8080/api/admin/datasetfield/loadpropertyfiles?unblock-key=your_key" -X POST --upload-file languages.zip -H "Content-Type: application/zip"
```

3. Enable language toggle:
```powershell
curl "http://localhost:8080/api/admin/settings/:Languages?unblock-key=your_key" -X PUT -d '[{"locale":"en","title":"English"},{"locale":"fr","title":"Français"}]'
```

## 📦 Container Architecture

### Container List

Running `docker ps` shows these containers:

| Container | Purpose | Port |
|-----------|---------|------|
| **dataverse** | Main application (Payara server) | 8080 |
| **postgres** | PostgreSQL database | 5432 |
| **solr** | Search engine (Apache Solr) | 8983 |
| **smtp** | Email server (for notifications) | 25 |
| **bootstrap** | Initial configuration (exits after setup) | - |

### Data Flow

```
User Browser
    ↓
Dataverse Application (Port 8080)
    ↓
├── PostgreSQL Database → Metadata storage
├── Solr Search Engine → Full-text search
├── File System → Binary file storage
└── SMTP Server → Email notifications
```

## 🏗️ Compose.yml Structure

<details>
<summary>Click to see minimal compose.yml example</summary>

```yaml
version: "3.8"

services:
  dataverse:
    container_name: dataverse
    image: gdcc/dataverse:latest
    ports:
      - "8080:8080"
    environment:
      - POSTGRES_HOST=postgres
      - POSTGRES_PORT=5432
      - POSTGRES_USER=dataverse
      - POSTGRES_PASSWORD=secret
      - SOLR_HOST=solr
      - SOLR_PORT=8983
    depends_on:
      - postgres
      - solr
    volumes:
      - dataverse-data:/dv
    networks:
      - dataverse

  postgres:
    container_name: postgres
    image: postgres:13
    environment:
      - POSTGRES_USER=dataverse
      - POSTGRES_PASSWORD=secret
      - POSTGRES_DB=dataverse
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - dataverse

  solr:
    container_name: solr
    image: solr:9.3.0
    volumes:
      - solr-data:/var/solr
    networks:
      - dataverse

  bootstrap:
    container_name: bootstrap
    image: gdcc/configbaker:latest
    restart: "no"
    command:
      - bootstrap.sh
      - dev
    environment:
      - TIMEOUT=3m
    networks:
      - dataverse
    depends_on:
      - dataverse

volumes:
  dataverse-data:
  postgres-data:
  solr-data:

networks:
  dataverse:
```
</details>

## 📚 Additional Resources

### Official Documentation
- **Dataverse Official Site**: https://dataverse.org
- **User Guide**: https://guides.dataverse.org/en/latest/user/
- **API Guide**: https://guides.dataverse.org/en/latest/api/
- **Installation Guide**: https://guides.dataverse.org/en/latest/installation/
- **Container Guide**: https://guides.dataverse.org/en/latest/container/

### Community
- **Dataverse Community**: https://dataverse.org/community  
- **GitHub Repository**: https://github.com/IQSS/dataverse
- **Google Group**: https://groups.google.com/g/dataverse-community
- **Slack Channel**: https://dataverse.org/slack

## 📄 License

Dataverse is open source software released under the Apache License 2.0.

## 🙏 Acknowledgments

Dataverse is developed at the [Institute for Quantitative Social Science](http://www.iq.harvard.edu/) at Harvard University.

---

**Ready to get started?** Run `docker compose up` and visit http://localhost:8080!
