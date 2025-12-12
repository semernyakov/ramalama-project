#!/bin/bash

# Скрипт для управления логами RamaLama
# Автоматически сохраняет логи в файлы

set -e

LOG_DIR="/workspace/data/logs"
LOG_FILE="$LOG_DIR/ramalama.log"
LOGROTATE_CONFIG="/workspace/data/logs/logrotate.conf"

# Функция для инициализации логирования
init_logging() {
    mkdir -p "$LOG_DIR"
    
    # Настройка logrotate для автоматической ротации логов
    cat > "$LOGROTATE_CONFIG" << 'EOF'
/workspace/data/logs/ramalama.log {
    daily
    rotate 30
    compress
    missingok
    notifempty
    sharedscripts
    postrotate
        # Перезапуск процесса логирования при ротации
        echo "$(date): Log rotation completed" >> /workspace/data/logs/ramalama.log
    endscript
}
EOF
    
    echo "$(date): Logging system initialized" >> "$LOG_FILE"
}

# Функция для запуска RamaLama с сохранением логов
run_with_logging() {
    local command="$*"
    
    # Создаем timestamped log files для каждой сессии
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local session_log="$LOG_DIR/ramalama_session_${timestamp}.log"
    
    echo "$(date): Starting RamaLama session" >> "$LOG_FILE"
    echo "$(date): Command: $command" >> "$LOG_FILE"
    
    # Запускаем команду и перенаправляем логи в файл
    if [ -t 0 ]; then
        # Интерактивный режим - показываем логи в реальном времени и сохраняем
        stdbuf -oL -eL $command 2>&1 | tee -a "$LOG_FILE" | tee -a "$session_log"
    else
        # Неинтерактивный режим - только сохраняем в файлы
        stdbuf -oL -eL $command >> "$LOG_FILE" 2>&1
        cat "$LOG_FILE" >> "$session_log"
    fi
    
    local exit_code=$?
    echo "$(date): Session completed with exit code: $exit_code" >> "$LOG_FILE"
    
    return $exit_code
}

# Функция для просмотра логов
show_logs() {
    local tail_lines="${1:-100}"
    
    if [ -f "$LOG_FILE" ]; then
        echo "=== Последние $tail_lines строк логов ==="
        tail -n "$tail_lines" "$LOG_FILE"
        echo ""
        echo "Полный файл: $LOG_FILE"
        echo "Размер файла: $(du -h "$LOG_FILE" | cut -f1)"
    else
        echo "Файл логов не найден: $LOG_FILE"
        echo "Инициализируйте логирование командой: init_logging"
    fi
}

# Функция для очистки старых логов
clean_logs() {
    echo "Очистка старых логов..."
    
    # Оставляем последние 7 дней логов
    find "$LOG_DIR" -name "ramalama_*.log" -mtime +7 -delete 2>/dev/null || true
    
    # Показываем статистику
    local log_count=$(find "$LOG_DIR" -name "ramalama_*.log" | wc -l)
    local total_size=$(du -sh "$LOG_DIR" | cut -f1)
    
    echo "Файлов логов: $log_count"
    echo "Общий размер: $total_size"
}

# Функция для мониторинга логов в реальном времени
tail_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "Мониторинг логов (Ctrl+C для выхода)..."
        tail -f "$LOG_FILE"
    else
        echo "Файл логов не найден: $LOG_FILE"
    fi
}

# Основная логика
main() {
    case "${1:-help}" in
        init)
            init_logging
            echo "Логирование инициализировано"
            ;;
        run)
            shift
            if [ $# -eq 0 ]; then
                echo "Использование: $0 run <команда ramalama>"
                exit 1
            fi
            init_logging
            run_with_logging "$@"
            ;;
        show|logs)
            show_logs "${2:-100}"
            ;;
        clean)
            clean_logs
            ;;
        tail|follow)
            tail_logs
            ;;
        status)
            if [ -f "$LOG_FILE" ]; then
                echo "Логи активны: $LOG_FILE"
                echo "Размер: $(du -h "$LOG_FILE" | cut -f1)"
                echo "Изменен: $(stat -c "%y" "$LOG_FILE")"
            else
                echo "Логи не инициализированы"
            fi
            ;;
        help|--help|-h)
            cat << EOF
RamaLama Log Manager - Управление логами

Использование:
  $0 init                    Инициализировать систему логирования
  $0 run <команда>           Запустить команду с сохранением логов
  $0 show [N]                Показать последние N строк логов (по умолчанию 100)
  $0 clean                   Очистить старые логи
  $0 tail                    Мониторинг логов в реальном времени
  $0 status                  Показать статус логирования
  $0 help                    Показать эту справку

Примеры:
  $0 run pull tinyllama      Скачать модель с сохранением логов
  $0 run serve tinyllama     Запустить сервер с логированием
  $0 show 50                 Показать последние 50 строк
  $0 tail                    Следить за логами в реальном времени

Файлы логов:
  Основной: $LOG_FILE
  Сессий:   $LOG_DIR/ramalama_session_*.log
EOF
            ;;
        *)
            echo "Неизвестная команда: $1"
            echo "Используйте '$0 help' для справки"
            exit 1
            ;;
    esac
}

main "$@"