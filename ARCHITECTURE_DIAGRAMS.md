# Microservices Architecture - Visual Reference

## System Overview

```
┌───────────────────────────────────────────────────────────────┐
│                        EXTERNAL USERS                         │
│                    (Internet / Intranet)                      │
└───────────────────────────┬───────────────────────────────────┘
                            │
                            │ HTTP/HTTPS
                            │
┌───────────────────────────▼───────────────────────────────────┐
│                                                                │
│                      FRONTEND NETWORK                          │
│                  (External-Facing Services)                    │
│                                                                │
│   ┌────────────────────────────────────────────────────┐      │
│   │                                                    │      │
│   │          🌐 API GATEWAY (nginx)                   │      │
│   │          Port 80 / 443 (HTTPS)                    │      │
│   │                                                    │      │
│   │  • Request Routing                                │      │
│   │  • Load Balancing                                 │      │
│   │  • SSL Termination                                │      │
│   │  • CORS Handling                                  │      │
│   │  • Rate Limiting                                  │      │
│   │  • Security Headers                               │      │
│   │                                                    │      │
│   └─────────────────────┬──────────────────────────────┘      │
│                         │                                     │
└─────────────────────────┼─────────────────────────────────────┘
                          │
                          │ Internal Routing
                          │
┌─────────────────────────▼─────────────────────────────────────┐
│                                                                │
│                      BACKEND NETWORK                           │
│                (Internal Service Communication)                │
│                        (Isolated)                              │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │                                                       │    │
│  │          📱 APPLICATION TIER                         │    │
│  │                                                       │    │
│  │  ┌─────────────────────────────────────────┐        │    │
│  │  │                                         │        │    │
│  │  │   Dataverse Application                │        │    │
│  │  │   (Java / Payara)                      │        │    │
│  │  │   Port 8080 (internal)                 │        │    │
│  │  │                                         │        │    │
│  │  │   • Dataset Management                 │        │    │
│  │  │   • User Authentication                │        │    │
│  │  │   • API Endpoints                      │        │    │
│  │  │   • File Upload/Download               │        │    │
│  │  │   • Metadata Processing                │        │    │
│  │  │                                         │        │    │
│  │  └────────────┬────────────────────────────┘        │    │
│  │               │                                     │    │
│  └───────────────┼─────────────────────────────────────┘    │
│                  │                                           │
│     ┌────────────┼────────────┬─────────────┬──────────┐    │
│     │            │            │             │          │    │
│  ┌──▼────┐  ┌───▼────┐  ┌───▼────┐  ┌─────▼───┐  ┌──▼───┐  │
│  │       │  │        │  │        │  │         │  │      │  │
│  │  💾   │  │   🔍   │  │   📧   │  │   🗄️    │  │  🎨  │  │
│  │       │  │        │  │        │  │         │  │      │  │
│  │ DATA  │  │ SEARCH │  │  COMM  │  │ STORAGE │  │RENDER│  │
│  │ TIER  │  │  TIER  │  │  TIER  │  │  TIER   │  │ TIER │  │
│  │       │  │        │  │        │  │         │  │      │  │
│  └───────┘  └────────┘  └────────┘  └─────────┘  └──────┘  │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │                                                       │    │
│  │  PostgreSQL Database                                 │    │
│  │  • Metadata Storage                                  │    │
│  │  • User Management                                   │    │
│  │  • Configuration                                     │    │
│  │  Port: 5432 (internal)                               │    │
│  │                                                       │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │                                                       │    │
│  │  Apache Solr Search Engine                           │    │
│  │  • Full-text Search                                  │    │
│  │  • Indexing                                          │    │
│  │  • Faceted Search                                    │    │
│  │  Port: 8983 (internal)                               │    │
│  │                                                       │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │                                                       │    │
│  │  SMTP Service (MailDev)                              │    │
│  │  • Email Notifications                               │    │
│  │  • Testing Interface                                 │    │
│  │  Port: 25 (internal), 1080 (web UI)                 │    │
│  │                                                       │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                │
│  ┌───────────────────────────────────────────────────────┐    │
│  │                                                       │    │
│  │  File Previewers Service                             │    │
│  │  • File Preview Generation                           │    │
│  │  • Format Support                                    │    │
│  │  Port: 9080 (internal)                               │    │
│  │                                                       │    │
│  └───────────────────────────────────────────────────────┘    │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

## Request Flow Diagram

```
1. User Request
   │
   ▼
┌────────────────┐
│  Web Browser   │
└────────┬───────┘
         │ http://localhost
         ▼
┌────────────────────────────┐
│    API Gateway (nginx)     │  ◄── Port 80/443
│    • Security Checks       │
│    • Rate Limiting         │
│    • SSL Termination       │
└────────┬───────────────────┘
         │ proxy_pass
         ▼
┌────────────────────────────┐
│  Dataverse Application     │  ◄── Port 8080 (internal)
│    • Authentication        │
│    • Business Logic        │
│    • API Processing        │
└────────┬───────────────────┘
         │
    ┌────┼──────┬──────────┬─────────┐
    │    │      │          │         │
    ▼    ▼      ▼          ▼         ▼
┌──────┐┌────┐┌──────┐ ┌──────┐ ┌────────┐
│PgSQL ││Solr││SMTP  │ │Files │ │Preview │
└──────┘└────┘└──────┘ └──────┘ └────────┘
```

## Service Communication Matrix

```
┌──────────────┬─────┬──────┬──────┬──────┬──────────┬───────────┐
│              │ API │ DV   │PgSQL │ Solr │  SMTP    │ Previewers│
│              │ GW  │ App  │      │      │          │           │
├──────────────┼─────┼──────┼──────┼──────┼──────────┼───────────┤
│ API Gateway  │  -  │  ✓   │  ✗   │  ✗   │  ✓ (UI)  │  ✓ (UI)   │
│ DV App       │  ✗  │  -   │  ✓   │  ✓   │  ✓       │  ✓        │
│ PostgreSQL   │  ✗  │  ✓   │  -   │  ✗   │  ✗       │  ✗        │
│ Solr         │  ✗  │  ✓   │  ✗   │  -   │  ✗       │  ✗        │
│ SMTP         │  ✗  │  ✓   │  ✗   │  ✗   │  -       │  ✗        │
│ Previewers   │  ✗  │  ✓   │  ✗   │  ✗   │  ✗       │  -        │
└──────────────┴─────┴──────┴──────┴──────┴──────────┴───────────┘

Legend:
  ✓ = Can communicate directly
  ✗ = No direct communication
  - = Self

Note: API Gateway acts as the single entry point for external traffic.
      Backend services communicate directly over the backend network.
```

## Network Topology

```
┌────────────────────────────────────────────────────────┐
│           FRONTEND NETWORK (dataverse-frontend)        │
│                                                        │
│   • API Gateway (nginx) ─────────────► External       │
│   • MailDev Web UI                                     │
│                                                        │
└─────────────────┬──────────────────────────────────────┘
                  │
                  │ Bridge Connection
                  │
┌─────────────────▼──────────────────────────────────────┐
│           BACKEND NETWORK (dataverse-backend)          │
│                                                        │
│   • Dataverse Application                              │
│   • PostgreSQL Database                                │
│   • Apache Solr                                        │
│   • SMTP Service                                       │
│   • File Previewers                                    │
│   • Initialization Services                            │
│                                                        │
│   Isolation: internal=false (can access internet)      │
│                                                        │
└────────────────────────────────────────────────────────┘
```

## Service Tiers

```
┌──────────────────────────────────────────────────────────┐
│                    TIER ARCHITECTURE                     │
└──────────────────────────────────────────────────────────┘

Tier 1: FRONTEND (Entry Point)
┌────────────────────┐
│   API Gateway      │  Port: 80, 443
│   (nginx)          │  Role: Routing, Security
└────────────────────┘

Tier 2: APPLICATION (Business Logic)
┌────────────────────┐
│   Dataverse App    │  Port: 8080 (internal)
│   (Payara/Java)    │  Role: Core Logic
└────────────────────┘

Tier 3: DATA (Persistence)
┌────────────────────┐
│   PostgreSQL       │  Port: 5432 (internal)
│                    │  Role: Data Storage
└────────────────────┘

Tier 4: SEARCH (Indexing)
┌────────────────────┐
│   Apache Solr      │  Port: 8983 (internal)
│                    │  Role: Full-text Search
└────────────────────┘

Tier 5: COMMUNICATION (Messaging)
┌────────────────────┐
│   SMTP/MailDev     │  Port: 25, 1080 (internal)
│                    │  Role: Email Service
└────────────────────┘

Tier 6: PRESENTATION (Rendering)
┌────────────────────┐
│   File Previewers  │  Port: 9080 (internal)
│                    │  Role: File Preview
└────────────────────┘

Tier 7: INITIALIZATION (Setup)
┌────────────────────┐
│   Bootstrap        │  Run once
│   Initializers     │  Role: Configuration
└────────────────────┘
```

## Scalability Model

```
CURRENT ARCHITECTURE (Single Instance)
────────────────────────────────────────

API Gateway ──► Dataverse (1 instance)
                    ↓
               Backend Services


FUTURE ARCHITECTURE (Horizontal Scaling)
────────────────────────────────────────

                        ┌─► Dataverse Instance 1
                        │
API Gateway ──► Load ───┼─► Dataverse Instance 2
                Balancer│
                        └─► Dataverse Instance 3
                                ↓
                          Backend Services
                                ↓
                        ┌─► PostgreSQL Primary
                        │
                        └─► PostgreSQL Replica(s)
```

## Health Check Flow

```
┌─────────────────────────────────────────────────────┐
│              HEALTH MONITORING                      │
└─────────────────────────────────────────────────────┘

External Monitor
    │
    ▼
API Gateway Health (/health)
    │ ✓ OK
    │
    ├─► Dataverse App (/api/info/version)
    │   │ ✓ OK
    │   │
    │   ├─► PostgreSQL (pg_isready)
    │   │   │ ✓ OK
    │   │
    │   ├─► Solr (/solr/admin/ping)
    │   │   │ ✓ OK
    │   │
    │   └─► SMTP (connection test)
    │       │ ✓ OK
    │
    └─► All Services Healthy ✓
```

## Security Layers

```
┌────────────────────────────────────────────────────┐
│         DEFENSE IN DEPTH ARCHITECTURE              │
└────────────────────────────────────────────────────┘

Layer 1: Network Security
         │
         ├─ Firewall (Infrastructure)
         ├─ Network Segmentation
         └─ Private Backend Network
         
Layer 2: API Gateway Security
         │
         ├─ SSL/TLS Termination
         ├─ Rate Limiting
         ├─ CORS Policies
         ├─ Security Headers
         └─ Request Filtering

Layer 3: Application Security
         │
         ├─ Authentication
         ├─ Authorization
         ├─ Input Validation
         └─ Session Management

Layer 4: Data Security
         │
         ├─ Database Access Control
         ├─ Encrypted Connections
         └─ Data Encryption at Rest
```

---

**Visual Reference Version**: 1.0  
**Architecture**: Microservices  
**Date**: March 29, 2026
