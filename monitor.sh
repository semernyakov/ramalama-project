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
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0B"
    elif [ $bytes -lt 1024 ]; then
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
    mkdir -p "$(dirname "$LOG_FILE")"
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
    
    local docker_cmd_output
    if docker_cmd_output=$(docker info 2>&1); then
        echo -e "${GREEN}✓${NC} Docker: Running"
        
        # Проверка образа
        local image_size=""
        if docker image inspect ramalama:latest &> /dev/null; then
            image_size=$(docker image inspect ramalama:latest --format='{{.Size}}' 2>/dev/null || echo "")
            if [ -n "$image_size" ]; then
                echo -e "${GREEN}✓${NC} Image: ramalama:latest ($(format_bytes "$image_size"))"
            else
                echo -e "${GREEN}✓${NC} Image: ramalama:latest"
            fi
        else
            echo -e "${YELLOW}⚠${NC} Image: Not built"
        fi
        
        # Проверка контейнеров
        local running_containers=0
        local total_containers=0
        local unhealthy_containers=0
        
        if running_containers=$(docker ps -q -f name=ramalama 2>/dev/null | wc -l) && \
           total_containers=$(docker ps -a -q -f name=ramalama 2>/dev/null | wc -l); then
            # Проверить статус контейнеров на предмет перезапусков
            unhealthy_containers=$(docker ps -a -f name=ramalama --format "{{.Status}}" 2>/dev/null | grep -i "restarting" | wc -l || echo "0")
            
            if [ $running_containers -gt 0 ]; then
                if [ $unhealthy_containers -gt 0 ]; then
                    echo -e "${YELLOW}⚠${NC} Containers: $running_containers running / $total_containers total ($unhealthy_containers restarting)"
                else
                    echo -e "${GREEN}✓${NC} Containers: $running_containers running / $total_containers total"
                fi
            else
                echo -e "${YELLOW}⚠${NC} Containers: 0 running / $total_containers total"
            fi
        else
            echo -e "${YELLOW}⚠${NC} Container information unavailable"
        fi
    else
        echo -e "${RED}✗${NC} Docker: Not running or API version mismatch"
        echo -e "${YELLOW}ℹ${NC} $docker_cmd_output" | head -2
    fi
    
    echo ""
}

# Статус моделей
check_models_status() {
    echo -e "${CYAN}━━━ Models Status ━━━${NC}"
    
    if [ -d "$MODELS_DIR" ]; then
        local model_count=$(find "$MODELS_DIR" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l)
        local total_size=0
        
        if [ $model_count -gt 0 ]; then
            total_size=$(du -sb "$MODELS_DIR" 2>/dev/null | cut -f1 || echo "0")
        fi
        
        echo -e "${GREEN}✓${NC} Models directory: $MODELS_DIR"
        echo -e "${BLUE}ℹ${NC} Total models: $model_count"
        echo -e "${BLUE}ℹ${NC} Total size: $(format_bytes "$total_size")"
        
        if [ $model_count -gt 0 ]; then
            echo ""
            echo "Recent models:"
            find "$MODELS_DIR" -type f \( -name "*.gguf" -o -name "*.bin" \) -printf "%T@ %p\n" 2>/dev/null | \
                sort -rn | head -5 | while read timestamp path; do
                local filename=$(basename "$path")
                local size=$(stat -f%z "$path" 2>/dev/null || stat -c%s "$path" 2>/dev/null)
                echo "  • $filename ($(format_bytes "$size"))"
            done
        fi
    else
        echo -e "${YELLOW}⚠${NC} Models directory not found"
        mkdir -p "$MODELS_DIR"
        echo -e "${BLUE}ℹ${NC} Created directory: $MODELS_DIR"
    fi
    
    echo ""
}

# Статус дискового пространства
check_disk_status() {
    echo -e "${CYAN}━━━ Disk Space ━━━${NC}"
    
    # Общее пространство
    if command -v df &> /dev/null; then
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
    else
        echo -e "${YELLOW}⚠${NC} Disk information not available"
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
    local docker_procs
    if docker_procs=$(docker ps --format "{{.Names}}: {{.Status}}" -f name=ramalama 2>/dev/null); then
        if [ -n "$docker_procs" ]; then
            echo "$docker_procs" | while read line; do
                if echo "$line" | grep -qi "restarting"; then
                    echo -e "${YELLOW}⚠${NC} $line"
                elif echo "$line" | grep -qi "up"; then
                    echo -e "${GREEN}✓${NC} $line"
                else
                    echo -e "${BLUE}ℹ${NC} $line"
                fi
            done
        else
            echo -e "${YELLOW}⚠${NC} No RamaLama containers running"
        fi
    else
        echo -e "${YELLOW}⚠${NC} Unable to query Docker processes (API version mismatch?)"
    fi
    
    echo ""
}

# Последние логи
check_recent_logs() {
    echo -e "${CYAN}━━━ Recent Activity ━━━${NC}"
    
    mkdir -p "$(dirname "$LOG_FILE")"
    
    if [ -f "$LOG_FILE" ]; then
        echo "Last 5 events:"
        tail -5 "$LOG_FILE" 2>/dev/null | while read line; do
            echo "  $line"
        done
    else
        echo -e "${YELLOW}⚠${NC} No log file found"
        echo -e "${BLUE}ℹ${NC} Log file will be created on first event"
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
    local containers_total=0
    local containers_restarting=0
    local models_count=0
    local disk_usage="0"
    local image_size=0
    local docker_error=""
    
    if docker info &> /dev/null; then
        docker_running="true"
        if docker image inspect ramalama:latest &> /dev/null; then
            image_exists="true"
            image_size=$(docker image inspect ramalama:latest --format='{{.Size}}' 2>/dev/null || echo "0")
        fi
        containers_running=$(docker ps -q -f name=ramalama 2>/dev/null | wc -l || echo "0")
        containers_total=$(docker ps -a -q -f name=ramalama 2>/dev/null | wc -l || echo "0")
        containers_restarting=$(docker ps -a -f name=ramalama --format "{{.Status}}" 2>/dev/null | grep -i "restarting" | wc -l || echo "0")
    else
        docker_error="Docker daemon not accessible or API version mismatch"
    fi
    
    if [ -d "$MODELS_DIR" ]; then
        models_count=$(find "$MODELS_DIR" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l)
    fi
    
    local disk_info=$(df . 2>/dev/null | tail -1 || echo "0 0 0 0 0%")
    disk_usage=$(echo $disk_info | awk '{print $5}' | sed 's/%//')
    
    cat << EOF
{
  "timestamp": "$(get_timestamp)",
  "docker": {
    "running": $docker_running,
    "image_exists": $image_exists,
    "image_size": $image_size,
    "image_size_formatted": "$(format_bytes "$image_size")",
    "containers_running": $containers_running,
    "containers_total": $containers_total,
    "containers_restarting": $containers_restarting
  },
  "models": {
    "count": $models_count,
    "directory": "$MODELS_DIR"
  },
  "disk": {
    "usage_percent": $disk_usage
  },
  "errors": $([ -n "$docker_error" ] && echo "\"$docker_error\"" || echo "null"),
  "health": $([ $containers_restarting -gt 0 ] && echo "\"unhealthy\"" || echo "\"healthy\"")
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
