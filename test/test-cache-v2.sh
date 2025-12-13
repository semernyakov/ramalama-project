#!/bin/bash

# ============================================
# RamaLama Cache System Test (Variant B)
# Тесты системы кеширования (Variant B)
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
log_section() { echo -e "${BLUE}$1${NC}"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# ============================================
# НАЧАЛО ТЕСТИРОВАНИЯ
# ============================================

echo ""
log_section "🔍 ПРОВЕРКА СИСТЕМЫ КЕШИРОВАНИЯ (Variant B)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Счетчики
CHECKS_PASSED=0
CHECKS_FAILED=0

# ============================================
# 1. ПРОВЕРКА ФИЗИЧЕСКОЙ СТРУКТУРЫ
# ============================================

log_section "1️⃣  ФИЗИЧЕСКАЯ СТРУКТУРА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# cache/ директория
if [ -d "cache" ]; then
    cache_size=$(du -sh cache 2>/dev/null | cut -f1)
    file_count=$(find cache -type f 2>/dev/null | wc -l)
    log_success "cache/ существует (размер: $cache_size, файлов: $file_count)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "cache/ не найдена"
    log_info "Создаю cache/ директорию..."
    mkdir -p cache
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

# logs/ директория
if [ -d "logs" ]; then
    logs_size=$(du -sh logs 2>/dev/null | cut -f1)
    log_success "logs/ существует (размер: $logs_size)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "logs/ не найдена"
    mkdir -p logs
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

# data/ директория
if [ -d "data" ]; then
    data_size=$(du -sh data 2>/dev/null | cut -f1)
    log_success "data/ существует (размер: $data_size)"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
else
    log_error "data/ не найдена"
    mkdir -p data
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

echo ""

# ============================================
# 2. ПРОВЕРКА КОНФИГУРАЦИИ
# ============================================

log_section "2️⃣  КОНФИГУРАЦИЯ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# docker-compose.yml - проверка монтирований
if [ -f "docker-compose.yml" ]; then
    log_success "docker-compose.yml существует"
    
    # Проверка cache - в Variant B cache остается внутри контейнера
    if grep -q "# Cache stays inside container" docker-compose.yml; then
        log_success "cache правильно настроен внутри контейнера (Variant B)"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    elif grep -q "cache:" docker-compose.yml; then
        log_warning "cache монтирование найдено (не соответствует Variant B)"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    else
        log_success "cache остается внутри контейнера (Variant B архитектура)"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    fi
    
    # Проверка logs монтирования
    if grep -q "logs" docker-compose.yml; then
        log_success "logs монтирование настроено в docker-compose.yml"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_warning "logs монтирование не найдено в docker-compose.yml"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
    
    # Проверка data монтирования
    if grep -q "data" docker-compose.yml; then
        log_success "data монтирование настроено в docker-compose.yml"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_warning "data монтирование не найдено в docker-compose.yml"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
else
    log_error "docker-compose.yml не найден"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
fi

echo ""

# ============================================
# 3. ПРОВЕРКА ПЕРЕМЕННЫХ ОКРУЖЕНИЯ
# ============================================

log_section "3️⃣  ПЕРЕМЕННЫЕ ОКРУЖЕНИЯ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# config/.env
if [ -f "config/.env" ]; then
    log_success "config/.env существует"
    
    # Проверка переменных
    if grep -q "HF_HUB" config/.env; then
        log_success "HF_HUB переменные настроены"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_info "HF_HUB переменные не настроены (это нормально)"
    fi
    
    if grep -q "CACHE" config/.env; then
        log_success "CACHE переменные настроены"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_info "CACHE переменные не явно настроены"
    fi
else
    log_warning "config/.env не найден (используется env.example?)"
    if [ -f "config/env.example" ]; then
        log_info "Используется config/env.example"
        log_info "Создайте config/.env из примера:"
        log_info "  cp config/env.example config/.env"
    fi
fi

echo ""

# ============================================
# 4. ПРОВЕРКА DOCKER МОНТИРОВАНИЯ
# ============================================

log_section "4️⃣  DOCKER МОНТИРОВАНИЕ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Проверяем доступность Docker
if ! command -v docker &> /dev/null; then
    log_warning "Docker не установлен"
    echo ""
else
    # Проверяем docker-compose конфигурацию
    if docker-compose config > /dev/null 2>&1; then
        log_success "docker-compose конфигурация валидна"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
        
        # Если контейнер запущен - проверяем монтирования внутри
        if docker-compose ps 2>/dev/null | grep -q ramalama; then
            log_info "Контейнер запущен - проверяю монтирования внутри..."
            
            # Проверка cache в контейнере (должен быть внутри)
            if docker-compose exec -T ramalama test -d /workspace/cache 2>/dev/null; then
                log_success "cache доступен в контейнере (/workspace/cache)"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_warning "cache не найден в контейнере"
                CHECKS_FAILED=$((CHECKS_FAILED + 1))
            fi
            
            # Проверка logs в контейнере
            if docker-compose exec -T ramalama test -d /workspace/logs 2>/dev/null; then
                log_success "logs монтирован в контейнере (/workspace/logs)"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_error "logs не монтирован в контейнере"
                CHECKS_FAILED=$((CHECKS_FAILED + 1))
            fi
            
            # Проверка data в контейнере
            if docker-compose exec -T ramalama test -d /workspace/data 2>/dev/null; then
                log_success "data монтирован в контейнере (/workspace/data)"
                CHECKS_PASSED=$((CHECKS_PASSED + 1))
            else
                log_error "data не монтирован в контейнере"
                CHECKS_FAILED=$((CHECKS_FAILED + 1))
            fi
        else
            log_info "Контейнер не запущен"
            log_info "Запустите: docker-compose up -d"
            log_info "Тогда все монтирования будут проверены"
        fi
    else
        log_error "docker-compose конфигурация невалидна"
        CHECKS_FAILED=$((CHECKS_FAILED + 1))
    fi
fi

echo ""

# ============================================
# 5. ПРОВЕРКА ПРАВ ДОСТУПА
# ============================================

log_section "5️⃣  ПРАВА ДОСТУПА"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Проверка прав на директориях
for dir in cache logs data models backups; do
    if [ -d "$dir" ]; then
        # Проверяем, что директория доступна для записи
        if [ -w "$dir" ]; then
            log_success "$dir доступна для записи"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
        else
            log_error "$dir не доступна для записи"
            log_info "Исправляю права: chmod 755 $dir"
            chmod 755 "$dir" 2>/dev/null || true
            CHECKS_FAILED=$((CHECKS_FAILED + 1))
        fi
    fi
done

echo ""

# ============================================
# 6. СТАТИСТИКА ИСПОЛЬЗОВАНИЯ
# ============================================

log_section "6️⃣  СТАТИСТИКА ИСПОЛЬЗОВАНИЯ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Использование диска
total_size=0
for dir in cache logs data models backups; do
    if [ -d "$dir" ]; then
        size=$(du -sb "$dir" 2>/dev/null | cut -f1)
        if [ -n "$size" ] && [ "$size" -gt 0 ]; then
            size_human=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size} bytes")
            echo "  $dir: $size_human"
            total_size=$((total_size + size))
        fi
    fi
done

if [ $total_size -gt 0 ]; then
    total_human=$(numfmt --to=iec-i --suffix=B "$total_size" 2>/dev/null || echo "${total_size} bytes")
    log_success "Общее использование: $total_human"
else
    log_info "Все директории пусты (это нормально для новой установки)"
fi

echo ""

# ============================================
# 7. РЕКОМЕНДАЦИИ
# ============================================

log_section "7️⃣  РЕКОМЕНДАЦИИ"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "📋 Структура Variant B:"
echo "  ✓ models/  - На хосте (персистентно, бэкапируется)"
echo "  ✓ backups/ - Архивы на хосте (бэкапируется)"
echo "  ✓ logs/    - В контейнере (временное)"
echo "  ✓ cache/   - В контейнере (временное)"
echo "  ✓ data/    - В контейнере (временное)"
echo ""

echo "💡 Советы по кешированию:"
echo "  • HuggingFace автоматически использует ./cache"
echo "  • Models кешируются в models/store/"
echo "  • PIP кеширование отключено (экономия места)"
echo "  • Временные файлы удаляются при перезагрузке"
echo ""

echo "🔧 Для оптимизации:"
echo "  • Проверяйте размер cache: du -sh cache/"
echo "  • Очищайте старые логи: ./scripts/log-manager.sh clean"
echo "  • Бэкапируйте модели: make backup"
echo "  • Мониторьте диск: ./scripts/monitor.sh -s"
echo ""

# ============================================
# ИТОГИ
# ============================================

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ РЕЗУЛЬТАТЫ ПРОВЕРКИ КЕШИРОВАНИЯ          ║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC} ${GREEN}Проверено:${NC}  %-3d${BLUE}                              ║${NC}\n" $CHECKS_PASSED
printf "${BLUE}║${NC} ${RED}Проблем:${NC}    %-3d${BLUE}                              ║${NC}\n" $CHECKS_FAILED
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

echo ""

if [ $CHECKS_FAILED -eq 0 ]; then
    log_success "Система кеширования готова к работе!"
    echo ""
    echo "Следующие шаги:"
    echo "  • Запустите контейнер: make up"
    echo "  • Загрузите модель: make pull MODEL=tinyllama"
    echo "  • Проверьте cache: du -sh cache/"
    echo ""
    exit 0
else
    log_warning "Обнаружены проблемы с кешированием"
    echo ""
    echo "Для решения:"
    echo "  • Проверьте docker-compose.yml монтирования"
    echo "  • Проверьте права доступа: chmod 755 cache logs data"
    echo "  • Перезагрузите контейнер: make restart"
    echo ""
    exit 1
fi
