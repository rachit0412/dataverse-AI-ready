# Security Deployment Guide

Complete guide for deploying Dataverse with comprehensive security hardening measures.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Security Overview](#security-overview)
3. [Deployment Steps](#deployment-steps)
4. [Validation & Testing](#validation--testing)
5. [Monitoring & Maintenance](#monitoring--maintenance)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Docker Desktop** 24.0+ or **Docker Engine** 24.0+
- **Docker Compose** 2.20+
- **PowerShell** 7.0+ (for automation scripts)
- **Git** (for version control)

### System Requirements

- **Memory**: 16 GB RAM minimum (32 GB recommended)
- **Storage**: 50 GB free disk space
- **CPU**: 4 cores minimum (8 cores recommended)
- **OS**: Windows 10/11, Linux, or macOS

### Network Requirements

- Port 80 (HTTP) - API Gateway
- Port 443 (HTTPS) - API Gateway (when SSL enabled)
- Outbound internet access for initial image pull

---

## Security Overview

### Security Architecture

The security-hardened deployment implements multiple layers of defense:

```
┌─────────────────────────────────────────────────────┐
│                  Internet/Users                      │
└────────────────────┬────────────────────────────────┘
                     │
                     │ HTTPS/TLS (Port 443)
                     │ Rate Limited
                     ▼
┌─────────────────────────────────────────────────────┐
│            API Gateway (nginx)                       │
│  - Rate Limiting                                     │
│  - Security Headers                                  │
│  - Request Filtering                                 │
│  - DDoS Protection                                   │
└────────────────────┬────────────────────────────────┘
                     │
      ┌──────────────┼──────────────┐
      │              │               │
      ▼              ▼               ▼
┌─────────────┐ ┌───────────┐ ┌──────────────┐
│  Dataverse  │ │  MailDev  │ │  Previewers  │
│  (Payara)   │ │  (SMTP)   │ │  (Provider)  │
└──────┬──────┘ └───────────┘ └──────────────┘
       │                Frontend Network
       │              (Internet Access)
       │
       ▼
┌─────────────────────────────────────────────────────┐
│           Backend Network (ISOLATED)                 │
│           internal: true (No Internet)               │
│  ┌──────────────┐  ┌──────────────────────────┐   │
│  │  PostgreSQL  │  │  Solr Search Engine      │   │
│  │  (Database)  │  │  (Full-text Search)      │   │
│  └──────────────┘  └──────────────────────────┘   │
│                                                      │
│  ★ Fully isolated from internet                     │
│  ★ No inbound/outbound external traffic             │
│  ★ Only accessible via frontend services            │
└─────────────────────────────────────────────────────┘
```

### Security Features Implemented

#### ✅ Container Security

- **Non-Root Users**: All containers run as non-root users
- **Read-Only Filesystems**: Root filesystems are read-only
- **Dropped Capabilities**: ALL capabilities dropped, only required ones added
- **No New Privileges**: `no-new-privileges:true` prevents privilege escalation
- **AppArmor/SELinux**: Mandatory Access Control (MAC) enabled

#### ✅ Network Security

- **Network Segmentation**: Frontend and backend networks isolated
- **Internal Backend**: Backend network has `internal: true` (no internet access)
- **API Gateway**: Single entry point with nginx reverse proxy
- **Rate Limiting**: Protection against brute force and DoS attacks
- **Security Headers**: HSTS, CSP, X-Frame-Options, etc.

#### ✅ Secrets Management

- **Docker Secrets**: Credentials stored as Docker secrets
- **No Environment Variables**: No sensitive data in environment variables
- **In-Memory Secrets**: Secrets mounted as tmpfs (in-memory filesystems)
- **Restricted Permissions**: Secret files have 0400 permissions

#### ✅ Resource Management

- **Memory Limits**: Prevents memory exhaustion attacks
- **CPU Limits**: Prevents CPU starvation
- **PID Limits**: Prevents fork bomb attacks
- **Disk Quotas**: Tmpfs mounts have size limits

#### ✅ Additional Hardening

- **Minimal Images**: Using Alpine Linux and slim variants
- **Health Checks**: Automated health monitoring
- **Logging**: Centralized logging configuration
- **Automated Updates**: Container restart policies configured

---

## Deployment Steps

### Step 1: Clone and Prepare Repository

```powershell
# Clone repository (if not already done)
git clone <your-repo-url>
cd dataverse-AI-ready

# Verify file structure
ls docker-compose-secure.yml
ls generate-secrets.ps1
ls security-scan.ps1
ls validate-host-isolation.ps1
```

### Step 2: Generate Docker Secrets

```powershell
# Generate secrets (REQUIRED before deployment)
.\generate-secrets.ps1

# This will create:
#   ./secrets/postgres_user.txt
#   ./secrets/postgres_password.txt
#   ./secrets/dataverse_admin_password.txt
#   ./secrets/SECRETS_SUMMARY.txt

# Review generated secrets
cat .\secrets\SECRETS_SUMMARY.txt
```

**🔒 Security Note**: The `generate-secrets.ps1` script:
- Generates cryptographically secure random passwords (32 characters)
- Sets restrictive file permissions (read-only for current user)
- Creates in-memory secrets for Docker Compose
- Generates a summary file for reference

### Step 3: Configure Environment Variables

```powershell
# Copy environment template
cp .env.example .env

# Edit .env file
notepad .env
```

**Key configurations**:

```bash
# Dataverse Configuration
DATAVERSE_VERSION=latest
DATAVERSE_DB_HOST=postgres
DATAVERSE_DB_NAME=dataverse

# Bootstrap Configuration
BOOTSTRAP_MODE=full
INIT_SCRIPTS_FOLDER=./demo

# API Gateway
API_GATEWAY_PORT=80

# Solr Configuration
SOLR_VERSION=9.6.1-slim
SOLR_COLLECTION=dataverse

# PostgreSQL
POSTGRES_VERSION=16-alpine
```

⚠️ **DO NOT** put passwords in `.env` file - they are managed via Docker secrets.

### Step 4: Verify Configuration

```powershell
# Run security scan (pre-deployment)
.\security-scan.ps1 -ComposeFile docker-compose-secure.yml

# This will check:
# - Docker installation
# - Compose file security
# - Secrets configuration
# - Network isolation
# - Resource limits
# - Security contexts
```

Expected output:
```
Security Score: 85-95 / 100
Critical: 0
High: 0
Medium: 0-2
Low: 0-3
```

### Step 5: Create Data Directories

```powershell
# Create directories for persistent data
mkdir -p data/postgres
mkdir -p data/solr
mkdir -p data/dataverse
mkdir -p data/secrets

# Set permissions (Linux/macOS)
# chmod 700 data/postgres
# chmod 700 data/solr
# chmod 700 data/dataverse
```

### Step 6: Pull Docker Images

```powershell
# Pull all required images
docker-compose -f docker-compose-secure.yml pull

# This will download:
# - gdcc/dataverse:latest
# - postgres:16-alpine
# - solr:9.6.1-slim
# - nginx:alpine
# - maildev/maildev:2.1.0
# - gdcc/configbaker:latest
# - trivadis/dataverse-previewers-provider:latest
```

### Step 7: Deploy Containers

```powershell
# Deploy all services
docker-compose -f docker-compose-secure.yml up -d

# Monitor deployment
docker-compose -f docker-compose-secure.yml ps
docker-compose -f docker-compose-secure.yml logs -f
```

**Deployment timeline**:
1. **Network Creation** (5 seconds)
2. **Database Initialization** (30-60 seconds)
   - PostgreSQL starts
   - Database schema created
3. **Solr Initialization** (30 seconds)
   - Core creation
   - Schema configuration
4. **ConfigBaker** (10-15 seconds)
   - Waits for dependencies
   - Configures Dataverse settings
5. **Dataverse Startup** (60-120 seconds)
   - Payara server initialization
   - Application deployment
   - Bootstrap configuration
6. **API Gateway** (5 seconds)
   - nginx starts immediately
   - Begins routing traffic

**Total deployment time**: 3-5 minutes

### Step 8: Wait for Bootstrap

```powershell
# Check bootstrap progress
docker-compose -f docker-compose-secure.yml logs bootstrap

# Wait for completion message:
# "Bootstrap configuration complete"
```

### Step 9: Verify Deployment

```powershell
# Check all services are running
docker-compose -f docker-compose-secure.yml ps

# Expected output:
NAME                    STATUS
dataverse               Up (healthy)
postgres                Up (healthy)
solr                    Up (healthy)
api-gateway             Up (healthy)
smtp                    Up
previewers-provider     Up
bootstrap               Exit 0

# Test API Gateway health
curl http://localhost/health
# Expected: "healthy"

# Test Dataverse API
curl http://localhost/api/info/version
# Expected: JSON response with version info
```

---

## Validation & Testing

### Security Validation

#### Run Security Scan

```powershell
# Comprehensive security scan
.\security-scan.ps1 -ComposeFile docker-compose-secure.yml

# Review report
cat .\security-scan-report.txt
```

#### Validate Host Isolation

```powershell
# Test container isolation from host
.\validate-host-isolation.ps1 -ContainerPrefix dataverse

# Review isolation report
cat .\host-isolation-report.txt
```

Expected results:
- ✅ Passed: 40-50 tests
- ⚠️ Warnings: 0-5 tests
- ❌ Failed: 0 tests

#### Manual Security Checks

```powershell
# 1. Verify containers running as non-root
docker exec dataverse_dataverse_1 whoami
# Expected: payara (not root)

docker exec dataverse_postgres_1 whoami
# Expected: postgres (not root)

# 2. Test read-only filesystem
docker exec dataverse_postgres_1 touch /test
# Expected: Error (read-only file system)

# 3. Verify backend network isolation
docker exec dataverse_postgres_1 ping -c 1 8.8.8.8
# Expected: Error (network unreachable)

# 4. Check secrets mounting
docker exec dataverse_postgres_1 ls /run/secrets/
# Expected: postgres_user, postgres_password

# 5. Verify capabilities dropped
docker inspect dataverse_postgres_1 --format='{{.HostConfig.CapDrop}}'
# Expected: [ALL]

# 6. Check resource limits
docker inspect dataverse_postgres_1 --format='Memory: {{.HostConfig.Memory}}, CPUs: {{.HostConfig.CpuQuota}}'
# Expected: Memory: 2147483648 (2GB), CPUs: 200000 (2.0 CPUs)
```

### Functional Testing

#### Test Web Interface

1. **Access Dataverse**
   ```
   http://localhost/
   ```

2. **Login as Admin**
   - Username: `dataverseAdmin`
   - Password: See `./secrets/dataverse_admin_password.txt`

3. **Create Test Dataverse**
   - Navigate to "Add Data" → "New Dataverse"
   - Fill in required fields
   - Verify creation successful

4. **Upload Test Dataset**
   - Create new dataset
   - Upload test file
   - Verify file preview works

#### Test API Endpoints

```powershell
# Get version info
curl http://localhost/api/info/version

# Get server info
curl http://localhost/api/info/server

# Search (should return empty initially)
curl http://localhost/api/search?q=*

# Test authentication
$password = Get-Content .\secrets\dataverse_admin_password.txt
curl -H "X-Dataverse-key: $password" http://localhost/api/users/:me
```

#### Test Email Functionality

1. **Access MailDev UI**
   ```
   http://localhost/maildev/
   ```

2. **Trigger Test Email**
   - Register new user in Dataverse
   - Check MailDev for confirmation email

### Performance Testing

```powershell
# Test API Gateway throughput
ab -n 1000 -c 10 http://localhost/health

# Test Dataverse API
ab -n 100 -c 5 http://localhost/api/info/version

# Monitor resource usage
docker stats
```

---

## Monitoring & Maintenance

### Health Monitoring

#### Check Service Health

```powershell
# View health status
docker-compose -f docker-compose-secure.yml ps

# Check individual service
docker inspect --format='{{.State.Health.Status}}' dataverse_dataverse_1
```

#### Monitor Logs

```powershell
# All services
docker-compose -f docker-compose-secure.yml logs -f

# Specific service
docker-compose -f docker-compose-secure.yml logs -f dataverse

# Filter errors
docker-compose -f docker-compose-secure.yml logs | Select-String -Pattern "ERROR|WARN"
```

### Resource Monitoring

```powershell
# Real-time resource usage
docker stats

# Per-container metrics
docker stats dataverse_postgres_1 dataverse_dataverse_1
```

### Security Monitoring

```powershell
# Run periodic security scans
.\security-scan.ps1 -ComposeFile docker-compose-secure.yml

# Schedule daily scan (Windows Task Scheduler)
# Create scheduled task to run security-scan.ps1 daily
```

### Backup & Recovery

#### Backup Database

```powershell
# Backup PostgreSQL
docker exec dataverse_postgres_1 pg_dump -U dataverse dataverse > backup_$(Get-Date -Format "yyyyMMdd").sql

# Backup with compression
docker exec dataverse_postgres_1 pg_dump -U dataverse -Fc dataverse > backup_$(Get-Date -Format "yyyyMMdd").dump
```

#### Backup Solr Index

```powershell
# Backup Solr data
docker exec dataverse_solr_1 tar czf /tmp/solr-backup.tar.gz /var/solr
docker cp dataverse_solr_1:/tmp/solr-backup.tar.gz ./backups/
```

#### Restore Database

```powershell
# Stop services
docker-compose -f docker-compose-secure.yml stop dataverse bootstrap

# Restore database
cat backup_20260330.sql | docker exec -i dataverse_postgres_1 psql -U dataverse dataverse

# Start services
docker-compose -f docker-compose-secure.yml start dataverse bootstrap
```

### Updates & Patching

#### Update Docker Images

```powershell
# Pull latest images
docker-compose -f docker-compose-secure.yml pull

# Recreate containers
docker-compose -f docker-compose-secure.yml up -d --force-recreate

# Cleanup old images
docker image prune -a
```

#### Update Configuration

```powershell
# Edit docker-compose-secure.yml
notepad docker-compose-secure.yml

# Validate configuration
docker-compose -f docker-compose-secure.yml config

# Apply changes
docker-compose -f docker-compose-secure.yml up -d
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Containers Won't Start

**Symptoms**:
- Services stuck in "Starting" state
- Exit codes 1, 137, or 139

**Diagnosis**:
```powershell
# Check logs
docker-compose -f docker-compose-secure.yml logs

# Check specific container
docker logs dataverse_postgres_1
```

**Solutions**:
```powershell
# Increase memory limits in docker-compose-secure.yml
# Check disk space
df -h  # Linux/macOS
Get-PSDrive  # Windows

# Reset environment
docker-compose -f docker-compose-secure.yml down -v
docker-compose -f docker-compose-secure.yml up -d
```

#### Issue 2: Database Connection Errors

**Symptoms**:
- Dataverse cannot connect to PostgreSQL
- "Connection refused" errors

**Diagnosis**:
```powershell
# Check PostgreSQL is running
docker exec dataverse_postgres_1 pg_isready

# Test connection
docker exec dataverse_postgres_1 psql -U dataverse -c "SELECT version();"
```

**Solutions**:
```powershell
# Verify secrets are mounted
docker exec dataverse_postgres_1 ls /run/secrets/

# Check network connectivity
docker exec dataverse_dataverse_1 ping postgres

# Restart services
docker-compose -f docker-compose-secure.yml restart postgres dataverse
```

#### Issue 3: Solr Search Not Working

**Symptoms**:
- Search returns no results
- "Solr unreachable" errors

**Diagnosis**:
```powershell
# Check Solr health
curl http://localhost:8983/solr/admin/ping

# Check Solr logs
docker-compose -f docker-compose-secure.yml logs solr
```

**Solutions**:
```powershell
# Reindex Solr
docker exec dataverse_dataverse_1 curl http://localhost:8080/api/admin/index

# Restart Solr
docker-compose -f docker-compose-secure.yml restart solr
```

#### Issue 4: API Gateway 502/504 Errors

**Symptoms**:
- HTTP 502 Bad Gateway
- HTTP 504 Gateway Timeout

**Diagnosis**:
```powershell
# Check nginx logs
docker-compose -f docker-compose-secure.yml logs api-gateway

# Check upstream health
docker exec dataverse_api-gateway_1 curl http://dataverse:8080/api/info/version
```

**Solutions**:
```powershell
# Increase nginx timeouts in nginx-secure.conf
proxy_read_timeout 300s;
proxy_connect_timeout 300s;

# Restart API Gateway
docker-compose -f docker-compose-secure.yml restart api-gateway
```

#### Issue 5: Performance Issues

**Symptoms**:
- Slow response times
- High CPU/memory usage

**Diagnosis**:
```powershell
# Monitor resources
docker stats

# Check container limits
docker inspect dataverse_dataverse_1 --format='Limits: {{.HostConfig.Memory}}, {{.HostConfig.CpuQuota}}'
```

**Solutions**:
```powershell
# Increase resource limits in docker-compose-secure.yml
resources:
  limits:
    cpus: '4.0'
    memory: 4G

# Scale horizontally (future enhancement)
docker-compose -f docker-compose-secure.yml up -d --scale dataverse=2
```

### Emergency Procedures

#### Complete Reset

```powershell
# CAUTION: This will delete ALL data!

# Stop all services
docker-compose -f docker-compose-secure.yml down

# Remove volumes
docker-compose -f docker-compose-secure.yml down -v

# Remove data directories
Remove-Item -Recurse -Force .\data\postgres
Remove-Item -Recurse -Force .\data\solr
Remove-Item -Recurse -Force .\data\dataverse

# Regenerate secrets
.\generate-secrets.ps1 -Force

# Redeploy
docker-compose -f docker-compose-secure.yml up -d
```

#### Disaster Recovery

```powershell
# 1. Stop services
docker-compose -f docker-compose-secure.yml stop

# 2. Restore from backup
cat backup_latest.sql | docker exec -i dataverse_postgres_1 psql -U dataverse dataverse

# 3. Restore Solr
docker cp ./backups/solr-backup.tar.gz dataverse_solr_1:/tmp/
docker exec dataverse_solr_1 tar xzf /tmp/solr-backup.tar.gz -C /

# 4. Restart services
docker-compose -f docker-compose-secure.yml start
```

### Getting Help

**Documentation**:
- Dataverse: https://guides.dataverse.org/
- Docker: https://docs.docker.com/
- Docker Compose: https://docs.docker.com/compose/

**Community Support**:
- Dataverse Google Group: https://groups.google.com/g/dataverse-community
- Dataverse Slack: https://dataverse.org/slack

**Security Issues**:
- Report security vulnerabilities privately
- Do not post sensitive information publicly

---

## Next Steps

1. **Enable HTTPS/TLS** - See SSL_SETUP.md (to be created)
2. **Configure External Authentication** - OAuth, SAML, LDAP
3. **Set Up Monitoring** - Prometheus, Grafana
4. **Configure Backups** - Automated backup solution
5. **Production Hardening** - Additional security measures

---

## Security Checklist

Before going to production:

- [ ] Docker secrets generated and secured
- [ ] Environment variables reviewed
- [ ] Security scan passed (score ≥ 85)
- [ ] Host isolation validated
- [ ] HTTPS/TLS enabled
- [ ] Regular backups configured
- [ ] Monitoring and alerting set up
- [ ] Security updates automated
- [ ] Access logs enabled
- [ ] Incident response plan documented
- [ ] Security training completed
- [ ] Disaster recovery tested

---

## References

- [SECURITY_AUDIT.md](./SECURITY_AUDIT.md) - Comprehensive security audit report
- [docker-compose-secure.yml](./docker-compose-secure.yml) - Security-hardened configuration
- [generate-secrets.ps1](./generate-secrets.ps1) - Secrets generation script
- [security-scan.ps1](./security-scan.ps1) - Security scanning tool
- [validate-host-isolation.ps1](./validate-host-isolation.ps1) - Isolation validation tool
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) - Industry security standards
- [OWASP Docker Security](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) - Best practices

---

**Document Version**: 1.0  
**Last Updated**: 2026-03-30  
**Status**: Production Ready
