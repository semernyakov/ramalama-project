#!/bin/bash

# Скрипт мониторинга RamaLama

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Настройки
REFRESH_INTERVAL=${REFRESH_INTERVAL:-5}
MODELS_DIR="./models"
LOG_FILE="./data/monitor.log"

# Функции для форматирования
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(( bytes / 1024 ))KB"
    elif [ $bytes -lt 1073741824 ]; then
        echo "$(( bytes / 1048576 ))MB"
    else
        echo "$(( bytes / 1073741824 ))GB"
    fi
}

get_timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

# Лог события
log_event() {
    echo "[$(get_timestamp)] $1" >> "$LOG_FILE"
}

# Очистка экрана и вывод заголовка
print_header() {
    clear
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║              RamaLama Monitoring Dashboard                     ║${NC}"
    echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${BLUE}║${NC} Обновление: $(get_timestamp)  Интервал: ${REFRESH_INTERVAL}s              ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Статус Docker
check_docker_status() {
    echo -e "${CYAN}━━━ Docker Status ━━━${NC}"
    
    if docker info &> /dev/null; then
        echo -e "${GREEN}✓${NC} Docker: Running"
        
        # Проверка образа
        if docker image inspect ramalama:latest &> /dev/null; then
            local image_size=$(docker image inspect ramalama:latest --format='{{.Size}}')
            echo -e "${GREEN}✓${NC} Image: ramalama:latest ($(format_bytes $image_size))"
        else
            echo -e "${YELLOW}⚠${NC} Image: Not built"
        fi
        
        # Проверка контейнеров
        local running_containers=$(docker ps -q -f name=ramalama | wc -l)
        local total_containers=$(docker ps -a -q -f name=ramalama | wc -l)
        
        if [ $running_containers -gt 0 ]; then
            echo -e "${GREEN}✓${NC} Containers: $running_containers running / $total_containers total"
        else
            echo -e "${YELLOW}⚠${NC} Containers: 0 running / $total_containers total"
        fi
    else
        echo -e "${RED}✗${NC} Docker: Not running"
    fi
    
    echo ""
}

# Статус моделей
check_models_status() {
    echo -e "${CYAN}━━━ Models Status ━━━${NC}"
    
    if [ -d "$MODELS_DIR" ]; then
        local model_count=$(find "$MODELS_DIR" -type f -name "*.gguf" 2>/dev/null | wc -l)
        local total_size=$(du -sb "$MODELS_DIR" 2>/dev/null | cut -f1)
        
        echo -e "${GREEN}✓${NC} Models directory: $MODELS_DIR"
        echo -e "${BLUE}ℹ${NC} Total models: $model_count"
        echo -e "${BLUE}ℹ${NC} Total size: $(format_bytes $total_size)"
        
        if [ $model_count -gt 0 ]; then
            echo ""
            echo "Recent models:"
            find "$MODELS_DIR" -type f -name "*.gguf" -printf "%T@ %p\n" 2>/dev/null | \
                sort -rn | head -5 | while read timestamp path; do
                local filename=$(basename "$path")
                local size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null)
                echo "  • $filename ($(format_bytes $size))"
            done
        fi
    else
        echo -e "${YELLOW}⚠${NC} Models directory not found"
    fi
    
    echo ""
}

# Статус дискового пространства
check_disk_status() {
    echo -e "${CYAN}━━━ Disk Space ━━━${NC}"
    
    # Общее пространство
    local disk_info=$(df -h . | tail -1)
    local total=$(echo $disk_info | awk '{print $2}')
    local used=$(echo $disk_info | awk '{print $3}')
    local avail=$(echo $disk_info | awk '{print $4}')
    local percent=$(echo $disk_info | awk '{print $5}')
    
    echo -e "${BLUE}ℹ${NC} Total: $total | Used: $used | Available: $avail | Usage: $percent"
    
    # Предупреждение при низком пространстве
    local percent_num=$(echo $percent | sed 's/%//')
    if [ $percent_num -gt 90 ]; then
        echo -e "${RED}⚠${NC} Warning: Disk space is running low!"
        log_event "WARNING: Disk space at ${percent}"
    elif [ $percent_num -gt 80 ]; then
        echo -e "${YELLOW}⚠${NC} Caution: Disk space usage is high"
    fi
    
    echo ""
}

# Статус памяти
check_memory_status() {
    echo -e "${CYAN}━━━ System Memory ━━━${NC}"
    
    if command -v free &> /dev/null; then
        local mem_info=$(free -h | grep "Mem:")
        local total=$(echo $mem_info | awk '{print $2}')
        local used=$(echo $mem_info | awk '{print $3}')
        local free=$(echo $mem_info | awk '{print $4}')
        
        echo -e "${BLUE}ℹ${NC} Total: $total | Used: $used | Free: $free"
    else
        echo -e "${YELLOW}⚠${NC} Memory information not available"
    fi
    
    echo ""
}

# Статус процессов
check_process_status() {
    echo -e "${CYAN}━━━ Running Processes ━━━${NC}"
    
    # Docker процессы
    local docker_procs=$(docker ps --format "{{.Names}}: {{.Status}}" -f name=ramalama 2>/dev/null)
    if [ -n "$docker_procs" ]; then
        echo "$docker_procs" | while read line; do
            echo -e "${GREEN}✓${NC} $line"
        done
    else
        echo -e "${YELLOW}⚠${NC} No RamaLama containers running"
    fi
    
    echo ""
}

# Последние логи
check_recent_logs() {
    echo -e "${CYAN}━━━ Recent Activity ━━━${NC}"
    
    if [ -f "$LOG_FILE" ]; then
        echo "Last 5 events:"
        tail -5 "$LOG_FILE" 2>/dev/null | while read line; do
            echo "  $line"
        done
    else
        echo -e "${YELLOW}⚠${NC} No log file found"
    fi
    
    echo ""
}

# Рекомендации
show_recommendations() {
    echo -e "${CYAN}━━━ Quick Actions ━━━${NC}"
    echo "  [i] Info:       ./ramalama.sh info"
    echo "  [l] List:       ./ramalama.sh list"
    echo "  [b] Build:      ./ramalama.sh build"
    echo "  [s] Shell:      ./ramalama.sh shell"
    echo "  [c] Clean:      ./ramalama.sh clean"
    echo "  [q] Quit:       Ctrl+C"
    echo ""
}

# Интерактивный режим
interactive_mode() {
    log_event "Monitor started in interactive mode"
    
    while true; do
        print_header
        check_docker_status
        check_models_status
        check_disk_status
        check_memory_status
        check_process_status
        check_recent_logs
        show_recommendations
        
        echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
        sleep $REFRESH_INTERVAL
    done
}

# Одноразовый режим
snapshot_mode() {
    log_event "Monitor snapshot taken"
    
    print_header
    check_docker_status
    check_models_status
    check_disk_status
    check_memory_status
    check_process_status
    check_recent_logs
}

# Режим JSON для автоматизации
json_mode() {
    local docker_running="false"
    local image_exists="false"
    local containers_running=0
    local models_count=0
    local disk_usage="0"
    
    docker info &> /dev/null && docker_running="true"
    docker image inspect ramalama:latest &> /dev/null && image_exists="true"
    containers_running=$(docker ps -q -f name=ramalama | wc -l)
    
    if [ -d "$MODELS_DIR" ]; then
        models_count=$(find "$MODELS_DIR" -type f -name "*.gguf" 2>/dev/null | wc -l)
    fi
    
    local disk_info=$(df . | tail -1)
    disk_usage=$(echo $disk_info | awk '{print $5}' | sed 's/%//')
    
    cat << EOF
{
  "timestamp": "$(get_timestamp)",
  "docker": {
    "running": $docker_running,
    "image_exists": $image_exists,
    "containers_running": $containers_running
  },
  "models": {
    "count": $models_count,
    "directory": "$MODELS_DIR"
  },
  "disk": {
    "usage_percent": $disk_usage
  }
}
EOF
}

# Справка
show_help() {
    cat << EOF
RamaLama Monitor - Мониторинг состояния системы

Использование:
  ./monitor.sh [опции]

Опции:
  -i, --interactive    Интерактивный режим (по умолчанию)
  -s, --snapshot       Одноразовый снимок состояния
  -j, --json          Вывод в формате JSON
  -t, --interval <N>  Интервал обновления в секундах (по умолчанию: 5)
  -h, --help          Показать эту справку

Примеры:
  ./monitor.sh                    # Интерактивный режим
  ./monitor.sh -s                 # Быстрый снимок
  ./monitor.sh -j                 # JSON вывод
  ./monitor.sh -t 10              # Обновление каждые 10 секунд
  watch -n 5 ./monitor.sh -s      # Авто-обновление через watch

Логи сохраняются в: $LOG_FILE
EOF
}

# Обработка сигналов
trap 'echo -e "\n${YELLOW}Monitor stopped${NC}"; log_event "Monitor stopped"; exit 0' INT TERM

# Основная логика
main() {
    local mode="interactive"
    
    while [ $# -gt 0 ]; do
        case "$1" in
            -i|--interactive)
                mode="interactive"
                shift
                ;;
            -s|--snapshot)
                mode="snapshot"
                shift
                ;;
            -j|--json)
                mode="json"
                shift
                ;;
            -t|--interval)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Создать директорию для логов
    mkdir -p "$(dirname "$LOG_FILE")"
    
    case "$mode" in
        interactive)
            interactive_mode
            ;;
        snapshot)
            snapshot_mode
            ;;
        json)
            json_mode
            ;;
    esac
}

main "$@"
