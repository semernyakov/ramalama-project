#!/bin/bash

# Скрипт проверки сохранения моделей

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     RamaLama Models Storage Check                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}━━━ 1. Проверка структуры директорий ━━━${NC}"
echo ""

# Проверка наличия директорий
check_dir() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo -e "  ${GREEN}✓${NC} $dir - существует"
        ls -lah "$dir" | head -5
    else
        echo -e "  ${RED}✗${NC} $dir - не найдена"
        return 1
    fi
}

check_dir "./models"
echo ""
check_dir "./logs"
echo ""
check_dir "./config"
echo ""

echo -e "${CYAN}━━━ 2. Проверка docker-compose.yml ━━━${NC}"
echo ""

if grep -q "/var/lib/ramalama" docker-compose.yml; then
    echo -e "  ${GREEN}✓${NC} Правильное монтирование: ./models:/var/lib/ramalama"
else
    echo -e "  ${RED}✗${NC} Неправильное монтирование!"
    echo "  Должно быть: ./models:/var/lib/ramalama"
    echo "  Запустите: ./migrate-structure.sh"
fi
echo ""

echo -e "${CYAN}━━━ 3. Проверка моделей на хосте ━━━${NC}"
echo ""

models_on_host=$(find ./models -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l)
echo "  Найдено моделей на хосте: $models_on_host"

if [ $models_on_host -gt 0 ]; then
    echo ""
    echo "  Модели:"
    find ./models -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | while read model; do
        size=$(du -h "$model" | cut -f1)
        echo "    📦 $(basename "$model") - $size"
    done
fi
echo ""

echo -e "${CYAN}━━━ 4. Проверка моделей в контейнере ━━━${NC}"
echo ""

if docker ps | grep -q ramalama; then
    echo "  Проверка внутри контейнера..."
    models_in_container=$(docker exec ramalama find /var/lib/ramalama -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l || echo "0")
    echo "  Найдено моделей в контейнере: $models_in_container"
    
    if [ $models_in_container -gt 0 ]; then
        echo ""
        echo "  Модели в контейнере:"
        docker exec ramalama find /var/lib/ramalama -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | while read model; do
            size=$(docker exec ramalama du -h "$model" 2>/dev/null | cut -f1 || echo "?")
            echo "    📦 $(basename "$model") - $size"
        done
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Контейнер не запущен"
    echo "  Запустите: docker-compose up -d"
fi
echo ""

echo -e "${CYAN}━━━ 5. Проверка RamaLama info ━━━${NC}"
echo ""

if docker ps | grep -q ramalama; then
    store_path=$(docker exec ramalama ramalama info 2>/dev/null | grep -A1 '"Store"' | tail -1 | cut -d'"' -f4 || echo "unknown")
    echo "  RamaLama Store path: $store_path"
    
    if [ "$store_path" = "/var/lib/ramalama" ]; then
        echo -e "  ${GREEN}✓${NC} Правильный путь!"
    else
        echo -e "  ${YELLOW}⚠${NC} Путь может быть неправильным"
    fi
else
    echo -e "  ${YELLOW}⚠${NC} Контейнер не запущен"
fi
echo ""

echo -e "${CYAN}━━━ 6. Тест сохранения ━━━${NC}"
echo ""

echo "  Создаем тестовый файл..."
test_file="./models/test-$(date +%s).txt"
echo "Test file created at $(date)" > "$test_file"

if [ -f "$test_file" ]; then
    echo -e "  ${GREEN}✓${NC} Файл создан на хосте: $test_file"
    
    if docker ps | grep -q ramalama; then
        container_file="/var/lib/ramalama/$(basename "$test_file")"
        if docker exec ramalama test -f "$container_file" 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} Файл виден в контейнере: $container_file"
            echo -e "  ${GREEN}✓${NC} Монтирование работает правильно!"
        else
            echo -e "  ${RED}✗${NC} Файл НЕ виден в контейнере!"
            echo "  Проблема с монтированием volumes"
        fi
    fi
    
    # Удаляем тестовый файл
    rm -f "$test_file"
    echo "  Тестовый файл удален"
else
    echo -e "  ${RED}✗${NC} Не удалось создать файл"
fi
echo ""

echo -e "${CYAN}━━━ 7. Рекомендации ━━━${NC}"
echo ""

if [ $models_on_host -eq 0 ]; then
    echo -e "  ${YELLOW}⚠${NC} Моделей не найдено"
    echo ""
    echo "  Для скачивания модели:"
    echo "    ./ramalama.sh pull tinyllama"
    echo ""
    echo "  После скачивания проверьте:"
    echo "    ls -lh ./models/"
    echo ""
elif [ $models_on_host -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Модели найдены и сохраняются правильно!"
    echo ""
    echo "  Для запуска модели:"
    echo "    ./ramalama.sh run <model_name>"
    echo ""
fi

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
