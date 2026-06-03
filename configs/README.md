# Dataverse Docker Deployment - Quick Reference

## Quick Start

### 1. First Time Setup

```powershell
# Navigate to project directory
cd path\to\dataverse-AI-ready

# Create .env file from template (optional — defaults are provided in compose.yml)
Copy-Item configs\.env.example .env

# Edit .env and set strong password for POSTGRES_PASSWORD
notepad .env
```

> **Note:** Data is stored in Docker named volumes (`dataverse-postgres-data`, `dataverse-solr-data`, `dataverse-app-data`), not in local directories.

### 2. Start Dataverse

**Option A: Enterprise startup script** (recommended):
```powershell
.\scripts\start.ps1
```
This builds solr-init, starts all containers, waits for readiness, and opens the browser.

**Option B: Manual:**
```powershell
# Start in foreground (see logs)
docker compose -f configs\compose.yml up

# OR start in background
docker compose -f configs\compose.yml up -d
```

**Wait time:** 10-15 minutes on first run (bootstrap configuration)

### 3. Access

- **URL:** http://localhost:8080
- **Username:** `dataverseAdmin`
- **Password:** `admin1`

**IMPORTANT:** Change default password after first login!

---

## Daily Operations

### View Logs

```powershell
# All containers
docker compose -f configs\compose.yml logs -f

# Specific container
docker compose -f configs\compose.yml logs -f dataverse
docker compose -f configs\compose.yml logs -f postgres
```

### Check Status

```powershell
docker compose -f configs\compose.yml ps
```

### Stop Dataverse

```powershell
# Graceful stop (preserves data)
docker compose -f configs\compose.yml stop

# Or use Ctrl+C if running in foreground
```

### Start Again (with existing data)

```powershell
docker compose -f configs\compose.yml up -d
```

---

## Troubleshooting

### Bootstrap Timeout

If bootstrap fails, increase timeout:

1. Edit `.env`
2. Set `BOOTSTRAP_TIMEOUT=10m`
3. Restart: `docker compose -f configs\compose.yml restart bootstrap`

### Port 8080 Conflict

If port 8080 is in use:

1. Edit `.env`
2. Change `DATAVERSE_PORT=8081` (or another free port)
3. Restart containers

### Out of Memory

1. Open Docker Desktop Settings
2. Resources → Memory → Increase to 8 GB minimum
3. Apply & Restart

### View Container Logs

```powershell
# Dataverse application logs
docker compose -f configs\compose.yml logs -f dataverse

# Database logs
docker compose -f configs\compose.yml logs -f postgres

# Search engine logs
docker compose -f configs\compose.yml logs -f solr

# Bootstrap logs
docker compose -f configs\compose.yml logs bootstrap
```

---

## Complete Reset (Start Fresh)

**⚠️ WARNING: This deletes ALL data!**

```powershell
# Stop and remove containers + volumes
docker compose -f configs\compose.yml down -v

# Start again
.\scripts\start.ps1
```

---

## Demo Mode (Recommended for Non-Localhost)

For deployments beyond localhost testing:

1. Edit `configs\demo\init.sh`:
   - Generate random key: `openssl rand -hex 32`
   - Replace `UNBLOCK_KEY="changeme-replace-with-random-key"`

2. Edit `configs\compose.yml`:
   - Find bootstrap service
   - Change `command: - dev` to `command: - demo`
   - Uncomment volume mount: `- ./configs/demo:/scripts/bootstrap/demo`

3. Restart:
   ```powershell
   docker compose -f configs\compose.yml down
   docker compose -f configs\compose.yml up -d
   ```

4. Note unblock key from logs for admin API access

---

## Health Check

```powershell
# Automated health check (recommended)
.\scripts\healthcheck.ps1 -Detailed

# Or manually:
docker compose -f configs\compose.yml ps

# Test API endpoint
Invoke-RestMethod http://localhost:8080/api/info/version
```

---

## Data Backup (Recommended)

See `scripts\backup.ps1` for automated backup procedures.

```powershell
# Automated backup with retention
.\scripts\backup.ps1

# Quick manual database backup
docker exec postgres pg_dump -U dataverse dataverse > backup_db.sql
```

---

## Integration Tests

```powershell
# Run 8 REST API integration tests
.\INTEGRATION_TEST_RUNNER.ps1
```

---

## Documentation

- **Full Installation Guide:** [INSTALLATION_GUIDE.md](../INSTALLATION_GUIDE.md)
- **Architecture:** [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md)
- **Security:** [docs/SECURITY.md](../docs/SECURITY.md)
- **Operations:** [docs/OPERATIONS.md](../docs/OPERATIONS.md)
- **Testing:** [TESTING_QUICK_REFERENCE.md](../TESTING_QUICK_REFERENCE.md)
- **Error Index:** [docs/ERRORS_AND_SOLUTIONS.md](../docs/ERRORS_AND_SOLUTIONS.md)

---

## Support

- **Logs:** `docker compose -f configs\compose.yml logs -f`
- **Status:** `docker compose -f configs\compose.yml ps`
- **Dataverse Community:** https://dataverse.org/community
- **GitHub Issues:** https://github.com/IQSS/dataverse/issues
