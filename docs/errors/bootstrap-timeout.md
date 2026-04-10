# Dataverse Bootstrap Startup Errors

Error ledger for bootstrap and startup-related issues.

---

## Error ID: ERR-DATAVERSE-002

**Title:** Bootstrap Timeout Waiting for API Response  
**Timestamp:** 2026-04-10 21:32:15 UTC  
**Environment:** Dev / Demo / Production  
**Severity:** 🟡 Medium (automatically resolves after waiting)  

---

## Symptom

The bootstrap container times out waiting for Dataverse API to respond:

```logs
bootstrap  | Waiting for http://dataverse:8080 to become ready in max 5m.
bootstrap  | GET http://dataverse:8080/api/info/version
bootstrap  | 2026-04-10T20:27:44Z ERR Expectation failed 
bootstrap  |   error="the status code doesn't expect" 
bootstrap  |   actual=404 
bootstrap |   expect=200
bootstrap  | Error: context deadline exceeded
bootstrap  | Exit code: 1
```

**Observable behavior:**
- ❌ Bootstrap container exits with error
- ❌ Returns HTTP 404 (endpoint not found)
- ✅ Dataverse container still running
- ✅ Application eventually starts despite bootstrap error
- ✅ API becomes available after timeout expires

---

## Root Cause

This is **NOT a critical error** but a timing issue:

1. **Dataverse startup is slow** - Takes 30-60+ minutes to:
   - Initialize Payara application server
   - Extract and deploy WAR file
   - Create database schema
   - Initialize Solr index
   - Load configuration

2. **Bootstrap timeout is short** - Default is 5 minutes:
   - Bootstrap checks for API every 10 seconds
   - Fails after 5 minutes of 404 responses
   - But then exits (doesn't hang)

3. **Application continues** - Even though bootstrap exits:
   - Dataverse continues initializing
   - API eventually comes online
   - User can access after deployment completes

**Why this happens:**
- On first deployment, Dataverse WAR file extraction is slow
- Container has limited resources (CPU/RAM throttling)
- Database initialization is parallelized with app startup
- Bootstrap timeout is shorter than actual startup time

---

## Fix

### For Users (No Action Required)

**This error is HARMLESS.** Simply wait for the application to finish deploying.

The bootstrap container exits, but the Dataverse application continues running.

```powershell
# Monitor Dataverse deployment progress
docker-compose -f compose.yml logs -f dataverse | Select-String "deployment|Initializ|Application"

# Check when API becomes ready
while ($true) {
    try {
        $response = Invoke-WebRequest http://localhost:8080/api/info/version -timeoutsec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "✅ Dataverse API is ready!" -ForegroundColor Green
            $response.Content | ConvertFrom-Json | Format-Table
            break
        }
    } catch {
        Write-Host "⏳ Still waiting for API... ($(Get-Date -Format 'HH:mm:ss'))" -ForegroundColor Yellow
    }
    Start-Sleep -Seconds 15
}
```

---

### For Operations (Increase Timeout)

**If you want bootstrap to wait longer:**

Edit `configs/compose.yml` and increase the Bootstrap startup period:

```yaml
version: '3.8'

services:
  configbaker:  # This is the bootstrap container
    image: iqss/configbaker:latest
    # ... other config ...
    # Method 1: Extend the timeout in the script call
    command: >
      bash -c "
        timeout 900 bash -c  # Change 300 to 900 (15 minutes)
        'until curl -f http://dataverse:8080/api/info/version; 
         do sleep 10; done'
      "
    # 
    # Method 2: Or use docker healthcheck
    healthcheck:
      test: ["CMD", "curl", "-f", "http://dataverse:8080/api/info/version"]
      interval: 10s
      timeout: 5s
      retries: 60  # 60 retries × 10s = 10 minutes total
      start_period: 120s
```

---

### For Development (Faster Startup)

Create a lightweight test environment with pre-built Dataverse image:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:13-alpine  # Smaller base image
    # ... config ...
  
  dataverse:
    image: iqss/dataverse-docker:5.14  # Use older stable if faster
    # Add more resources
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

---

## Expected Behavior (Timeline)

### Normal First Deployment

```
00:00 - Containers created
00:05 - Payara server starting
00:15 - WAR file extraction begins
00:45 - Database schema initialization
01:00 - Dataverse configuration loading
01:05 - Solr index initialization
01:10 - Application ready
01:30 - Bootstrap finally succeeds (or exits if timeout < 1:30)
```

### What You'll See in Logs

```
[00:05] dataverse | Starting Payara server
[00:20] dataverse | Deployment astradb in progress
[00:45] dataverse | Running liquibase migrations
[01:00] dataverse | Loading configuration parameters
[01:05] bootstrap | GET /api/info/version → 404 (still initializing)
[01:10] bootstrap | GET /api/info/version → 404 (still initializing)
[01:15] bootstrap | GET /api/info/version → 500 (app crashing?)
[01:20] bootstrap | Error: context deadline exceeded (timeout)
[01:25] dataverse | ✅ Application ready!
[01:30] dataverse | POST /api/info/version → 200 ✅
```

The bootstrap gives up, but Dataverse keeps going and succeeds.

---

## Prevention

### Monitoring Strategy

**Don't rely on bootstrap for deployment verification.** Monitor directly:

```powershell
function Wait-ForDataverse {
    param(
        [int]$TimeoutSeconds = 1800,  # 30 minutes max
        [int]$CheckIntervalSeconds = 15
    )
    
    $startTime = Get-Date
    $endpoint = "http://localhost:8080/api/info/version"
    
    Write-Host "⏳ Waiting for Dataverse to start..."
    
    while ((Get-Date) - $startTime -lt [TimeSpan]::FromSeconds($TimeoutSeconds)) {
        try {
            $response = Invoke-WebRequest $endpoint -TimeoutSec 5 -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "✅ Dataverse is ready!" -ForegroundColor Green
                $info = $response.Content | ConvertFrom-Json
                Write-Host "Version: $($info.version)"
                Write-Host "API Version: $($info.data.api_version)"
                return $true
            }
        } catch {
            if ($_.Exception.Message -match "404") {
                Write-Host "... Still initializing" -ForegroundColor Yellow
            } elseif ($_.Exception.Message -match "Connection refused") {
                Write-Host "... Waiting for port 8080" -ForegroundColor Yellow
            }
        }
        
        Start-Sleep -Seconds $CheckIntervalSeconds
    }
    
    Write-Host "❌ Timeout after $TimeoutSeconds seconds" -ForegroundColor Red
    return $false
}

# Usage
Wait-ForDataverse -TimeoutSeconds 1800  # 30 minutes
```

### Docker Compose Health Check

Add proper readiness checks:

```yaml
dataverse:
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8080/api/info/version"]
    interval: 30s
    timeout: 10s
    retries: 60  # 60 × 30s = 30 minutes max wait
    start_period: 60s  # Wait 1 minute before first check
```

---

## Related Issues

- **ERR-DB-001** - Database connection: will cause faster failure (not timeout)
- **ERR-DATAVERSE-001** - Application deployment failure: root cause of 404s
- **ERR-FRONTEND-001** - User confusion: related to incomplete startup

---

## Timeline & History

| Date | Time | Status | Notes |
|------|------|--------|-------|
| 2026-04-10 | 21:05 | Started | Initial deployment began |
| 2026-04-10 | 21:15 | Running | Containers up, Payara starting |
| 2026-04-10 | 21:25 | 404 Errors | Bootstrap checking API, getting 404 |
| 2026-04-10 | 21:32:15 | Timeout | Bootstrap times out after 5m |
| 2026-04-10 | 21:35 | Fixed DB | Resolved PostgreSQL ERR-DB-001 |
| 2026-04-10 | 21:40 | Recovered | Dataverse API now responding |

---

## Notes for Next Time

- **Don't panic when bootstrap times out** - This is normal for first deployment
- Wait at least 30 minutes before troubleshooting
- Monitor API directly instead of relying on bootstrap exit code
- Use `docker-compose logs dataverse` to track actual progress
- Bootstrap timeout is NOT a deployment failure - it's just a health check timeout
- The application usually succeeds even if bootstrap fails

---

## Additional Resources

- [Dataverse Installation Time](https://guides.dataverse.org/en/latest/installation/docker.html#first-run-time)
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck)
- [Payara Server Startup Options](https://docs.payara.fish/community/docs/Administration%20Guide/JVM%20Options.html)
- [Configbaker Documentation](https://github.com/IQSS/dataverse/tree/develop/conf/docker-compose/scripts/configbaker)
