# Architecture Documentation

## System Overview

**Dataverse Enterprise Deployment** is a containerized, production-ready deployment of the Dataverse research data repository platform, designed for institutional-scale data management, preservation, and sharing.

### Purpose

This deployment provides:
- **Research Data Repository**: Web-based platform for dataset publication, sharing, and citation
- **Persistent Identifiers**: DOI/Handle assignment for datasets
- **Access Control**: Fine-grained permissions for data access and collaboration
- **Search & Discovery**: Full-text search across metadata and file content
- **Interoperability**: OAI-PMH, SWORD, REST API support

---

## Architecture Principles

1. **Containerization**: All components run in Docker containers for portability and isolation
2. **Data Durability**: All persistent data stored in volume mounts, separated from container lifecycle
3. **Security by Default**: Secrets externalized, admin APIs protected, principle of least privilege
4. **Observability**: Health checks, structured logging, resource monitoring
5. **Operational Simplicity**: One-command deployment, automated backups, clear runbooks

---

## Component Architecture

### High-Level Diagram

```
┌────────────────────────────────────────────────────────────────┐
│                        Users / Browsers                         │
└────────────────────┬───────────────────────────────────────────┘
                     │ HTTP(S)
                     ↓
┌────────────────────────────────────────────────────────────────┐
│              Reverse Proxy (nginx/Caddy/Traefik)               │
│                    (Optional, for HTTPS)                        │
└────────────────────┬───────────────────────────────────────────┘
                     │ HTTP
                     ↓
         ┌───────────────────────────┐
         │  Dataverse Application    │
         │  (Payara Server)          │
         │  Port: 8080               │
         │  Container: dataverse     │
         └─┬──────────┬──────────┬───┘
           │          │          │
           ↓          ↓          ↓
    ┌──────────┐ ┌─────────┐ ┌────────────┐
    │PostgreSQL│ │  Solr   │ │    SMTP    │
    │Database  │ │ Search  │ │   Server   │
    │Port: 5432│ │Port:8983│ │  Port: 25  │
    └──────────┘ └─────────┘ └────────────┘
         │            │             │
         ↓            ↓             ↓
    [data/postgres] [data/solr] [Email Queue]
```

### Container Network

All containers communicate over an internal Docker network (`dataverse`) with no external exposure except the web application (port 8080).

**Network Security:**
- Database and Solr are **not** exposed to host network
- Only Dataverse application port is published
- Inter-container communication uses service names (DNS resolution by Docker)

---

## Component Details

### 1. Dataverse Application Container

**Image:** `gdcc/dataverse:latest` (official GDCC build)  
**Base:** Payara Server (Jakarta EE application server)  
**Language:** Java  
**Responsibilities:**
- Serve web UI (React/JSF frontend)
- Process API requests (REST + SWORD)
- Business logic (dataset creation, file upload, permissions)
- Generate DOIs/Handles
- Send notification emails

**Configuration:**
- Environment variables for database, Solr, SMTP connection
- JVM options for memory tuning
- Admin API protection (dev mode vs demo mode)

**Persistent Data:**
- Uploaded files: `/dv` volume mount → `data/dataverse/`
- Configuration: Database-backed (not files)

**Health Check:**
- HTTP GET `http://localhost:8080/api/info/version`
- Expects JSON response with version number
- Interval: 30s, Timeout: 10s, Retries: 3

---

### 2. PostgreSQL Database Container

**Image:** `postgres:13`  
**Responsibilities:**
- Store all metadata (datasets, users, collections, permissions)
- Store configuration settings
- Store file metadata (not file content)

**Schema:**
- Managed by Dataverse Flyway migrations
- ~200 tables (users, datasets, dataverses, files, permissions, etc.)

**Persistent Data:**
- Database files: `/var/lib/postgresql/data` → `data/postgres/`

**Backup Strategy:**
- Daily `pg_dump` to external storage
- Transaction logs for point-in-time recovery (optional)

**Security:**
- Password stored in `.env` file (not committed)
- No external port exposure
- Connection encryption recommended for production

---

### 3. Solr Search Engine Container

**Image:** `solr:9.3.0` (Apache Solr)  
**Responsibilities:**
- Index dataset metadata for full-text search
- Provide faceted search (by subject, author, date, etc.)
- Support auto-suggest queries

**Configuration:**
- Core name: `collection1` (created by bootstrap)
- Schema defined by Dataverse

**Persistent Data:**
- Index files: `/var/solr` → `data/solr/`

**Reindexing:**
- Triggered via Dataverse admin API: `/api/admin/index`
- Required after major version upgrades or index corruption

---

### 4. SMTP Server Container

**Image:** `maildev/maildev` or `mailhog/mailhog` (dev/demo)  
**Responsibilities:**
- Send email notifications (dataset published, access requests, etc.)
- Capture outbound emails for testing (dev mode)

**Production Notes:**
- Replace with external SMTP relay (SendGrid, AWS SES, etc.)
- Configure `MAIL_SERVER` environment variable

---

### 5. Bootstrap Container

**Image:** `gdcc/configbaker:latest`  
**Lifecycle:** Runs once at startup, exits after completion  
**Responsibilities:**
- Wait for Dataverse to be responsive
- Configure initial settings via API
- Create root dataverse
- Set up demo mode (if enabled)

**Modes:**
- **dev**: Admin APIs open (no authentication)
- **demo**: Admin APIs require unblock key (moderate security)

**Configuration Files:**
- `demo/init.sh`: Custom initialization script for demo mode
- `demo/config/dataverse-complete.json`: Custom root dataverse metadata

---

## Data Flow

### User Workflow: Publish a Dataset

1. **User** uploads files via web UI
2. **Dataverse Application** stores files in `/dv` volume
3. **Dataverse Application** writes metadata to **PostgreSQL**
4. **Dataverse Application** indexes metadata in **Solr**
5. **Dataverse Application** requests DOI from DataCite (if configured)
6. **Dataverse Application** sends notification email via **SMTP**
7. **User** receives confirmation, dataset is searchable

### Search Query Flow

1. **User** enters search term in web UI
2. **Dataverse Application** queries **Solr** with search term
3. **Solr** returns matching dataset IDs + highlighted snippets
4. **Dataverse Application** fetches full metadata from **PostgreSQL**
5. **Dataverse Application** renders search results to user

---

## Persistent Storage

All data is stored in the `data/` directory with the following structure:

```
data/
├── postgres/       # PostgreSQL database files
│   └── pg_data/    # Managed by Postgres container
├── solr/           # Solr index files
│   └── collection1/
├── dataverse/      # Uploaded dataset files
│   ├── files/
│   └── temp/
└── secrets/        # Secrets (passwords, keys)
    └── unblock-key.txt
```

**Backup Considerations:**
- **Database**: Use `pg_dump` for logical backups (recommended)
- **Files**: Use filesystem-level backups (rsync, Restic, etc.)
- **Solr**: Can be rebuilt from database (reindexing), backup optional
- **Secrets**: Must be backed up separately (not in git)

**Restore Procedure:**
1. Stop all containers
2. Restore database from `pg_dump`
3. Restore file storage
4. Start containers
5. Reindex Solr if needed

---

## Security Architecture

### Threat Model

**Assets:**
- Research data (files + metadata)
- User credentials
- Database access
- Admin API access

**Threats:**
- Unauthorized data access (mitigated by application-level permissions)
- Credential theft (mitigated by secrets management, .gitignore)
- Data loss (mitigated by backups)
- Network eavesdropping (mitigated by HTTPS reverse proxy)
- Admin API abuse (mitigated by demo mode + unblock key)

### Security Controls

| Control | Implementation | Status |
|---------|----------------|--------|
| Secrets not in git | .gitignore, .env.example | ✅ Implemented |
| Strong passwords | Random generation in setup docs | ✅ Documented |
| Network isolation | Docker internal networks | ✅ Implemented |
| Admin API protection | Demo mode with unblock key | ⏳ Pending |
| HTTPS encryption | Reverse proxy (nginx/Caddy) | 📝 Documented |
| Database encryption at rest | Volume encryption (host-level) | 📝 Recommended |
| Backup encryption | GPG encryption in backup script | ⏳ Pending |
| Security updates | Dependabot for Docker images | ⏳ Pending |

---

## Deployment Modes

### Development Mode (`dev`)

**Use Case:** Local testing, feature development  
**Security:** Low (admin APIs open)  
**Configuration:** Default in `compose.yml`  
**Admin API Access:** No authentication required

**To enable:**
```yaml
bootstrap:
  command:
    - bootstrap.sh
    - dev
```

---

### Demo Mode (`demo`)

**Use Case:** Demonstrations, staging environments, limited production  
**Security:** Medium (admin APIs require unblock key)  
**Configuration:** Requires `demo/init.sh`

**To enable:**
```yaml
bootstrap:
  command:
    - bootstrap.sh
    - demo
  volumes:
    - ./configs/demo:/scripts/bootstrap/demo
```

**Unblock Key:**
- Generated in `demo/init.sh`
- Must be provided in API calls: `?unblock-key=<key>`
- Stored in `data/secrets/unblock-key.txt` (not committed)

---

### Production Mode (Future)

**Use Case:** Public-facing, high-security deployments  
**Security:** High (HTTPS, WAF, rate limiting, audit logging)  
**Configuration:** Reverse proxy + additional hardening

**Requirements:**
- HTTPS with valid SSL certificate
- External authentication (Shibboleth, OAuth)
- Database connection encryption
- Log aggregation (ELK, Splunk)
- Intrusion detection
- Regular security audits

---

## Scalability Considerations

### Current Limitations (Single-Instance)

- **Single Dataverse container**: No horizontal scaling
- **Single PostgreSQL**: No read replicas
- **Single Solr**: No sharding

### Future Scaling Options

If workload exceeds single-instance capacity:

1. **Database Scaling:**
   - PostgreSQL read replicas
   - Connection pooling (PgBouncer)
   - Larger instance (vertical scaling)

2. **Application Scaling:**
   - Multiple Dataverse containers behind load balancer
   - Shared storage for `/dv` (NFS, S3)
   - Session affinity or stateless sessions

3. **Search Scaling:**
   - Solr Cloud (distributed search)
   - Elasticsearch as alternative

4. **Kubernetes Migration:**
   - Convert Docker Compose to Helm chart
   - Autoscaling based on CPU/memory
   - Managed database (Azure Database for PostgreSQL)

---

## Monitoring & Observability

### Health Checks

Each service has a health check defined in `compose.yml`:

- **Dataverse**: HTTP `/api/info/version` (every 30s)
- **PostgreSQL**: `pg_isready` (every 10s)
- **Solr**: HTTP `/solr/admin/cores` (every 30s)

### Logs

Logs are captured via Docker logging driver:

```yaml
logging:
  driver: json-file
  options:
    max-size: "10m"
    max-file: "3"
```

**View logs:**
```bash
docker compose logs -f dataverse
docker compose logs --tail=100 postgres
```

### Metrics (Optional)

For advanced monitoring, integrate:
- **Prometheus**: Scrape JMX metrics from Payara
- **Grafana**: Visualize container metrics, database queries
- **cAdvisor**: Container resource usage

---

## Disaster Recovery

### Backup Strategy

**Frequency:**
- Database: Daily (automated via cron/Task Scheduler)
- Files: Daily (incremental)
- Full system: Weekly

**Retention:**
- Daily backups: 7 days
- Weekly backups: 4 weeks
- Monthly backups: 12 months

**Testing:**
- Monthly restore test to verify backup integrity

### Recovery Time Objective (RTO)

**Target:** 4 hours from disaster to operational system

**Steps:**
1. Provision new infrastructure (30 min)
2. Restore database from backup (1 hour)
3. Restore file storage (2 hours)
4. Start containers and validate (30 min)

### Recovery Point Objective (RPO)

**Target:** 24 hours (maximum data loss acceptable)

**Achieved by:** Daily backups at midnight

---

## Technology Stack

| Component | Technology | Version | Purpose |
|-----------|------------|---------|---------|
| Application Server | Payara | 5.x | Jakarta EE runtime |
| Frontend | React/JSF | N/A | Web UI |
| Backend | Java | 11+ | Business logic |
| Database | PostgreSQL | 13 | Metadata storage |
| Search | Apache Solr | 9.3.0 | Full-text search |
| Email | MailDev/SMTP | N/A | Notifications |
| Container Runtime | Docker | 24.x | Containerization |
| Orchestration | Docker Compose | v2.x | Multi-container mgmt |

---

## Integration Points

### External Services

- **DOI Provider**: DataCite or EZID (for persistent identifiers)
- **Authentication**: Shibboleth, OAuth2 (ORCID, GitHub, Google)
- **Storage**: S3-compatible for file storage (optional)
- **SMTP**: External email relay (production)

### APIs

**REST API:**
- Base URL: `http://localhost:8080/api/`
- Authentication: API tokens
- Documentation: https://guides.dataverse.org/en/latest/api/

**SWORD API:**
- Endpoint: `http://localhost:8080/dvn/api/data-deposit/v1.1/swordv2/`
- Use case: Programmatic dataset deposits

**OAI-PMH:**
- Endpoint: `http://localhost:8080/oai`
- Use case: Metadata harvesting

---

## Configuration Management

### Environment Variables

Defined in `.env` file (not committed):

- `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`
- `DATAVERSE_URL`
- `MAIL_SERVER`, `MAIL_PORT`
- `DOI_USERNAME`, `DOI_PASSWORD` (if using DataCite)

### Settings Database

Runtime settings stored in PostgreSQL `setting` table:

- `:InstallationName`
- `:FooterCopyright`
- `:SystemEmail`
- `:Protocol` (doi/handle)

**Access via API:**
```bash
curl http://localhost:8080/api/admin/settings/:InstallationName
curl -X PUT -d "My Repo" http://localhost:8080/api/admin/settings/:InstallationName
```

---

## Change Management

All architecture changes must be documented via **Architecture Decision Records (ADRs)** in `docs/adr/`.

See: `docs/adr/README.md` for template and process.

---

## References

- **Dataverse Official Docs**: https://guides.dataverse.org/
- **Container Guide**: https://guides.dataverse.org/en/latest/container/
- **API Guide**: https://guides.dataverse.org/en/latest/api/
- **GitHub Repository**: https://github.com/IQSS/dataverse

---

*Last updated: 2026-04-10 | Version: 1.0*
