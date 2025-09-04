# Scripts Directory

This directory contains all the automation and deployment scripts for the CI/CD Docker project.

## 📁 Scripts Overview

| Script | Purpose | Usage |
|--------|---------|-------|
| `check-updates.sh` | **Docker Hub Update Checker** - Checks for and applies updates to Docker images | `./check-updates.sh --help` |
| `setup.sh` | **Environment Setup** - Sets up the complete development environment | `./setup.sh` |
| `deploy-backend.sh` | **Backend Deployment** - Automated backend service deployment | `./deploy-backend.sh deploy` |

## 🚀 Quick Start

### 1. Setup Development Environment

```bash
cd scripts/
./setup.sh
```

### 2. Check for Docker Image Updates

```bash
cd scripts/
./check-updates.sh --check
```

### 3. Update All Services

```bash
cd scripts/
./check-updates.sh --update-all
```

### 4. Deploy Backend Services

```bash
cd scripts/
./deploy-backend.sh deploy
```

## 📋 Script Details

### `check-updates.sh` - Docker Hub Update Checker

**Latest addition to Phase 4 requirements**

**Commands:**

- `--check` - Check for updates only (default)
- `--update-all` - Update all services that have updates
- `--update <service>` - Update specific service (backend, nginx, frontend)
- `--dry-run` - Show what would be updated without making changes
- `--verbose` - Show detailed logging

**Examples:**

```bash
./check-updates.sh --check                    # Check for updates
./check-updates.sh --update-all              # Update all services
./check-updates.sh --update backend          # Update only backend
./check-updates.sh --dry-run --verbose       # Dry run with verbose output
```

### `setup.sh` - Environment Setup

Sets up the complete Docker development environment with all services.

### `deploy-backend.sh` - Backend Deployment

Handles automated backend deployment with health checks and rollback capabilities.

**Commands:**

- `deploy` - Deploy backend services
- `health-check` - Check service health
- `logs` - View service logs

## 📊 Log Files

- `check-updates.log` - Logs from the update checker script

## 🔧 Dependencies

All scripts require:

- Docker
- docker-compose
- curl (for API calls)
- jq (for JSON parsing)

## 📚 Related Documentation

- Core documentation: `../README.md`
- Setup guides: `../JENKINS_SETUP.md`, `../GITHUB_ACTIONS_SETUP.md`, `../DISCORD_NOTIFICATIONS_SETUP.md`
