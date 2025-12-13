#!/bin/bash

# ============================================
# RamaLama Log Manager (Variant B optimized)
# Управление логами с поддержкой Variant B
# ============================================

set -euo pipefail

# Определяем директорию логов
LOG_DIR="${LOG_DIR:-./logs}"
LOG_FILE="$LOG_DIR/ramalama.log"

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Функции логирования
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }

# Инициализация логирования
init_logging() {
    mkdir -p "$LOG_DIR"/{sessions,archives}
    echo "$(date '+%Y-%m-%d %H:%M:%S'): Logging system initialized" >> "$LOG_FILE"
    log_success "Logging initialized: $LOG_FILE"
}

# Запуск команды с логированием
run_with_logging() {
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local session_log="$LOG_DIR/sessions/session_${timestamp}.log"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Command: $*" >> "$LOG_FILE"
    
    mkdir -p "$LOG_DIR/sessions"
    
    # Интерактивный режим - показываем и логируем
    stdbuf -oL -eL "$@" 2>&1 | tee -a "$LOG_FILE" "$session_log" || return $?
}

# Просмотр логов
show_logs() {
    local lines=${1:-50}
    if [ -f "$LOG_FILE" ]; then
        echo "=== Last $lines lines from $LOG_FILE ==="
        tail -n "$lines" "$LOG_FILE"
        echo ""
        log_info "Total lines: $(wc -l < "$LOG_FILE")"
        log_info "Size: $(du -h "$LOG_FILE" | cut -f1)"
    else
        log_error "Log file not found: $LOG_FILE"
    fi
}

# Мониторинг логов (tail -f)
tail_logs() {
    if [ -f "$LOG_FILE" ]; then
        log_info "Monitoring logs (Ctrl+C to exit)..."
        tail -f "$LOG_FILE"
    else
        log_error "Log file not found: $LOG_FILE"
    fi
}

# Очистка старых логов
clean_logs() {
    log_info "Cleaning old logs..."
    
    # Архивируем основной лог если больше 10MB
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]; then
        local archive_name="$LOG_DIR/archives/ramalama_$(date +%Y%m%d_%H%M%S).log.gz"
        gzip -c "$LOG_FILE" > "$archive_name"
        > "$LOG_FILE"  # Очищаем основной файл
        log_success "Archived to: $archive_name"
    fi
    
    # Удаляем старые сессии (старше 30 дней)
    find "$LOG_DIR/sessions" -name "session_*.log" -mtime +30 -delete 2>/dev/null || true
    
    # Удаляем старые архивы (старше 90 дней)
    find "$LOG_DIR/archives" -name "*.log.gz" -mtime +90 -delete 2>/dev/null || true
    
    log_success "Cleanup completed"
}

# Статус логирования
status() {
    echo ""
    log_info "Log Directory: $LOG_DIR"
    if [ -f "$LOG_FILE" ]; then
        log_success "Main log exists"
        log_info "  Size: $(du -h "$LOG_FILE" | cut -f1)"
        log_info "  Lines: $(wc -l < "$LOG_FILE")"
        log_info "  Modified: $(stat -c '%y' "$LOG_FILE" 2>/dev/null || echo 'unknown')"
    else
        log_info "Main log: not created yet"
    fi
    
    if [ -d "$LOG_DIR/sessions" ]; then
        local sessions=$(find "$LOG_DIR/sessions" -name "session_*.log" 2>/dev/null | wc -l)
        log_info "Sessions: $sessions"
    fi
    
    if [ -d "$LOG_DIR/archives" ]; then
        local archives=$(find "$LOG_DIR/archives" -name "*.log.gz" 2>/dev/null | wc -l)
        log_info "Archived logs: $archives"
    fi
    echo ""
}

# Справка
show_help() {
    cat << 'EOF'
RamaLama Log Manager - Log management utility

Usage:
  ./log-manager.sh init          Initialize logging
  ./log-manager.sh run <cmd>     Run command with logging
  ./log-manager.sh show [N]      Show last N lines (default: 50)
  ./log-manager.sh tail          Monitor logs (tail -f)
  ./log-manager.sh clean         Clean old logs and archives
  ./log-manager.sh status        Show logging status
  ./log-manager.sh help          Show this help

Examples:
  ./log-manager.sh init
  ./log-manager.sh run ramalama pull tinyllama
  ./log-manager.sh show 100
  ./log-manager.sh tail
  ./log-manager.sh clean
  ./log-manager.sh status

Log location: ./logs/
  - ramalama.log          Main log file
  - sessions/             Session logs
  - archives/             Compressed old logs

EOF
}

# Основная логика
main() {
    case "${1:-help}" in
        init)
            init_logging
            ;;
        run)
            shift
            [ $# -eq 0 ] && { log_error "No command specified"; exit 1; }
            init_logging
            run_with_logging "$@"
            ;;
        show|logs)
            show_logs "${2:-50}"
            ;;
        tail|follow)
            tail_logs
            ;;
        clean)
            clean_logs
            ;;
        status)
            status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
