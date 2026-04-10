# Security Documentation

This document outlines the security architecture, threat model, controls, and procedures for the Dataverse Enterprise Deployment.

---

## 📋 Table of Contents

- [Security Overview](#security-overview)
- [Threat Model](#threat-model)
- [Security Controls](#security-controls)
- [Secrets Management](#secrets-management)
- [Authentication & Authorization](#authentication--authorization)
- [Network Security](#network-security)
- [Data Protection](#data-protection)
- [Incident Response](#incident-response)
- [Security Checklist](#security-checklist)
- [Compliance](#compliance)

---

## Security Overview

### Security Posture

**Current Deployment Mode:** Demo Mode (Medium Security)  
**Target Environment:** Internal/Institutional Use  
**Sensitivity:** Research Data (varies by dataset)

### Security Principles

1. **Defense in Depth**: Multiple layers of security controls
2. **Least Privilege**: Minimal access rights for users and services
3. **Secure by Default**: Security features enabled out-of-the-box
4. **Separation of Concerns**: Network isolation between components
5. **Audit Trail**: All administrative actions logged

---

## Threat Model

### Assets

| Asset | Sensitivity | Impact if Compromised |
|-------|-------------|----------------------|
| **Research datasets** | High (may contain PII/confidential data) | Data breach, regulatory violation |
| **User credentials** | High | Account takeover, unauthorized access |
| **Database** | High | Complete system compromise |
| **Admin API keys** | Critical | Full system control |
| **Backup files** | High | Data exfiltration |
| **System logs** | Medium | Information disclosure |

### Threat Actors

**External Attackers:**
- Motivation: Data theft, vandalism, ransomware
- Capabilities: Network scanning, automated exploits
- Mitigations: Firewall, HTTPS, rate limiting, WAF

**Malicious Insiders:**
- Motivation: Data theft, sabotage
- Capabilities: Legitimate access, privilege escalation
- Mitigations: Audit logging, least privilege, MFA

**Accidental Exposure:**
- Motivation: N/A (unintentional)
- Capabilities: Credential leaks, misconfigurations
- Mitigations: Secrets scanning, .gitignore, code review

### Threat Scenarios

#### Scenario 1: Credential Leak via Git

**Threat:** Developer accidentally commits `.env` file with database password

**Impact:** Attacker gains database access  
**Likelihood:** Medium  
**Mitigations:**
- ✅ `.gitignore` blocks `.env` files
- ✅ CI pipeline scans for secrets
- ⏳ Pre-commit hooks (planned)
- ⏳ Secret scanning (GitHub Advanced Security)

---

#### Scenario 2: SQL Injection Attack

**Threat:** Attacker exploits SQL injection vulnerability in Dataverse application

**Impact:** Database compromise, data exfiltration  
**Likelihood:** Low (Dataverse uses prepared statements)  
**Mitigations:**
- ✅ Dataverse built with JPA/Hibernate (parameterized queries)
- ✅ Regular security updates
- ⏳ Web Application Firewall (WAF)
- ⏳ Database activity monitoring

---

#### Scenario 3: Unauthorized Admin API Access

**Threat:** Attacker discovers unprotected admin API endpoints

**Impact:** Full system control, data manipulation  
**Likelihood:** High (if dev mode used in production)  
**Mitigations:**
- ✅ Demo mode requires unblock key
- ✅ Unblock key not committed to git
- ⏳ API rate limiting
- ⏳ IP whitelisting for admin APIs

---

#### Scenario 4: Container Escape

**Threat:** Attacker exploits Docker vulnerability to escape container

**Impact:** Host system compromise  
**Likelihood:** Low  
**Mitigations:**
- ✅ Docker running as non-root user (where possible)
- ✅ Regular Docker updates
- ⏳ AppArmor/SELinux profiles
- ⏳ Container image scanning (Trivy)

---

## Security Controls

### OWASP Top 10 Coverage

| OWASP Risk | Control | Status |
|------------|---------|--------|
| **A01: Broken Access Control** | Dataverse RBAC, least privilege | ✅ Application-level |
| **A02: Cryptographic Failures** | HTTPS (via reverse proxy), encrypted backups | ⏳ Pending HTTPS |
| **A03: Injection** | Prepared statements, input validation | ✅ Application-level |
| **A04: Insecure Design** | Threat modeling, secure architecture | ✅ Documented |
| **A05: Security Misconfiguration** | Demo mode, secure defaults, hardening checklist | ✅ Implemented |
| **A06: Vulnerable Components** | Regular updates, Dependabot | ⏳ Pending |
| **A07: Authentication Failures** | Strong passwords, MFA (optional), session timeout | ⚠️ Partial |
| **A08: Data Integrity Failures** | Backup validation, checksums | ✅ Implemented |
| **A09: Logging Failures** | Centralized logging, audit trail | ⚠️ Basic logging |
| **A10: SSRF** | Network isolation, internal-only services | ✅ Implemented |

**Legend:**  
✅ Fully implemented | ⏳ Planned | ⚠️ Partially implemented | ❌ Not implemented

---

## Secrets Management

### Secret Types

1. **Database Credentials**
   - PostgreSQL password
   - Stored in: `.env` file (gitignored)

2. **Admin API Keys**
   - Unblock key for demo mode
   - Stored in: `data/secrets/unblock-key.txt` (gitignored)

3. **External Service Credentials**
   - DOI provider (DataCite) credentials
   - Email server (SMTP) credentials
   - Stored in: `.env` file

### .gitignore Protection

**File:** `.gitignore`

```gitignore
# Environment files with secrets
.env
*.env.local

# Secrets directory
secrets/
data/secrets/

# Backup files (may contain sensitive data)
backups/
*.sql
*.dump
```

**Verification:**
```powershell
# Check for secrets in git history
git log -p | Select-String -Pattern "password|secret|key" -Context 2

# Should return NO matches
```

### Password Requirements

**Database Passwords:**
- Minimum 16 characters
- Mix of uppercase, lowercase, numbers, symbols
- No dictionary words
- Use password generator:
  ```powershell
  # PowerShell password generator
  -join ((48..57) + (65..90) + (97..122) + (33..47) | Get-Random -Count 24 | % {[char]$_})
  ```

**Admin Passwords:**
- Minimum 12 characters
- Enforce via Dataverse settings:
  ```bash
  curl -X PUT -d "12" http://localhost:8080/api/admin/settings/:PVMinLength
  ```

### Secrets Rotation

**Schedule:**
- Database password: Every 90 days
- Admin unblock key: Every 180 days
- User passwords: Prompt every 90 days (recommended)

**Rotation Procedure:**

1. **Database Password Rotation:**
   ```powershell
   # 1. Generate new password
   $newPassword = -join ((48..57) + (65..90) + (97..122) + (33..47) | Get-Random -Count 24 | % {[char]$_})
   
   # 2. Update PostgreSQL
   docker compose exec postgres psql -U dataverse -c "ALTER USER dataverse PASSWORD '$newPassword';"
   
   # 3. Update .env file
   (Get-Content .env) -replace 'POSTGRES_PASSWORD=.*', "POSTGRES_PASSWORD=$newPassword" | Set-Content .env
   
   # 4. Restart Dataverse
   docker compose restart dataverse
   ```

2. **Unblock Key Rotation:**
   ```powershell
   # 1. Generate new key
   $newKey = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | % {[char]$_})
   
   # 2. Update init.sh
   (Get-Content configs/demo/init.sh) -replace 'UNBLOCK_KEY=.*', "UNBLOCK_KEY=$newKey" | Set-Content configs/demo/init.sh
   
   # 3. Recreate bootstrap
   docker compose up -d bootstrap
   ```

### Secrets Backup

**Backup secrets separately from data:**

```powershell
# Encrypt secrets before offsite storage
$secretsBackup = "backups/secrets-$(Get-Date -Format 'yyyyMMdd').zip"
Compress-Archive -Path .env,configs/demo/init.sh -DestinationPath $secretsBackup

# Encrypt with GPG (requires GPG installed)
gpg --symmetric --cipher-algo AES256 $secretsBackup
Remove-Item $secretsBackup  # Delete unencrypted copy
```

**Store encrypted backup in secure location (not in git).**

---

## Authentication & Authorization

### User Authentication

**Supported Methods:**

1. **Built-in (Local):**
   - Username/password stored in PostgreSQL
   - Bcrypt password hashing
   - Recommended for: Internal users, small deployments

2. **Shibboleth (SAML):**
   - Integrate with institutional IdP
   - Single Sign-On (SSO)
   - Recommended for: Universities, enterprises

3. **OAuth2:**
   - Supported providers: ORCID, GitHub, Google
   - Recommended for: Researcher communities

**Configuration:**
See: https://guides.dataverse.org/en/latest/installation/shibboleth.html

### Multi-Factor Authentication (MFA)

**Status:** Not natively supported by Dataverse  
**Workarounds:**
- Use Shibboleth IdP with MFA enforcement
- Use OAuth provider with MFA (e.g., Google with 2FA)

### Authorization Model

**Dataverse uses Role-Based Access Control (RBAC):**

| Role | Permissions |
|------|-------------|
| **Admin** | Full system access, settings, users |
| **Curator** | Create collections, datasets, publish |
| **Contributor** | Upload files, edit metadata |
| **Guest** | Read public datasets |

**Assignment:**
- Roles assigned per collection/dataset
- Inherited hierarchically
- Managed via web UI or API

---

## Network Security

### Network Topology

```
Internet
    ↓
[Firewall]
    ↓
[Reverse Proxy - HTTPS]
    ↓
[Docker Network - dataverse]
    ├── Dataverse App (port 8080 exposed)
    ├── PostgreSQL (internal only)
    ├── Solr (internal only)
    └── SMTP (internal only)
```

### Port Exposure

**Externally Accessible:**
- Port 8080: Dataverse web UI/API (HTTP)
- Port 443: HTTPS (if reverse proxy configured)

**Internal Only (Docker network):**
- Port 5432: PostgreSQL
- Port 8983: Solr
- Port 25: SMTP

### Firewall Rules

**Inbound:**
- Allow: Port 8080 from trusted networks
- Allow: Port 443 from internet (if HTTPS enabled)
- Deny: All other inbound traffic

**Outbound:**
- Allow: HTTP/HTTPS to internet (for DOI registration, updates)
- Allow: SMTP to email relay
- Deny: All other outbound traffic

### HTTPS Configuration

**Production Deployment MUST use HTTPS.**

**Option 1: Nginx Reverse Proxy**

```nginx
server {
    listen 443 ssl http2;
    server_name dataverse.yourorg.edu;

    ssl_certificate /etc/ssl/certs/dataverse.crt;
    ssl_certificate_key /etc/ssl/private/dataverse.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

**Option 2: Caddy (Auto-HTTPS with Let's Encrypt)**

```caddyfile
dataverse.yourorg.edu {
    reverse_proxy localhost:8080
}
```

---

## Data Protection

### Data at Rest

**Encryption:**
- Database: Use volume encryption (BitLocker/LUKS)
- Files: Use volume encryption
- Backups: Encrypt with GPG or cloud storage encryption

**Configuration:**
```powershell
# Windows: Enable BitLocker on data volume
Enable-BitLocker -MountPoint "D:" -EncryptionMethod Aes256
```

### Data in Transit

**HTTPS Required:**
- All external communication must use HTTPS
- Internal Docker network is unencrypted (trusted environment)

**Database Connection Encryption:**
For production, enable PostgreSQL SSL:
```yaml
postgres:
  command: -c ssl=on -c ssl_cert_file=/var/lib/postgresql/server.crt -c ssl_key_file=/var/lib/postgresql/server.key
```

### Data Retention

**User Data:**
- Published datasets: Retained indefinitely (research record)
- Draft datasets: Configurable, default: no expiration
- User accounts: Retained until deletion requested

**Logs:**
- Application logs: 30 days
- Audit logs: 1 year (compliance)
- Backup logs: 90 days

**Deletion Procedure:**
```powershell
# Permanently delete dataset (admin only)
curl -X DELETE "http://localhost:8080/api/datasets/:persistentId/destroy/?persistentId=doi:..."
```

---

## Incident Response

### Security Incident Types

| Type | Examples | Response |
|------|----------|----------|
| **P1 - Critical** | Data breach, ransomware, database compromise | Immediate |
| **P2 - High** | Credential leak, vulnerability exploit | 4 hours |
| **P3 - Medium** | Suspicious login, failed intrusion attempt | 24 hours |
| **P4 - Low** | Security scan finding, configuration drift | 7 days |

### Incident Response Plan

**Phase 1: Detection & Triage**
1. Alert received (monitoring, user report, security scan)
2. Assign severity level
3. Notify security team
4. Preserve evidence (logs, snapshots)

**Phase 2: Containment**
- Isolate affected systems (network disconnect if needed)
- Reset compromised credentials
- Block malicious IPs
- Take system offline if data breach suspected

**Phase 3: Investigation**
- Review logs: `docker compose logs -f`
- Check file integrity
- Analyze network traffic
- Interview users/admins

**Phase 4: Eradication**
- Remove malware/backdoors
- Patch vulnerabilities
- Update credentials
- Rebuild from clean backups if needed

**Phase 5: Recovery**
- Restore service from secure backup
- Monitor for recurrence
- Verify data integrity

**Phase 6: Post-Incident**
- Document incident (date, impact, root cause, resolution)
- Update security controls
- Train team on lessons learned

### Security Contacts

- **Security Team**: security@yourorg.com
- **On-Call**: +1-555-0100
- **Dataverse Security**: security@dataverse.org

---

## Security Checklist

### Pre-Deployment

- [ ] Strong passwords set in `.env`
- [ ] `.gitignore` protects secrets
- [ ] Demo mode enabled (not dev mode)
- [ ] Unblock key generated and secured
- [ ] Firewall rules configured
- [ ] HTTPS reverse proxy ready
- [ ] Backup encryption configured
- [ ] Monitoring alerts configured

### Post-Deployment

- [ ] Default admin password changed
- [ ] Unnecessary user accounts disabled
- [ ] Security settings reviewed
- [ ] Log monitoring active
- [ ] Backup tested and validated
- [ ] Incident response plan reviewed
- [ ] Team trained on security procedures

### Periodic Reviews (Quarterly)

- [ ] Rotate database credentials
- [ ] Review user accounts and permissions
- [ ] Update Docker images
- [ ] Run security vulnerability scan
- [ ] Test backup restore
- [ ] Review logs for anomalies
- [ ] Update security documentation

---

## Compliance

### Data Protection Regulations

**GDPR (EU):**
- User consent for data processing: ✅ Supported (via Dataverse UI)
- Right to access: ✅ API available
- Right to deletion: ✅ Delete user/dataset API
- Data portability: ✅ Export dataset API
- Breach notification: ⚠️ Manual process

**CCPA (California):**
- Similar requirements to GDPR
- Supported via same mechanisms

### Research Data Standards

**FAIR Principles:**
- Findable: ✅ DOI, metadata, search
- Accessible: ✅ API, authentication
- Interoperable: ✅ OAI-PMH, standard formats
- Reusable: ✅ Licensing, citation

---

## Security Updates

### Monitoring for Vulnerabilities

- **Dataverse Releases**: https://github.com/IQSS/dataverse/releases
- **CVE Database**: https://cve.mitre.org/
- **Docker Security Advisories**: https://docs.docker.com/security/

### Update Process

1. Subscribe to Dataverse security announcements
2. Review CVE severity (CVSS score)
3. Test patch in staging environment
4. Schedule maintenance window
5. Apply update (see OPERATIONS.md)
6. Verify fix and monitor

---

## References

- **Dataverse Security Guide**: https://guides.dataverse.org/en/latest/admin/dataverses-datasets.html#permissions
- **OWASP Top 10**: https://owasp.org/www-project-top-ten/
- **CIS Docker Benchmark**: https://www.cisecurity.org/benchmark/docker

---

*Last updated: 2026-04-10 | Version: 1.0*
