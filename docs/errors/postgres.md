# PostgreSQL Database Errors

Error ledger for PostgreSQL-related issues in Dataverse deployment.

---

## Error ID: ERR-DB-001

**Title:** PostgreSQL pg_hba.conf Authentication Error on Container Restart  
**Timestamp:** 2026-04-10 21:28:44 UTC  
**Environment:** Dev / Demo / Production  
**Severity:** 🔴 Critical (blocks application deployment)  

---

## Symptom

After restarting Docker containers, Dataverse fails to deploy with the following error in logs:

```
FATAL: no pg_hba.conf entry for host "172.19.0.5", user "dataverse", database "dataverse", SSL off
```

Application logs show:
```
Exception [EclipseLink-4002]: DatabaseException
Internal Exception: java.sql.SQLException: Error in allocating a connection.
Cause: Connection could not be allocated because: FATAL: no pg_hba.conf entry...
```

**Observable behavior:**
- ❌ Port 8080 returns Payara admin page (not Dataverse)
- ❌ Dataverse application cannot deploy
- ❌ Bootstrap container times out
- ✅ PostgreSQL container shows as "healthy"
- ✅ Payara server starts successfully

---

## Root Cause

When Docker containers restart:

1. PostgreSQL IP address changes (Docker assigns new IP from pool)
2. The new IP address is not in the `pg_hba.conf` file
3. PostgreSQL rejects connection attempts from the new unknown IP
4. Dataverse cannot initialize because database is unreachable

**Why it happens:**
- Docker volumes persist, but `pg_hba.conf` is inside the volume
- On restart, PostgreSQL loads the old `pg_hba.conf` with old/missing IP entries
- New Dataverse container starts with a different IP
- Connection authentication fails

---

## Fix

### Quick Fix (Recommended for Dev)

**Reset the database completely:**

```powershell
cd configs

# 1. Stop all services
docker-compose -f compose.yml down -v

# 2. Remove all volumes to force recreation
docker volume rm $(docker volume ls -q | Select-String dataverse) -Force

# 3. Start fresh
docker-compose -f compose.yml up -d

# 4. Wait for initialization
Start-Sleep -Seconds 30

# 5. Verify status
docker-compose -f compose.yml ps
```

**Expected output:**
```
STATUS
Up 30 seconds (health: starting)
Up 37 seconds (healthy)
Up 37 seconds (healthy)
```

---

### Alternative Fix (Preserve Data)

**If you have important data in PostgreSQL:**

```powershell
# 1. Backup the database FIRST
docker exec compose-postgres-1 pg_dump -U dataverse dataverse > backup_$(Get-Date -Format yyyyMMdd).sql

# 2. Stop containers (but keep volumes)
docker-compose -f compose.yml down

# 3. Inspect the old pg_hba.conf
docker run --rm -v postgres-data:/data alpine cat /data/pg_hba.conf

# 4. Remove just postgres volume to reinitialize
docker volume rm configs_postgres-data

# 5. Restart
docker-compose -f compose.yml up -d

# 6. Wait for PostgreSQL to initialize
Start-Sleep -Seconds 15

# 7. Restore your backup
cat backup_*.sql | docker exec -i compose-postgres-1 psql -U dataverse dataverse
```

---

## Prevention

### For Development (Enable Auto-Recovery)

Add this to `compose.yml` PostgreSQL section:

```yaml
postgres:
  image: postgres:13
  environment:
    POSTGRES_DB: dataverse
    POSTGRES_USER: dataverse
    POSTGRES_PASSWORD: ${DB_PASSWORD:-secret}
  volumes:
    - postgres-data:/var/lib/postgresql/data
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U dataverse"]
    interval: 10s
    timeout: 5s
    retries: 5
  # Auto-restart if health check fails
  restart: unless-stopped
```

### For Production (Better Solution)

Use **Docker named volumes** with proper initialization:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_INITDB_ARGS: "-c host_based_authentication=trust"
      # OR use custom init script:
      # POSTGRES_INITDB_ARGS: "-c hba_file=/docker-entrypoint-initdb.d/pg_hba.conf"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      # Optional: Mount custom pg_hba.conf
      # - ./config/pg_hba.conf:/etc/postgresql/pg_hba.conf:ro
    restart: unless-stopped

volumes:
  postgres-data:
    driver: local
```

### Monitor & Alert

Add health monitoring:

```powershell
# Monitor database health
while ($true) {
    $status = docker exec compose-postgres-1 pg_isready -U dataverse
    if ($status -ne "accepting connections") {
        Write-Host "⚠️ Database health warning!" -ForegroundColor Yellow
        # Send alert here
    }
    Start-Sleep -Seconds 60
}
```

---

## Validation

### How to Verify the Fix

```powershell
# 1. Check PostgreSQL is healthy
docker-compose -f compose.yml ps
# Should show: postgres ... Healthy ✅

# 2. Test database connection
docker exec compose-postgres-1 psql -U dataverse -d dataverse -c "SELECT version();" 
# Should return: PostgreSQL 13.x ...

# 3. Check Dataverse can connect
docker compose logs dataverse | Select-String "database" | Select-Object -First 5
# Should show: "Creating a connection..." or "Connected" (no errors)

# 4. Verify Dataverse deployed
curl http://localhost:8080/api/info/version
# Should return JSON with version info (HTTP 200)

# 5. Check homepage loads
$html = Invoke-WebRequest http://localhost:8080/
if ($html.Content -match "Dataverse") { 
    Write-Host "✅ Dataverse UI loaded successfully" 
} else { 
    Write-Host "❌ Still showing Payara page" 
}
```

---

## Related Issues

- **ERR-DATAVERSE-001** - Application fails to deploy (caused by this DB connection error)
- **ERR-DATAVERSE-002** - Bootstrap timeout (consequence of DB unavailability)
- **ERR-COMPOSE-001** - Docker networking issues

---

## Timeline & History

| Date | Status | Notes |
|------|--------|-------|
| 2026-04-10 21:05 | Discovered | Initial deployment worked |
| 2026-04-10 21:28 | Error Detected | Containers restarted, pg_hba.conf mismatch |
| 2026-04-10 21:31 | Root Cause Found | IP address mismatch in pg_hba.conf |
| 2026-04-10 21:35 | Fixed | Database volume reset, fresh initialization |
| 2026-04-10 21:37 | Verified | All services healthy, Dataverse deployed |

---

## Additional Resources

- [PostgreSQL Documentation: Client Authentication](https://www.postgresql.org/docs/13/client-authentication.html)
- [Docker PostgreSQL Image](https://hub.docker.com/_/postgres)
- [Docker Network Guide](https://docs.docker.com/network/)
- [Dataverse Database Setup](https://guides.dataverse.org/en/latest/container/dev-environment.html)

---

## Notes for Next Time

- Consider using `host: all` in `pg_hba.conf` for development environments
- For production, maintain a static IP range or use service-to-service discovery
- Always backup database before attempting fixes
- Document any custom PostgreSQL configuration changes
