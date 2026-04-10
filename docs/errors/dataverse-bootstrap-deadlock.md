# ERR-COMPOSE-002: Incorrect Environment Variable Names

**Error ID:** ERR-COMPOSE-002  
**Category:** Configuration Error  
**Severity:** HIGH  
**Status:** RESOLVED  
**First Encountered:** 2026-04-10  
**Last Updated:** 2026-04-10  
**Resolution Time:** 6 hours (including investigation)

---

## Summary

Dataverse failed to connect to PostgreSQL during startup due to **incorrect environment variable names**. The compose.yml used `POSTGRES_HOST=postgres` (generic PostgreSQL convention) instead of `DATAVERSE_DB_HOST=postgres` (Dataverse MicroProfile Config format).

---

## Symptom

**Dataverse Container:**
```
dataverse  | Internal Exception: java.sql.SQLException: Error in allocating a connection.
dataverse  | Cause: Connection to localhost:5432 refused. Check that the hostname and port
dataverse  | are correct and that the postmaster is accepting TCP/IP connections.
```

**Bootstrap Container:**
```
bootstrap  | Waiting for http://dataverse:8080 to become ready in max 5m.
bootstrap  | 2026-04-10T20:27:44Z ERR Expectation failed error="the status code doesn't expect" actual=404 expect=200
bootstrap  | Error: context deadline exceeded
```

**Container Status:**
- postgres: healthy ✅
- solr: healthy ✅
- smtp: healthy ✅
- dataverse: **unhealthy** ❌ (can't connect to database)
- bootstrap: **exited with timeout** ❌

---

## Root Cause Analysis

### Configuration Error

The issue was caused by using **incorrect environment variable names** in `configs/compose.yml`.

**What We Used (WRONG):**
```yaml
dataverse:
  environment:
    - POSTGRES_HOST=postgres       # ← Not recognized by Dataverse
    - POSTGRES_PORT=5432
    - POSTGRES_USER=dataverse
    - POSTGRES_PASSWORD=changeme
    - POSTGRES_DATABASE=dataverse
```

**What Official Repo Uses (CORRECT):**
```yaml
dataverse:
  environment:
    DATAVERSE_DB_HOST: postgres     # ← Correct MicroProfile Config format
    DATAVERSE_DB_USER: dataverse    # ← Correct
    DATAVERSE_DB_PASSWORD: secret   # ← Correct
```

### Why Our Variables Were Ignored

Dataverse uses **MicroProfile Config API** for configuration. Environment variables must follow this naming convention:

1. Start with `DATAVERSE_`
2. Convert JVM option name (e.g., `dataverse.db.host`) to environment variable:
   - Uppercase all letters
   - Replace `.` with `_`
   - Replace `-` with `__` (double underscore)

**Example:**
- JVM Option: `dataverse.db.host`
- Env Variable: `DATAVERSE_DB_HOST` ✅

The variables `POSTGRES_HOST`, `POSTGRES_SERVER`, etc. are **generic PostgreSQL conventions**, not Dataverse-specific. Dataverse does not read these variables.

### Source of Confusion

The incorrect variable names likely came from:
1. Third-party or outdated documentation
2. Generic PostgreSQL/Docker tutorials
3. Assumptions based on other container applications

The **official IQSS/dataverse repository** uses the correct variable names in `/docker/compose/demo/compose.yml`.

---

## Impact

**Deployment Failure:** Complete inability to deploy Dataverse due to database connection failure.

**Time Cost:** ~6 hours spent investigating what appeared to be a fundamental design flaw, when it was actually a simple configuration error.

**Misleading Diagnosis:** Initially misdiagnosed as a chicken-and-egg problem in Dataverse container design, leading to extensive (but valuable) documentation of container internals.

---

## Fix

### Step 1: Update Environment Variables

Change `configs/compose.yml` dataverse service environment section:

**FROM:**
```yaml
environment:
  - POSTGRES_HOST=postgres
  - POSTGRES_PORT=5432
  - POSTGRES_USER=${POSTGRES_USER:-dataverse}
  - POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}
  - POSTGRES_DATABASE=${POSTGRES_DB:-dataverse}
```

**TO:**
```yaml
environment:
  DATAVERSE_DB_HOST: postgres
  DATAVERSE_DB_USER: ${POSTGRES_USER:-dataverse}
  DATAVERSE_DB_PASSWORD: ${POSTGRES_PASSWORD:-changeme}
  # Note: Port 5432 is default, DB name 'dataverse' is default
```

### Step 2: Test Deployment

```powershell
# Clean previous failed deployment
docker compose -f configs\compose.yml down -v

# Start with corrected configuration
docker compose -f configs\compose.yml up -d

# Monitor for successful startup
docker compose -f configs\compose.yml logs -f dataverse bootstrap
```

### Step 3: Validate Success

```powershell
# Check all containers healthy
docker compose -f configs\compose.yml ps

# Expected output:
# dataverse: healthy
# postgres: healthy
# solr: healthy
# smtp: healthy
# bootstrap: exited (0)

# Access web interface
Start-Process http://localhost:8080

# Login: dataverseAdmin / admin1
```

---

## Prevention Guidelines

### For This Project

1. **Always reference official repository** at https://github.com/IQSS/dataverse
2. **Use official compose file as template:** `/docker/compose/demo/compose.yml`
3. **Read official container guide:** https://guides.dataverse.org/en/latest/container/
4. **Verify variable names** against `/doc/sphinx-guides/source/installation/config.rst`

### For Dataverse Configuration

1. **Follow MicroProfile Config naming convention:**
   - All Dataverse config uses `DATAVERSE_*` prefix
   - Convert JVM options: `dataverse.option.name` → `DATAVERSE_OPTION_NAME`
   - Double underscore `__` for hyphens in option names

2. **Cross-reference with official examples:**
   - Check `/docker/compose/demo/compose.yml` for environment variables
   - Verify against configuration documentation
   - Test one variable change at a time

3. **Document deviations from official:**
   - If you must deviate, document WHY in comments
   - Link to official source in commit messages
   - Keep a diff/changelog of customizations

### For Container Deployments

1. **Clone official repo for reference:**
   ```bash
   git clone https://github.com/IQSS/dataverse.git
   cd dataverse/docker/compose/demo
   ```

2. **Compare your compose file:**
   ```bash
   diff your-compose.yml official-compose.yml
   ```

3. **Test official first, then customize:**
   - Start with unmodified official compose.yml
   - Verify it works
   - Make changes incrementally
   - Test after each change

---

## Validation Steps

### Verify This Error

```powershell
# Use WRONG variable names
$env:POSTGRES_HOST = "postgres"

# Start deployment
docker compose up -d

# Check logs - will show localhost:5432 refused
docker compose logs dataverse | Select-String "localhost:5432"
```

### Verify Fix

```powershell
# Use CORRECT variable names  
# (already in corrected configs/compose.yml)

# Start deployment
docker compose -f configs\compose.yml up -d

# Wait 3-5 minutes for bootstrap
Start-Sleep -Seconds 300

# Check status - all healthy
docker compose -f configs\compose.yml ps

# Verify API responds
Invoke-WebRequest http://localhost:8080/api/info/version
# Expected: HTTP 200 with JSON response
```

---

## Related Errors

- **ERR-COMPOSE-001:** Docker bind mount networking failure (UNRELATED - different root cause)
- **Future:** If using custom JVM options, always verify MicroProfile Config variable names

---

## References

### Official Documentation
- Container Guide: https://guides.dataverse.org/en/latest/container/
- Official Compose File: https://github.com/IQSS/dataverse/blob/develop/docker/compose/demo/compose.yml
- Configuration Reference: https://guides.dataverse.org/en/latest/installation/config.html
- MicroProfile Config: Line 880 of config.rst explains naming convention

### Variable Name Mappings

| JVM Option | Environment Variable | Notes |
|------------|---------------------|-------|
| `dataverse.db.host` | `DATAVERSE_DB_HOST` | Database hostname |
| `dataverse.db.user` | `DATAVERSE_DB_USER` | Database username |
| `dataverse.db.password` | `DATAVERSE_DB_PASSWORD` | Database password |
| `dataverse.db.name` | `DATAVERSE_DB_NAME` | Database name (default: dataverse) |
| `dataverse.db.port` | `DATAVERSE_DB_PORT` | Database port (default: 5432) |

**WRONG Variable Names (DO NOT USE):**
- ❌ `POSTGRES_HOST` - Generic PostgreSQL, not Dataverse-specific
- ❌ `POSTGRES_SERVER` - Not recognized
- ❌ `DB_HOST` - Too generic
- ❌ `DATABASE_HOST` - Wrong prefix

---

## Lessons Learned

1. **Official > Third-Party:** Always start with official repository and documentation
2. **Test Assumptions:** Don't assume variable names follow common conventions
3. **Read Source Code:** When in doubt, check official compose files
4. **Document Everything:** Even "obvious" variable names should be documented
5. **Ask Community:** #containers at chat.dataverse.org would have resolved this in minutes

---

**Resolution:** Configuration error fixed by using correct environment variable names per MicroProfile Config convention.

**Time Saved (Future):** This error ledger should prevent anyone else from spending hours on this issue.


---

## Symptom

**Bootstrap Container:**
```
bootstrap  | Waiting for http://dataverse:8080 to become ready in max 5m.
bootstrap  | 2026-04-10T20:27:44Z ERR Expectation failed error="the status code doesn't expect" actual=404 expect=200
bootstrap  | Error: context deadline exceeded
```

**Dataverse Container:**
```
dataverse  | Internal Exception: java.sql.SQLException: Error in allocating a connection.
dataverse  | Cause: Connection to localhost:5432 refused. Check that the hostname and port
dataverse  | are correct and that the postmaster is accepting TCP/IP connections.
dataverse  | Boot Command deploy failed
```

**Container Status:**
- postgres: healthy
- solr: healthy
- smtp: healthy
- dataverse: **unhealthy** (can't connect to database)
- bootstrap: **exited with timeout** (Dataverse never became ready)

---

## Root Cause Analysis

### Architecture Flaw

The official `gdcc/dataverse:latest` container has this hardcoded startup sequence:

1. **Container starts** with `domain.xml` that has:
   - H2 embedded database configured (default Payara config)
   - **NO PostgreSQL connection pool** (must be added by bootstrap)
   - Dataverse application attempts to deploy using JPA/EclipseLink

2. **Dataverse deployment fails** because:
   - The Dataverse WAR file tries to establish a database connection during deployment
   - `domain.xml` has no PostgreSQL JDBC resource configured
   - Application fails to deploy, `/api/*` endpoints return HTTP 404

3. **Bootstrap container waits** for:
   - HTTP 200 response from `http://dataverse:8080/api/info/version`
   - This endpoint doesn't exist until the Dataverse application fully deploys
   - Timeout after 5 minutes with "context deadline exceeded"

4. **Deadlock:** Bootstrap can't configure database → Dataverse can't deploy → API never responds → Bootstrap times out

### Why Environment Variables Don't Work

Setting `POSTGRES_HOST=postgres` as an environment variable does NOT help because:
- The Dataverse container does **not** read these variables during startup
- `domain.xml` is generated at **image build time**, not container runtime
- The bootstrap container is supposed to **modify domain.xml via Admin API** after Dataverse is running

### Confirmed via Investigation

```powershell
# Environment variables ARE set correctly in the container
docker exec dataverse env | Select-String POSTGRES
# Output:
# POSTGRES_HOST=postgres
# POSTGRES_PORT=5432
# POSTGRES_USER=dataverse
# POSTGRES_PASSWORD=changeme
# POSTGRES_DATABASE=dataverse

# But domain.xml has NO PostgreSQL config
docker exec dataverse cat /opt/payara/appserver/glassfish/domains/domain1/config/domain.xml | Select-String PostgreSQL
# Output: (empty - no matches)

# Only H2 embedded database configured
docker exec dataverse cat /opt/payara/appserver/glassfish/domains/domain1/config/domain.xml | Select-String jdbc
# Output shows only jdbc:h2: connections
```

---

## Impact

**Deployment Failure:** Complete inability to deploy Dataverse in multi-container configuration using official gdcc/dataverse:latest image with default orchestration.

**User Experience:** 
- 5-10 minute wait followed by timeout
- No clear error message indicating the root cause
- Misleading "connection refused" errors suggesting network issues

**Production Readiness:** This is a **BLOCKER** for any production deployment using official containers.

---

## Attempted Fixes (All Failed)

### Attempt 1: Fix Docker Networking (ERR-COMPOSE-001)
- **Action:** Changed from bind mount volumes to Docker-managed volumes
- **Rationale:** Windows bind mounts can cause Docker DNS issues
- **Result:** ❌ FAILED - Dataverse still tries to connect to localhost:5432

### Attempt 2: Correct Environment Variable Name
- **Action:** Changed `POSTGRES_SERVER` to `POSTGRES_HOST` (per official docs)
- **Rationale:** Environment variable typo
- **Result:** ❌ FAILED - Variables are set but ignored

### Attempt 3: Remove Bootstrap Health Check Dependency
- **Action:** Changed `depends_on: dataverse: condition: service_healthy` to simple `depends_on: - dataverse`
- **Rationale:** Allow bootstrap to start even if dataverse is unhealthy
- **Result:** ⚠️ PARTIAL - Bootstrap starts, but times out waiting for API

---

## Workarounds

### Option A: Pre-configure domain.xml (RECOMMENDED)

**Approach:** Inject a pre-configured `domain.xml` with PostgreSQL connection pool before Dataverse starts.

**Implementation:**

1. Extract default domain.xml from container:
```powershell
docker run --rm -it gdcc/dataverse:latest cat /opt/payara/appserver/glassfish/domains/domain1/config/domain.xml > domain.xml.template
```

2. Add PostgreSQL JDBC resources to domain.xml:
```xml
<jdbc-connection-pool
    name="VDCNetDSPool"
    datasource-classname="org.postgresql.ds.PGConnectionPoolDataSource"
    res-type="javax.sql.ConnectionPoolDataSource"
    is-isolation-level-guaranteed="false">
  <property name="serverName" value="postgres"></property>
  <property name="portNumber" value="5432"></property>
  <property name="databaseName" value="dataverse"></property>
  <property name="user" value="dataverse"></property>
  <property name="password" value="${POSTGRES_PASSWORD}"></property>
</jdbc-connection-pool>

<jdbc-resource
    pool-name="VDCNetDSPool"
    jndi-name="jdbc/VDCNetDS">
</jdbc-resource>
```

3. Mount modified domain.xml into container:
```yaml
dataverse:
  volumes:
    - ./configs/domain.xml:/opt/payara/appserver/glassfish/domains/domain1/config/domain.xml:ro
    - dataverse-data:/dv
```

4. Use bootstrap ONLY for application-level configuration (settings, users, etc.)

**Pros:**
- ✅ Breaks the deadlock - Dataverse can deploy immediately
- ✅ No timeout issues
- ✅ Faster startup (no waiting for API to be ready)

**Cons:**
- ❌ Requires maintaining a custom domain.xml
- ❌ Password in domain.xml (mitigate with environment variable substitution)
- ❌ Deviates from official documentation

---

### Option B: Increase Bootstrap Timeout + Disable Health Checks

**Approach:** Give Dataverse more time to fail health checks repeatedly until bootstrap forcibly configures it.

**Implementation:**

1. Increase bootstrap timeout to 15-20 minutes:
```yaml
bootstrap:
  environment:
    - TIMEOUT=20m  # Very long timeout
```

2. Remove Dataverse health check entirely:
```yaml
dataverse:
  # healthcheck:  # COMMENTED OUT
  #   test: ["CMD-SHELL", "curl -sf http://localhost:8080/api/info/version || exit 1"]
```

3. Let Dataverse startup fail repeatedly in background while bootstrap waits

**Pros:**
- ✅ Stays closer to official documentation
- ✅ No custom domain.xml required

**Cons:**
- ❌ Very slow (15-20 minute wait with continuous errors in logs)
- ❌ Still might not work (bootstrap expects HTTP 200, not deployment failure)
- ❌ Resource waste (failed deployments retry indefinitely)
- ❌ **NOT TESTED** - may still fail

---

### Option C: Single-Container Deployment

**Approach:** Run PostgreSQL and Dataverse in the same container (not recommended for production).

**Implementation:**

Use official `gdcc/dataverse:latest` which bundles PostgreSQL, Solr, and Dataverse in one container.

**Pros:**
- ✅ No orchestration complexity
- ✅ Works out of the box

**Cons:**
- ❌ NOT production-ready (violates container best practices)
- ❌ No horizontal scaling
- ❌ Difficult to backup/maintain
- ❌ Resource limits affect all services together

---

## Recommended Solution

**Use Workaround Option A** (Pre-configured domain.xml):

1. Create `configs/domain.xml` with PostgreSQL connection pool
2. Mount it into the dataverse container
3. Keep bootstrap for application-level configuration only
4. Document deviation from official setup in OPERATIONS.md

**Rationale:**
- Only solution that guarantees success
- Minimal deviation from official architecture (still multi-container)
- Production-viable (explicit configuration is better than implicit magic)
- Can be templated/parameterized for different environments

---

## Prevention Guidelines

### For Future Dataverse Container Updates

1. **Check Release Notes:** Verify if upstream fixes this deadlock in newer versions
2. **Test Bootstrap First:** Always test if bootstrap can configure database before relying on it
3. **Have domain.xml Backup:** Keep a working domain.xml template in version control

### For Similar Multi-Container Apps

1. **Config-First, Not Config-Later:** Inject configuration at container start, not after
2. **Health Checks Must Be Independent:** Don't depend on external services being configured first
3. **Document Initialization Order:** Make startup dependencies explicit in docker-compose.yml

---

## Validation Steps

### Verify This Error

```powershell
# Start deployment
docker compose -f configs\compose.yml up -d

# Wait 6 minutes, then check status
docker compose -f configs\compose.yml ps
# Expected: dataverse=unhealthy, bootstrap=exited (timeout)

# Check dataverse logs for localhost:5432
docker compose -f configs\compose.yml logs dataverse | Select-String "localhost:5432"
# Expected: Multiple "Connection refused" errors

# Check bootstrap logs for timeout
docker compose -f configs\compose.yml logs bootstrap | Select-String "deadline"
# Expected: "Error: context deadline exceeded"
```

### Verify Fix (After Implementing Workaround A)

```powershell
# Start deployment with pre-configured domain.xml
docker compose -f configs\compose.yml up -d

# Wait 3-5 minutes
Start-Sleep -Seconds 300

# Check status - should ALL be healthy
docker compose -f configs\compose.yml ps
# Expected: dataverse=healthy, bootstrap=exited(0), postgres/solr/smtp=healthy

# Verify API responds
curl http://localhost:8080/api/info/version
# Expected: HTTP 200 with version JSON
```

---

## Related Errors

- **ERR-COMPOSE-001:** Docker bind mount networking failure (RESOLVED - unrelated to this)
- **ERR-BOOTSTRAP-001:** (Future) Bootstrap timeout due to slow API startup (DIFFERENT - assumes API eventually works)

---

## References

- Dataverse Container Guide: https://guides.dataverse.org/en/latest/container/
- Official Compose Example: https://guides.dataverse.org/en/latest/_downloads/f08d721f1b85dd424dff557bf65fdc5c/compose.yml
- Bootstrap Container Source: https://github.com/IQSS/dataverse-docker/tree/master/configbaker
- Payara JDBC Configuration: https://docs.payara.fish/community/docs/documentation/user-guides/connection-pools/connection-pools.html

---

**Note:** This error highlights a fundamental flaw in the official Dataverse container design. The issue should be reported upstream to the IQSS/dataverse-docker project.
