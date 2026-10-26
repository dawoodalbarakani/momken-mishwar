SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c

API_DIR := apps/api
ADMIN_DIR := apps/admin_web
RIDER_DIR := apps/rider_app
DRIVER_DIR := apps/driver_app
DOCKER_DIR := infrastructure/docker
DATABASE_DIR := database
DOCKER_COMPOSE_FILE := $(DOCKER_DIR)/docker-compose.yml

DATABASE_URL ?= postgres://mishwar:mishwar_dev_only@localhost:5432/mishwar
DATABASE_TEST_URL ?= postgres://mishwar:mishwar_test_only@localhost:5433/mishwar_test
FLUTTER ?= flutter
DC := docker compose -f $(DOCKER_COMPOSE_FILE)

HASH := \#
SEP := $(HASH)$(HASH)

.PHONY: help up down db\:up db\:down db\:restart db\:logs db\:status db\:migrate db\:seed db\:reset db\:test\:up api\:install api\:typecheck api\:build api\:start api\:start\:dev api\:test api\:test\:domain api\:test\:cov api\:prisma\:generate api\:prisma\:db-pull api\:prisma\:seed admin\:install admin\:typecheck admin\:build admin\:dev admin\:lint flutter\:doctor rider\:install rider\:analyze driver\:install driver\:analyze install typecheck test test\:domain test\:all lint env\:setup test\:ci ci

help: ## Show available make targets with descriptions
	@bash -c 'grep "$(SEP)" $(MAKEFILE_LIST) | awk -F" $(SEP)" '\''{t=$$1; gsub(/\\/,"",t); if (substr(t,length(t))==":") t=substr(t,1,length(t)-1); printf "\033[36m%-28s\033[0m %s\n", t, $$2}'\''' sh "$(MAKEFILE_LIST)"

# ---------------------------------------------------------------
# Convenience aliases
# ---------------------------------------------------------------

up: db\:up ## Start the database service
down: db\:down ## Stop the database and related services

# ---------------------------------------------------------------
# Database targets
# ---------------------------------------------------------------

db\:up: ## Start the postgres db service (port 5432)
	$(DC) up -d db

db\:down: ## Stop the database service
	$(DC) down

db\:restart: ## Restart the database service
	$(DC) restart db

db\:logs: ## Follow database service logs
	$(DC) logs -f db

db\:status: ## Show database service status
	$(DC) ps db

db\:migrate: ## Apply Prisma migrations to the database
	cd $(API_DIR) && DATABASE_URL=$(DATABASE_URL) pnpm prisma migrate dev --schema=src/prisma/schema.prisma --url=$(DATABASE_URL) -n auto

db\:seed: ## Seed reference data into the database
	psql "$(DATABASE_URL)" -v ON_ERROR_STOP=1 -f database/seeds/001_reference_data.sql

db\:reset: db\:down db\:up db\:migrate db\:seed ## Reset database: down, up, migrate, seed

db\:test\:up: ## Start the test database service (port 5433)
	$(DC) up -d db_test

# ---------------------------------------------------------------
# API targets (NestJS)
# ---------------------------------------------------------------

api\:install: ## Install API dependencies
	cd $(API_DIR) && pnpm install

api\:typecheck: ## Run API typecheck
	cd $(API_DIR) && pnpm run typecheck

api\:build: ## Build the API
	cd $(API_DIR) && pnpm run build

api\:start: ## Start the API (production)
	cd $(API_DIR) && pnpm run start

api\:start\:dev: ## Start the API in watch mode
	cd $(API_DIR) && pnpm run start:dev

api\:test: ## Run API tests (vitest run)
	cd $(API_DIR) && pnpm run test

api\:test\:domain: ## Run API domain tests
	cd $(API_DIR) && pnpm run test:domain

api\:test\:cov: ## Run API tests with coverage
	cd $(API_DIR) && pnpm run test:cov

api\:prisma\:generate: ## Generate Prisma client for the API
	cd $(API_DIR) && pnpm run prisma:generate

api\:prisma\:db-pull: ## Pull Prisma schema from the database
	cd $(API_DIR) && pnpm run prisma:db-pull

api\:prisma\:seed: ## Seed the API database via Prisma
	cd $(API_DIR) && pnpm run prisma:seed

# ---------------------------------------------------------------
# Admin targets (Next.js)
# ---------------------------------------------------------------

admin\:install: ## Install admin web dependencies
	cd $(ADMIN_DIR) && npm install

admin\:typecheck: ## Run admin web typecheck
	cd $(ADMIN_DIR) && npm run typecheck

admin\:build: ## Build the admin web app
	cd $(ADMIN_DIR) && npm run build

admin\:dev: ## Start the admin web dev server
	cd $(ADMIN_DIR) && npm run dev

admin\:lint: ## Lint the admin web app
	cd $(ADMIN_DIR) && npm run lint

# ---------------------------------------------------------------
# Flutter targets (rider / driver apps)
# NOTE: Flutter SDK is NOT available on the host.
# ---------------------------------------------------------------

flutter\:doctor: ## Check Flutter SDK installation
	@if command -v $(FLUTTER) >/dev/null 2>&1; then $(FLUTTER) doctor; else echo "Flutter SDK not found on host. Install Flutter SDK to run Flutter targets."; fi

rider\:install: ## Install rider app Flutter dependencies
	cd $(RIDER_DIR) && $(FLUTTER) pub get

rider\:analyze: ## Analyze rider app Flutter code
	cd $(RIDER_DIR) && $(FLUTTER) analyze

driver\:install: ## Install driver app Flutter dependencies
	cd $(DRIVER_DIR) && $(FLUTTER) pub get

driver\:analyze: ## Analyze driver app Flutter code
	cd $(DRIVER_DIR) && $(FLUTTER) analyze

# ---------------------------------------------------------------
# Root targets
# ---------------------------------------------------------------

install: api\:install admin\:install ## Install all workspace dependencies

typecheck: api\:typecheck admin\:typecheck ## Typecheck all projects

test: api\:test ## Run all tests

test\:domain: api\:test\:domain ## Run domain tests

test\:all: api\:test\:cov ## Run all tests with coverage

lint: admin\:lint ## Run lint checks

clean: ## Clean build artifacts and dependencies
	rm -rf node_modules
	rm -rf $(API_DIR)/node_modules $(API_DIR)/dist $(API_DIR)/.turbo
	rm -rf $(ADMIN_DIR)/node_modules $(ADMIN_DIR)/.next $(ADMIN_DIR)/out $(ADMIN_DIR)/dist

env\:setup: ## Copy .env.example to .env if .env does not exist
	@if [ ! -f .env ]; then cp .env.example .env; echo ".env created from .env.example"; else echo ".env already exists"; fi

# ---------------------------------------------------------------
# CI targets
# ---------------------------------------------------------------

test\:ci: db\:test\:up test ## Run tests against the test database

ci: db\:test\:up typecheck test ## Run full CI pipeline: test db, typecheck, tests

