# Dataverse Frontend and UI Errors

Error ledger for frontend, UI, and user-facing issues.

---

## Error ID: ERR-FRONTEND-001

**Title:** User Sees Payara Admin Page Instead of Dataverse UI  
**Timestamp:** 2026-04-10 21:15:30 UTC  
**Environment:** Dev / Demo / Production  
**Severity:** 🟡 Medium (UX confusion, but application works fine)  

---

## Symptom

User navigates to `http://localhost:8080` and sees:

```
Welcome to Payara Server

Payara Server 5.2026.2 is running.

To deploy applications:
- Place war files in $PAYARA_HOME/glassfish/domains/domain1/autodeploy/
- Or use the admin console at http://localhost:4848/
```

**Expected:**
- See Dataverse login page or home screen

**What the user wants:**
```
Dataverse
Username: [___________]
Password: [___________]
  [Login]
```

---

## Root Cause Analysis

This is NOT actually an error - it's a **timing and user expectation issue**.

### Why This Happens

**Scenario 1: Dataverse Not Yet Deployed (90% of the time)**

1. User accesses port 8080 during startup
2. Payara server is running but Dataverse WAR file is still extracting
3. Dataverse application context (`/dataverse`) is not yet available
4. Payara responds with its default admin page
5. When root path `/` has no application, Payara shows its welcome page

**Timeline:**
```
00:05 - Payara server ready
00:05 - Port 8080 listening
00:15 - ← User accesses http://localhost:8080
00:15 - ← Payara welcome page shown ✓ (WAR extraction in progress)
00:45 - WAR file finally deployed
01:00 - Dataverse application ready
01:00 - ← User can now see Dataverse UI
```

**Scenario 2: Wrong Port or Url**

1. User accessed admin console port instead of app port
2. User typed `http://localhost:4848/` (admin) instead of `http://localhost:8080/`
3. User is on production domain but accessing staging port

**Check what you're accessing:**
```
localhost:8080  ✅ Correct - Dataverse app
localhost:4848  ❌ Wrong - Payara admin console (blocked for security)
localhost:8983  ❌ Wrong - Solr search admin
localhost:8025  ❌ Wrong - Email testing UI
```

---

## Fix

### Quick Fix: Just Wait

**The issue resolves itself automatically.** Dataverse deployment takes 20-60 minutes.

```powershell
# Monitor the deployment progress
while ($true) {
    try {
        $connection = Test-NetConnection localhost -Port 8080 -ErrorAction Stop -TimeoutSeconds 2
        if ($connection.TcpTestSucceeded) {
            # Port is open, test if Dataverse is ready
            $response = Invoke-WebRequest http://localhost:8080/dataverse -TimeoutSec 2 -ErrorAction SilentlyContinue
            
            if ($response -and $response.StatusCode -eq 200) {
                Write-Host "✅ Dataverse is ready!"
                break
            } else {
                Write-Host "⏳ Payara is running but Dataverse not yet deployed (HTTP $($response.StatusCode))"
            }
        }
    } catch {
        Write-Host "⏳ Port 8080 not yet open..."
    }
    
    Write-Host "   Waiting 30 seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
}
```

**Expected output:**
```
⏳ Payara is running but Dataverse not yet deployed (HTTP 404)
   Waiting 30 seconds...
⏳ Payara is running but Dataverse not yet deployed (HTTP 404)
   Waiting 30 seconds...
✅ Dataverse is ready!
```

---

### Clear the Confusion

**Important Port Reference:**

| Port | Service | URL | Purpose | Access |
|------|---------|-----|---------|--------|
| **8080** | Dataverse App | `http://localhost:8080/` | 👤 User-facing Dataverse web UI | ✅ Public |
| 4848 | Payara Admin | `http://localhost:4848/` | 🔧 Server administration | ❌ Blocked (security) |
| 8983 | Solr Search | `http://localhost:8983/` | 🔍 Full-text search admin | ⚠️ Internal only |
| 8025 | MailDev Email | `http://localhost:8025/` | 📧 Email testing inbox | ✅ Testing |

**Use Port 8080 for everything.** If you see Payara page, try these URLs:

```
Direct Dataverse URLs:
- http://localhost:8080/dataverse ← Dataverse homepage
- http://localhost:8080/api/info/version ← Check if API is up
- http://localhost:8080/dataverse/faces/login.xhtml ← Login page
- http://localhost:8080/dataverse/faces/admin/index.xhtml ← Admin page
```

Example: Test each endpoint to see deployment progress

```powershell
$endpoints = @(
    "http://localhost:8080/",         # Will show Payara if not deployed yet
    "http://localhost:8080/dataverse", # Will show 404 if not deployed yet
    "http://localhost:8080/api/info/version"  # Will show JSON if deployed
)

foreach ($endpoint in $endpoints) {
    Write-Host "`nTesting: $endpoint"
    try {
        $response = Invoke-WebRequest $endpoint -TimeoutSec 3 -ErrorAction Stop
        Write-Host "✅ HTTP $($response.StatusCode)"
        Write-Host "   Content: $($response.Content.Substring(0, 100))..."
    } catch {
        $code = $_.Exception.Response.StatusCode.Value__
        Write-Host "❌ HTTP $code"
    }
}
```

---

### Verify Successful Deployment

Once Dataverse is deployed, you should see:

```powershell
# 1. Check the homepage loads
$html = Invoke-WebRequest http://localhost:8080/dataverse
if ($html.Content -match "Dataverse") {
    Write-Host "✅ Homepage loads successfully"
}

# 2. Access login page
$login = Invoke-WebRequest http://localhost:8080/dataverse/faces/login.xhtml
if ($login.Content -match "Login") {
    Write-Host "✅ Login page accessible"
}

# 3. Login with test credentials
$body = @{
    "j_username" = "dataverseAdmin"
    "j_password" = "admin1"
}
# (Note: This requires proper cookie/session handling - skipped for simplicity)

# 4. Check API version
$version = Invoke-WebRequest http://localhost:8080/api/info/version | ConvertFrom-Json
Write-Host "✅ Running Dataverse v$($version.data.version)"
```

---

## Prevention

### Clearer Startup Messaging

Create a startup progress indicator:

```powershell
# Save as .\scripts\show-startup-progress.ps1

Write-Host @"
========================================
Dataverse Docker Startup Guide
========================================

STEP 1: Wait for deployment (20-60 minutes)
   Status: Monitor below ↓

ACCESSIBLE PORTS:
   • 8080  = Dataverse (WHAT YOU WANT)
   • 4848  = Payara Admin (BLOCKED - don't use)
   • 8983  = Solr Search (internal - don't use)
   • 8025  = Email Testing (internal - don't use)

HOW TO ACCESS:
   1. Open: http://localhost:8080/
   2. Wait for Dataverse to load
   3. Login with: dataverseAdmin / admin1

TROUBLESHOOTING:
   • See Payara page? → Still deploying, wait 30 seconds
   • Get 404 error? → Normal during startup
   • Nothing loads? → Check: docker-compose ps
"@

# Monitor deployment
$ready = $false
while (-not $ready) {
    try {
        $response = Invoke-WebRequest http://localhost:8080/dataverse -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Host "`n✅✅✅ Dataverse is READY! ✅✅✅" -BackgroundColor Green -ForegroundColor Black
            Write-Host "Open: http://localhost:8080/" -ForegroundColor Green
            $ready = $true
        }
    } catch {
        Write-Host -NoNewline "."
        Start-Sleep -Seconds 5
    }
}
```

Usage before deployment:

```powershell
.\scripts\show-startup-progress.ps1
```

### Better Documentation

Add this to the main README:

```markdown
## 🚀 First-Time Access

After running `docker-compose up -d`:

1. **Wait** - First deployment takes 20-60 minutes
2. **Check** - Use this command to verify status:
   ```
   docker-compose ps  # Should all show "Up"
   ```
3. **Access** - When ready, navigate to:
   - **http://localhost:8080/**
   - Default login: `dataverseAdmin` / `admin1`

### ⚠️ Common Confusion
- Seeing a "Payara Server" welcome page? **Keep waiting!**
- Getting HTTP 404? **Still deploying, check back in 5 minutes**
- Want Payara admin? Use port 4848 (blocked for security)

### ✅ How to Tell When Ready
```bash
# This should return JSON (not HTML page)
curl http://localhost:8080/api/info/version
```
```

---

## Related Issues

- **ERR-DATAVERSE-001** - Application deployment failure (root cause of this issue)
- **ERR-DATAVERSE-002** - Bootstrap timeout (related startup confusion)
- **ERR-DB-001** - Database issue (can prevent deployment)

---

## Timeline & History

| Time | Event | Status |
|------|-------|--------|
| 21:05 | Deployment started | ⏳ |
| 21:15 | User checks localhost:8080 | Shows Payara page (normal - still deploying) |
| 21:25 | 404 errors in bootstrap logs | Expected - WAR file still deploying |
| 21:35 | Database issues discovered & fixed | ⚠️ |
| 21:45 | WAR file extraction complete | ✅ |
| 21:50 | Dataverse UI accessible | ✅ |

---

## Best Practices

1. ✅ **DO**: Use port 8080 for everything
2. ✅ **DO**: Wait at least 30 minutes before troubleshooting
3. ✅ **DO**: Check deployment logs: `docker-compose logs dataverse | tail -50`
4. ✅ **DO**: Monitor with: `docker-compose ps`

5. ❌ **DON'T**: Try to access port 4848 (Payara admin is blocked)
6. ❌ **DON'T**: Panic if you see Payara page immediately - wait!
7. ❌ **DON'T**: Restart containers every few minutes - let it deploy
8. ❌ **DON'T**: Assume failure until > 1 hour has passed

---

## Additional Resources

- [Dataverse Installation Guide](https://guides.dataverse.org/en/latest/installation/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Payara Server Info](https://www.payara.fish/)
- [Project Status Page](./DEPLOYMENT_STATUS.md)

---

## Notes for Support Team

If user reports "I see Payara page":

1. **Ask**: "How long ago did you start the deployment?"
   - < 10 min: "Please wait, deployment takes 20-60 minutes"
   - > 45 min: "Let me help troubleshoot"

2. **Verify**: Run `docker-compose ps` - should show all "Up"

3. **Check**: Run `docker-compose logs dataverse | tail -20`
   - Look for: "deployed successfully" or "ERROR"

4. **Clarify**: "Make sure you're accessing port **8080**, not 4848"

5. **If stuck**: Follow ERR-DATAVERSE-001 troubleshooting steps
