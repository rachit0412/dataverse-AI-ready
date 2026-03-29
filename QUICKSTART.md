# Dataverse Quick Start Guide (Microservices Architecture)

## 🎯 Get Running in 5 Minutes

This deployment uses a **microservices architecture** with an API Gateway as the single entry point.

### Step 1: Start Docker Desktop
Make sure Docker Desktop is running on your Windows machine.

### Step 2: Open PowerShell
Navigate to this directory:
```powershell
cd "c:\Users\rachitgupta5\OneDrive - KPMG\Apps\Dataverse\dataverse-AI-ready"
```

### Step 3: Start Dataverse
```powershell
docker compose up -d
```

### Step 4: Wait for Bootstrap
This takes about 5-10 minutes the first time:
```powershell
docker compose logs -f bootstrap
```

Watch for the success message. Press `Ctrl+C` when you see it.

### Step 5: Access Dataverse
Open your browser to: **http://localhost** (via API Gateway)

Login with:
- Username: `dataverseAdmin`
- Password: `admin1`

## 🎉 You're Done!

### What You Can Do Now

1. **Explore the UI**: Navigate through collections and datasets
2. **Create a Collection**: Click "Add Data" → "New Dataverse Collection"
3. **Upload Data**: Create a dataset and upload files
3. **Check Emails**: Visit http://localhost/maildev to see sent emails
4. **Use the API**: Try `curl http://localhost/api/info/version`

### Important URLs

| What | URL |
|------|-----|
| Main Application | **http://localhost** |
| Email Testing | http://localhost/maildev |

**Note**: All services are accessed through the API Gateway (port 80) for security.

## 🛑 Stopping Dataverse

```powershell
docker compose stop
```

To restart later:
```powershell
docker compose start
```

## 🗑️ Complete Cleanup

To remove everything and start fresh:
```powershell
docker compose down -v
```
⚠️ This deletes all data!

## 🔧 Common Commands

```powershell
# View all logs
docker compose logs -f

# View specific service logs
docker compose logs -f dataverse

# Check service status
docker compose ps

# Restart a service
docker compose restart dataverse

# Get resource usage
docker stats
```

## ❓ Problems?

### "Port already in use"
Edit `.env` and change the conflicting port numbers.

### "Not enough memory"
Make sure Docker Desktop has at least 8 GB RAM allocated.
Settings → Resources → Memory → Set to 8 GB or more.

### Bootstrap taking too long
Normal on first run. If it's been more than 15 minutes, check logs:
```powershell
docker compose logs dataverse
docker compose logs postgres
```

### Can't connect to http://localhost
Wait for bootstrap to complete. Check if it's running:
```powershell
docker compose ps
curl http://localhost/api/info/version
```

## 🏗️ Architecture

This setup uses microservices architecture:
- **API Gateway (nginx)**: Single entry point at port 80
- **Backend Services**: Isolated internal network
- **Service Discovery**: Automatic DNS-based routing

See [MICROSERVICES_ARCHITECTURE.md](MICROSERVICES_ARCHITECTURE.md) for details.

## 📖 Next Steps

Check out the full [README.md](README.md) for:
- Production security setup
- Configuration options
- Backup procedures
- Advanced features
- Troubleshooting guide

---

**Need help?** See the [Dataverse Documentation](https://guides.dataverse.org/en/latest/)
