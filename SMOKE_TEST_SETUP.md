# Smoke Test: Verify Dataverse Deployment + Testing Setup

## Quick Status Check (< 2 minutes)

Run this PowerShell script to verify everything is ready for testing:

```powershell
Write-Host "
╔════════════════════════════════════════════╗
║  Dataverse Testing Environment Verification ║
╚════════════════════════════════════════════╝
" -ForegroundColor Cyan

$checks_pass = 0
$checks_total = 8

# 1. Docker running
Write-Host "`n[1/8] Checking Docker..." -ForegroundColor Yellow
try {
    $docker_version = docker --version
    Write-Host "✅ $docker_version" -ForegroundColor Green
    $checks_pass++
} catch {
    Write-Host "❌ Docker not found. Install from: https://www.docker.com/products/docker-desktop" -ForegroundColor Red
}

# 2. Containers running
Write-Host "`n[2/8] Checking containers..." -ForegroundColor Yellow
try {
    $containers = docker-compose -f "configs/compose.yml" ps --format json | ConvertFrom-Json
    $running = $containers | Where-Object { $_.State -eq "running" } | Measure-Object | Select-Object -ExpandProperty Count
    if ($running -ge 4) {
        Write-Host "✅ All services running ($running/4)" -ForegroundColor Green
        $checks_pass++
    } else {
        Write-Host "⚠️  Only $running/4 services running. Start with: docker-compose up -d" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Docker Compose failed: $_" -ForegroundColor Red
}

# 3. Dataverse API
Write-Host "`n[3/8] Checking Dataverse API..." -ForegroundColor Yellow
try {
    $api_response = Invoke-WebRequest -Uri "http://localhost:8080/api/info/version" -TimeoutSec 5 -ErrorAction Stop
    if ($api_response.StatusCode -eq 200) {
        $version = $api_response.Content | ConvertFrom-Json | Select-Object -ExpandProperty "data" | Select-Object -ExpandProperty "version"
        Write-Host "✅ Dataverse v$version responding" -ForegroundColor Green
        $checks_pass++
    }
} catch {
    Write-Host "❌ Dataverse API not responding. Check: docker-compose logs dataverse" -ForegroundColor Red
}

# 4. PostgreSQL
Write-Host "`n[4/8] Checking PostgreSQL..." -ForegroundColor Yellow
try {
    docker exec compose-postgres-1 pg_isready -U dataverse 2>&1 | Out-Null
    Write-Host "✅ PostgreSQL accepting connections" -ForegroundColor Green
    $checks_pass++
} catch {
    Write-Host "⚠️  PostgreSQL check inconclusive" -ForegroundColor Yellow
}

# 5. Solr
Write-Host "`n[5/8] Checking Solr..." -ForegroundColor Yellow
try {
    $solr_response = Invoke-WebRequest -Uri "http://localhost:8983/solr/admin/ping" -TimeoutSec 5 -ErrorAction Stop
    if ($solr_response.StatusCode -eq 200) {
        Write-Host "✅ Solr search engine healthy" -ForegroundColor Green
        $checks_pass++
    }
} catch {
    Write-Host "⚠️  Solr check inconclusive" -ForegroundColor Yellow
}

# 6. Java
Write-Host "`n[6/8] Checking Java..." -ForegroundColor Yellow
try {
    $java_version = java -version 2>&1
    if ($java_version -match "(\d+\.\d+)") {
        Write-Host "✅ Java installed: $(($java_version -split '\n')[0])" -ForegroundColor Green
        $checks_pass++
    } else {
        Write-Host "⚠️  Java detected but version unclear" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Java not found. Install with: choco install openjdk" -ForegroundColor Red
}

# 7. Maven
Write-Host "`n[7/8] Checking Maven..." -ForegroundColor Yellow
try {
    $mvn_version = mvn -version 2>&1
    if ($mvn_version -match "Apache Maven") {
        Write-Host "✅ Maven installed" -ForegroundColor Green
        $checks_pass++
    } else {
        Write-Host "⚠️  Maven detected but unclear" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Maven not found (optional). Install with: choco install maven" -ForegroundColor Yellow
}

# 8. Git
Write-Host "`n[8/8] Checking Git..." -ForegroundColor Yellow
try {
    $git_version = git --version
    Write-Host "✅ Git installed: $git_version" -ForegroundColor Green
    $checks_pass++
} catch {
    Write-Host "⚠️  Git not found (needed to clone Dataverse source)" -ForegroundColor Yellow
}

# Summary
Write-Host "`
╔════════════════════════════════════════════╗
║         Summary: $checks_pass/8 Checks Passed         ║
╚════════════════════════════════════════════╝
" -ForegroundColor Cyan

if ($checks_pass -ge 6) {
    Write-Host "
✅ READY FOR TESTING!

Next steps:
1. Read: TESTING_WORKFLOW_GUIDE.md
2. Choose your path:
   - For smoke tests (quick): Run REST Assured against live instance
   - For full tests: Clone Dataverse and run Maven tests
   - For coverage: Generate JaCoCo reports
" -ForegroundColor Green
} else {
    Write-Host "
⚠️  Please fix the issues above before testing

Common fixes:
• Docker not running: Start Docker Desktop
• Dataverse not responding: docker-compose up -d
• Java/Maven missing: choco install openjdk maven
" -ForegroundColor Yellow
}
```

---

## Run Test Command Examples

Once setup verified, run these to validate:

### Unit Test Smoke (Requires Maven + Java)
```powershell
cd c:\dev\dataverse
mvn test -Dtest=BuiltinUsersTest --ff
# Expected: 1-2 minutes, BUILD SUCCESS
```

### Integration Test Smoke (Requires Running Dataverse)
```powershell
cd c:\dev\dataverse
mvn verify -P integration-tests -Dit.test=BuiltinUsersIT#testCreateUser `
  -Dapi.baseurl=http://localhost:8080
# Expected: 30-60 seconds, BUILD SUCCESS
```

### Coverage Report (Requires Maven)
```powershell
cd c:\dev\dataverse
mvn test jacoco:report
# Check: target/site/jacoco/index.html
```

### Simple API Health Check (No setup needed)
```powershell
# Verify deployment responding
curl -v http://localhost:8080/api/info/version

# Create test user
curl -X POST `
  -H "Content-Type: application/json" `
  -d '{"firstName":"Test","lastName":"User","username":"testuser","email":"test@x","password":"pass123"}' `
  http://localhost:8080/api/users?key=secret

# Verify user created
curl http://localhost:8080/api/admin/userData/testuser?key=secret
```

---

## File Structure After Setup

```
c:\Users\rachitgupta5\OneDrive - KPMG\Apps\Dataverse\dataverse-AI-ready\
├── TESTING_WORKFLOW_GUIDE.md          ← You are here
├── DOCUMENTATION_INDEX.md             ← Navigation hub
├── DEPLOYMENT_STATUS.md               ← Current status
├── INSTALLATION_GUIDE.md              ← Deployment guide
│
├── configs/                           ← Docker compose
│   ├── compose.yml
│   └── data/                          ← Persistent volumes
│
├── docs/                              ← Documentation
│   ├── ERRORS_AND_SOLUTIONS.md        ← Error index
│   ├── OPERATIONS.md
│   └── errors/                        ← Detailed error guides
│
└── c:\dev\dataverse\                  ← (After cloning)
    ├── pom.xml                        ← Maven project
    ├── src/
    │   ├── main/                      ← Source code
    │   └── test/                      ← Tests
    │       ├── java/                  ← JUnit tests
    │       └── resources/             ← Test data
    └── target/
        ├── surefire-reports/          ← Test results
        └── site/
            └── jacoco/                ← Coverage reports
```

---

## Decision Tree: What to Test?

```
Q: What do you want to test?

├─ "Verify deployment works"
│  └─ Run: Smoke test → Simple API checks (done in < 5 min)
│
├─ "Test new feature I added"
│  ├─ If in Docker container: REST Assured test + integration test
│  └─ If in source code: Unit test + integration test
│
├─ "Check test coverage"
│  └─ Run: mvn test jacoco:report → target/site/jacoco/index.html
│
├─ "Run full test suite"
│  ├─ Option A (Fast): mvn test -P dev → ~2 min
│  └─ Option B (Comprehensive): mvn verify -P all-unit-tests,integration-tests → ~10 min
│
└─ "Debug test failure"
   ├─ Is it network? → Check docker-compose ps + curl endpoints
   ├─ Is it auth? → Verify API key and user created
   ├─ Is it data? → Reset DB with docker-compose down -v
   └─ Is it code? → Review test log + stack trace
```

---

## Most Common Issues & Quick Fixes

| Issue | Fix | Time |
|-------|-----|------|
| 401 Unauthorized | `curl -X PUT -d "BurritoBep" http://localhost:8080/api/admin/settings/:BurritoBep` | 30s |
| Connection refused | `docker-compose up -d` + wait 30s | 35s |
| Maven not found | `choco install maven openjdk` | 5min |
| Tests timeout | Increase: `mvn verify -DargLine="-Dclient.timeout=60000"` | 30s |
| DB connection error | `docker-compose down -v && docker-compose up -d` | 2min |
| Out of memory | Docker Desktop → Settings → Resources → increase RAM | 1min |

---

## Next: Read Full Guide

For comprehensive testing instructions, see: **[TESTING_WORKFLOW_GUIDE.md](TESTING_WORKFLOW_GUIDE.md)**

- Unit tests details
- Integration tests setup
- JaCoCo coverage reporting
- Troubleshooting guide
- How to write tests
