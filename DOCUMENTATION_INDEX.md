# 📚 Dataverse Documentation Index

Complete navigation guide for all Dataverse deployment and operations documentation.

---

## 🚀 Getting Started

**Start here if this is your first time:**

1. **[README.md](README.md)** - Project overview & quick start
2. **[INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md)** - Complete installation procedure  
3. **[DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md)** - Current system status & verification

---

## 🔍 Troubleshooting & Support

**Having issues? Start here:**

### 🐛 Error Documentation (MOST IMPORTANT)
**[docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md)** ← START HERE FOR ANY ISSUES

Contains comprehensive troubleshooting for all known problems:

| Error Code | Issue | Details |
|-----------|-------|---------|
| **ERR-DB-001** | PostgreSQL authentication error | [postgres.md](docs/errors/postgres.md) |
| **ERR-DATAVERSE-001** | Application deployment failure | [dataverse-app.md](docs/errors/dataverse-app.md) |
| **ERR-DATAVERSE-002** | Bootstrap timeout | [bootstrap-timeout.md](docs/errors/bootstrap-timeout.md) |
| **ERR-FRONTEND-001** | UI/Payara issues | [frontend-ui.md](docs/errors/frontend-ui.md) |
| **ERR-FRONTEND-002** | Browser warnings | [browser-resources.md](docs/errors/browser-resources.md) |
| **ERR-COMPOSE-001/002** | Docker config issues | [docker-compose.md](docs/errors/docker-compose.md) |

### Common Questions
- **"I see Payara page instead of Dataverse"** → [ERR-FRONTEND-001](docs/errors/frontend-ui.md)
- **"Database connection refused"** → [ERR-DB-001](docs/errors/postgres.md)
- **"Application won't deploy"** → [ERR-DATAVERSE-001](docs/errors/dataverse-app.md)
- **"Bootstrap times out"** → [ERR-DATAVERSE-002](docs/errors/bootstrap-timeout.md)
- **"Browser warnings about favicon"** → [ERR-FRONTEND-002](docs/errors/browser-resources.md)

---

## 📖 Complete Documentation

### Core Documentation

| Document | Purpose | Best For |
|----------|---------|----------|
| [README.md](README.md) | Project overview, quick start, features | New users |
| [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) | Complete 8-phase installation & setup | Installation & setup |
| [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) | Current system status, health checks | Monitoring & verification |
| [docs/OPERATIONS.md](docs/OPERATIONS.md) | Daily operations, backups, updates | Operations team |
| [docs/SECURITY.md](docs/SECURITY.md) | Security guidelines & hardening | Production deployments |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System architecture & design | Developers |

### Error & Resolution Documentation

| File | Coverage |
|------|----------|
| [docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md) | Master error index (7 documented errors) |
| [docs/errors/postgres.md](docs/errors/postgres.md) | Database connection & PostgreSQL issues |
| [docs/errors/dataverse-app.md](docs/errors/dataverse-app.md) | Application deployment failures |
| [docs/errors/bootstrap-timeout.md](docs/errors/bootstrap-timeout.md) | Bootstrap & startup issues |
| [docs/errors/frontend-ui.md](docs/errors/frontend-ui.md) | User interface & access issues |
| [docs/errors/browser-resources.md](docs/errors/browser-resources.md) | Browser-level warnings |
| [docs/errors/docker-compose.md](docs/errors/docker-compose.md) | Docker & configuration issues |

---

## 🎯 Quick Reference

### Installation & Deployment

**Fast Track:**
```bash
cd configs/
docker-compose up -d
# Wait 20-60 minutes for first deployment
# Access: http://localhost:8080/
# Login: dataverseAdmin / admin1
```

**Full Procedure:**
See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) - 8 detailed phases

### Day-to-Day Operations

**Start Dataverse:**
```bash
cd configs/
docker-compose up -d
```

**Stop Dataverse:**
```bash
cd configs/
docker-compose down
```

**View Logs:**
```bash
docker-compose logs -f dataverse
```

**Backup Database:**
```bash
docker exec compose-postgres-1 pg_dump -U dataverse dataverse > backup.sql
```

See [docs/OPERATIONS.md](docs/OPERATIONS.md) for more operations

### Troubleshooting Quick Checks

```powershell
# 1. Check containers are running
docker-compose ps

# 2. Check API is responding
curl http://localhost:8080/api/info/version

# 3. Check database
docker exec compose-postgres-1 pg_isready -U dataverse

# 4. View recent logs
docker-compose logs dataverse --tail 50
```

For detailed troubleshooting, see [INSTALLATION_GUIDE.md Phase 7](INSTALLATION_GUIDE.md#-phase-7-troubleshooting--error-resolution)

---

## 📋 Documentation Organization

```
.
├── README.md                          ← Start here
├── INSTALLATION_GUIDE.md              ← Installation procedure
├── DEPLOYMENT_STATUS.md               ← Current status
├── DOCUMENTATION_INDEX.md             ← You are here
│
└── docs/
    ├── ERRORS_AND_SOLUTIONS.md        ← 🔴 ERROR INDEX
    ├── OPERATIONS.md                  ← Daily operations
    ├── SECURITY.md                    ← Security guidelines
    ├── ARCHITECTURE.md                ← System architecture
    ├── CONTRIBUTING.md                ← Contributing guide
    ├── CHANGELOG.md                   ← Version history
    │
    └── errors/                        ← Detailed error documentation
        ├── postgres.md                ← ERR-DB-001
        ├── dataverse-app.md           ← ERR-DATAVERSE-001
        ├── bootstrap-timeout.md       ← ERR-DATAVERSE-002
        ├── frontend-ui.md             ← ERR-FRONTEND-001
        ├── browser-resources.md       ← ERR-FRONTEND-002
        ├── docker-compose.md          ← ERR-COMPOSE-001/002
        └── [more error ledgers]
```

---

## ✅ Status Indicators

### Health Check Dashboard

**Current System Status:** [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md)

- ✅ All services running
- ✅ Database healthy
- ✅ API responding
- ✅ Search operational
- ✅ Email working

---

## 🤝 Support Resources

### Internal Resources
- **Error Index:** [docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md)
- **Operations Guide:** [docs/OPERATIONS.md](docs/OPERATIONS.md)
- **Security Guide:** [docs/SECURITY.md](docs/SECURITY.md)
- **Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

### External Resources
- **Dataverse Documentation:** https://guides.dataverse.org
- **Community Forum:** https://groups.google.com/g/dataverse-community
- **GitHub Issues:** https://github.com/IQSS/dataverse/issues
- **Slack Community:** https://dataverse.org/slack

---

## 📞 How to Get Help

### Step 1: Self-Help
Start with [docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md) - most issues are documented

### Step 2: Detailed Troubleshooting
Check the specific error ledger in `docs/errors/` folder

### Step 3: Gather Information
Before contacting support, collect:
```bash
docker-compose ps > status.txt
docker-compose logs --tail 100 > logs.txt
```

### Step 4: Community Support
Post on [Dataverse Community Forum](https://groups.google.com/g/dataverse-community)

---

## 🔄 Documentation Maintenance

**Last Updated:** 2026-04-11  
**Deployment Status:** ✅ Complete and operational  
**Documentation Coverage:** 7 known errors, all documented  
**Support Level:** Autonomous self-service + community

---

## 📝 Contributing

Want to improve documentation? See [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)

---

**Happy Dataverse deploying! 🎉**

**Need help?** Start with [docs/ERRORS_AND_SOLUTIONS.md](docs/ERRORS_AND_SOLUTIONS.md)
