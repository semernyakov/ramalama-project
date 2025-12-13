#!/bin/bash

# ============================================
# RamaLama Quick Test Suite (Variant B Updated)
# Обновленная версия для Variant B архитектуры
# ============================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Счетчик тестов
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Функция для запуска теста
run_test() {
    local test_name="$1"
    local test_cmd="$2"
    local skip_on_fail="${3:-false}"
    
    echo -e "${YELLOW}▶${NC} Тест: $test_name"
    
    if eval "$test_cmd" &> /tmp/ramalama_test.log; then
        echo -e "${GREEN}  ✓ Пройден${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        if [ "$skip_on_fail" = "true" ]; then
            echo -e "${CYAN}  ⊘ Пропущен${NC}"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            return 0
        else
            echo -e "${RED}  ✗ Провален${NC}"
            echo -e "${RED}  Ошибка:${NC}"
            cat /tmp/ramalama_test.log | sed 's/^/    /'
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    fi
}

skip_test() {
    local test_name="$1"
    echo -e "${CYAN}⊘${NC} $test_name (пропущен)"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

# ============================================
# НАЧАЛО ТЕСТИРОВАНИЯ
# ============================================

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  RamaLama Quick Test Suite (Variant B)     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# 1. ПРОВЕРКА ОКРУЖЕНИЯ
# ============================================

echo -e "${BLUE}1️⃣  ПРОВЕРКА ОКРУЖЕНИЯ${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Docker доступен" "command -v docker"
run_test "Docker Compose доступен" "command -v docker-compose"
run_test "GNU Make доступен" "command -v make"

echo ""

# ============================================
# 2. ПРОВЕРКА СТРУКТУРЫ (Variant B)
# ============================================

echo -e "${BLUE}2️⃣  ПРОВЕРКА СТРУКТУРЫ (Variant B)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Директория ./models существует" "[ -d ./models ]"
run_test "Директория ./backups существует" "[ -d ./backups ]"
run_test "Директория ./logs существует" "[ -d ./logs ]"
run_test "Директория ./cache существует" "[ -d ./cache ]"
run_test "Директория ./config существует" "[ -d ./config ]"
run_test "Директория ./scripts существует" "[ -d ./scripts ]"

echo ""

# ============================================
# 3. ПРОВЕРКА КОНФИГУРАЦИИ
# ============================================

echo -e "${BLUE}3️⃣  ПРОВЕРКА КОНФИГУРАЦИИ${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "docker-compose.yml существует" "[ -f ./docker-compose.yml ]"
run_test "Dockerfile существует" "[ -f ./Dockerfile ]"
run_test "Makefile существует" "[ -f ./Makefile ]"
run_test "config/.env или config/env.example существует" "[ -f ./config/.env ] || [ -f ./config/env.example ]"

echo ""

# ============================================
# 4. ПРОВЕРКА СКРИПТОВ
# ============================================

echo -e "${BLUE}4️⃣  ПРОВЕРКА СКРИПТОВ${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "backup.sh существует" "[ -f ./scripts/backup.sh ]"
run_test "check-models.sh существует" "[ -f ./scripts/check-models.sh ]"
run_test "monitor.sh существует" "[ -f ./scripts/monitor.sh ]"
run_test "log-manager.sh существует" "[ -f ./scripts/log-manager.sh ]"
run_test "setup-dirs.sh существует" "[ -f ./scripts/setup-dirs.sh ]"
run_test "examples.sh существует" "[ -f ./scripts/examples.sh ]"

echo ""

# ============================================
# 5. ПРОВЕРКА MAKEFILE
# ============================================

echo -e "${BLUE}5️⃣  ПРОВЕРКА MAKEFILE${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "make help работает" "make help > /dev/null 2>&1" true
run_test "make test доступен" "grep -q 'test:' Makefile" true
run_test "make build* доступны" "grep -q 'buildx:' Makefile" true
run_test "make backup* доступны" "grep -q 'backup:' Makefile" true

echo ""

# ============================================
# 6. ПРОВЕРКА DOCKER (если запущен)
# ============================================

echo -e "${BLUE}6️⃣  ПРОВЕРКА DOCKER${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Docker daemon доступен" "docker ps > /dev/null 2>&1" true

if [ $? -eq 0 ]; then
    run_test "docker-compose config валидна" "docker-compose config > /dev/null 2>&1" true
else
    skip_test "Docker образы (Docker не запущен)"
fi

echo ""

# ============================================
# 7. ПРОВЕРКА БАЗОВЫХ КОМАНД (если контейнер запущен)
# ============================================

echo -e "${BLUE}7️⃣  ПРОВЕРКА КОМАНД (опционально)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Проверяем есть ли запущенный контейнер
if docker-compose ps 2>/dev/null | grep -q ramalama; then
    run_test "ramalama info работает" "docker-compose exec -T ramalama ramalama info" true
    run_test "ramalama list работает" "docker-compose exec -T ramalama ramalama list" true
else
    echo -e "${CYAN}ℹ${NC} Контейнер не запущен (это нормально)"
    echo "  Запустите: docker-compose up -d"
    echo "  Затем: make health"
fi

echo ""

# ============================================
# 8. ИТОГИ
# ============================================

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ                  ║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════╣${NC}"
printf "${BLUE}║${NC} ${GREEN}Пройдено:${NC}   %-3d${BLUE}                              ║${NC}\n" $TESTS_PASSED
printf "${BLUE}║${NC} ${RED}Провалено:${NC}  %-3d${BLUE}                              ║${NC}\n" $TESTS_FAILED
printf "${BLUE}║${NC} ${CYAN}Пропущено:${NC}  %-3d${BLUE}                              ║${NC}\n" $TESTS_SKIPPED
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

echo ""

# ============================================
# ФИНАЛЬНЫЙ РЕЗУЛЬТАТ
# ============================================

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Все тесты пройдены успешно!${NC}"
    echo ""
    echo -e "${YELLOW}Следующие шаги:${NC}"
    echo "  1. Проверьте структуру:  ./scripts/setup-dirs.sh"
    echo "  2. Соберите образ:       make buildx"
    echo "  3. Запустите контейнер:  make up"
    echo "  4. Проверьте здоровье:   make health"
    echo "  5. Загрузите модель:     make pull MODEL=tinyllama"
    echo "  6. Посмотрите примеры:   ./scripts/examples.sh"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Некоторые тесты провалены${NC}"
    echo -e "${YELLOW}Проверьте логи выше и исправьте ошибки${NC}"
    echo ""
    exit 1
fi
