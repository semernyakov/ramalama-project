#!/bin/bash

# ============================================
# RamaLama Model Storage Check (Variant B)
# Проверка хранения моделей в Variant B
# ============================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции
log_header() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

format_size() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1 bytes"
}

# Основная проверка
main() {
    log_header "🔍 RamaLama Model Storage Check (Variant B)"
    
    # 1. Проверка структуры
    log_header "1️⃣  Directory Structure"
    
    local models_on_host=0
    if [ -d "models" ]; then
        models_on_host=$(find models -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l || echo 0)
        local models_size=$(du -sb models 2>/dev/null | cut -f1 || echo 0)
        log_success "Host storage: ./models"
        log_info "  Models: $models_on_host"
        log_info "  Size: $(format_size "$models_size")"
    else
        log_error "Host storage not found: ./models"
        mkdir -p models
        log_info "Created directory: ./models"
    fi
    
    # 2. Проверка docker-compose.yml
    log_header "2️⃣  Docker Compose Configuration"
    
    if grep -q "/workspace/models" docker-compose.yml 2>/dev/null; then
        log_success "Correct Variant B configuration detected"
        log_info "Mount: ./models:/workspace/models (RW)"
    else
        log_warning "Config may need update"
        log_info "Expected: ./models:/workspace/models:rw"
    fi
    
    # 3. Проверка контейнера
    log_header "3️⃣  Container Status"
    
    if docker ps | grep -q ramalama; then
        log_success "Container is running"
        
        local models_in_container=0
        if docker exec ramalama test -d /workspace/models 2>/dev/null; then
            models_in_container=$(docker exec ramalama find /workspace/models -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l || echo 0)
            log_info "Models in container: $models_in_container"
            
            if [ "$models_on_host" -eq "$models_in_container" ]; then
                log_success "Mount synchronization: OK"
            else
                log_warning "Model count mismatch"
                log_info "  Host: $models_on_host"
                log_info "  Container: $models_in_container"
            fi
        else
            log_warning "/workspace/models not accessible in container"
        fi
    else
        log_info "Container not running"
        log_info "Start with: make up"
    fi
    
    # 4. Перечисление моделей
    log_header "4️⃣  Available Models"
    
    if [ $models_on_host -gt 0 ]; then
        echo "Models on host:"
        find models -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | sort | while read model; do
            local size=$(stat -c%s "$model" 2>/dev/null || stat -f%z "$model" 2>/dev/null || echo 0)
            echo -e "  📦 $(basename "$model") - $(format_size "$size")"
        done
    else
        log_info "No models found"
        log_info "Download with: make pull MODEL=tinyllama"
    fi
    
    # 5. Проверка RamaLama info
    log_header "5️⃣  RamaLama Configuration"
    
    if docker ps | grep -q ramalama; then
        local store_path=$(docker exec ramalama ramalama info 2>/dev/null | grep -i "store" | head -1 || echo "unknown")
        log_info "RamaLama config: $store_path"
    else
        log_info "Container not running - skip ramalama info"
    fi
    
    # 6. Тест целостности
    log_header "6️⃣  Integration Test"
    
    local test_file="models/test-$(date +%s).txt"
    echo "Variant B test - $(date)" > "$test_file"
    
    if [ -f "$test_file" ]; then
        log_success "File created on host: $(basename "$test_file")"
        
        if docker ps | grep -q ramalama; then
            local container_test="/workspace/models/$(basename "$test_file")"
            if docker exec ramalama test -f "$container_test" 2>/dev/null; then
                log_success "File visible in container"
                log_success "Mount synchronization: WORKING"
            else
                log_error "File NOT visible in container"
                log_warning "Mount issue detected"
            fi
        fi
        
        rm -f "$test_file"
        log_info "Test file removed"
    else
        log_error "Could not create test file"
    fi
    
    # 7. Рекомендации
    log_header "✅ Summary"
    
    echo ""
    echo "Variant B Architecture:"
    echo "  ✓ Models persisted on host (./models)"
    echo "  ✓ Logs local in container (./logs)"
    echo "  ✓ Data local in container (./data)"
    echo "  ✓ Cache local in container (./cache)"
    echo ""
    
    if [ $models_on_host -eq 0 ]; then
        echo -e "${YELLOW}No models found. Next steps:${NC}"
        echo "  1. make pull MODEL=tinyllama"
        echo "  2. Check with: ls -lh models/"
        echo "  3. make serve MODEL=tinyllama PORT=8080"
    else
        echo -e "${GREEN}Models ready. You can:${NC}"
        echo "  1. make serve MODEL=<name> PORT=8080"
        echo "  2. make run MODEL=<name>"
        echo "  3. make shell"
    fi
    echo ""
}

main "$@"
