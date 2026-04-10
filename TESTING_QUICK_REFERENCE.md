# 🎯 Dataverse Testing Quick Reference Card

**Status**: ✅ Complete  
**Branch**: `dataverse-AI-testing`  
**Deployment**: v6.10.1 (Healthy)  

---

## 📄 Files You Just Got

| File | Purpose | Read Time | When To Use |
|------|---------|-----------|-------------|
| **TESTING_SUMMARY.md** | Executive overview | 5 min | Start here - big picture |
| **SMOKE_TEST_SETUP.md** | Quick validation | 10 min | Fast verification of deploy |
| **TESTING_WORKFLOW_GUIDE.md** | Complete reference | 45 min | Deep dive into all testing |

---

## ⚡ 3-Minute Start

```powershell
# 1. Verify deployment
docker-compose ps
curl http://localhost:8080/api/info/version

# 2. Create test user
curl -X POST -H "Content-Type: application/json" `
  -d '{"firstName":"T","lastName":"U","username":"tu1","email":"t@x","password":"p"}' `
  http://localhost:8080/api/users?key=secret

# 3. Verify connected
curl http://localhost:8080/api/admin/userData/tu1?key=secret

# Result: ✅ If 200 OK = deployment works
```

---

## 🚀 Command Cheat Sheet

### Health Checks
```powershell
docker-compose ps                          # All containers running?
curl http://localhost:8080/api/info/version         # API responding?
docker exec compose-postgres-1 pg_isready -U dataverse  # DB healthy?
```

### Setup (One-time)
```powershell
# Install Java (if missing)
choco install openjdk

# Install Maven (if missing)
choco install maven

# Clone Dataverse source
cd c:\dev
git clone https://github.com/IQSS/dataverse.git
cd dataverse
```

### Run Tests
```powershell
# Unit tests only (fast)
mvn test -P dev

# Integration tests (slow, requires running instance)
mvn verify -P integration-tests -Dit.test=BuiltinUsersIT

# Single test method
mvn verify -P integration-tests -Dit.test=BuiltinUsersIT#testCreateUser

# All unit + integration + coverage
mvn clean verify -P all-unit-tests,integration-tests jacoco:report
```

### Coverage Reports
```powershell
mvn test jacoco:report
Start-Process "target/site/jacoco/index.html"
```

---

## ❓ Minimal Q&A

**Q: Where do I start?**  
A: Read TESTING_SUMMARY.md (5 min), then choose Path 1/2/3

**Q: Can I test without installing Java/Maven?**  
A: Yes! Run smoke tests from SMOKE_TEST_SETUP.md (curl-based only)

**Q: What if tests fail?**  
A: See "If Things Go Wrong" section in TESTING_WORKFLOW_GUIDE.md (Category 1-5)

**Q: How do I run tests against my deployed instance?**  
A: Follow "Integration Tests: REST Assured" in TESTING_WORKFLOW_GUIDE.md

**Q: Do I need Podman instead of Docker?**  
A: No, Docker works. Podman support is WIP in Dataverse.

**Q: Can I write my own tests?**  
A: Yes! See "Next Improvements: Writing Tests" in TESTING_WORKFLOW_GUIDE.md

---

## 📊 Testing Landscape (One Pager)

```
┌─────────────────────────────────────────────────────────────────┐
│                   DATAVERSE TESTING TYPES                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│ UNIT TESTS                                                      │
│ ├─ Fast: 1-5 seconds per test                                   │
│ ├─ No external deps needed                                      │
│ ├─ Tool: JUnit 5 + Maven                                        │
│ ├─ Command: mvn test -P dev                                     │
│ └─ Coverage: Individual methods, local logic                    │
│                                                                 │
│ INTEGRATION TESTS (REST Assured)                                │
│ ├─ Slower: 2-30 seconds per test                                │
│ ├─ Requires: Dataverse + PostgreSQL + Solr                      │
│ ├─ Tool: REST Assured + Maven Failsafe                          │
│ ├─ Command: mvn verify -P integration-tests                     │
│ └─ Coverage: Full API workflows, cross-service interactions     │
│                                                                 │
│ INTEGRATION TESTS (Testcontainers)                              │
│ ├─ Mixed: 10-60 seconds per test                                │
│ ├─ Requires: Docker + Maven                                    │
│ ├─ Tool: Testcontainers + Docker                                │
│ ├─ Command: mvn verify -P testcontainers                        │
│ └─ Coverage: Database operations, isolated tests                │
│                                                                 │
│ COVERAGE REPORTS                                                │
│ ├─ Tool: JaCoCo (Java Code Coverage)                            │
│ ├─ Command: mvn test jacoco:report                              │
│ ├─ Output: target/site/jacoco/index.html (viewable)             │
│ └─ Metrics: Line %, branch %, method % coverage                 │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## ✅ 60-Second Verification

Copy & run this to verify your setup:

```powershell
Write-Host "=== Dataverse Testing Environment ===" -ForegroundColor Cyan

# Check deployment
Write-Host "[1] Containers:" -ForegroundColor Yellow
docker-compose ps | Select-Object NAME, STATUS

# Check API
Write-Host "[2] API Health:" -ForegroundColor Yellow
$api = curl -s http://localhost:8080/api/info/version 2>$null
if ($api) { Write-Host "✅ OK" } else { Write-Host "❌ FAIL" }

# Check Java
Write-Host "[3] Java:" -ForegroundColor Yellow
java -version 2>&1 | Select-Object -First 1

# Check Maven  
Write-Host "[4] Maven:" -ForegroundColor Yellow
mvn -version 2>&1 | Select-Object -First 1

Write-Host "`n✅ If all pass, you're ready!" -ForegroundColor Green
```

---

## 🎯 Choose Your Testing Path

```
START HERE:
├─ Read: TESTING_SUMMARY.md (5 min executive brief)
│
├─ PATH 1: Smoke Test (Quick deploy validation)
│  ├─ Read: SMOKE_TEST_SETUP.md
│  ├─ Run: curl-based API tests
│  └─ Time: 5 minutes
│
├─ PATH 2: Integration Tests (Test API features)
│  ├─ Prerequisites: Java 11+, Maven 3.8+
│  ├─ Setup: Clone dataverse repo
│  ├─ Run: mvn verify -P integration-tests
│  └─ Time: 30 min setup + 5 min tests
│
└─ PATH 3: Full Test Suite (Everything)
   ├─ All of PATH 1 + 2
   ├─ Plus: Unit tests, Coverage reports
   ├─ Run: Full runbook in TESTING_WORKFLOW_GUIDE.md
   └─ Time: 2-3 hours
```

---

## 🐛 Top 5 Issues & Fixes

| Issue | Symptom | Fix | Time |
|-------|---------|-----|------|
| No connection | "Connection refused" | `docker-compose up -d` | 35s |
| No auth | "401 Unauthorized" | Set burrito key (see TESTING_WORKFLOW_GUIDE.md) | 30s |
| No Java | "mvn: command not found" | `choco install openjdk maven` | 5min |
| DB locked | "Database error" | `docker-compose down -v && up -d` | 2min |
| Tests timeout | Tests take too long | Increase heap: `mvn -Xmx2g verify` | 30s |

---

## 📍 Current Branch Info

```powershell
# Current branch
git branch

# Expected output:
#   main
# * dataverse-AI-testing  ← you are here

# Commits since main
git log main..dataverse-AI-testing

# Switch branches
git checkout main                    # Go to main
git checkout dataverse-AI-testing    # Go back to testing
```

---

## 🎓 Learning Path (By Day)

| Day | Task | Time | Files |
|-----|------|------|-------|
| **1** | Understand testing landscape | 30 min | TESTING_SUMMARY.md |
| **2** | Verify deployment + smoke test | 20 min | SMOKE_TEST_SETUP.md |
| **3** | Install Java/Maven + run tests | 1 hour | TESTING_WORKFLOW_GUIDE.md |
| **4+** | Deep dive + write new tests | Variable | Full guide |

---

## 📚 Documentation Map

```
Root Repo
├── TESTING_SUMMARY.md .................. ← START HERE (executive)
├── SMOKE_TEST_SETUP.md ................ Quick validation
├── TESTING_WORKFLOW_GUIDE.md .......... Complete reference
├── DOCUMENTATION_INDEX.md ............. Navigation hub
├── DEPLOYMENT_STATUS.md ............... Current status
└── docs/
    ├── ERRORS_AND_SOLUTIONS.md ........ Error reference
    ├── OPERATIONS.md .................. Daily ops
    └── errors/ ........................ Detailed error guides
```

---

## 🔗 Useful Links

| Resource | Purpose | URL |
|----------|---------|-----|
| **Dataverse Testing Guide** | Official reference | https://guides.dataverse.org/en/latest/developers/testing.html |
| **REST Assured** | API testing docs | https://rest-assured.io/ |
| **JUnit 5** | Testing framework | https://junit.org/junit5/ |
| **Dataverse Community** | Support & questions | https://groups.google.com/g/dataverse-community |
| **GitHub Issues** | Bug reports | https://github.com/IQSS/dataverse/issues |

---

## ✨ What You Can Now Do

✅ **Run smoke tests** against deployed instance (no setup)  
✅ **Run unit tests** locally with Maven  
✅ **Run integration tests** against your instance  
✅ **Generate coverage reports** showing code covered by tests  
✅ **Troubleshoot failures** with categorized root causes  
✅ **Write new tests** for new features  
✅ **Understand** the full testing landscape  

---

## 🚀 Next Action

**Pick ONE:**

1. **I want quick status** → Run 60-second verification above
2. **I want to understand** → Open TESTING_SUMMARY.md
3. **I want to test now** → Open SMOKE_TEST_SETUP.md
4. **I want all details** → Open TESTING_WORKFLOW_GUIDE.md

---

**Version**: 1.0  
**Date**: 2026-04-11  
**Branch**: dataverse-AI-testing  
**Status**: ✅ Ready to Test

🎉 **You're all set! Happy testing!**
