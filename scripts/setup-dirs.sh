#!/bin/bash

# ============================================
# RamaLama Workspace Directory Setup
# Вариант Б: Единая архитектура /workspace
# ============================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции логирования
log_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Основная проверка
main() {
    log_header "🔧 RamaLama Workspace Structure Check"
    echo ""

    # 1. Проверка и создание основных директорий
    log_header "Step 1: Creating Workspace Structure"
    
    local dirs=("models" "logs" "data" "cache" "config")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            log_success "Created: $dir/"
        else
            log_info "Exists: $dir/"
        fi
    done
    echo ""

    # 2. Проверка конфигурации
    log_header "Step 2: Checking Configuration"
    
    if [ -f "config/.env" ]; then
        log_success "Config found: config/.env"
        log_info "$(wc -l < config/.env) configuration lines"
    else
        log_warning "Config file not found: config/.env"
        log_info "Will use Docker environment defaults"
    fi
    echo ""

    # 3. Проверка структуры на хосте
    log_header "Step 3: Host Storage Status"
    
    check_directory() {
        local dir=$1
        local emoji=$2
        if [ -d "$dir" ]; then
            local count=$(find "$dir" -type f 2>/dev/null | wc -l)
            local size=$(du -sh "$dir" 2>/dev/null | cut -f1)
            echo -e " ${GREEN}✓${NC} $emoji $dir/ - $count files ($size)"
        else
            echo -e " ${RED}✗${NC} $emoji $dir/ - not found"
        fi
    }
    
    check_directory "models" "📦"
    check_directory "logs" "📋"
    check_directory "data" "📁"
    check_directory "cache" "⚡"
    check_directory "config" "⚙"
    echo ""

    # 4. Проверка Docker образа
    log_header "Step 4: Docker Image Status"
    
    if docker images | grep -q "ramalama"; then
        local image_size=$(docker image inspect ramalama:latest --format='{{.Size}}' 2>/dev/null)
        log_success "Docker image found: ramalama:latest"
        log_info "Image size: $(numfmt --to=iec-i --suffix=B $image_size 2>/dev/null || echo 'Unknown')"
    else
        log_warning "Docker image not built yet"
        log_info "Run: make buildx"
    fi
    echo ""

    # 5. Проверка монтирований
    log_header "Step 5: Volume Mounts Check"
    
    if docker ps | grep -q ramalama; then
        log_success "Container is running: ramalama"
        
        log_info "Checking volume bindings..."
        docker inspect ramalama --format='{{range .Mounts}}{{.Source}} → {{.Destination}} ({{.Mode}}){{println}}{{end}}' 2>/dev/null || \
            log_warning "Could not read mount points"
    else
        log_info "Container is not running (this is normal)"
        log_info "Start with: make up"
    fi
    echo ""

    # 6. Проверка размера данных
    log_header "Step 6: Storage Usage"
    
    local total_size=0
    [ -d "models" ] && total_size=$(( $total_size + $(du -sb models 2>/dev/null | cut -f1) ))
    [ -d "logs" ] && total_size=$(( $total_size + $(du -sb logs 2>/dev/null | cut -f1) ))
    [ -d "data" ] && total_size=$(( $total_size + $(du -sb data 2>/dev/null | cut -f1) ))
    [ -d "cache" ] && total_size=$(( $total_size + $(du -sb cache 2>/dev/null | cut -f1) ))
    
    log_info "Total workspace size: $(numfmt --to=iec-i --suffix=B $total_size 2>/dev/null || echo "${total_size} bytes")"
    echo ""

    # 7. Рекомендации
    log_header "Recommendations"
    
    echo ""
    echo "✓ Workspace structure is ready for Variant B (models on host only)"
    echo ""
    echo "Directory mapping:"
    echo "  ./models         → Container:/workspace/models  (RW - persisted)"
    echo "  ./logs           → Local only                  (Not persisted)"
    echo "  ./data           → Local only                  (Not persisted)"
    echo "  ./cache          → Local only                  (Not persisted)"
    echo "  ./config         → Container:/workspace/config (RO)"
    echo ""
    echo "Next steps:"
    echo "  1. Build: make buildx"
    echo "  2. Start: make up"
    echo "  3. Pull model: make pull MODEL=tinyllama"
    echo "  4. Serve: make serve MODEL=tinyllama PORT=8080"
    echo ""
}

main "$@"
