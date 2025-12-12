#!/bin/bash

# Скрипт быстрого тестирования RamaLama

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     RamaLama Quick Test Suite             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Счетчик тестов
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local test_name="$1"
    local test_cmd="$2"
    
    echo -e "${YELLOW}▶${NC} Тест: $test_name"
    
    if eval "$test_cmd" &> /tmp/ramalama_test.log; then
        echo -e "${GREEN}  ✓ Пройден${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}  ✗ Провален${NC}"
        echo -e "${RED}  Лог ошибки:${NC}"
        cat /tmp/ramalama_test.log | sed 's/^/    /'
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo -e "${BLUE}1. Проверка окружения${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Docker доступен" "command -v docker"
run_test "Docker Compose доступен" "command -v docker-compose"
run_test "Директория models существует" "[ -d ./models ]"
run_test "Директория data существует" "[ -d ./data ]"

echo ""
echo -e "${BLUE}2. Сборка и проверка образа${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "Сборка Docker образа" "docker-compose build"
run_test "Образ создан" "docker image inspect ramalama:latest"

echo ""
echo -e "${BLUE}3. Проверка базовых команд${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "ramalama --version" "./ramalama.sh version"
run_test "ramalama info" "./ramalama.sh info"
run_test "ramalama list" "./ramalama.sh list"

echo ""
echo -e "${BLUE}4. Проверка прокси (опционально)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ ! -z "$HTTP_PROXY" ]; then
    echo -e "${GREEN}✓${NC} Прокси настроен: $HTTP_PROXY"
    
    # Попытка скачать маленькую модель для теста
    echo -e "${YELLOW}▶${NC} Опциональный тест: скачивание тестовой модели"
    echo -e "${YELLOW}  (этот тест может занять время, нажмите Ctrl+C для пропуска)${NC}"
    
    if timeout 30s ./ramalama.sh pull tinyllama 2>&1 | head -20; then
        echo -e "${GREEN}  ✓ Скачивание через прокси работает${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${YELLOW}  ⊘ Тест пропущен или превышено время${NC}"
    fi
else
    echo -e "${YELLOW}⊘${NC} Прокси не настроен (это нормально если не требуется)"
fi

echo ""
echo -e "${BLUE}5. Проверка скриптов управления${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

run_test "ramalama.sh доступен" "[ -x ./ramalama.sh ]"
run_test "ramalama.sh help" "./ramalama.sh help"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           Результаты тестов                ║${NC}"
echo -e "${BLUE}╠════════════════════════════════════════════╣${NC}"
echo -e "${BLUE}║${NC} ${GREEN}Пройдено:${NC} $(printf '%2d' $TESTS_PASSED)                              ${BLUE}║${NC}"
echo -e "${BLUE}║${NC} ${RED}Провалено:${NC} $(printf '%2d' $TESTS_FAILED)                             ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Все тесты пройдены успешно!${NC}"
    echo ""
    echo -e "${YELLOW}Следующие шаги:${NC}"
    echo "  1. Скачайте модель:  ./ramalama.sh pull llama3.2:1b"
    echo "  2. Запустите модель: ./ramalama.sh run llama3.2:1b"
    echo "  3. Или запустите как сервер: ./ramalama.sh serve llama3.2:1b"
    echo ""
    exit 0
else
    echo ""
    echo -e "${RED}✗ Некоторые тесты провалены${NC}"
    echo -e "${YELLOW}Проверьте логи выше для деталей${NC}"
    echo ""
    exit 1
fi
