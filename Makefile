# Project automation helpers.
SHELL := /bin/bash

ENV_FILE := .env
INSTALLER := installer/install.sh

.PHONY: up down logs reset update

# Starts/bootstraps the full stack and auto-generates secrets if needed.
up:
	@bash $(INSTALLER) --skip-clone --target-dir .

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
