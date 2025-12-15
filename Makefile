.PHONY: help build rebuild dev fast pull-llama up-cpu up-cuda down restart shell-rama shell-llama logs verify clean prune

DOCKER := docker
COMPOSE := docker compose
BUILDX := docker buildx
BAKE := docker buildx bake

IMAGE_NAME := ramalama
IMAGE_TAG := latest

CACHE_DIR := /tmp/.buildx-cache

# Load env
-include config/.env
export HTTP_PROXY HTTPS_PROXY NO_PROXY

# BuildKit optimizations
export BUILDKIT_INLINE_CACHE=1
export DOCKER_BUILDKIT=1
export BUILDX_BAKE_ENTITLEMENTS_FS=1
export BUILDX_EXPERIMENTAL=1

BUILDX_BUILDER_OPTS := --driver-opt=network=host \
	--driver-opt=image=moby/buildkit:latest

help:
	@echo "════════════════════════════════════════════════════"
	@echo "RamaLama + llama.cpp Microservices"
	@echo "════════════════════════════════════════════════════"
	@echo ""
	@echo "Usage:"
	@echo "  make cli cmd=\"command\"  → Example: make cli cmd=\"run tinyllama --port 8080\""
	@echo ""
	@echo "Build:"
	@echo "  make build         → Build ramalama (10-20s)"
	@echo "  make fast          → Ultra-fast ramalama (5-10s)"
	@echo "  make rebuild       → Clean rebuild"
	@echo "  make pull-llama    → Pull llama.cpp images"
	@echo ""
	@echo "Run:"
	@echo "  make up-cpu        → Start CPU stack"
	@echo "  make up-cuda       → Start CUDA stack"
	@echo "  make down          → Stop all"
	@echo "  make restart       → Restart"
	@echo ""
	@echo "Shell:"
	@echo "  make shell-rama    → RamaLama shell"
	@echo "  make shell-llama   → llama.cpp shell"
	@echo ""
	@echo "Utils:"
	@echo "  make logs          → All logs"
	@echo "  make check-logs    → Check logs"
	@echo "  make verify        → Test services"
	@echo "  make prune         → Clean cache"
	@echo "  make clean         → Full cleanup"


cli:
	@if [ -z "$(cmd)" ]; then \
		echo "Usage: make cli cmd=\"list\""; \
		echo "Example: make cli cmd=\"run tinyllama --port 8080\""; \
		exit 1; \
	fi
	@echo "Executing: cli $(cmd)"
	$(COMPOSE) exec ramalama ramalama $(cmd)


buildx-setup:
	@if ! $(BUILDX) ls | grep -q ramalama-builder; then \
		$(BUILDX) create --name ramalama-builder $(BUILDX_BUILDER_OPTS) --bootstrap; \
	fi
	@$(BUILDX) use ramalama-builder
	@$(DOCKER) pull python:3.11-slim-bookworm 2>/dev/null || true

# ============================================
# Build ramalama
# ============================================
build: buildx-setup
	@mkdir -p $(CACHE_DIR)/ramalama
	$(BAKE) -f docker-bake.hcl ramalama \
		--allow=fs.read=/tmp/.buildx-cache/ramalama \
		--allow=fs.write=/tmp/.buildx-cache \
		--set ramalama.args.HTTP_PROXY="$(HTTP_PROXY)" \
		--set ramalama.args.HTTPS_PROXY="$(HTTPS_PROXY)" \
		--set ramalama.args.NO_PROXY="$(NO_PROXY)"
	@$(MAKE) cache-rotate

fast: buildx-setup
	@echo "⚡ Ultra-fast ramalama build"
	$(BAKE) -f docker-bake.hcl ramalama-fast \
		--allow=fs.read=/tmp/.buildx-cache/ramalama \
		--allow=fs.write=/tmp/.buildx-cache \
		--set ramalama-fast.args.HTTP_PROXY="$(HTTP_PROXY)" \
		--set ramalama-fast.args.HTTPS_PROXY="$(HTTPS_PROXY)"

rebuild: buildx-setup
	@rm -rf $(CACHE_DIR)/ramalama $(CACHE_DIR)/ramalama-new
	@mkdir -p $(CACHE_DIR)/ramalama
	$(BAKE) -f docker-bake.hcl ramalama --no-cache \
		--allow=fs.read=/tmp/.buildx-cache/ramalama \
		--allow=fs.write=/tmp/.buildx-cache \
		--set ramalama.args.HTTP_PROXY="$(HTTP_PROXY)" \
		--set ramalama.args.HTTPS_PROXY="$(HTTPS_PROXY)" \
		--set ramalama.args.NO_PROXY="$(NO_PROXY)"
	@$(MAKE) cache-rotate

dev: buildx-setup
	$(BAKE) -f docker-bake.hcl ramalama-dev \
		--set ramalama-dev.args.HTTP_PROXY="$(HTTP_PROXY)" \
		--set ramalama-dev.args.HTTPS_PROXY="$(HTTPS_PROXY)"

# ============================================
# Pull llama.cpp
# ============================================
pull-llama:
	@echo "Pulling official llama.cpp images..."
	$(DOCKER) pull ghcr.io/ggml-org/llama.cpp:full
	$(DOCKER) pull ghcr.io/ggml-org/llama.cpp:full-cuda
	@echo "✓ llama.cpp images ready"

# ============================================
# Run services
# ============================================
up-cpu: build
	@mkdir -p models cache logs data config
	@echo "Starting CPU stack (ramalama + llama.cpp)..."
	$(COMPOSE) --profile cpu up -d
	@sleep 3
	@$(MAKE) verify

up-cuda: build
	@mkdir -p models cache logs data config
	@echo "Starting CUDA stack (ramalama + llama.cpp-cuda)..."
	$(COMPOSE) --profile cuda up -d
	@sleep 3
	@$(MAKE) verify

down:
	$(COMPOSE) --profile cpu --profile cuda down

restart: down up-cpu

restart-cuda: down up-cuda

# ============================================
# Shell access
# ============================================
shell-rama:
	$(COMPOSE) exec ramalama bash

shell-llama:
	@if $(COMPOSE) ps | grep -q llama-cpp-cuda; then \
		$(COMPOSE) exec llama-cpp-cuda bash; \
	else \
		$(COMPOSE) exec llama-cpp bash; \
	fi

logs:
	$(COMPOSE) --profile cpu --profile cuda logs -f

logs-rama:
	$(COMPOSE) logs -f ramalama

logs-llama:
	@if $(COMPOSE) ps | grep -q llama-cpp-cuda; then \
		$(COMPOSE) logs -f llama-cpp-cuda; \
	else \
		$(COMPOSE) logs -f llama-cpp; \
	fi

check-logs:
	@echo "Checking log directory permissions..."
	@ls -la ./logs/ 2>/dev/null || echo "Logs directory not found"
	@echo "Creating test log entry..."
	@$(COMPOSE) exec ramalama bash -c 'echo "$(date): Test log entry" >> /workspace/logs/ramalama.log'
	@echo "Checking log file..."
	@if [ -f "./logs/ramalama.log" ]; then \
		echo "✓ Logs are correctly mounted on host"; \
		tail -1 ./logs/ramalama.log; \
	else \
		echo "✗ Logs are NOT mounted on host"; \
	fi
# ============================================
# Verify
# ============================================
verify:
	@echo "════════════════════════════════════════"
	@echo "Verifying services..."
	@echo ""
	@echo "RamaLama image:"
	@$(DOCKER) images $(IMAGE_NAME):$(IMAGE_TAG) --format "  Size: {{.Size}}"
	@echo ""
	@echo "RamaLama health:"
	@$(COMPOSE) exec ramalama ramalama --version || echo "  ✗ Failed"
	@echo ""
	@echo "llama.cpp health:"
	@if $(COMPOSE) ps | grep -q llama-cpp-cuda; then \
		curl -sf http://localhost:8080/health || echo "  ✗ Not responding"; \
	elif $(COMPOSE) ps | grep -q llama-cpp; then \
		curl -sf http://localhost:8080/health || echo "  ✗ Not responding"; \
	else \
		echo "  ✗ Not running"; \
	fi
	@echo ""
	@echo "Network connectivity:"
	@$(COMPOSE) exec ramalama curl -sf http://llama-cpp:8080/health && echo "  ✓ ramalama → llama-cpp OK" || echo "  ✗ Failed"
	@echo "════════════════════════════════════════"

# ============================================
# Cleanup
# ============================================
prune:
	$(DOCKER) buildx prune -af
	rm -rf $(CACHE_DIR)/ramalama $(CACHE_DIR)/ramalama-new

clean: down
	@$(DOCKER) rmi $(IMAGE_NAME):$(IMAGE_TAG) $(IMAGE_NAME):dev 2>/dev/null || true
	@rm -rf $(CACHE_DIR)/ramalama $(CACHE_DIR)/ramalama-new

cache-rotate:
	@if [ -d "$(CACHE_DIR)/ramalama-new" ]; then \
		rm -rf $(CACHE_DIR)/ramalama; \
		mv $(CACHE_DIR)/ramalama-new $(CACHE_DIR)/ramalama; \
	fi

.DEFAULT_GOAL := help
