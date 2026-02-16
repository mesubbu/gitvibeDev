# Project automation helpers.
SHELL := /bin/bash

ENV_FILE := .env
INSTALLER := installer/install.sh
PYTHON ?= python3

.PHONY: up up-full down logs reset update local local-stop dev-deps test-fast test test-integration test-stress coverage

# Starts/bootstraps the default stack (backend + frontend + ollama).
up:
	@bash $(INSTALLER) --skip-clone --target-dir .

# Starts the full stack including PostgreSQL and Redis.
up-full:
	@bash $(INSTALLER) --skip-clone --target-dir .
	@docker compose --env-file $(ENV_FILE) --profile full up -d --build

# Starts locally without Docker (Python venv + built-in HTTP server).
local:
	@bash installer/install-local.sh start

# Stops the local (non-Docker) stack.
local-stop:
	@bash installer/install-local.sh stop

# Stops the stack while keeping volumes.
down:
	@docker compose --env-file $(ENV_FILE) down

# Tails runtime logs for all services.
logs:
	@docker compose --env-file $(ENV_FILE) logs -f --tail=200

# Removes containers + volumes, then recreates everything.
reset:
	@docker compose --env-file $(ENV_FILE) down -v --remove-orphans
	@docker compose --env-file $(ENV_FILE) up -d --build

# Updates code and service images, then restarts.
update:
	@git pull --ff-only
	@docker compose --env-file $(ENV_FILE) pull
	@docker compose --env-file $(ENV_FILE) up -d --build

# Installs backend development/test dependencies.
dev-deps:
	@$(PYTHON) -m pip install -r backend/requirements-dev.txt

# Fast local test run (unit + API + regression).
test-fast:
	@cd backend && $(PYTHON) -m pytest -m "unit or api or regression" --maxfail=1 -q

# Full default suite (excludes stress).
test:
	@cd backend && $(PYTHON) -m pytest -m "not stress" --maxfail=1

# Integration-focused suite.
test-integration:
	@cd backend && $(PYTHON) -m pytest -m "integration" --maxfail=1

# Stress suite (opt-in).
test-stress:
	@cd backend && $(PYTHON) -m pytest -m "stress"

# Coverage report for fast local suites.
coverage:
	@cd backend && $(PYTHON) -m pytest -m "unit or api or regression" --cov=app --cov-config=.coveragerc --cov-report=term-missing --cov-report=xml
