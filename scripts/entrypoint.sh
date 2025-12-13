#!/bin/bash

set -euo pipefail

# ============================================
# INITIALIZATION & LOGGING
# ============================================

log_info() {
    echo "ℹ️  $*"
}

log_success() {
    echo "✅ $*"
}

log_error() {
    echo "❌ $*" >&2
}

log_header() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$*"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ============================================
# CONFIGURATION SETUP
# ============================================

log_header "🚀 RamaLama Docker Environment"

# Proxy configuration
if [ -n "${HTTP_PROXY:-}" ]; then
    export http_proxy="${HTTP_PROXY}"
    export https_proxy="${HTTPS_PROXY:-${HTTP_PROXY}}"
    log_info "Proxy: ${HTTP_PROXY}"
else
    log_info "Proxy: none"
fi

# Disable unused proxy vars
export PYTHONWARNINGS="ignore"
unset ftp_proxy FTP_PROXY all_proxy ALL_PROXY 2>/dev/null || true

# Unified paths (all in /workspace)
export RAMALAMA_MODELS_PATH="${RAMALAMA_MODELS_PATH:-/workspace/models}"
export RAMALAMA_DATA_PATH="${RAMALAMA_DATA_PATH:-/workspace/data}"
export RAMALAMA_LOG_FILE="${RAMALAMA_LOG_FILE:-/workspace/logs/ramalama.log}"
export RAMALAMA_LOG_LEVEL="${RAMALAMA_LOG_LEVEL:-ERROR}"
export RAMALAMA_ENGINE="${RAMALAMA_ENGINE:-llama.cpp}"

log_info "Models path: $RAMALAMA_MODELS_PATH"
log_info "Data path: $RAMALAMA_DATA_PATH"
log_info "Log file: $RAMALAMA_LOG_FILE"
log_info "Engine: $RAMALAMA_ENGINE"

# ============================================
# WORKSPACE DIRECTORY SETUP
# ============================================

WORKSPACE_DIR="/workspace"

# Create necessary directories (relative to /workspace)
mkdir -p \
    "$WORKSPACE_DIR/models" \
    "$WORKSPACE_DIR/logs" \
    "$WORKSPACE_DIR/data" \
    "$WORKSPACE_DIR/cache" \
    "$WORKSPACE_DIR/config" \
    "$WORKSPACE_DIR/tmp"

# Ensure proper permissions (user ramalama should own these)
chmod 755 "$WORKSPACE_DIR"/{models,logs,data,cache,config,tmp}

log_success "Workspace directories ready:"
echo "   📁 Models:  $WORKSPACE_DIR/models"
echo "   📁 Logs:    $WORKSPACE_DIR/logs"
echo "   📁 Data:    $WORKSPACE_DIR/data"
echo "   📁 Cache:   $WORKSPACE_DIR/cache"

log_header "📦 Existing Models"

# List existing models
model_files=$(find "$RAMALAMA_MODELS_PATH" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | head -10 || true)

if [ -n "$model_files" ]; then
    model_count=0
    total_size=0
    
    echo "$model_files" | while IFS= read -r model; do
        if [ -n "$model" ]; then
            size=$(du -h "$model" 2>/dev/null | cut -f1 || echo "?")
            echo " 📦 $(basename "$model") ($size)"
            ((model_count++)) || true
        fi
    done
    
    model_count=$(echo "$model_files" | wc -l)
    echo ""
    echo "Total: $model_count model(s)"
else
    log_info "No models found in $RAMALAMA_MODELS_PATH"
fi

# ============================================
# COMMAND ROUTING
# ============================================

# Wait mode for docker-compose
if [[ "${1:-}" == "tail" && "${2:-}" == "-f" ]]; then
    log_success "Container ready! Waiting for commands..."
    echo ""
    log_info "Use these commands:"
    echo " docker-compose exec ramalama ramalama info"
    echo " docker-compose exec ramalama ramalama pull tinyllama"
    echo " docker-compose exec ramalama ramalama list"
    echo ""
    exec tail -f /dev/null
fi

# llama-server mode
if [[ "${1:-}" == "llama-server" ]]; then
    log_info "Executing: llama-server with args: ${@:2}"
    echo ""
    exec /usr/local/bin/llama-server "${@:2}"
fi

# RamaLama command (default)
log_info "Executing: ramalama $@"
echo ""

# Execute with proxy log filtering
exec ramalama "$@" 2>&1 | grep -v "INFO:ramalama:Using proxy" || true
