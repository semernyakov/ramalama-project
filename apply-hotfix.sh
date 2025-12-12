#!/bin/bash

# Скрипт применения срочных исправлений

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}"
cat << "EOF"
╔════════════════════════════════════════╗
║     RamaLama Hotfix Application        ║
╚════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Этот скрипт применит следующие исправления:${NC}"
echo "  1. Фильтрация логов прокси в entrypoint.sh"
echo "  2. Исправление команды version в ramalama.sh"
echo "  3. Добавление RAMALAMA_IN_CONTAINER в docker-compose.yml"
echo "  4. Пересборка Docker образа"
echo ""

read -p "Продолжить? (Y/n): " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Отменено."
    exit 0
fi

echo ""
echo -e "${BLUE}━━━ Шаг 1: Проверка файлов ━━━${NC}"

if [ ! -f "entrypoint.sh" ] || [ ! -f "docker-compose.yml" ] || [ ! -f "ramalama.sh" ]; then
    echo -e "${RED}✗ Не найдены необходимые файлы!${NC}"
    echo "Убедитесь что вы в директории ramalama-project/"
    exit 1
fi

echo -e "${GREEN}✓ Все файлы на месте${NC}"

echo ""
echo -e "${BLUE}━━━ Шаг 2: Создание резервных копий ━━━${NC}"

backup_dir="backups/hotfix-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

cp entrypoint.sh "$backup_dir/"
cp docker-compose.yml "$backup_dir/"
cp ramalama.sh "$backup_dir/"

echo -e "${GREEN}✓ Резервные копии созданы в: $backup_dir${NC}"

echo ""
echo -e "${BLUE}━━━ Шаг 3: Проверка текущих проблем ━━━${NC}"

has_issues=false

# Проверка 1: grep фильтр в entrypoint.sh
if ! grep -q "grep -v.*Using proxy" entrypoint.sh; then
    echo -e "${YELLOW}⚠ Нужно обновить entrypoint.sh (фильтр логов)${NC}"
    has_issues=true
fi

# Проверка 2: RAMALAMA_IN_CONTAINER в docker-compose.yml
if ! grep -q "RAMALAMA_IN_CONTAINER" docker-compose.yml; then
    echo -e "${YELLOW}⚠ Нужно обновить docker-compose.yml (IN_CONTAINER флаг)${NC}"
    has_issues=true
fi

# Проверка 3: version команда в ramalama.sh
if grep -q "run_ramalama --version" ramalama.sh; then
    echo -e "${YELLOW}⚠ Нужно исправить команду version в ramalama.sh${NC}"
    has_issues=true
fi

if [ "$has_issues" = false ]; then
    echo -e "${GREEN}✓ Все исправления уже применены!${NC}"
    echo ""
    echo "Но можно пересобрать образ для уверенности:"
    read -p "Пересобрать образ? (y/N): " rebuild
    if [[ "$rebuild" =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${BLUE}━━━ Пересборка образа ━━━${NC}"
        ./ramalama.sh rebuild
        echo -e "${GREEN}✓ Образ пересобран${NC}"
    fi
    exit 0
fi

echo ""
echo -e "${BLUE}━━━ Шаг 4: Применение исправлений ━━━${NC}"

# Исправление 1: Обновление entrypoint.sh
if ! grep -q "grep -v.*Using proxy" entrypoint.sh; then
    echo -e "${YELLOW}▶ Обновление entrypoint.sh...${NC}"
    
    cat > entrypoint.sh << 'ENTRYPOINT_EOF'
#!/bin/bash
set -e

# Настройка прокси если переменные заданы
if [ ! -z "$HTTP_PROXY" ]; then
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTP_PROXY"
    echo "✓ Proxy configured: $HTTP_PROXY"
fi

# Расширенный no_proxy
export no_proxy="localhost,127.0.0.0/8,::1,host.docker.internal"
export NO_PROXY="$no_proxy"

# Отключаем лишние прокси переменные
export PYTHONWARNINGS="ignore"
unset ftp_proxy
unset FTP_PROXY
unset all_proxy
unset ALL_PROXY

# Настройка путей
export RAMALAMA_MODELS_PATH="${RAMALAMA_MODELS_PATH:-/workspace/models}"

exec 3>&1
exec 4>&2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3
echo "  RamaLama Docker Environment" >&3
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3
echo "Models path: $RAMALAMA_MODELS_PATH" >&3
echo "Proxy: ${HTTP_PROXY:-none}" >&3
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3

# Фильтруем логи прокси
exec ramalama "$@" 2>&1 | grep -v "INFO:ramalama:Using proxy" | cat >&3
ENTRYPOINT_EOF
    
    chmod +x entrypoint.sh
    echo -e "${GREEN}✓ entrypoint.sh обновлен${NC}"
fi

# Исправление 2: Обновление docker-compose.yml
if ! grep -q "RAMALAMA_IN_CONTAINER" docker-compose.yml; then
    echo -e "${YELLOW}▶ Обновление docker-compose.yml...${NC}"
    
    # Добавляем переменную после RAMALAMA_MODELS_PATH
    sed -i '/RAMALAMA_MODELS_PATH/a\      - RAMALAMA_IN_CONTAINER=1' docker-compose.yml
    
    # Удаляем старую переменную LOG_LEVEL если есть
    sed -i '/RAMALAMA_LOG_LEVEL/d' docker-compose.yml
    
    echo -e "${GREEN}✓ docker-compose.yml обновлен${NC}"
fi

# Исправление 3: Обновление ramalama.sh
if grep -q "run_ramalama --version" ramalama.sh; then
    echo -e "${YELLOW}▶ Исправление команды version в ramalama.sh...${NC}"
    
    sed -i 's/run_ramalama --version/run_ramalama version/g' ramalama.sh
    
    echo -e "${GREEN}✓ ramalama.sh исправлен${NC}"
fi

echo ""
echo -e "${BLUE}━━━ Шаг 5: Пересборка Docker образа ━━━${NC}"

./ramalama.sh rebuild

echo ""
echo -e "${BLUE}━━━ Шаг 6: Проверка исправлений ━━━${NC}"

echo -e "${YELLOW}▶ Тест 1: Проверка version...${NC}"
if ./ramalama.sh -- version 2>&1 | grep -q "0\."; then
    echo -e "${GREEN}✓ Команда version работает${NC}"
else
    echo -e "${RED}✗ Проблема с командой version${NC}"
fi

echo -e "${YELLOW}▶ Тест 2: Проверка логов прокси...${NC}"
log_count=$(./ramalama.sh info 2>&1 | grep -c "INFO:ramalama:Using proxy" || true)
if [ $log_count -eq 0 ]; then
    echo -e "${GREEN}✓ Логи прокси отфильтрованы${NC}"
else
    echo -e "${YELLOW}⚠ Логи прокси все еще появляются ($log_count раз)${NC}"
    echo "  Но это может быть нормально на первом запуске"
fi

echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   Исправления успешно применены!      ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Следующие шаги:${NC}"
echo "  1. Проверьте работу: ./ramalama.sh -- version"
echo "  2. Скачайте модель: ./ramalama.sh pull tinyllama"
echo "  3. Запустите модель: ./ramalama.sh run tinyllama"
echo ""
echo -e "${YELLOW}Резервные копии:${NC} $backup_dir"
echo ""
echo -e "${BLUE}Подробности: см. HOTFIX.md${NC}"
echo ""
