# === Makefile Helper ===

# Styles
YELLOW=$(shell echo "\033[00;33m")
RED=$(shell echo "\033[00;31m")
RESTORE=$(shell echo "\033[0m")

# Variables
DOCKER_COMPOSE_ARGS := COMPOSE_PROJECT_NAME=my-crystallize-project COMPOSE_FILE=provisioning/dev/docker-compose.yaml
DOCKER_COMPOSE := $(DOCKER_COMPOSE_ARGS) docker compose
NPM := npm
CADDY = caddy
MKCERT = mkcert

.DEFAULT_GOAL := list

.PHONY: list
list:
	@echo "******************************"
	@echo "${YELLOW}Available targets${RESTORE}:"
	@grep -E '^[a-zA-Z-]+:.*?## .*$$' Makefile | sort | awk 'BEGIN {FS = ":.*?## "}; {printf " ${YELLOW}%-15s${RESTORE} > %s\n", $$1, $$2}'
	@echo "${RED}==============================${RESTORE}"

.PHONY: clean
clean: stop ## Clean non-essential files
	@rm -rf frontend/node_modules
	@rm -rf service-api/node_modules
	@$(DOCKER_COMPOSE) down
	
.PHONY: install
install: install-certificates ## Install
	@$(NPM) install
	@cd frontend && $(NPM) install && cd ..
	@cd service-api && cp .env.dist .env && cd ..
	@cd service-api && $(NPM) install && cd ..

.PHONY: install-certificates
install-certificates: ## Install the certificates
	@$(MKCERT) -install
	@cd provisioning/dev/certs && $(MKCERT) --cert-file domains.pem -key-file key.pem "frontend.domain.name" "service-api.domain.name"

.PHONY: serve-front
serve-front: ## Service the Frontend
	@cd frontend && $(NPM) run dev

.PHONY: serve-service-api
serve-service-api: ## Service the Service API
	@cd service-api && $(NPM) run dev

.PHONY: stop
stop: ## Stop all the local services you need
	-@$(DOCKER_COMPOSE) stop > /dev/null 2>&1
	-@$(CADDY) stop > /dev/null 2>&1

.PHONY: serve
serve: ## Run all the local services you need
	@$(DOCKER_COMPOSE) up -d
	@$(CADDY) start --config provisioning/dev/Caddyfile --pidfile provisioning/dev/caddy.dev.pid
	@$(MAKE) -j 2 serve-front serve-service-api
	
.PHONY: tests
tests: ## Run the tests
	@curl -s -I https://frontend.domain.name | grep "HTTP/2 200"
	@curl -s -I https://service-api.domain.name | grep "HTTP/2 200"
	

