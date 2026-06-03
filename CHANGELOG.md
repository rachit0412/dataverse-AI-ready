# CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- **Solr auto-initialization service** (`configs/solr-init/`)
  - Custom Dockerfile and `init-solr.sh` script
  - Ensures `collection1` exists with correct Dataverse schema on every startup
  - Fixes Payara-instead-of-Dataverse issue after Docker restart
  - Idempotent — exits 0 immediately if core is already healthy
- **Enterprise startup script** (`scripts/start.ps1`)
  - 4-phase startup: build solr-init → start containers → wait for Solr init → poll Dataverse API
  - Configurable timeout (default 420s), optional `--Build` and `--NoBrowser` flags
  - Outputs success banner with version, URL, and login info
- **Integration test runner** (`INTEGRATION_TEST_RUNNER.ps1`)
  - 8 REST API integration tests against a live Dataverse deployment
  - Tests: API health, list users, get admin, create user, retrieve user, list dataverses, root dataverse, API permissions
  - Outputs pass/fail summary with pass rate percentage
- **Comprehensive testing documentation suite**
  - `TESTING_SUMMARY.md` — Executive overview with 3 quick-start paths
  - `TESTING_WORKFLOW_GUIDE.md` — Complete testing runbook (unit, integration, coverage)
  - `TESTING_QUICK_REFERENCE.md` — Cheat sheet and 3-minute start guide
  - `SMOKE_TEST_SETUP.md` — Environment verification and smoke test setup
- Created comprehensive error ledgers for deployment issues
  - ERR-COMPOSE-001: Bind mount volume networking failure (RESOLVED)
  - ERR-COMPOSE-002: Incorrect environment variable names (RESOLVED)
- Created enterprise directory structure
- Created operational scripts (backup.ps1, restore.ps1, healthcheck.ps1)
- Created comprehensive documentation suite (ARCHITECTURE, OPERATIONS, SECURITY, CONTRIBUTING)

### Fixed
- **ERR-COMPOSE-002 (CRITICAL):** Changed POSTGRES_HOST → DATAVERSE_DB_HOST (correct MicroProfile Config format)
  - Root cause: Used generic PostgreSQL variable names instead of Dataverse-specific names
  - Impact: Prevented successful deployment (appeared as database connection failure)
  - Resolution: Aligned with official repository's environment variable naming convention
- ERR-COMPOSE-001: Changed from Windows bind mount volumes to Docker-managed volumes

### Changed
- **Enhanced compose.yml** with production-ready features
  - Added security hardening: `read_only`, `no-new-privileges`, `tmpfs` for postgres
  - Added resource limits and reservations for all services
  - Added structured JSON logging with rotation (`max-size`, `max-file`)
  - Bootstrap now depends on `dataverse: service_healthy` (not just `service_started`)
  - Dataverse depends on `solr-init: service_completed_successfully`
  - Added configurable versions via environment variables (`POSTGRES_VERSION`, `SOLR_VERSION`, etc.)
- Updated compose.yml to use official Dataverse environment variable names (DATAVERSE_DB_*)
- Updated healthcheck.ps1 with Solr collection check and memory monitoring
- Removed incorrect assumption about fundamental design flaw (was configuration error)

---

## [0.1.0] - 2026-04-10

### Added
- Enterprise directory structure (/docs, /configs, /scripts, /tests, /.github)
- Comprehensive documentation:
  - ARCHITECTURE.md - System architecture and design
  - CONTRIBUTING.md - Development and contribution guidelines
  - OPERATIONS.md - Operational runbooks and procedures
  - SECURITY.md - Security architecture and procedures
  - ERRORS_AND_SOLUTIONS.md - Error tracking index
  - EXECUTION_PLAN_LOCAL.md - Step-by-step local deployment guide
  - docs/adr/README.md - Architecture Decision Records guide
  - docs/errors/docker-compose.md - Docker Compose error ledger
- Production-ready Docker Compose configuration:
  - configs/compose.yml - Multi-container orchestration with health checks
  - configs/.env.example - Environment variable template with security notes
  - configs/demo/init.sh - Demo mode initialization script
  - configs/README.md - Quick reference guide
- .gitignore protecting secrets and persistent data
- Automated data directory creation

### Changed
- README.md remains user-facing installation guide
- Enhanced security: Demo mode support with unblock key protection

### Fixed
- ERR-COMPOSE-001: Docker Compose bind mount volumes causing networking failures on Windows/WSL2 (changed to Docker-managed volumes)

### Deprecated
- None

### Removed
- None

### Fixed
- None

### Security
- Added .gitignore to prevent secrets from being committed
- Documented secrets management procedures
- Established security baseline in SECURITY.md

---

## [1.0.0] - TBD

### Initial Release
- Production-ready Docker Compose configuration for Dataverse
- Automated backup and restore scripts
- Health check monitoring
- Security hardening (demo mode)
- CI/CD pipeline for validation
- Comprehensive operational documentation

---

## Version Format

**Format:** MAJOR.MINOR.PATCH

- **MAJOR**: Incompatible API changes or major architecture changes
- **MINOR**: New features, backward-compatible
- **PATCH**: Bug fixes, backward-compatible

---

## Categories

- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Features that will be removed in future versions
- **Removed**: Features that have been removed
- **Fixed**: Bug fixes
- **Security**: Security fixes and improvements

---

## Keeping the Changelog Updated

**When making changes:**

1. Add entry under `[Unreleased]` section
2. Use appropriate category (Added, Changed, Fixed, etc.)
3. Write clear, user-facing descriptions
4. Link to issues/PRs when relevant

**On release:**

1. Move `[Unreleased]` items to new version section
2. Add release date
3. Update version tag
4. Create git tag: `git tag -a v1.0.0 -m "Release v1.0.0"`

---

*For internal technical changes, see git commit history. This changelog focuses on user-visible changes.*
