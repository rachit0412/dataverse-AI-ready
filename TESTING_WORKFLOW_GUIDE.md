# Dataverse Testing Workflow Runbook

**Deployment Status**: ✅ v6.10.1 - Healthy  
**Environment**: Docker-based (postgres 13, solr 9.3.0, maildev)  
**Target**: Comprehensive testing of deployed instance + integration tests  
**Reference**: https://guides.dataverse.org/en/latest/developers/testing.html

---

## 📊 Testing Landscape Summary (Quick Overview)

Dataverse (v6.0+) uses **JUnit 5** with three testing layers:

1. **Unit Tests** (Fast, no external deps)
   - Located in `src/test/java` within core Dataverse source
   - File pattern: `*Test.java`
   - Run: **<5 sec typical**
   - Coverage: Individual methods, local logic
   - Tool: JUnit 5 + Mockito

2. **Non-Essential Unit Tests** (Tagged, excluded by default)
   - Same as above but marked `@Tag(Tags.NOT_ESSENTIAL_UNITTESTS)`
   - Run when: testing edge cases, backward compatibility
   - Run: **via Maven profile `all-unit-tests`**

3. **Integration Tests** (Slower, require running Dataverse + dependencies)
   - **REST Assured API tests** (`*IT.java` files)
     - Exercise HTTP endpoints against running instance
     - Require: Dataverse, PostgreSQL, Solr, admin auth
     - Run: **2-10 minutes per test**
     - Coverage: Full API workflows, cross-service interactions
   - **Testcontainers tests** (Docker-based unit tests)
     - Spin up isolated containers for each test
     - Require: Docker + Maven
     - Run: **variable, per test**

4. **Coverage Reports** (JaCoCo)
   - Unit coverage: `target/site/jacoco-unit-test-coverage-report/`
   - Integration coverage: `target/site/jacoco-integration-test-coverage-report/`
   - Merged: `target/site/jacoco-merged-test-coverage-report/`
   - Format: HTML, viewable in browser

---

## ✅ Quick Assessment Checklist

### Environment Verified

| Check | Status | Details |
|-------|--------|---------|
| **Dataverse Running** | ✅ | v6.10.1 on http://localhost:8080 |
| **PostgreSQL** | ✅ | Port 5432 (internal) |
| **Solr** | ✅ | Port 8983 (internal) |
| **Email** | ✅ | MailDev on http://localhost:8025 |
| **API Health** | ✅ | `/api/info/version` responds 200 |
| **Docker** | ✅ | Available (Docker compose running) |
| **Maven** | ❓ | To be verified - needed for source testing |
| **Java** | ❓ | To be verified - needed for source testing |

### What You Have

- ✅ **Deployed Dataverse instance** - Ready for smoke/integration testing
- ✅ **Docker environment** - Can run containerized integration tests
- ✅ **Docker Compose** - Can orchestrate test dependencies
- ❌ **Dataverse source code** - Not in this repo (it's a deployment wrapper)
- ❌ **Maven project** - Not configured locally

### What You Need (Decision Point)

**Option A**: Test the deployed instance (SMOKE/INTEGRATION TESTS)
- ✅ Can do NOW - No setup needed
- Tools: PowerShell + REST Assured + Postman/curl
- Time: 15 minutes to setup tests

**Option B**: Develop & test Dataverse source features (FULL TEST SUITE)
- ⏳ Requires: Maven, Java, cloning core Dataverse repo
- Tools: Maven, JUnit 5, Maven Failsafe plugin
- Time: 1-2 hours setup + build

**RECOMMENDED**: Start with Option A (smoke tests), then Option B if needed

---

## 🧪 Unit Tests Runbook

### Important Note on Architecture

Your repository is a **deployment wrapper** around the published `gdcc/dataverse:latest` Docker image. The actual unit tests live in the core Dataverse source code repository, which is compiled into the Docker image.

**To run unit tests, you have two paths:**

### Path 1: Unit Tests from Deployed Docker Image (Quickest)

Extract and run tests from the running Docker container:

```powershell
# 1. List available test files in running container
docker exec compose-dataverse-1 bash -c "find /opt/payara -name '*Test.jar' 2>/dev/null" | head -20

# 2. Extract test JARs (if available)
docker exec compose-dataverse-1 bash -c "find /opt/payara/glassfish/domains/domain1 -name '*test*' -type f 2>/dev/null" | head -10

# 3. View Dataverse build info (shows version, build time)
curl -s http://localhost:8080/api/info/version | ConvertFrom-Json | Format-Table
```

**Expected**: Build info from v6.10.1, but test JARs typically not packaged in deployment image

**Verdict**: ❌ Not recommended - deployment image doesn't include test sources

---

### Path 2: Clone Dataverse Source & Run Unit Tests Locally (Comprehensive)

**Prerequisites:**
```powershell
# 1. Verify Java installed
java -version

# 2. Verify Maven installed
mvn -version

# 3. If not installed - install via Chocolatey (Windows)
choco install openjdk maven -y
```

**Setup:**

```powershell
# 1. Create a workspace directory
cd c:\dev
mkdir dataverse-testing
cd dataverse-testing

# 2. Clone the Dataverse repository
git clone https://github.com/IQSS/dataverse.git
cd dataverse

# 3. Verify Maven structure
ls -la pom.xml
```

**Run Default Unit Tests (Fast Path):**

```powershell
# Maven compiles and runs unit tests (skips integration tests by default)
cd dataverse
mvn clean test

# Expected output:
# [INFO] -------------------------------------------------------
# [INFO] BUILD SUCCESS
# [INFO] -------------------------------------------------------
# [INFO] Total time: 2-5 minutes
# [INFO] Tests run: 100+, Failures: 0, Errors: 0
```

**Run with Dev Profile (Recommended):**

```powershell
# Use 'dev' profile - optimizes for faster local testing
mvn clean test -P dev

# Expected: Faster than default, excludes slow/flaky tests
```

**Run Single Test File:**

```powershell
# Run one test class (fast verification)
mvn test -Dtest=BuiltinUsersTest

# Run one test method
mvn test -Dtest=BuiltinUsersTest#testBuiltinUserCreation
```

---

## 🏷️ Non-Essential Unit Tests Runbook

**What are they?**
- Tests marked with `@Tag(Tags.NOT_ESSENTIAL_UNITTESTS)`
- Excluded from default Maven run
- Include: backward compatibility, rarely-used features, edge cases

**Run ALL unit tests (including non-essential):**

```powershell
cd dataverse

# Profile 'all-unit-tests' runs everything
mvn clean test -P all-unit-tests

# Expected:
# [INFO] Total time: 5-10 minutes
# [INFO] Tests run: 150+  (includes non-essential)
```

**Count non-essential tests:**

```powershell
# Search for the tag in source
grep -r "@Tag.*NOT_ESSENTIAL_UNITTESTS" src/test/java --include="*.java" | wc -l

# Expected: 20-40 tests across the codebase
```

**Run non-essential tests only:**

```powershell
# Use Maven tag filter (requires Maven 3.5.1+)
mvn clean test -P all-unit-tests -Dgroups="NOT_ESSENTIAL_UNITTESTS"

# Alternative: Run with JUnit platform filter
mvn clean test -P all-unit-tests "-DincludeTags=NOT_ESSENTIAL_UNITTESTS"
```

**Include non-essential in IDE:**

If developing in NetBeans/IntelliJ:
1. Right-click test file
2. Open with editor
3. Find: `@Tag("NOT_ESSENTIAL_UNITTESTS")`
4. Temporarily comment out: `//@Tag("NOT_ESSENTIAL_UNITTESTS")`
5. Run: `Shift+F6` (NetBeans) or `Ctrl+Shift+F10` (IntelliJ)
6. Uncomment when done

---

## 📈 Coverage Runbook (JaCoCo)

### Generate Unit Test Coverage

```powershell
cd dataverse

# Generate with Maven - automatically creates JaCoCo report
mvn clean test -P all-unit-tests jacoco:report

# Maven output:
# [INFO] Analyzing the generated report...
# [INFO] BUILD SUCCESS

# Report location: target/site/jacoco/index.html
```

**Open coverage report:**

```powershell
# Option 1: Open in browser (Windows)
Start-Process "$(Get-Item target/site/jacoco/index.html | % FullName)"

# Option 2: Manual path
# Navigate to: target/site/jacoco/index.html
# View in: Any modern browser
```

### Generate Integration Test Coverage

Requires running Dataverse instance:

```powershell
cd dataverse

# Run integration tests WITH coverage tracking
mvn clean verify \
  -P integration-tests \
  jacoco:report-integration

# Report location: target/site/jacoco-integration/index.html
```

### Merged Coverage (Unit + Integration)

```powershell
cd dataverse

# Generate both unit and integration coverage, then merge
mvn clean verify \
  -P all-unit-tests,integration-tests \
  jacoco:report \
  jacoco:report-integration \
  jacoco:merge

# Reports:
# - Unit only: target/site/jacoco/
# - Integration only: target/site/jacoco-integration/
# - Merged: target/site/jacoco-merged/
```

**Interpret Coverage Report:**

1. Open `target/site/jacoco/index.html`
2. Green bar = covered code, Red bar = uncovered
3. Look at:
   - **Line Coverage**: % of lines executed
   - **Branch Coverage**: % of if/else branches tested
   - **Method Coverage**: % of methods called
4. Click on package or class to drill down
5. Identify files with < 70% coverage for additional tests

**NetBeans Integration (Optional):**

```powershell
# Install JaCoCo plugin in NetBeans
# Tools → Plugins → Search "emma" → Install

# Then: Run tests → Right-click project → "Show Code Coverage"
```

---

## 🔌 Integration Tests Runbook

### Landscape & Flavors

Dataverse integration tests come in two types:

**Type 1: REST Assured API Tests** (Most Common)
- Files: `src/test/java/edu/harvard/iq/dataverse/it/*IT.java`
- Pattern: BuiltinUsersIT.java, DatasetsIT.java, etc.
- Approach: HTTP client that calls running Dataverse endpoints
- Requirement: **Running instance + PostgreSQL + Solr**
- Speed: 2-30 seconds per test
- Coverage: End-to-end workflows

**Type 2: Testcontainers Tests** (Containerized)
- Files: `src/test/java/edu/harvard/iq/dataverse/containerized/*Test.java`
- Pattern: Uses Docker containers spun up inside test
- Approach: JUnit 5 + Docker client API
- Requirement: Docker + Maven
- Speed: 10-60 seconds per test (includes container startup)
- Coverage: Database operations, complex interactions

**Recommended**: Start with REST Assured tests - simpler, faster feedback

---

## 🚀 Integration Tests: REST Assured (Against Your Deployed Instance)

### Prerequisites (One-Time Setup)

**1. Verify connection to running Dataverse:**

```powershell
# Test API connectivity
curl -i http://localhost:8080/api/info/version
# Expected: HTTP/1.1 200 OK

# Test with authentication (needed for tests)
curl -i -X POST http://localhost:8080/api/admin/authorizationUtil/dumpRoles \
  -H "X-Dataverse-key: secret"
# Expected: HTTP/1.1 200 or 401 (401 means auth not enabled yet)
```

**2. Clone Dataverse source (if not done):**

```powershell
cd c:\dev
git clone https://github.com/IQSS/dataverse.git
cd dataverse
```

**3. Create test user for API tests:**

Create a file: `setup-test-user.sh`

```bash
#!/bin/bash

# Configure test user for integration tests
# Run this ONCE before first integration test run

BASE_URL="${1:-http://localhost:8080}"
API_KEY="secret"

echo "Setting up integration test user on: $BASE_URL"

# 1. Enable test user management (via burrito key)
echo "Step 1: Enabling test user management..."
curl -X PUT \
  -d "BurritoKey" \
  "$BASE_URL/api/admin/settings/:BurritoBep"

# 2. Create test user 'dataverseadmin'
echo "Step 2: Creating admin test user..."
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "Admin",
    "username": "dataverseadmin",
    "email": "admin@test.local",
    "password": "testpass123"
  }' \
  "$BASE_URL/api/users?key=$API_KEY"

# 3. Verify user created
echo "Step 3: Verifying user..."
curl "$BASE_URL/api/admin/userData/dataverseadmin?key=$API_KEY"

echo "✅ Setup complete. Test user: dataverseadmin / testpass123"
```

**Run setup (WSL/Git Bash on Windows):**

```bash
bash setup-test-user.sh http://localhost:8080
```

**4. Configure test parameters in Maven:**

Create file: `test.properties`

```properties
# Integration test configuration
dataverse.api.baseurl=http://localhost:8080
dataverse.api.key=secret

# Test credentials
test.username=dataverseadmin
test.password=testpass123

# Optional: S3 config for file tests
test.s3.enabled=false
```

### Running REST Assured Tests

**Run all integration tests:**

```powershell
cd dataverse

# Run all *IT.java files (requires running Dataverse)
mvn clean verify \
  -P integration-tests \
  -Dapi.baseurl=http://localhost:8080 \
  -Dapi.key=secret

# Expected times:
# - First run with setup: 2-5 minutes
# - Subsequent runs: 1-3 minutes
# - Failures: 0 (for passing tests)
```

**Run single integration test:**

```powershell
# Run BuiltinUsersIT only
mvn verify \
  -P integration-tests \
  -Dit.test=BuiltinUsersIT \
  -Dapi.baseurl=http://localhost:8080

# Run specific test method
mvn verify \
  -P integration-tests \
  -Dit.test=BuiltinUsersIT#testBuiltinUserCreation \
  -Dapi.baseurl=http://localhost:8080
```

**Run with test filtering (focus area):**

```powershell
# Run only tests tagged with "auth"
mvn verify \
  -P integration-tests \
  "-DincludeTags=auth" \
  -Dapi.baseurl=http://localhost:8080

# Run excluding slow tests
mvn verify \
  -P integration-tests \
  "-DexcludeTags=slow" \
  -Dapi.baseurl=http://localhost:8080
```

### Smoke Test Plan: Single Integration Test

**Goal**: Verify REST Assured setup works in 5 minutes

```powershell
# 1. Navigate to source
cd c:\dev\dataverse

# 2. Run the simplest integration test
mvn verify \
  -P integration-tests \
  -Dit.test=BuiltinUsersIT#testCreateUser \
  -Dapi.baseurl=http://localhost:8080 \
  -DskipUnitTests=true

# Expected output (SUCCESS):
# [INFO] -------------------------------------------------------
# [INFO] BUILD SUCCESS
# [INFO] -------------------------------------------------------
# [INFO] Tests run: 1, Failures: 0, Errors: 0, Skipped: 0
```

### Writing Your Own REST Assured Test

**Template: MyFeatureIT.java**

```java
package edu.harvard.iq.dataverse.it;

import com.jayway.restassured.RestAssured;
import com.jayway.restassured.http.ContentType;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.BeforeAll;

import static com.jayway.restassured.RestAssured.*;
import static org.hamcrest.Matchers.*;

public class MyFeatureIT {

    private static String baseUrl;
    private static String apiKey;

    @BeforeAll
    public static void setUp() {
        baseUrl = System.getProperty("dataverse.api.baseurl", "http://localhost:8080");
        apiKey = System.getProperty("dataverse.api.key", "secret");
        RestAssured.baseURI = baseUrl;
    }

    @Test
    public void testMyFeature() {
        // Test: Create a dataset
        given()
            .header("X-Dataverse-key", apiKey)
            .contentType(ContentType.JSON)
            .body("{\"datasetVersion\": {\"metadataBlocks\": {...}}}")
        .when()
            .post("/api/dataverses/root/datasets")
        .then()
            .statusCode(201)  // Assert HTTP 201
            .body("data.id", greaterThan(0));  // Assert response has ID
    }

    @Test
    public void testMyFeatureCleanup() {
        // Use UtilIT helper to create and cleanup
        // UtilIT.createRandomUser() - create test user
        // UtilIT.deleteUser(userId) - cleanup
    }
}
```

**Best Practices:**
- Use UtilIT helper methods: `createRandomUser()`, `createDataset()`, `deleteUser()`
- Always cleanup: create users/datasets, then delete at end
- Assert HTTP status codes first, then response body
- Isolate tests: each test should be independent
- Use meaningful names: `testCreateDatasetAsAuthenticatedUser()`

---

## 🐳 Integration Tests: Testcontainers (Docker-based)

### Prerequisites

```powershell
# Verify Docker is available
docker --version
# Expected: Docker version 20.x or higher

# Verify Docker can run containers
docker run hello-world
# Expected: Hello from Docker message
```

### Running Testcontainers Tests

```powershell
cd dataverse

# Run Testcontainers tests (spins up Docker containers)
mvn clean verify \
  -P testcontainers \
  -DskipUnitTests=true \
  -DskipIntegrationTests=true

# Expected:
# - Docker container started (postgres, solr, etc.)
# - Tests execute
# - Container cleaned up
# - [INFO] BUILD SUCCESS
```

**Run single Testcontainers test:**

```powershell
mvn verify \
  -P testcontainers \
  -Dtest=DataverseContainer* \
  -DskipUnitTests=true
```

### Testcontainers Test Example

```java
package edu.harvard.iq.dataverse;

import org.junit.jupiter.api.Test;
import org.testcontainers.junit.jupiter.Container;
import org.testcontainers.junit.jupiter.Testcontainers;
import org.testcontainers.containers.PostgreSQLContainer;

@Testcontainers
public class DataverseContainerTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>()
        .withDatabaseName("dataverse")
        .withUsername("dataverse")
        .withPassword("secret");

    @Test
    public void testWithContainer() {
        // Database is automatically available
        String jdbcUrl = postgres.getJdbcUrl();
        
        // Connect and test...
        assert jdbcUrl.contains("dataverse");
    }
}
```

---

## 🐛 If Things Go Wrong: Triage Guide

### Category 1: Connection Errors

**Symptom**: `java.net.ConnectException: Connection refused`

```
java.net.ConnectException: Connection refused at 
  edu.harvard.iq.dataverse.it.BuiltinUsersIT.testXXX
```

**Root Causes (Check In Order):**

1. **Dataverse not running**
   ```powershell
   docker-compose ps dataverse
   # Should show: STATUS = "Up"
   
   # Fix:
   docker-compose up -d dataverse
   Start-Sleep -Seconds 30  # Wait for startup
   ```

2. **Wrong URL configured**
   ```powershell
   # Check what's being used
   mvn verify -Dapi.baseurl
   
   # Should be: http://localhost:8080
   # If different, adjust in Maven command or test.properties
   ```

3. **Port 8080 in use by something else**
   ```powershell
   netstat -ano | Select-String ":8080"
   
   # See what process owns it:
   Get-Process | Where-Object { $_.Id -eq <PID> }
   ```

**Fix Steps:**
```powershell
# Step 1: Verify endpoint responding
curl http://localhost:8080/api/info/version

# Step 2: If 404 or timeout, check container logs
docker-compose logs dataverse | tail -50

# Step 3: Restart container
docker-compose restart dataverse
Start-Sleep -Seconds 20

# Step 4: Try test again with verbose output
mvn -X verify -P integration-tests -Dit.test=BuiltinUsersIT
```

---

### Category 2: Authentication Errors

**Symptom**: `HTTP 401 Unauthorized` or `HTTP 403 Forbidden`

```
expected: 201
but was: 401
```

**Root Causes (Check In Order):**

1. **API key not set or wrong**
   ```powershell
   # Verify key with info endpoint (no key needed)
   curl http://localhost:8080/api/info/version
   
   # Try with key header
   curl -H "X-Dataverse-key: secret" http://localhost:8080/api/admin/roles
   ```

2. **Admin user not created**
   ```powershell
   # Create test admin user
   curl -X POST \
     -H "Content-Type: application/json" \
     -d '{"firstName":"Test","lastName":"Admin","username":"dataverseadmin","email":"admin@test","password":"test123"}' \
     http://localhost:8080/api/users?key=secret
   
   # Verify
   curl http://localhost:8080/api/admin/userData/dataverseadmin?key=secret
   ```

3. **Burrito key not set (for insecure mode)**
   ```powershell
   # Enable burrito (disables requirement for auth on certain APIs)
   curl -X PUT -d "BurritoBep" http://localhost:8080/api/admin/settings/:BurritoBep
   ```

**Fix Steps:**
```powershell
# Reset admin user with password
curl -X POST \
  http://localhost:8080/api/admin/authorizationUtil/dumpRoles

# If that fails, check container logs for auth setup
docker-compose exec dataverse bash -c "grep -i auth /opt/payara/glassfish/domains/domain1/logs/server.log" | tail -20
```

---

### Category 3: Test Data Issues

**Symptom**: `AssertionError: expected 200 but was 400` with "Bad Request"

```
statusCode(200)
Expected status code 200 but was 400
```

**Root Causes:**

1. **Database not initialized (first run)**
   ```powershell
   # Check PostgreSQL
   docker-compose logs postgres | grep -i init
   
   # Wait longer:
   Start-Sleep -Seconds 60
   
   # Restart if needed:
   docker-compose down -v
   docker-compose up -d
   Start-Sleep -Seconds 90  # First run takes time
   ```

2. **Test data already exists (duplicate key)**
   ```
   ERROR: duplicate key value violates unique constraint...
   ```
   
   ```powershell
   # Clean up old test data:
   # Option A: Reset database
   docker-compose down -v
   docker-compose up -d
   
   # Option B: Point to clean test database
   # Create new schema in PostgreSQL
   docker-compose exec postgres bash -c \
     "psql -U dataverse -c 'DROP DATABASE test_dataverse; CREATE DATABASE test_dataverse;'"
   ```

3. **Solr index out of sync**
   ```powershell
   # Reindex everything
   curl -X POST \
     -H "X-Dataverse-key: secret" \
     http://localhost:8080/api/admin/index
   
   # Wait for completion
   Start-Sleep -Seconds 30
   ```

**Fix Steps:**
```powershell
# Complete reset (nuclear option - deletes all data)
docker-compose down -v
docker-compose up -d
Start-Sleep -Seconds 90
# Re-run setup steps
```

---

### Category 4: Maven/Build Errors

**Symptom**: `[ERROR] COMPILATION ERROR`

```
[ERROR] Cannot find symbol: class BuiltinUsersIT
[ERROR] symbol:   class BuiltinUsersIT
```

**Root Causes:**

1. **Not in dataverse project directory**
   ```powershell
   # Verify you're in core Dataverse repo
   ls pom.xml
   # Should exist
   
   # If not, navigate:
   cd c:\dev\dataverse
   ```

2. **Maven not installed**
   ```powershell
   mvn -version
   # If not found, install:
   choco install maven
   ```

3. **Java version incompatible**
   ```powershell
   java -version
   # Should be: Java 11, 17, or 21 (v6.10+ requires 11+)
   
   # Install if needed:
   choco install openjdk11
   ```

**Fix Steps:**
```powershell
# Clean Maven cache
mvn clean

# Update dependencies
mvn dependency:resolve

# Rebuild
mvn test
```

---

### Category 5: Coverage Report Missing

**Symptom**: No `target/site/jacoco/` directory after test run

```
File not found: target/site/jacoco/index.html
```

**Root Causes:**

1. **Tests didn't actually run**
   ```powershell
   # Check test results
   ls target/surefire-reports/
   # Should contain: TEST-*.xml files
   ```

2. **Maven didn't execute JaCoCo goal**
   ```powershell
   # Missing command section
   mvn test  # ❌ No jacoco:report goal
   mvn test jacoco:report  # ✅ Includes coverage
   ```

3. **No code actually covered (all tests skipped)**
   ```powershell
   # Check output for:
   # [INFO] Tests run: 0, Failures: 0, Skipped: 0
   ```

**Fix Steps:**
```powershell
# Full command with coverage
mvn clean test \
  -P dev \
  jacoco:report

# Verify report created
dir target/site/jacoco/
# Expected: index.html present

# Open report
Start-Process "$(Get-Item target/site/jacoco/index.html | % FullName)"
```

---

## 🏥 Top 5 Root Causes & Validation

| Rank | Root Cause | Validation | Priority |
|------|-----------|-----------|----------|
| 1 | **Dataverse not running** | `curl http://localhost:8080/api/info/version` → 200 OK | P0 |
| 2 | **Wrong API key** | `curl -H "X-Dataverse-key: secret" http://localhost:8080/...` → 200 | P1 |
| 3 | **Database not initialized** | Check logs: `docker-compose logs postgres` | P1 |
| 4 | **Test data conflicts** | Clear DB: `docker-compose down -v && up -d` | P2 |
| 5 | **Maven/Java wrong version** | `mvn -version` && `java -version` | P2 |

---

## ✨ Next Improvements: Writing Tests for Your Changes

### For New Features (REST Assured)

1. **Locate existing similar test** (e.g., other dataset tests)
   ```powershell
   grep -r "testCreate" src/test/java --include="*IT.java"
   ```

2. **Copy and adapt template:**
   ```
   DatasetsIT.java → MyFeatureIT.java
   ```

3. **Write test before implementation** (TDD):
   ```java
   @Test
   public void testMyNewFeature() {
       // Arrange: setup test data
       String datasetId = UtilIT.createDataset(apiKey, "test");
       
       // Act: call new endpoint
       given()
           .header("X-Dataverse-key", apiKey)
       .when()
           .post("/api/datasets/{id}/myNewAction", datasetId)
       .then()
           .statusCode(200);
       
       // Cleanup
       UtilIT.deleteDataset(datasetId, apiKey);
   }
   ```

4. **Run and validate:**
   ```powershell
   mvn verify -P integration-tests -Dit.test=MyFeatureIT
   ```

### For Deployment/Container Changes (This Repo)

1. **Create smoke test file**: `tests/smoke-test.ps1`
   ```powershell
   # Test deployment stability
   
   # 1. Check containers
   docker-compose ps
   
   # 2. Verify services
   curl http://localhost:8080/api/info/version
   curl http://localhost:8025/  # Email
   
   # 3. Run sample operations
   # ... add your tests ...
   ```

2. **Run as part of CI/CD:**
   ```bash
   # In GitHub Actions workflow
   - name: Run smoke tests
     run: powershell tests/smoke-test.ps1
   ```

### For Database/Solr Changes (Testcontainers)

1. **Create containerized test** in `tests/integration/`:
   ```java
   @Testcontainers
   public class DatabaseMigrationTest {
       @Container
       static PostgreSQLContainer db = new PostgreSQLContainer<>();
       
       @Test
       public void testMigration() {
           // Verify schema changes applied
       }
   }
   ```

2. **Run isolated:**
   ```powershell
   mvn verify -P testcontainers -Dtest=DatabaseMigrationTest
   ```

---

## 🔗 Quick Reference: Commands

```powershell
# Unit Tests (Fast)
mvn clean test -P dev
mvn test -Dtest=BuiltinUsersTest

# Non-essential Unit Tests
mvn clean test -P all-unit-tests

# Coverage Reports
mvn clean test jacoco:report
# Open: target/site/jacoco/index.html

# Integration Tests (Against your instance)
mvn clear verify -P integration-tests -Dapi.baseurl=http://localhost:8080
mvn verify -P integration-tests -Dit.test=BuiltinUsersIT

# Testcontainers Tests
mvn verify -P testcontainers

# Single test with verbose output
mvn -X verify -Dit.test=BuiltinUsersIT#testCreateUser
```

---

## 📋 Final Checklist: Ready to Test?

- [ ] Dataverse running: `docker-compose ps` shows all healthy
- [ ] API responding: `curl http://localhost:8080/api/info/version` returns 200
- [ ] Java installed: `java -version` shows Java 11+
- [ ] Maven installed: `mvn -version` shows Maven 3.8+
- [ ] Dataverse source cloned: `cd c:\dev\dataverse`
- [ ] Can run unit test: `mvn test -Dtest=BuiltinUsersTest` passes
- [ ] Can run integration test: `mvn verify -P integration-tests -Dit.test=BuiltinUsersIT` passes
- [ ] Coverage reports generate: `target/site/jacoco/index.html` exists

✅ **If all checked, you're ready to start comprehensive testing!**

---

## 📞 Support & Resources

| Need | Reference |
|------|-----------|
| **Official Testing Guide** | https://guides.dataverse.org/en/latest/developers/testing.html |
| **REST Assured Docs** | https://rest-assured.io/ |
| **JUnit 5** | https://junit.org/junit5/ |
| **Testcontainers** | https://www.testcontainers.org/ |
| **JaCoCo Coverage** | https://www.jacoco.org/jacoco/ |
| **Dataverse Issues** | https://github.com/IQSS/dataverse/issues |
| **Community Forum** | https://groups.google.com/g/dataverse-community |

---

**Document Version**: 1.0  
**Created**: 2026-04-11  
**For**: Dataverse v6.10.1 Testing  
**Environment**: Docker-based deployment on Windows
