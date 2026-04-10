# Operations Manual

This document provides operational procedures for deploying, monitoring, maintaining, and troubleshooting the Dataverse production environment.

---

## 📋 Table of Contents

- [Deployment Procedures](#deployment-procedures)
- [Monitoring & Health Checks](#monitoring--health-checks)
- [Backup & Recovery](#backup--recovery)
- [Incident Response](#incident-response)
- [Maintenance Windows](#maintenance-windows)
- [Troubleshooting Runbooks](#troubleshooting-runbooks)
- [Escalation Procedures](#escalation-procedures)
- [Operational Metrics](#operational-metrics)

---

## Deployment Procedures

### Initial Deployment

**Prerequisites Checklist:**
- [ ] Docker installed and running
- [ ] `.env` file created with secure passwords
- [ ] Firewall rules configured (port 8080 accessible)
- [ ] Backup storage provisioned
- [ ] Monitoring tools configured

**Steps:**

1. **Verify Prerequisites**
   ```powershell
   docker --version
   docker compose version
   Test-Path .env  # Should return True
   ```

2. **Pull Images**
   ```powershell
   docker compose pull
   ```

3. **Start Services**
   ```powershell
   docker compose up -d
   ```

4. **Monitor Bootstrap**
   ```powershell
   docker compose logs -f bootstrap
   # Wait for "Successfully completed bootstrap" message
   ```

5. **Verify Health**
   ```powershell
   .\scripts\healthcheck.ps1
   ```

6. **Access Web UI**
   - Navigate to: http://localhost:8080
   - Login: `dataverseAdmin` / `admin1`

7. **Change Default Password**
   - Go to Account Settings
   - Update password to strong value

**Expected Duration:** 10-15 minutes

**Rollback Procedure:**
```powershell
docker compose down
Remove-Item -Recurse -Force data
# Restore from last known good backup
```

---

### Upgrade Procedure

**Before Upgrade:**
- [ ] Read release notes for breaking changes
- [ ] Schedule maintenance window (4 hours recommended)
- [ ] Notify users of downtime
- [ ] Complete full backup
- [ ] Test upgrade in staging environment

**Steps:**

1. **Backup Current State**
   ```powershell
   .\scripts\backup.ps1 -BackupPath "backups\pre-upgrade-$(Get-Date -Format 'yyyyMMdd')"
   ```

2. **Stop Services**
   ```powershell
   docker compose down
   ```

3. **Update Images**
   ```powershell
   # Edit .env to specify new version
   $env:DATAVERSE_VERSION = "6.0"
   docker compose pull
   ```

4. **Start Services**
   ```powershell
   docker compose up -d
   ```

5. **Monitor Database Migration**
   ```powershell
   docker compose logs -f dataverse | Select-String "Flyway"
   # Watch for successful migration
   ```

6. **Reindex Search**
   ```powershell
   curl -X POST "http://localhost:8080/api/admin/index"
   ```

7. **Verify Functionality**
   ```powershell
   .\tests\smoke-test.ps1
   ```

8. **Monitor for 24 Hours**
   - Check logs for errors
   - Monitor resource usage
   - Verify user reports

**Rollback Procedure:**
```powershell
docker compose down
.\scripts\restore.ps1 -BackupPath "backups\pre-upgrade-20260410"
docker compose up -d
```

---

## Monitoring & Health Checks

### Automated Health Checks

Docker Compose health checks run automatically:

```powershell
# View health status
docker compose ps

# Expected output:
# NAME         STATUS
# dataverse    Up (healthy)
# postgres     Up (healthy)
# solr         Up (healthy)
```

### Manual Health Check Script

Run periodically (or via cron/Task Scheduler):

```powershell
.\scripts\healthcheck.ps1
```

**Checks Performed:**
- ✅ All containers running
- ✅ Dataverse web UI accessible
- ✅ API responding
- ✅ Database connectivity
- ✅ Solr search functional
- ✅ Disk space >20% free
- ✅ Memory usage <80%

### Log Monitoring

**View Real-Time Logs:**
```powershell
docker compose logs -f
```

**Check for Errors:**
```powershell
docker compose logs dataverse | Select-String "ERROR"
docker compose logs postgres | Select-String "FATAL"
```

**Log Rotation:**
Configured in `compose.yml`:
```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

### Resource Monitoring

**Container Resource Usage:**
```powershell
docker stats --no-stream
```

**Disk Usage:**
```powershell
# Check data directory size
Get-ChildItem -Path data -Recurse | Measure-Object -Property Length -Sum

# Check available space
Get-PSDrive C | Select-Object Used,Free
```

**Thresholds:**
- CPU: Alert if >80% for >5 minutes
- Memory: Alert if >90%
- Disk: Alert if <10 GB free

---

## Backup & Recovery

### Automated Daily Backup

**Schedule Setup (Windows Task Scheduler):**

1. Open Task Scheduler
2. Create New Task:
   - Name: "Dataverse Daily Backup"
   - Trigger: Daily at 2:00 AM
   - Action: Run `powershell.exe -File C:\path\to\scripts\backup.ps1`
   - Run whether user is logged on or not

**Backup Script:**
```powershell
.\scripts\backup.ps1
```

**What Gets Backed Up:**
- PostgreSQL database (via `pg_dump`)
- Uploaded files (entire `data/dataverse/` directory)
- Configuration files (`.env`, `compose.yml`, `demo/`)
- Secrets (encrypted)

**Storage:**
- Local: `backups/` directory
- Offsite: Copy to network share or cloud storage (recommended)

### Manual Backup

**On-Demand Backup:**
```powershell
.\scripts\backup.ps1 -BackupPath "backups\manual-$(Get-Date -Format 'yyyyMMdd-HHmm')"
```

### Restore Procedure

**Prerequisites:**
- Valid backup files
- Downtime window (1-2 hours)

**Steps:**

1. **Stop Services**
   ```powershell
   docker compose down
   ```

2. **Restore Database**
   ```powershell
   .\scripts\restore.ps1 -BackupPath "backups\20260410" -RestoreDatabase
   ```

3. **Restore Files**
   ```powershell
   .\scripts\restore.ps1 -BackupPath "backups\20260410" -RestoreFiles
   ```

4. **Start Services**
   ```powershell
   docker compose up -d
   ```

5. **Verify Integrity**
   ```powershell
   .\tests\smoke-test.ps1
   ```

**Expected Duration:** 1-2 hours (depends on data size)

### Backup Retention Policy

- **Daily Backups:** Keep for 7 days
- **Weekly Backups:** Keep for 4 weeks
- **Monthly Backups:** Keep for 12 months
- **Yearly Backups:** Keep for 7 years (compliance)

---

## Incident Response

### Severity Levels

| Severity | Definition | Response Time | Examples |
|----------|------------|---------------|----------|
| **P1 - Critical** | Service down, data loss risk | 15 minutes | Database unreachable, container crash loop |
| **P2 - High** | Major degradation | 1 hour | Slow performance, search broken |
| **P3 - Medium** | Partial impact | 4 hours | File upload fails for some formats |
| **P4 - Low** | Minimal impact | 1 business day | Cosmetic issues, minor bugs |

### Incident Response Workflow

1. **Detection**
   - Monitoring alert triggers
   - User report received
   - Health check fails

2. **Triage**
   - Assign severity level
   - Notify on-call engineer
   - Create incident ticket

3. **Investigation**
   - Check logs: `docker compose logs -f`
   - Check resource usage: `docker stats`
   - Check disk space
   - Review recent changes

4. **Mitigation**
   - Restart services if needed
   - Rollback if caused by recent deployment
   - Apply hotfix

5. **Resolution**
   - Verify service restored
   - Update incident ticket
   - Notify users

6. **Post-Incident Review**
   - Document root cause
   - Update error ledger
   - Implement preventive measures

---

## Maintenance Windows

### Scheduled Maintenance

**Frequency:** Monthly (first Sunday, 2:00 AM - 6:00 AM)

**Activities:**
- Apply security updates
- Upgrade Docker images
- Database vacuum and reindex
- Review and rotate logs
- Test backup restore

**Notification:**
- Email users 7 days in advance
- Display banner 24 hours before

### Emergency Maintenance

For critical security patches or service restoration:
- Notify users as soon as possible
- Complete within 4-hour window
- Provide post-maintenance summary

---

## Troubleshooting Runbooks

### Runbook 1: Container Won't Start

**Symptoms:**
- `docker compose up` fails
- Container status: `Exited (1)`

**Investigation:**
```powershell
docker compose logs <container_name>
docker compose ps
docker inspect <container_id>
```

**Common Causes & Fixes:**

1. **Port Already in Use**
   - Check: `netstat -ano | Select-String ":8080"`
   - Fix: Change port in `.env` or stop conflicting service

2. **Missing Environment Variable**
   - Check: `.env` file exists and has required values
   - Fix: Copy from `.env.example`

3. **Volume Mount Failure**
   - Check: Permissions on `data/` directory
   - Fix: `icacls data /grant Everyone:F /T`

4. **Out of Memory**
   - Check: `docker stats`
   - Fix: Increase Docker Desktop memory allocation

**Escalation:** If not resolved in 30 minutes, escalate to P2.

---

### Runbook 2: Database Connection Errors

**Symptoms:**
- Dataverse logs show: `Unable to connect to database`
- API returns 500 errors

**Investigation:**
```powershell
docker compose ps postgres  # Should be "Up (healthy)"
docker compose logs postgres
docker compose exec postgres psql -U dataverse -d dataverse -c "SELECT 1;"
```

**Common Causes & Fixes:**

1. **PostgreSQL Not Running**
   - Fix: `docker compose restart postgres`

2. **Wrong Credentials**
   - Check: `.env` file has correct `POSTGRES_PASSWORD`
   - Fix: Update `.env` and restart

3. **Database Corruption**
   - Check: `docker compose logs postgres | Select-String "PANIC"`
   - Fix: Restore from backup

4. **Disk Full**
   - Check: `Get-PSDrive C`
   - Fix: Free up space or expand disk

**Escalation:** If data corruption suspected, escalate to P1 immediately.

---

### Runbook 3: Search Not Working

**Symptoms:**
- Search returns no results
- Search returns errors

**Investigation:**
```powershell
docker compose ps solr
docker compose logs solr
curl http://localhost:8983/solr/admin/cores?action=STATUS
```

**Common Causes & Fixes:**

1. **Solr Not Running**
   - Fix: `docker compose restart solr`

2. **Index Corrupted**
   - Fix: Reindex from database:
     ```powershell
     curl -X POST http://localhost:8080/api/admin/index
     ```

3. **Solr Core Missing**
   - Fix: Recreate core (requires bootstrap)

**Escalation:** If reindexing fails, escalate to P2.

---

### Runbook 4: Slow Performance

**Symptoms:**
- Pages load slowly (>5 seconds)
- API requests timeout

**Investigation:**
```powershell
docker stats
docker compose logs dataverse | Select-String "slow query"
```

**Common Causes & Fixes:**

1. **High CPU/Memory Usage**
   - Check: `docker stats`
   - Fix: Increase resource allocation or scale horizontally

2. **Database Needs Vacuum**
   - Fix:
     ```powershell
     docker compose exec postgres vacuumdb -U dataverse -d dataverse --analyze
     ```

3. **Large Solr Index**
   - Fix: Optimize index:
     ```powershell
     curl "http://localhost:8983/solr/collection1/update?optimize=true"
     ```

4. **Disk I/O Bottleneck**
   - Check: Disk queue length
   - Fix: Move to faster storage (SSD)

**Escalation:** If performance doesn't improve in 1 hour, escalate to P2.

---

### Runbook 5: File Upload Failures

**Symptoms:**
- Users report upload errors
- Files don't appear after upload

**Investigation:**
```powershell
docker compose logs dataverse | Select-String "upload"
Get-ChildItem -Path data\dataverse
$disk = Get-PSDrive C
$disk.Free / 1GB  # Check free space in GB
```

**Common Causes & Fixes:**

1. **Disk Full**
   - Check: Free space <5 GB
   - Fix: Free up space or expand disk

2. **Permissions Issue**
   - Check: `icacls data\dataverse`
   - Fix: Grant write permissions

3. **File Too Large**
   - Check: Dataverse max file size setting
   - Fix: Increase limit via API:
     ```powershell
     curl -X PUT -d "5000000000" http://localhost:8080/api/admin/settings/:MaxFileUploadSizeInBytes
     ```

**Escalation:** If issue affects multiple users, escalate to P2.

---

## Escalation Procedures

### On-Call Rotation

| Time | Primary | Secondary |
|------|---------|-----------|
| Mon-Fri 9-5 | Team Lead | Senior Engineer |
| Mon-Fri 5-9 | On-Call Engineer | Team Lead |
| Weekends | On-Call Engineer | Senior Engineer |

### Escalation Path

1. **L1 Support** → Check runbooks, attempt standard fixes
2. **L2 Support** → Senior engineer, advanced troubleshooting
3. **L3 Support** → System architect, code-level debugging
4. **Vendor Support** → Dataverse community, GDCC team

### Contact Information

- **Team Lead**: team-lead@yourorg.com
- **On-Call**: +1-555-0100 (PagerDuty)
- **Security Incidents**: security@yourorg.com
- **Dataverse Community**: https://groups.google.com/g/dataverse-community

---

## Operational Metrics

### Key Performance Indicators (KPIs)

| Metric | Target | Measurement |
|--------|--------|-------------|
| **Uptime** | 99.5% | Monthly |
| **Response Time** | <2s (P95) | Real-time |
| **Error Rate** | <0.1% | Hourly |
| **Backup Success** | 100% | Daily |
| **Mean Time to Recovery** | <4 hours | Per incident |

### Monitoring Dashboards

**Docker Stats:**
```powershell
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

**Dataverse Metrics (via API):**
```powershell
curl http://localhost:8080/api/info/metrics
```

**Custom Dashboard:**
- Install Grafana + Prometheus (optional)
- Import Dataverse dashboard template
- Configure alerts for threshold violations

---

## Change Log

All operational changes must be logged:

| Date | Change | Operator | Result |
|------|--------|----------|--------|
| 2026-04-10 | Initial deployment | ops-team | Success |
| TBD | First backup test | TBD | TBD |

---

## References

- **Dataverse Admin Guide**: https://guides.dataverse.org/en/latest/admin/
- **Docker Documentation**: https://docs.docker.com/
- **PostgreSQL Operations**: https://www.postgresql.org/docs/13/admin.html
- **ARCHITECTURE.md**: System architecture
- **SECURITY.md**: Security procedures

---

*Last updated: 2026-04-10 | Version: 1.0*
