#!/bin/bash

# Скрипт для управления логами RamaLama
# Автоматически сохраняет логи в файлы

set -e

# Определяем логическую директорию (работает и внутри, и снаружи контейнера)
if [ -d "/workspace/logs" ]; then
    # Внутри контейнера
    LOG_DIR="/workspace/logs"
elif [ -d "./logs" ]; then
    # Снаружи контейнера
    LOG_DIR="./logs"
else
    LOG_DIR="./logs"
fi

LOG_FILE="$LOG_DIR/ramalama.log"

# Функция для запуска RamaLama с сохранением логов сессий
run_with_logging() {
    local command="$*"
    
    # Создаем timestamped log files для каждой сессии
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local session_log="$LOG_DIR/sessions/ramalama_session_${timestamp}.log"
    
    echo "$(date): Starting RamaLama session" >> "$LOG_FILE"
    echo "$(date): Command: $command" >> "$LOG_FILE"
    
    # Создаем директорию sessions если не существует
    mkdir -p "$LOG_DIR/sessions"
    
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

# Функция для инициализации логирования
init_logging() {
    mkdir -p "$LOG_DIR"
    echo "$(date): Logging system initialized" >> "$LOG_FILE"
    echo "✓ Логирование инициализировано: $LOG_FILE"
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
        echo "Инициализируйте логирование командой: ./log-manager.sh init"
    fi
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

# Функция для очистки старых логов
clean_logs() {
    echo "Очистка старых логов..."
    
    # Оставляем последние 7 дней основного файла логов
    find "$LOG_DIR" -name "ramalama.log" -mtime +7 -delete 2>/dev/null || true
    
    # Очищаем старые сессии (старше 30 дней)
    mkdir -p "$LOG_DIR/sessions"
    find "$LOG_DIR/sessions" -name "ramalama_session_*.log" -mtime +30 -delete 2>/dev/null || true
    
    # Показываем статистику
    local main_log_count=$(find "$LOG_DIR" -name "ramalama.log" | wc -l)
    local session_count=$(find "$LOG_DIR/sessions" -name "ramalama_session_*.log" | wc -l)
    local total_size=$(du -sh "$LOG_DIR" | cut -f1)
    
    echo "Основных логов: $main_log_count"
    echo "Сессий: $session_count"
    echo "Общий размер: $total_size"
}

# Функция для показа сессий
show_sessions() {
    if [ -d "$LOG_DIR/sessions" ]; then
        echo "=== Логи сессий в $LOG_DIR/sessions/ ==="
        find "$LOG_DIR/sessions" -name "ramalama_session_*.log" -type f -exec ls -la {} \; 2>/dev/null || echo "Файлы сессий не найдены"
        echo ""
        echo "Всего сессий: $(find "$LOG_DIR/sessions" -name "ramalama_session_*.log" | wc -l)"
        echo "Размер: $(du -sh "$LOG_DIR/sessions" | cut -f1)"
    else
        echo "Директория сессий не найдена: $LOG_DIR/sessions"
        echo "Запустите сессию командой: ./log-manager.sh run <команда>"
    fi
}

# Функция для проверки статуса логирования
status_logs() {
    if [ -f "$LOG_FILE" ]; then
        echo "✓ Логи активны: $LOG_FILE"
        echo "  Размер: $(du -h "$LOG_FILE" | cut -f1)"
        echo "  Изменен: $(stat -c "%y" "$LOG_FILE" 2>/dev/null || echo "неизвестно")"
        echo "  Строк: $(wc -l < "$LOG_FILE")"
    else
        echo "✗ Логи не инициализированы"
        echo "  Путь: $LOG_FILE"
        echo "  Создайте командой: ./log-manager.sh init"
    fi
}

# Основная логика
main() {
    case "${1:-help}" in
        init)
            init_logging
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
        sessions)
            show_sessions
            ;;
        tail|follow)
            tail_logs
            ;;
        status)
            status_logs
            ;;
        help|--help|-h)
            cat << 'HELP'
RamaLama Log Manager - Управление логами

Использование:
  ./log-manager.sh init              Инициализировать систему логирования
  ./log-manager.sh run <команда>     Запустить команду с сохранением сессии
  ./log-manager.sh show [N]          Показать последние N строк логов (по умолчанию 100)
  ./log-manager.sh sessions          Показать логи всех сессий
  ./log-manager.sh clean             Очистить старые логи и сессии
  ./log-manager.sh tail              Мониторинг логов в реальном времени
  ./log-manager.sh status            Показать статус логирования
  ./log-manager.sh help              Показать эту справку

Примеры:
  ./log-manager.sh init              Инициализировать логирование
  ./log-manager.sh run pull tinyllama Скачать модель с сохранением сессии
  ./log-manager.sh show 50           Показать последние 50 строк
  ./log-manager.sh sessions          Показать все сессии
  ./log-manager.sh tail              Следить за логами в реальном времени

Файлы логов:
  Основной: ./logs/ramalama.log
  Сессии:   ./logs/sessions/ramalama_session_*.log

Директории:
  Логи: ./logs/
  Сессии: ./logs/sessions/
HELP
            ;;
        *)
            echo "Неизвестная команда: $1"
            echo "Используйте '$0 help' для справки"
            exit 1
            ;;
    esac
}

main "$@"
