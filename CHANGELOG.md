# CHANGELOG

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Created comprehensive error ledgers for deployment issues
  - ERR-COMPOSE-001: Bind mount volume networking failure (RESOLVED)
  - ERR-COMPOSE-002: Incorrect environment variable names (RESOLVED)
- Created enterprise directory structure
- Created operational scripts (backup.ps1, restore.ps1, healthcheck.ps1)
- Created comprehensive documentation suite (ARCHITECTURE, OPERATIONS, SECURITY, CONTRIBUTING)
- Analyzed official IQSS/dataverse repository (see files/official-repo-analysis.md)

### Fixed
- **ERR-COMPOSE-002 (CRITICAL):** Changed POSTGRES_HOST → DATAVERSE_DB_HOST (correct MicroProfile Config format)
  - Root cause: Used generic PostgreSQL variable names instead of Dataverse-specific names
  - Impact: Prevented successful deployment (appeared as database connection failure)
  - Resolution: Aligned with official repository's environment variable naming convention
- ERR-COMPOSE-001: Changed from Windows bind mount volumes to Docker-managed volumes

### Changed
- Updated compose.yml to use official Dataverse environment variable names (DATAVERSE_DB_*)
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
