.PHONY: help build rebuild serve run pull list clean logs \
        health config test info up down restart shell setup-dirs cache-clean

# ============================================
# VARIABLES
# ============================================

DOCKER := docker
COMPOSE := docker-compose
IMAGE_NAME := ramalama
IMAGE_TAG := latest
CONTAINER_NAME := ramalama
CONFIG_FILE := config/.env

# Environment variables for Variant B configuration
RAMALAMA_STORE := /workspace/models
HF_HOME := /workspace/cache
RAMALAMA_DATA_PATH := /workspace/data
RAMALAMA_LOG_PATH := /workspace/logs

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
NC := \033[0m

# ============================================
# HELP
# ============================================

help:
	@echo "$(GREEN)RamaLama Docker CLI$(NC)"
	@echo ""
	@echo "$(YELLOW)Build & Setup:$(NC)"
	@echo "  make setup-dirs       - Create required directories"
	@echo "  make build            - Build Docker image"
	@echo "  make rebuild          - Rebuild without cache"
	@echo "  make buildx           - Fast parallel build with buildx"
	@echo ""
	@echo "$(YELLOW)Run & Serve:$(NC)"
	@echo "  make up               - Start container in background"
	@echo "  make serve MODEL=... PORT=...  - Serve model (default: llama3.2:1b:8080)"
	@echo "  make run CMD=...      - Run command in container"
	@echo "  make shell            - Interactive bash shell"
	@echo ""
	@echo "$(YELLOW)Models:$(NC)"
	@echo "  make pull MODEL=...   - Pull model (e.g., tinyllama, llama3.2:1b)"
	@echo "  make list             - List available models"
	@echo "  make info             - Show RamaLama info"
	@echo ""
	@echo "$(YELLOW)Maintenance:$(NC)"
	@echo "  make logs             - Show container logs (tail -f)"
	@echo "  make health           - Check container health"
	@echo "  make cache-clean      - Clean HuggingFace cache only"
	@echo "  make down             - Stop and remove container"
	@echo "  make clean            - Clean up containers, images, volumes"
	@echo "  make config           - Show loaded config (.env)"
	@echo "  make test             - Quick sanity test"

# ============================================
# SETUP TARGETS
# ============================================

setup-dirs:
	@echo "$(GREEN)Creating required directories for Variant B...$(NC)"
	@mkdir -p models cache data logs
	@echo "$(GREEN)✓ Directories created: models/ cache/ data/ logs/$(NC)"

# ============================================
# BUILD TARGETS
# ============================================

build:
	@echo "$(GREEN)Building Docker image...$(NC)"
	docker buildx build \
		--file Dockerfile \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--load .
	@echo "$(GREEN)✓ Image built with buildx$(NC)"

rebuild:
	@echo "$(GREEN)Rebuilding Docker image (no cache)...$(NC)"
	docker buildx build \
		--file Dockerfile \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--no-cache \
		--load .
	@echo "$(GREEN)✓ Image rebuilt with buildx (no cache)$(NC)"

buildx:
	@echo "$(GREEN)Building with buildx...$(NC)"
	docker buildx build \
		--file Dockerfile \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--load .
	@echo "$(GREEN)✓ Image built with buildx$(NC)"

# ============================================
# RUN & SERVE TARGETS
# ============================================

up:
	@echo "$(GREEN)Starting container...$(NC)"
	$(COMPOSE) up -d
	@sleep 2
	@$(MAKE) health

down:
	@echo "$(YELLOW)Stopping container...$(NC)"
	$(COMPOSE) down

restart: down up

shell:
	@echo "$(GREEN)Opening interactive shell...$(NC)"
	$(COMPOSE) exec ramalama bash

run:
	@if [ -z "$(CMD)" ]; then \
		echo "$(RED)Error: CMD not specified$(NC)"; \
		echo "Usage: make run CMD='ramalama list'"; \
		exit 1; \
	fi
	@$(COMPOSE) exec ramalama $(CMD)

serve:
	@MODEL=$${MODEL:-llama3.2:1b}; \
PORT=$${PORT:-8080}; \
	echo "$(GREEN)Serving model: $$MODEL on port $$PORT$(NC)"; \
	$(MAKE) up; \
	sleep 2; \
	$(COMPOSE) exec ramalama ramalama serve $$MODEL --port $$PORT

# ============================================
# MODEL MANAGEMENT
# ============================================

pull:
	@if [ -z "$(MODEL)" ]; then \
		echo "$(RED)Error: MODEL not specified$(NC)"; \
		echo "Usage: make pull MODEL=tinyllama"; \
		exit 1; \
	fi
	@echo "$(GREEN)Pulling model: $(MODEL)$(NC)"
	$(COMPOSE) exec ramalama ramalama pull $(MODEL)

list:
	@echo "$(GREEN)Available models:$(NC)"
	$(COMPOSE) exec ramalama ramalama list

info:
	@echo "$(GREEN)RamaLama Info:$(NC)"
	$(COMPOSE) exec ramalama ramalama info

# ============================================
# LOGS & HEALTH
# ============================================

logs:
	$(COMPOSE) logs -f ramalama

health:
	@echo "$(GREEN)Checking container health...$(NC)"
	@if $(COMPOSE) exec ramalama curl -f http://localhost:8080/health 2>/dev/null; then \
		echo "$(GREEN)✓ Container is healthy$(NC)"; \
	else \
		echo "$(YELLOW)⚠ Container may not be ready yet$(NC)"; \
	fi

# ============================================
# CONFIG & TESTING
# ============================================

config:
	@echo "$(GREEN)Configuration from $(CONFIG_FILE):$(NC)"
	@if [ -f "$(CONFIG_FILE)" ]; then \
		cat "$(CONFIG_FILE)"; \
	else \
		echo "$(RED)Config file not found: $(CONFIG_FILE)$(NC)"; \
	fi

test:
	@echo "$(GREEN)Running sanity checks...$(NC)"
	@echo ""
	@echo "Checking Docker..."
	@$(DOCKER) --version
	@echo ""
	@echo "Checking docker-compose..."
	@$(COMPOSE) --version
	@echo ""
	@echo "Checking config..."
	@[ -f "$(CONFIG_FILE)" ] && echo "$(GREEN)✓ Config file exists$(NC)" || \
		echo "$(YELLOW)⚠ Config file missing (will use defaults)$(NC)"
	@echo ""
	@echo "$(GREEN)✓ Sanity checks passed$(NC)"

# ============================================
# CLEANUP
# ============================================

cache-clean:
	@echo "$(YELLOW)Cleaning HuggingFace cache...$(NC)"
	@if [ -d "cache" ]; then \
		rm -rf ./cache/*; \
		echo "$(GREEN)✓ Cache cleaned$(NC)"; \
	else \
		echo "$(YELLOW)Cache directory not found$(NC)"; \
	fi

clean:
	@echo "$(RED)Cleaning up Docker resources...$(NC)"
	$(COMPOSE) down -v
	$(DOCKER) rmi $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
	rm -rf ./logs ./cache ./data
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

.DEFAULT_GOAL := help
