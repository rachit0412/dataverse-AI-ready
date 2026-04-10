# Docker Compose Configuration Errors

This ledger tracks errors related to Docker Compose configuration and container orchestration.

---

## Error ID: ERR-COMPOSE-001

**Timestamp:** 2026-04-10 21:49:00 UTC  
**Environment:** Local development (Windows with WSL2)  
**Severity:** High (blocks deployment)  
**Status:** Resolved

### Symptom

Dataverse container fails to start with health check failing after 5+ minutes. Docker Compose reports:

```
Container dataverse           Waiting 333.5s
✘ Container dataverse          Error dependency dataverse failed to start
dependency failed to start: container dataverse is unhealthy
```

### Error Messages

From `docker compose logs dataverse`:

```
[SEVERE] Exception [EclipseLink-4002] 
Internal Exception: java.sql.SQLException: Error in allocating a connection. 
Cause: Connection could not be allocated because: Connection to localhost:5432 refused. 
Check that the hostname and port are correct and that the postmaster is accepting TCP/IP connections.
Error Code: 0
```

### Root Cause

**Technical Explanation:**

The initial `compose.yml` used bind mount volumes with Windows-style paths:

```yaml
volumes:
  postgres-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ./data/postgres
```

On Windows with WSL2, these bind mounts can cause Docker networking issues where:
1. The Dataverse container cannot properly resolve Docker service hostnames
2. Database connection attempts to `postgres:5432` fail or route incorrectly to `localhost:5432`
3. Health checks fail because the application cannot connect to dependencies

**Why it happens:**
- Windows path handling in Docker volume bind mounts
- WSL2 filesystem translation layers interfering with container networking
- Docker Desktop on Windows experimental support for bind mounts with complex paths

### Fix

**Step 1: Change volume configuration** from bind mounts to Docker-managed volumes:

```yaml
# configs/compose.yml (updated)
volumes:
  postgres-data:
  solr-data:
  dataverse-data:
```

**Step 2: Restart deployment:**

```powershell
# Clean up old deployment
docker compose -f configs\compose.yml down -v

# Start with fixed configuration
docker compose -f configs\compose.yml up -d
```

**Commit:** Updated compose.yml volumes (ERR-COMPOSE-001 fix)

### Prevention

**For future development:**

1. **Use Docker-managed volumes** for cross-platform compatibility
   - Works consistently across Windows/macOS/Linux
   - No path translation issues
   - Docker handles filesystem differences

2. **If bind mounts are required** (for backup/access):
   - Use Linux-style paths in WSL2: `/mnt/c/path/to/data`
   - OR use Docker Desktop's bind mount proxy
   - OR add volume mapping in `.wslconfig`

3. **Test on target platform early**
   - Verify containers start and connect
   - Check health checks pass within expected time
   - Validate inter-container networking

### Validation

**Verify fix worked:**

```powershell
# 1. Check all containers are healthy
docker compose -f configs\compose.yml ps
# Expected: All containers show "Up (healthy)" status

# 2. Check Dataverse can connect to database
docker compose -f configs\compose.yml logs dataverse | Select-String "deployed|ready"
# Expected: See successful deployment messages

# 3. Test API endpoint
curl http://localhost:8080/api/info/version
# Expected: JSON response with version info
```

### Related

- **Issue:** #N/A (discovered during initial testing)
- **PR:** Pending (fix applied, needs commit)
- **Similar errors:** None yet
- **Documentation:** Updated EXECUTION_PLAN_LOCAL.md to note Windows-specific considerations

### Notes

**Platform compatibility:**
- ✅ Docker-managed volumes: Works on all platforms
- ⚠️ Bind mounts: Requires platform-specific paths
- ❌ Windows paths in bind mounts: Not reliable with Docker networking

**Data access:**
To access data in Docker-managed volumes:
```powershell
# Find volume location
docker volume inspect configs_postgres-data

# Or use docker cp
docker cp postgres:/var/lib/postgresql/data ./backup
```

**Trade-offs:**
- ✅ Pro: Reliable networking, cross-platform
- ⚠️ Con: Data not directly accessible in filesystem (requires docker cp or volume inspect)
- 💡 Alternative: Use separate bind mount for backups only

---

*Last updated: 2026-04-10*
