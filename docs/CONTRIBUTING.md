# Contributing Guide

Welcome to the Dataverse Enterprise Deployment project! This guide explains how to set up your development environment, make changes, and submit contributions.

---

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment Setup](#development-environment-setup)
- [Project Structure](#project-structure)
- [Coding Standards](#coding-standards)
- [Testing Requirements](#testing-requirements)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Quality Gates](#quality-gates)
- [Troubleshooting](#troubleshooting)

---

## Code of Conduct

This project adheres to professional standards:

- **Be respectful**: Treat all contributors with respect
- **Be collaborative**: Share knowledge and help others
- **Be professional**: Focus on technical merit
- **Be secure**: Never commit secrets or sensitive data

---

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Docker Desktop** (latest version)
  - Windows: Docker Desktop with WSL2
  - macOS: Docker Desktop
  - Linux: Docker Engine + Docker Compose
- **Git** (2.30+)
- **PowerShell** 7+ (for automation scripts)
- **Code Editor** (VS Code recommended)

### Verify Installation

```powershell
docker --version        # Should be 24.x or higher
docker compose version  # Should be v2.x or higher
git --version          # Should be 2.30 or higher
pwsh --version         # PowerShell 7.x
```

---

## Development Environment Setup

### 1. Clone Repository

```powershell
git clone https://github.com/your-org/dataverse-AI-ready.git
cd dataverse-AI-ready
```

### 2. Create Environment File

Copy `.env.example` to `.env` and customize:

```powershell
Copy-Item .env.example .env
notepad .env
```

**Required Changes:**
- Set strong passwords for `POSTGRES_PASSWORD`
- Update `DATAVERSE_URL` if not using localhost
- Configure email settings (or use MailDev defaults)

### 3. Install Development Tools

**VS Code Extensions (Recommended):**
- Docker (microsoft.azure-account)
- YAML (redhat.vscode-yaml)
- PowerShell (ms-vscode.powershell)
- GitLens (eamodio.gitlens)

**YAML Linter:**
```powershell
# Windows (Chocolatey)
choco install yamllint

# macOS (Homebrew)
brew install yamllint

# Linux (apt)
sudo apt install yamllint
```

**PowerShell Linter:**
```powershell
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
```

### 4. Start Development Environment

```powershell
# Start in development mode
docker compose up -d

# Watch logs
docker compose logs -f
```

Access Dataverse at: http://localhost:8080  
Login: `dataverseAdmin` / `admin1`

---

## Project Structure

```
dataverse-AI-ready/
├── configs/              # Configuration files
│   ├── compose.yml       # Docker Compose production config
│   ├── compose.dev.yml   # Docker Compose dev overrides
│   ├── .env.example      # Environment template
│   └── demo/             # Demo mode initialization
│       └── init.sh       # Custom bootstrap script
├── scripts/              # Automation scripts
│   ├── backup.ps1        # Backup automation
│   ├── restore.ps1       # Restore procedures
│   ├── healthcheck.ps1   # Health monitoring
│   └── validate.ps1      # Pre-commit validation
├── docs/                 # Documentation
│   ├── ARCHITECTURE.md   # System architecture
│   ├── CONTRIBUTING.md   # This file
│   ├── OPERATIONS.md     # Operational runbooks
│   ├── SECURITY.md       # Security documentation
│   ├── ERRORS_AND_SOLUTIONS.md  # Error index
│   ├── adr/              # Architecture Decision Records
│   │   ├── template.md
│   │   └── 001-docker-compose.md
│   └── errors/           # File-specific error ledgers
├── tests/                # Validation tests
│   ├── smoke-test.ps1    # Basic deployment test
│   └── integration/      # Integration tests
├── .github/
│   └── workflows/        # CI/CD pipelines
│       └── validate.yml  # Pull request validation
├── data/                 # Persistent data (gitignored)
├── backups/              # Backup storage (gitignored)
├── .gitignore            # Git ignore rules
├── README.md             # User-facing documentation
├── INSTALLATION_GUIDE.md # Step-by-step setup
├── CHANGELOG.md          # Version history
└── LICENSE               # Project license
```

---

## Coding Standards

### YAML Files (Docker Compose, GitHub Actions)

**Rules:**
- Use 2 spaces for indentation (not tabs)
- Double-quote strings with special characters
- Sort keys alphabetically within sections
- Add comments for non-obvious configurations

**Validation:**
```powershell
yamllint configs/compose.yml
```

**Example:**
```yaml
services:
  dataverse:
    container_name: dataverse
    image: gdcc/dataverse:${DATAVERSE_VERSION:-latest}
    restart: unless-stopped
    # Expose web UI on port 8080
    ports:
      - "${DATAVERSE_PORT:-8080}:8080"
```

### PowerShell Scripts

**Rules:**
- Use `PascalCase` for functions
- Use `$camelCase` for variables
- Add comment-based help for all functions
- Use `Write-Output` not `Write-Host` (for testability)
- Always validate inputs with `[Parameter()]` attributes
- Use `Set-StrictMode -Version Latest`

**Validation:**
```powershell
Invoke-ScriptAnalyzer -Path scripts/ -Recurse
```

**Example:**
```powershell
<#
.SYNOPSIS
Backs up PostgreSQL database and file storage.

.DESCRIPTION
Creates timestamped backups of the database and uploaded files.
Stores backups in the backups/ directory.

.PARAMETER BackupPath
Path to store backup files. Defaults to ./backups

.EXAMPLE
.\backup.ps1 -BackupPath "C:\Backups"
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$BackupPath = ".\backups"
)

Set-StrictMode -Version Latest
```

### Markdown Documentation

**Rules:**
- Use ATX-style headers (`#` not `===`)
- Add table of contents for docs >200 lines
- Use code blocks with language identifiers
- Keep line length ≤100 characters for readability
- Use relative links for internal references

**Example:**
```markdown
## Installation

Follow these steps:

1. Download configuration:
   ```powershell
   Invoke-WebRequest -Uri "..." -OutFile "compose.yml"
   ```
2. Start services
```

---

## Testing Requirements

### Pre-Commit Validation

Before committing, run:

```powershell
.\scripts\validate.ps1
```

This checks:
- ✅ YAML syntax (yamllint)
- ✅ PowerShell syntax (PSScriptAnalyzer)
- ✅ No secrets in files (basic regex scan)
- ✅ Docker Compose validates (`docker compose config`)

### Smoke Tests

After deployment changes, run:

```powershell
.\tests\smoke-test.ps1
```

This verifies:
- ✅ All containers start and are healthy
- ✅ Dataverse web UI is accessible
- ✅ Admin login works
- ✅ API responds correctly
- ✅ Database connection is healthy

### Manual Testing Checklist

For major changes, test:

- [ ] Fresh deployment (`docker compose up`)
- [ ] Create collection
- [ ] Create dataset
- [ ] Upload file
- [ ] Publish dataset
- [ ] Search for dataset
- [ ] Backup/restore cycle
- [ ] Upgrade from previous version

---

## Commit Guidelines

### Commit Message Format

Use **Conventional Commits** format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `chore`: Maintenance (dependencies, config)
- `test`: Test additions/changes
- `refactor`: Code restructuring (no behavior change)
- `perf`: Performance improvements
- `security`: Security fixes

**Examples:**

```
feat(compose): Add health checks to all services

Added health checks for dataverse, postgres, and solr containers.
This enables Docker to detect and restart failed services.

Closes #42
```

```
fix(backup): Handle spaces in backup paths

The backup script failed when BACKUP_PATH contained spaces.
Now properly quotes all path variables.

Fixes #38
```

```
docs(security): Document password rotation procedure

Added step-by-step guide for rotating database passwords
without downtime. Includes rollback procedure.
```

### Commit Checklist

Before committing:

- [ ] Validation script passes (`.\scripts\validate.ps1`)
- [ ] Commit message follows convention
- [ ] No debug code or commented-out blocks
- [ ] No secrets or credentials
- [ ] Documentation updated (if applicable)
- [ ] CHANGELOG.md updated (for user-visible changes)

---

## Pull Request Process

### 1. Create Feature Branch

```powershell
git checkout -b feat/add-monitoring-dashboard
```

**Branch Naming:**
- `feat/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `chore/` - Maintenance tasks

### 2. Make Changes

Follow coding standards and testing requirements above.

### 3. Commit Changes

```powershell
git add .
git commit -m "feat(monitoring): Add Grafana dashboard"
```

### 4. Push to Remote

```powershell
git push origin feat/add-monitoring-dashboard
```

### 5. Open Pull Request

**PR Title:** Same format as commit message  
**PR Description Template:**

```markdown
## Summary
Brief description of changes

## Motivation
Why is this change needed?

## Changes Made
- Added X
- Modified Y
- Removed Z

## Testing
- [ ] Smoke tests pass
- [ ] Manual testing completed
- [ ] Documentation updated

## Screenshots (if UI changes)
[Attach screenshots]

## Checklist
- [ ] Follows coding standards
- [ ] No secrets committed
- [ ] CI pipeline passes
- [ ] Reviewed own code
```

### 6. Address Review Comments

- Respond to all comments
- Push fixes to same branch (will update PR)
- Request re-review when ready

### 7. Merge

Once approved:
- Use "Squash and merge" for clean history
- Delete branch after merge

---

## Quality Gates

All pull requests must pass these checks:

### Automated CI Pipeline (GitHub Actions)

✅ **YAML Lint**: All YAML files pass yamllint  
✅ **PowerShell Lint**: All scripts pass PSScriptAnalyzer  
✅ **Compose Validation**: `docker compose config` succeeds  
✅ **Secrets Scan**: No hardcoded credentials  
✅ **Smoke Test**: Fresh deployment completes successfully

### Manual Review

✅ **Code Quality**: Clear, maintainable code  
✅ **Documentation**: User-visible changes documented  
✅ **Security**: No new vulnerabilities introduced  
✅ **Testing**: Adequate test coverage

---

## Troubleshooting

### Common Issues

#### "yamllint: command not found"

**Solution:**
```powershell
# Windows
choco install yamllint

# macOS
brew install yamllint
```

#### "PSScriptAnalyzer module not found"

**Solution:**
```powershell
Install-Module -Name PSScriptAnalyzer -Force -Scope CurrentUser
```

#### "Docker Compose validation failed"

**Solution:**
Check `compose.yml` syntax:
```powershell
docker compose config
```

Look for YAML indentation errors or invalid keys.

#### "Containers fail to start after changes"

**Solution:**
1. Check logs: `docker compose logs -f`
2. Validate environment: `cat .env`
3. Reset: `docker compose down && docker compose up`

---

## Getting Help

- **Documentation Issues**: Open GitHub issue with `docs` label
- **Technical Questions**: Ask in GitHub Discussions
- **Security Concerns**: Email security@yourorg.com (do not open public issue)
- **Dataverse Platform**: https://groups.google.com/g/dataverse-community

---

## Recognition

Contributors are recognized in:
- GitHub Contributors graph
- CHANGELOG.md (for significant contributions)
- Project README.md (for major features)

---

## License

By contributing, you agree that your contributions will be licensed under the same license as the project (see LICENSE file).

---

*Thank you for contributing to making Dataverse enterprise-ready!*
