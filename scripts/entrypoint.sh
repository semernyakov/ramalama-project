#!/bin/bash
set -euo pipefail

# ============================================
# LOGGING
# ============================================
log_info()    { echo "ℹ️  $*"; }
log_success() { echo "✅ $*"; }
log_error()   { echo "❌ $*" >&2; }
log_header() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "$*"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

log_header "🚀 RamaLama Docker Environment"

# ============================================
# PROXY
# ============================================
if [ -n "${HTTP_PROXY:-}" ]; then
    export http_proxy="$HTTP_PROXY"
    export https_proxy="${HTTPS_PROXY:-$HTTP_PROXY}"
    log_info "Proxy: $HTTP_PROXY"
else
    log_info "Proxy: none"
fi

unset ftp_proxy FTP_PROXY all_proxy ALL_PROXY 2>/dev/null || true
export PYTHONWARNINGS="ignore"

# ============================================
# PATHS / ENV
# ============================================
WORKSPACE_DIR="/workspace"

export RAMALAMA_STORE="${RAMALAMA_STORE:-$WORKSPACE_DIR/models}"
export RAMALAMA_MODELS_PATH="$RAMALAMA_STORE"
export RAMALAMA_DATA_PATH="${RAMALAMA_DATA_PATH:-$WORKSPACE_DIR/data}"
export RAMALAMA_LOG_FILE="${RAMALAMA_LOG_FILE:-$WORKSPACE_DIR/logs/ramalama.log}"
export RAMALAMA_LOG_LEVEL="${RAMALAMA_LOG_LEVEL:-ERROR}"
export RAMALAMA_ENGINE="${RAMALAMA_ENGINE:-llama.cpp}"

log_info "Models path: $RAMALAMA_MODELS_PATH"
log_info "Data path:   $RAMALAMA_DATA_PATH"
log_info "Log file:    $RAMALAMA_LOG_FILE"
log_info "Engine:      $RAMALAMA_ENGINE"

# ============================================
# DIRECTORIES
# ============================================
mkdir -p \
    "$WORKSPACE_DIR"/{models,logs,data,cache,config,tmp}

chmod 755 "$WORKSPACE_DIR"/{models,logs,data,cache,config,tmp}

if [ "$(id -u)" -eq 0 ] && id ramalama &>/dev/null; then
    chown -R ramalama:ramalama "$WORKSPACE_DIR"
fi

log_success "Workspace ready"

# ============================================
# MODELS LIST
# ============================================
log_header "📦 Existing Models"

mapfile -t model_files < <(
  find "$RAMALAMA_MODELS_PATH" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | head -10
)

if [ "${#model_files[@]}" -gt 0 ]; then
    for model in "${model_files[@]}"; do
        size=$(du -h "$model" 2>/dev/null | cut -f1 || echo "?")
        echo " 📦 $(basename "$model") ($size)"
    done
    echo ""
    echo "Total: ${#model_files[@]} model(s)"
else
    log_info "No models found"
fi

# ============================================
# COMMAND ROUTING
# ============================================

if [[ "${1:-}" == "tail" && "${2:-}" == "-f" ]]; then
    log_success "Container ready — idle mode"
    exec tail -f /dev/null
fi

if [[ "${1:-}" == "llama-server" ]]; then
    exec /usr/local/bin/llama-server "${@:2}"
fi

log_info "Executing: ramalama $*"
ramalama "$@" 2>&1 | sed '/INFO:ramalama:Using proxy/d'
exit ${PIPESTATUS[0]}
