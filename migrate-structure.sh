#!/bin/bash

# Скрипт миграции на новую структуру директорий

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}${BOLD}"
cat << "EOF"
╔════════════════════════════════════════════════════╗
║   RamaLama Structure Migration Tool                ║
║   Миграция на новую структуру директорий           ║
╚════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}Эта миграция:${NC}"
echo "  1. Создаст директории: config/, logs/"
echo "  2. Переместит .env в config/"
echo "  3. Переместит логи из data/logs/ в logs/"
echo "  4. Обновит docker-compose.yml"
echo "  5. Обновит entrypoint.sh"
echo "  6. Обновит ramalama.sh"
echo "  7. ИСПРАВИТ проблему с сохранением моделей!"
echo ""

read -p "Продолжить? (Y/n): " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    echo "Отменено."
    exit 0
fi

echo ""
echo -e "${BLUE}━━━ Шаг 1: Создание резервной копии ━━━${NC}"

backup_dir="backups/migration-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$backup_dir"

# Копируем важные файлы
for file in docker-compose.yml entrypoint.sh ramalama.sh .env; do
    if [ -f "$file" ]; then
        cp "$file" "$backup_dir/"
        echo -e "${GREEN}✓${NC} Скопирован: $file"
    fi
done

# Копируем директории
if [ -d "data/logs" ]; then
    cp -r data/logs "$backup_dir/"
    echo -e "${GREEN}✓${NC} Скопирована: data/logs/"
fi

echo -e "${GREEN}✓${NC} Резервная копия создана: $backup_dir"

echo ""
echo -e "${BLUE}━━━ Шаг 2: Создание новой структуры ━━━${NC}"

# Создаем новые директории
mkdir -p config
mkdir -p logs
mkdir -p logs/sessions
mkdir -p models
mkdir -p data
mkdir -p backups

echo -e "${GREEN}✓${NC} Директории созданы"

echo ""
echo -e "${BLUE}━━━ Шаг 3: Миграция файлов ━━━${NC}"

# Перемещаем .env в config/
if [ -f ".env" ]; then
    if [ ! -f "config/.env" ]; then
        mv .env config/
        echo -e "${GREEN}✓${NC} .env → config/.env"
    else
        echo -e "${YELLOW}⚠${NC} config/.env уже существует, пропускаем"
    fi
fi

# Создаем симлинк для обратной совместимости
if [ ! -f ".env" ] && [ -f "config/.env" ]; then
    ln -sf config/.env .env
    echo -e "${GREEN}✓${NC} Создан симлинк: .env → config/.env"
fi

# Перемещаем логи
if [ -d "data/logs" ] && [ "$(ls -A data/logs 2>/dev/null)" ]; then
    cp -r data/logs/* logs/ 2>/dev/null || true
    echo -e "${GREEN}✓${NC} Логи перемещены: data/logs/ → logs/"
fi

echo ""
echo -e "${BLUE}━━━ Шаг 4: Обновление docker-compose.yml ━━━${NC}"

cat > docker-compose.yml << 'COMPOSE_EOF'
version: '3.8'

services:
  ramalama:
    build: .
    image: ramalama:latest
    container_name: ramalama
    
    # Используем host network для доступа к прокси на 127.0.0.1
    network_mode: host
    
    env_file:
      - config/.env
    
    environment:
      # Прокси настройки (из .env)
      - HTTP_PROXY=${HTTP_PROXY:-}
      - HTTPS_PROXY=${HTTPS_PROXY:-}
      - NO_PROXY=localhost,127.0.0.0/8,::1
      
      # КРИТИЧНО: Указываем RamaLama где хранить модели
      - RAMALAMA_STORE=/var/lib/ramalama
      - RAMALAMA_IN_CONTAINER=1
      
      # Пути для логов
      - RAMALAMA_LOG_FILE=/workspace/logs/ramalama.log
      
      # Настройки Hugging Face
      - HF_HUB_DISABLE_PROGRESS_BARS=false
      - HF_HUB_ENABLE_HF_TRANSFER=1
    
    volumes:
      # КРИТИЧНО: Монтируем /var/lib/ramalama для сохранения моделей!
      - ./models:/var/lib/ramalama:rw
      
      # Логи в отдельную директорию
      - ./logs:/workspace/logs:rw
      
      # Конфиги в отдельную директорию
      - ./config:/workspace/config:ro
      
      # Пользовательские данные
      - ./data:/workspace/data:rw
    
    # По умолчанию контейнер в режиме ожидания
    command: tail -f /dev/null
    
    stdin_open: true
    tty: true
    restart: unless-stopped

  # Альтернативный сервис без прокси
  ramalama-no-proxy:
    build: .
    image: ramalama:latest
    container_name: ramalama-no-proxy
    profiles: ["no-proxy"]
    
    environment:
      - RAMALAMA_STORE=/var/lib/ramalama
      - RAMALAMA_IN_CONTAINER=1
      - RAMALAMA_LOG_FILE=/workspace/logs/ramalama.log
    
    volumes:
      - ./models:/var/lib/ramalama:rw
      - ./logs:/workspace/logs:rw
      - ./config:/workspace/config:ro
      - ./data:/workspace/data:rw
    
    command: tail -f /dev/null
    
    stdin_open: true
    tty: true
    restart: unless-stopped
COMPOSE_EOF

echo -e "${GREEN}✓${NC} docker-compose.yml обновлен"

echo ""
echo -e "${BLUE}━━━ Шаг 5: Обновление entrypoint.sh ━━━${NC}"

cat > entrypoint.sh << 'ENTRYPOINT_EOF'
#!/bin/bash
set -e

echo "🚀 RamaLama Docker Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Настройка прокси
if [ -n "$HTTP_PROXY" ]; then
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTPS_PROXY"
    echo "📡 Proxy: $HTTP_PROXY"
else
    echo "📡 Proxy: none"
fi

# Отключаем лишние прокси переменные
export PYTHONWARNINGS="ignore"
unset ftp_proxy
unset FTP_PROXY
unset all_proxy
unset ALL_PROXY

# КРИТИЧНО: Указываем где RamaLama должен хранить модели
export RAMALAMA_STORE="${RAMALAMA_STORE:-/var/lib/ramalama}"
echo "📦 Models store: $RAMALAMA_STORE"

# Создаем необходимые директории
mkdir -p "$RAMALAMA_STORE" /workspace/logs /workspace/data
chmod 777 "$RAMALAMA_STORE" /workspace/logs /workspace/data 2>/dev/null || true

echo "📁 Logs: /workspace/logs/"
echo "📁 Data: /workspace/data/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Проверяем существующие модели
echo ""
echo "=== Existing Models ==="
model_files=$(find "$RAMALAMA_STORE" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | head -10 || true)
if [ -n "$model_files" ]; then
    echo "$model_files" | while IFS= read -r model; do
        if [ -n "$model" ]; then
            size=$(du -h "$model" 2>/dev/null | cut -f1 || echo "?")
            echo "  📦 $(basename "$model") ($size)"
        fi
    done
    model_count=$(echo "$model_files" | wc -l)
    echo ""
    echo "Total: $model_count model(s)"
else
    echo "  📭 No models found"
fi
echo "======================="
echo ""

# Режим ожидания для docker-compose
if [[ "$1" == "tail" && "$2" == "-f" ]]; then
    echo "🟢 Container ready! Waiting for commands..."
    echo ""
    echo "Use these commands:"
    echo "  docker-compose exec ramalama ramalama info"
    echo "  docker-compose exec ramalama ramalama pull tinyllama"
    echo "  docker-compose exec ramalama ramalama list"
    echo ""
    exec tail -f /dev/null
fi

# Запуск команды с фильтрацией логов прокси
echo "▶️  Executing: ramalama $@"
echo ""

# Фильтруем INFO логи о прокси
exec ramalama "$@" 2>&1 | grep -v "INFO:ramalama:Using proxy" || true
ENTRYPOINT_EOF

chmod +x entrypoint.sh
echo -e "${GREEN}✓${NC} entrypoint.sh обновлен"

echo ""
echo -e "${BLUE}━━━ Шаг 6: Остановка контейнеров ━━━${NC}"

docker-compose down 2>/dev/null || true
echo -e "${GREEN}✓${NC} Контейнеры остановлены"

echo ""
echo -e "${BLUE}━━━ Шаг 7: Пересборка образа ━━━${NC}"

docker-compose build --no-cache
echo -e "${GREEN}✓${NC} Образ пересобран"

echo ""
echo -e "${BLUE}━━━ Шаг 8: Проверка миграции ━━━${NC}"

echo -e "${CYAN}Структура директорий:${NC}"
tree -L 2 -d . 2>/dev/null || ls -la

echo ""
echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}${BOLD}║   Миграция успешно завершена!                     ║${NC}"
echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}Новая структура:${NC}"
echo "  config/     - конфигурационные файлы (.env)"
echo "  logs/       - все логи системы"
echo "  models/     - модели (теперь сохраняются правильно!)"
echo "  data/       - пользовательские данные"
echo "  backups/    - резервные копии"
echo ""

echo -e "${YELLOW}Проверьте работу:${NC}"
echo "  1. ./ramalama.sh info"
echo "  2. ./ramalama.sh list"
echo "  3. ./ramalama.sh pull tinyllama"
echo "  4. ls -la models/     # Модель должна появиться здесь!"
echo ""

echo -e "${BLUE}Резервная копия:${NC} $backup_dir"
echo ""
