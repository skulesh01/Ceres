# CERES Platform - Makefile Helper
# Provides convenient shortcuts for common operations
# Works on Linux/Mac with make, and Windows with WSL or Git Bash

.PHONY: help start stop restart status logs backup restore clean update test docs

# Default target
.DEFAULT_GOAL := help

# Colors for output
CYAN := \033[0;36m
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

## help: Display this help message
help:
	@echo "$(CYAN)╔═══════════════════════════════════════════════════════╗$(NC)"
	@echo "$(CYAN)║          CERES Platform - Quick Commands          ║$(NC)"
	@echo "$(CYAN)╚═══════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(YELLOW)Core Commands:$(NC)"
	@echo "  make start      - Start CERES services (default modules)"
	@echo "  make stop       - Stop all services"
	@echo "  make restart    - Restart services"
	@echo "  make status     - Show service status and health"
	@echo "  make logs       - Follow logs from all services"
	@echo ""
	@echo "$(YELLOW)Maintenance:$(NC)"
	@echo "  make backup     - Create backup of volumes and config"
	@echo "  make restore    - Restore from latest backup"
	@echo "  make clean      - Remove containers and volumes"
	@echo "  make update     - Update Docker images"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  make test       - Run tests and validation"
	@echo "  make docs       - Open documentation"
	@echo "  make shell      - Open shell in core container"
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make start modules='core apps'     - Start specific modules"
	@echo "  make logs service=postgres         - Show logs for one service"
	@echo "  make backup name=before-upgrade    - Named backup"
	@echo ""

## start: Start CERES services
start:
	@echo "$(GREEN)Starting CERES services...$(NC)"
	@cd scripts && bash start.sh $(if $(modules),$(modules),)

## stop: Stop all services
stop:
	@echo "$(YELLOW)Stopping CERES services...$(NC)"
	@cd config && docker compose --project-name ceres down

## restart: Restart services
restart: stop start
	@echo "$(GREEN)Services restarted$(NC)"

## status: Check service status
status:
	@echo "$(CYAN)Checking service status...$(NC)"
	@cd scripts && bash -c 'if command -v pwsh &> /dev/null; then pwsh -File status.ps1; else powershell -File status.ps1; fi'

## logs: Follow service logs
logs:
	@cd config && docker compose --project-name ceres logs -f $(if $(service),$(service),)

## logs-errors: Show only error logs
logs-errors:
	@cd config && docker compose --project-name ceres logs --tail=100 | grep -i error

## backup: Create backup
backup:
	@echo "$(CYAN)Creating backup...$(NC)"
	@cd scripts && bash backup.sh $(if $(name),--name $(name),)
	@echo "$(GREEN)Backup complete$(NC)"

## restore: Restore from backup
restore:
	@if [ -z "$(file)" ]; then \
		echo "$(YELLOW)Usage: make restore file=backups/backup-YYYYMMDD-HHMMSS.tar.gz$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Restoring from $(file)...$(NC)"
	@cd scripts && bash restore.sh $(file)
	@echo "$(GREEN)Restore complete$(NC)"

## clean: Remove containers and volumes (DANGEROUS)
clean:
	@echo "$(YELLOW)WARNING: This will remove all containers and volumes!$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cd scripts && bash cleanup.sh; \
		echo "$(GREEN)Cleanup complete$(NC)"; \
	else \
		echo "Cancelled"; \
	fi

## update: Update Docker images
update:
	@echo "$(CYAN)Updating Docker images...$(NC)"
	@cd config && docker compose --project-name ceres pull
	@echo "$(GREEN)Update complete. Run 'make restart' to use new images$(NC)"

## test: Run health checks and validation
test:
	@echo "$(CYAN)Running tests and validation...$(NC)"
	@cd scripts && bash -c 'if command -v pwsh &> /dev/null; then pwsh -File Test-Installation.ps1; else echo "Tests require PowerShell"; fi'

## docs: Open documentation in browser
docs:
	@if command -v xdg-open &> /dev/null; then \
		xdg-open README.md; \
	elif command -v open &> /dev/null; then \
		open README.md; \
	else \
		echo "$(YELLOW)Please open README.md manually$(NC)"; \
	fi

## shell: Open shell in PostgreSQL container
shell:
	@docker exec -it ceres-postgres-1 bash || echo "$(YELLOW)Container not running$(NC)"

## psql: Open PostgreSQL CLI
psql:
	@docker exec -it ceres-postgres-1 psql -U postgres

## redis-cli: Open Redis CLI
redis-cli:
	@docker exec -it ceres-redis-1 redis-cli

## stats: Show resource usage statistics
stats:
	@docker stats --no-stream ceres-postgres-1 ceres-redis-1 ceres-keycloak-1 2>/dev/null || echo "$(YELLOW)No running containers$(NC)"

## ps: List containers
ps:
	@docker compose --project-name ceres ps

## top: Show running processes in containers
top:
	@docker compose --project-name ceres top

## version: Show versions
version:
	@echo "$(CYAN)CERES Platform v2.1$(NC)"
	@echo "Docker: $$(docker --version)"
	@echo "Docker Compose: $$(docker compose version)"

## install-git-hooks: Install pre-commit hooks
install-git-hooks:
	@echo "$(CYAN)Installing Git hooks...$(NC)"
	@if [ -f .git/hooks/pre-commit ]; then \
		echo "$(YELLOW)pre-commit hook already exists$(NC)"; \
	else \
		echo '#!/bin/bash' > .git/hooks/pre-commit; \
		echo 'echo "Running pre-commit checks..."' >> .git/hooks/pre-commit; \
		echo 'git diff --cached --name-only | grep "\.ps1$$" && echo "PowerShell files changed"' >> .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "$(GREEN)Git hooks installed$(NC)"; \
	fi

# Quick aliases
.PHONY: up down st log
up: start
down: stop  
st: status
log: logs
