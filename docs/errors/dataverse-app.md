# Dataverse Application Deployment Errors

Error ledger for Dataverse application (Payara) deployment issues.

---

## Error ID: ERR-DATAVERSE-001

**Title:** Application Fails to Deploy - Database Connection Refused  
**Timestamp:** 2026-04-10 21:28:44 UTC  
**Environment:** Dev / Demo / Production  
**Severity:** 🔴 Critical (prevents API requests)  

---

## Symptom

Dataverse application starts but does not fully deploy. Web interface shows Payara admin page instead of Dataverse UI:

```
http://localhost:8080 → Shows "Welcome to Payara Server"
```

Application logs show repeated errors:

```
javax.persistence.PersistenceException: Exception [EclipseLink-4002]: DatabaseException
Internal Exception: java.sql.SQLException: Error in allocating a connection.
Cause: Connection could not be allocated because: FATAL: no pg_hba.conf entry...
```

**Observable behavior:**
- ❌ Dataverse homepage not loading
- ❌ `localhost:8080/api/info/version` returns HTTP 500
- ❌ Bootstrap times out waiting for API
- ✅ Payara server is running (port 8080 responding)
- ✅ No container crashes (status shows "Up")

---

## Root Cause Analysis

This is typically a **secondary symptom** of the PostgreSQL authentication issue (ERR-DB-001).

### Primary Causes (in order of likelihood)

1. **PostgreSQL Connection Failed** ← Most Common
   - Database is unreachable from application container
   - Network connectivity issue
   - Authentication failure (see ERR-DB-001)
   
2. **Database Schema Not Initialized**
   - Tables don't exist
   - Migration scripts haven't run
   - Database has wrong charset/encoding

3. **Dataverse Configuration Missing**
   - `domain.xml` or `settings.xml` not configured
   - API key not set
   - Base URL misconfigured

4. **Insufficient Resources**
   - Payara running out of memory
   - Container CPU throttled
   - Disk space full

5. **Port Conflict**
   - Another service using port 8080
   - Docker port mapping failed

---

## Fix

### Step 1: Verify PostgreSQL Connection

```powershell
# Check if PostgreSQL is accepting connections
docker exec compose-postgres-1 pg_isready -U dataverse
# Expected: "accepting connections"

# Test direct connection
docker exec compose-postgres-1 psql -U dataverse -d dataverse -c "SELECT COUNT(*) FROM pg_tables;"
# Should return a number (list of tables)
```

**If PostgreSQL is NOT responding:**
- Follow the fix in **ERR-DB-001** (PostgreSQL errors)
- Reset database volumes
- Restart containers

---

### Step 2: Monitor Dataverse Startup

```powershell
# Follow the Dataverse deployment logs
docker-compose -f compose.yml logs -f dataverse | Select-String -Pattern "deployment|deployed|ERROR|Exception" -Context 2

# Watch for these good signs:
# ✅ "deployment astradb started successfully"
# ✅ "POST http://localhost:8080/api/info/version HTTP 200"
# ✅ "Application Initialized"

# Bad signs to stop and troubleshoot:
# ❌ "FATAL" keyword
# ❌ "DatabaseException"
# ❌ "Connection refused"
```

**Expected startup timeline:**
```
00:05 - Container created
00:10 - Payara starting
00:15-00:45 - WAR file deployment (longest phase)
00:45 - Database migrations running
01:00+ - Application ready
```

If deployment stalls:
1. Stop containers: `docker-compose -f compose.yml down`
2. Check logs for errors: `docker-compose -f compose.yml logs dataverse | tail -100`
3. See section below: "Troubleshooting Stuck Deployment"

---

### Step 3: Restart Application

```powershell
# Option A: Soft restart (keep containers)
docker-compose -f compose.yml restart dataverse
Start-Sleep -Seconds 10

# Option B: Hard restart (recreate containers)
docker-compose -f compose.yml up -d  # This will recreate if needed

# Option C: Full reset (use only if Option B fails)
docker-compose -f compose.yml down
docker-compose -f compose.yml up -d
```

---

### Step 4: Verify Deployment Success

```powershell
# 1. Check container status
docker-compose -f compose.yml ps dataverse
# Should show: "Up X minutes"

# 2. Check application logs for deployed message
docker-compose -f compose.yml logs dataverse | Select-String "deployed successfully"

# 3. Test API endpoint
$response = Invoke-WebRequest http://localhost:8080/api/info/version -ErrorAction SilentlyContinue
if ($response.StatusCode -eq 200) { 
    Write-Host "✅ Application deployed successfully!"
    Write-Host "Version: $($response.Content | ConvertFrom-Json | Select -ExpandProperty version)"
} else {
    Write-Host "❌ Application still not ready (HTTP $($response.StatusCode))"
}

# 4. Try loading homepage
curl http://localhost:8080/ | Select-String "Dataverse" | Select-Object -First 1

# 5. Check if you can access login page
$html = Invoke-WebRequest http://localhost:8080/dataverse/faces/login.xhtml -ErrorAction SilentlyContinue
if ($html.Content -match "Login") {
    Write-Host "✅ Dataverse UI loaded!"
} else {
    Write-Host "❌ Still showing Payara page or error"
}
```

---

## Troubleshooting Stuck Deployment

### Scenario: Deployment takes too long (> 2 hours)

```powershell
# 1. Check the current deployment log
docker-compose -f compose.yml logs dataverse > deployment_log.txt
Get-Content deployment_log.txt | Tail -50  # Last 50 lines

# 2. Search for specific errors
Select-String "ERROR|Exception|FAILED" deployment_log.txt | Select -First 10

# 3. Check Payara server log (if accessible)
docker exec compose-dataverse-1 cat /opt/payara/logs/payara.log | Tail -50
```

**If stuck on "Undeploying" or "Deploying astradb":**
```powershell
# Force restart
docker-compose -f compose.yml down
docker-compose -f compose.yml rm -f dataverse
docker volume rm configs_dataverse-data  # WARNING: Deletes uploaded data!
docker-compose -f compose.yml up -d dataverse

# Wait 60 seconds
Start-Sleep -Seconds 60

# Check if it's deploying now
docker-compose -f compose.yml logs dataverse | Tail -20
```

---

### Scenario: High Memory Usage (App crashes)

```powershell
# Check memory usage
docker stats compose-dataverse-1 --no-stream

# Increase heap size in compose.yml
# Find and modify:
dataverse:
  environment:
    JAVA_HEAP_SIZE: "-Xms2g -Xmx4g"  # Increase from default
```

---

### Scenario: Port 8080 Already in Use

```powershell
# Find what's using port 8080
netstat -ano | Select-String ":8080"

# Or use PowerShell
Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue

# If another service is using it:
# Stop that service and restart Docker containers
```

---

## Prevention

### For Development

1. **Add startup health checks:**

```yaml
dataverse:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/api/info/version"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 120s  # Give 2 minutes before first check
  restart: unless-stopped
```

2. **Monitor startup progress:**

```powershell
# Create a startup monitor script
while ($true) {
    $logs = docker-compose logs dataverse | Select-String "deployed successfully"
    if ($logs) {
        Write-Host "✅ Deployment complete!" -ForegroundColor Green
        break
    } else {
        Write-Host "⏳ Still deploying..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }
}
```

### For Production

1. **Use container orchestration:**
   - Enable automatic restart even if deployment partially fails
   - Set resource limits and requests
   - Use readiness probes

2. **Database setup verification:**
   ```powershell
   # Before starting Dataverse:
   docker-compose -f compose.yml up -d postgres
   Start-Sleep -Seconds 30
   docker exec compose-postgres-1 psql -U dataverse -d dataverse -c "\dt"
   # Should list Dataverse tables
   ```

3. **Pre-flight checks:**
   ```powershell
   # Create a health check script
   $checks = @{
       "PostgreSQL" = "docker exec compose-postgres-1 pg_isready -U dataverse"
       "Solr" = "curl -s http://localhost:8983/solr/admin/ping"
       "Disk Space" = "df -h"
   }
   
   # Run all checks before deploying
   foreach ($check in $checks.Keys) {
       Write-Host "Checking: $check"
       # ... execute check
   }
   ```

---

## Related Issues

- **ERR-DB-001** - PostgreSQL connection issue (root cause)
- **ERR-DATAVERSE-002** - Bootstrap timeout (consequence)
- **ERR-FRONTEND-001** - User sees Payara instead of Dataverse (visible symptom)

---

## Timeline & History

| Date | Status | Notes |
|------|--------|-------|
| 2026-04-10 21:05 | First Attempt | Deployment started, DB connection failed immediately |
| 2026-04-10 21:10 | Diagnosed | Identified PostgreSQL as root cause (ERR-DB-001) |
| 2026-04-10 21:35 | Fixed | Reset database, restarted Dataverse |
| 2026-04-10 21:40 | Verified | Dataverse deployed successfully, API responding |

---

## Additional Resources

- [Dataverse Installation Guide](https://guides.dataverse.org/en/latest/installation/)
- [Payara Server Documentation](https://docs.payara.fish/)
- [Java Heap Size Configuration](https://docs.oracle.com/javase/8/docs/technotes/tools/windows/java.html)
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)

---

## Notes for Next Time

- Deployment time is normal - be patient (up to 1 hour)
- Always check PostgreSQL connectivity FIRST before troubleshooting Dataverse
- Monitor logs actively - look for database errors
- Keep backup of working database state
- Document any custom configuration changes
