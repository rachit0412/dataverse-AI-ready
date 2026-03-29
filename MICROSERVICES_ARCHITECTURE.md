# 🏗️ Microservices Architecture Documentation

## Overview

This Dataverse deployment follows **microservices architecture principles** with clear service boundaries, isolated networks, and a centralized API Gateway for routing and load balancing.

## 🎯 Architecture Principles

### 1. **Single Entry Point (API Gateway Pattern)**
- All external traffic flows through the nginx API Gateway
- Provides centralized security, routing, and load balancing
- Enables service discovery and health monitoring

### 2. **Service Isolation**
- Services are grouped into logical tiers
- Separate networks for frontend and backend communication
- Each service has well-defined boundaries and responsibilities

### 3. **Network Segmentation**
```
┌─────────────────────────────────────────────────────────────┐
│                     FRONTEND NETWORK                        │
│  (External Access via API Gateway)                          │
├─────────────────────────────────────────────────────────────┤
│  • API Gateway (nginx)                                      │
│  • MailDev UI                                               │
│  • Dataverse App (limited)                                  │
│  • Previewers (limited)                                     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                     BACKEND NETWORK                         │
│  (Internal Service-to-Service Communication)                │
├─────────────────────────────────────────────────────────────┤
│  • Dataverse Application                                    │
│  • PostgreSQL Database                                      │
│  • Apache Solr Search                                       │
│  • SMTP Email Service                                       │
│  • File Previewers                                          │
│  • Configuration Services                                   │
└─────────────────────────────────────────────────────────────┘
```

### 4. **Health Monitoring**
- Each critical service has health checks
- API Gateway monitors upstream service health
- Automatic service recovery with restart policies

### 5. **Scalability Ready**
- Services can be scaled independently
- Stateless design where possible
- Persistent data in volumes

## 🔷 Service Tiers

### **1. Frontend Tier**
**Purpose**: Handle external requests and provide user interfaces

| Service | Role | Ports | Network |
|---------|------|-------|---------|
| **API Gateway** | Single entry point, routing, load balancing | 80, 443 | frontend, backend |

**Key Features**:
- Request routing to internal services
- SSL/TLS termination (ready)
- Rate limiting (configurable)
- CORS handling
- Static content caching

---

### **2. Application Tier**
**Purpose**: Business logic and core functionality

| Service | Role | Ports | Network |
|---------|------|-------|---------|
| **Dataverse** | Core application logic | 8080 (internal) | backend, frontend |

**Key Features**:
- Dataset management
- User authentication
- Metadata processing
- File storage coordination
- API endpoint handling

**Dependencies**:
- PostgreSQL (database)
- Solr (search)
- SMTP (notifications)
- Previewers (file preview)

---

### **3. Data Tier**
**Purpose**: Persistent data storage

| Service | Role | Ports | Network |
|---------|------|-------|---------|
| **PostgreSQL** | Relational database | 5432 (internal) | backend only |

**Key Features**:
- Metadata storage
- User accounts and permissions
- System configuration
- Transaction management

**Storage**: Persistent volume `dataverse-postgres-data`

---

### **4. Search Tier**
**Purpose**: Full-text search and indexing

| Service | Role | Ports | Network |
|---------|------|-------|---------|
| **Apache Solr** | Search engine | 8983 (internal) | backend only |

**Key Features**:
- Dataset indexing
- Fast search queries
- Faceted search
- Metadata aggregation

**Storage**: 
- Data: `dataverse-solr-data`
- Config: `dataverse-solr-conf`

---

### **5. Communication Tier**
**Purpose**: Inter-service and external communication

| Service | Role | Ports | Network |
|---------|------|-------|---------|
| **SMTP (MailDev)** | Email service | 25 (internal), 1080 (UI) | backend, frontend |

**Key Features**:
- Email notifications
- Testing interface
- Email capture and review

---

### **6. Presentation Tier**
**Purpose**: Content rendering and preview

| Service | Role | Ports | Network |
|---------|------|-------|---------|
| **Previewers** | File preview service | 9080 (internal) | backend, frontend |

**Key Features**:
- Preview various file types
- Inline document viewing
- Format conversion

**Supported Formats**: Text, HTML, PDF, Images, CSV, Markdown

---

### **7. Initialization Tier**
**Purpose**: Setup and configuration

| Service | Role | Network |
|---------|------|---------|
| **Bootstrap** | Initial configuration | backend |
| **Solr Initializer** | Solr setup | backend |
| **DV Initializer** | Filesystem setup | backend |
| **Register Previewers** | Previewer registration | backend |

**Lifecycle**: Run once, then exit

## 🔄 Service Communication Flow

### External Request Flow
```
┌──────────┐
│  Client  │
└─────┬────┘
      │ HTTP/HTTPS
      ▼
┌─────────────────┐
│  API Gateway    │ ◄── Single Entry Point
│    (nginx)      │
└────────┬────────┘
         │
    ┌────┴────┐
    │  Route  │
    └────┬────┘
         │
    ┌────┴────────────────────┐
    │                         │
    ▼                         ▼
┌──────────┐          ┌─────────────┐
│Dataverse │          │   MailDev   │
│   App    │          │  (Web UI)   │
└────┬─────┘          └─────────────┘
     │
     │ Internal Calls
     │
     ├──► PostgreSQL (Data)
     ├──► Solr (Search)
     ├──► SMTP (Email)
     └──► Previewers (Files)
```

### Internal Service Communication
```
Dataverse Application
    │
    ├─[SQL]──────► PostgreSQL Database
    ├─[HTTP]─────► Apache Solr (indexing/search)
    ├─[SMTP]─────► Email Service
    └─[HTTP]─────► File Previewers
```

## 🔒 Security Architecture

### Network Isolation
1. **Frontend Network**: 
   - Only API Gateway and UI services
   - Controlled external access
   
2. **Backend Network**: 
   - All internal services
   - No direct external access
   - Service-to-service communication only

### Access Control
```
External User
    ↓
[API Gateway] ← Only entry point
    ↓
[Dataverse App] ← Authentication/Authorization
    ↓
[Backend Services] ← Internal network only
```

### Security Layers
1. **Perimeter Security**: API Gateway filters all requests
2. **Application Security**: Dataverse handles auth/authz
3. **Network Security**: Isolated backend network
4. **Data Security**: PostgreSQL access control

## 📊 Service Discovery

Services use Docker DNS for discovery:
- `postgres:5432` - Database endpoint
- `solr:8983` - Search endpoint
- `smtp:25` - SMTP endpoint
- `dataverse:8080` - Application endpoint
- `previewers-provider:9080` - Preview endpoint

## 🏷️ Service Labels

Each service is tagged with metadata for orchestration:

```yaml
labels:
  - "com.dataverse.service=<service-name>"
  - "com.dataverse.tier=<tier-name>"
  - "com.dataverse.description=<description>"
```

**Tiers**:
- `frontend` - External-facing services
- `application` - Business logic
- `data` - Persistence
- `search` - Indexing and search
- `communication` - Messaging
- `presentation` - UI/rendering
- `initialization` - Setup services

## 🔄 Scaling Strategy

### Vertical Scaling (Current)
- Increase CPU/memory for individual services
- Configured via `mem_limit` in docker-compose.yml

### Horizontal Scaling (Future)
Ready for:
1. **Multiple Dataverse instances** behind API Gateway
2. **PostgreSQL replication** (primary/replica)
3. **Solr clustering** (SolrCloud)
4. **Redis caching** layer (add-on)

Example horizontal scaling:
```yaml
dataverse:
  deploy:
    replicas: 3  # Multiple instances
    update_config:
      parallelism: 1
      delay: 10s
```

## 📈 Monitoring & Observability

### Health Endpoints
- API Gateway: `http://api-gateway:80/health`
- Dataverse: `http://dataverse:8080/api/info/version`
- PostgreSQL: `pg_isready` command
- Solr: `http://solr:8983/solr/collection1/admin/ping`

### Logging
Centralized through Docker:
```bash
docker compose logs <service>
docker compose logs -f --tail=100 dataverse
```

### Metrics (Future Integration)
Ready for:
- Prometheus metrics scraping
- Grafana dashboards
- ELK stack integration
- Distributed tracing (Jaeger)

## 🚀 Deployment Patterns

### Blue-Green Deployment
```yaml
# Deploy new version alongside old
dataverse_blue:
  image: gdcc/dataverse:v6.10
  
dataverse_green:
  image: gdcc/dataverse:v6.11

# API Gateway routes to active version
```

### Canary Deployment
```nginx
# Route 90% to stable, 10% to canary
upstream dataverse_app {
    server dataverse-stable:8080 weight=9;
    server dataverse-canary:8080 weight=1;
}
```

## 🔧 Configuration Management

### Environment-Based
- `.env` file for environment variables
- Service-specific environment blocks
- Network configuration in docker-compose.yml

### Externalized Configuration
- Dataverse settings via API
- Database connection strings
- Feature flags
- API keys and secrets

### Configuration Hierarchy
```
1. Environment Variables (.env)
2. Docker Compose (docker-compose.yml)
3. Service Config Files (nginx/*, demo/*)
4. Runtime Configuration (Dataverse API)
```

## 🎯 Best Practices Implemented

✅ **Single Responsibility**: Each service has one job  
✅ **Loose Coupling**: Services communicate via well-defined APIs  
✅ **Service Discovery**: DNS-based service resolution  
✅ **Health Checks**: Automatic health monitoring  
✅ **Graceful Degradation**: Services can restart independently  
✅ **Idempotency**: Safe to restart/redeploy services  
✅ **Stateless Design**: Application state in database, not containers  
✅ **Immutable Infrastructure**: Containers are disposable  
✅ **Configuration as Code**: Everything in version control  
✅ **Network Segmentation**: Isolated security zones  

## 📚 Comparison: Monolith vs Microservices

### Traditional Monolithic Dataverse
```
┌─────────────────────────────────┐
│                                 │
│    All-in-One Dataverse         │
│    (App + DB + Search)          │
│                                 │
└─────────────────────────────────┘
```

### Our Microservices Architecture
```
                    ┌──────────────┐
                    │ API Gateway  │
                    └───────┬──────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
   ┌────▼─────┐      ┌─────▼──────┐     ┌─────▼─────┐
   │Dataverse │      │ PostgreSQL │     │   Solr    │
   │   App    │      │  Service   │     │  Service  │
   └──────────┘      └────────────┘     └───────────┘
```

**Benefits**:
- Independent scaling
- Isolated failures
- Technology flexibility
- Easier maintenance
- Better security

## 🔄 Service Lifecycle

### Startup Sequence
1. **Networks** created
2. **Volumes** mounted
3. **Initializers** run (Solr, DV setup)
4. **PostgreSQL** starts and becomes healthy
5. **Solr** starts and becomes healthy
6. **SMTP** starts
7. **Dataverse** starts and becomes healthy
8. **API Gateway** starts and routes traffic
9. **Bootstrap** configures system
10. **Previewers** register

### Shutdown Sequence
```bash
docker compose down  # Graceful shutdown
```

Services stop in reverse dependency order.

## 🎓 Further Reading

- [Microservices Patterns](https://microservices.io/patterns/)
- [API Gateway Pattern](https://microservices.io/patterns/apigateway.html)
- [Service Discovery](https://microservices.io/patterns/service-registry.html)
- [Docker Networking](https://docs.docker.com/network/)
- [Nginx Load Balancing](https://nginx.org/en/docs/http/load_balancing.html)

---

**Architecture Version**: 2.0 (Microservices)  
**Last Updated**: March 29, 2026  
**Author**: System Architecture Team
