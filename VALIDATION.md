# Pre-Flight Checklist for Dataverse Container Setup

## ✅ Configuration Validation

### Docker Compose Syntax
- [x] docker-compose.yml syntax validated successfully
- [x] All services defined correctly
- [x] Environment variables properly configured
- [x] Volume mounts configured
- [x] Network configuration validated

### Services Included
- [x] PostgreSQL 16 - Database
- [x] Apache Solr 9.6.1 - Search Engine
- [x] MailDev 2.1.0 - SMTP Server
- [x] Dataverse Application - Latest version
- [x] ConfigBaker - Bootstrap and configuration
- [x] File Previewers Provider
- [x] Previewer Registration

### Health Checks Configured
- [x] PostgreSQL health check
- [x] Solr health check
- [x] Dataverse health check

### Persistent Volumes
- [x] postgres-data (Database persistence)
- [x] solr-data (Search index persistence)
- [x] solr-conf (Solr configuration)
- [x] dataverse-data (File storage)
- [x] dataverse-secrets (Secrets storage)

### Port Mappings
- [x] 8080 - Dataverse Web UI
- [x] 4949 - Payara Admin Console
- [x] 5432 - PostgreSQL
- [x] 8983 - Solr
- [x] 25/1080 - SMTP/MailDev
- [x] 9080 - File Previewers

### Security Features
- [x] Environment-based password configuration
- [x] Demo mode with unblock key support
- [x] Separate secrets volume
- [x] Network isolation

### Resource Limits
- [x] Memory limit set for Dataverse (2 GiB)
- [x] Memory reservation configured
- [x] Tmpfs mounts for temporary data

## 🚀 Ready to Deploy

All configuration files are in place and validated. The setup is ready to be built and hosted.

## ⚠️ Before Starting

### Requirements Check
- [ ] Docker Desktop installed and running
- [ ] At least 8 GB RAM allocated to Docker
- [ ] At least 10 GB free disk space
- [ ] Ports 8080, 5432, 8983, 1080, 4949, 9080 available

### Security Check
- [ ] Review and modify .env file (especially database password)
- [ ] If using demo mode, change unblock key in demo/init.sh
- [ ] Plan for HTTPS/SSL in production

## 📝 Deployment Steps

1. **Start Docker Desktop**
   ```powershell
   # Ensure Docker Desktop is running
   ```

2. **Pull Images** (optional, but recommended)
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
   ```

5. **Verify Deployment**
   ```powershell
   # Check all services are running
   docker compose ps
   
   # Check Dataverse is responding
   curl http://localhost:8080/api/info/version
   ```

6. **Access Application**
   - Open browser to http://localhost:8080
   - Login: dataverseAdmin / admin1

## 🧪 Post-Deployment Tests

### Smoke Tests
- [ ] Can access Dataverse UI at http://localhost:8080
- [ ] Can login with default credentials
- [ ] Can create a new collection
- [ ] Can create a dataset
- [ ] Can upload a file
- [ ] Can publish a dataset
- [ ] Emails visible in MailDev at http://localhost:1080

### Service Health
- [ ] PostgreSQL accepting connections
- [ ] Solr responding to queries
- [ ] File previewers working
- [ ] SMTP sending test emails

### API Tests
```powershell
# Version check
curl http://localhost:8080/api/info/version

# Server info
curl http://localhost:8080/api/info/server

# Database settings (if dev mode)
curl http://localhost:8080/api/admin/settings
```

## 📊 Success Criteria

✅ All containers running
✅ No error logs in any service
✅ Dataverse UI accessible
✅ Can login as admin
✅ Can perform basic operations (create collection, dataset)
✅ File uploads work
✅ Search functionality works
✅ Email notifications work

## 🎉 Setup Complete!

Once all checks pass, your Dataverse installation is ready for use.

---

**Validation Date**: March 29, 2026
**Configuration Version**: 1.0
**Dataverse Version**: Latest (configurable in .env)
