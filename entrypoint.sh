#!/bin/bash
set -e

echo "🚀 Запуск RamaLama в Docker"
echo "📁 Модели сохраняются в: /workspace/models"
echo "📁 Данные хранятся в: /workspace/data"
echo ""

# Настраиваем proxy если установлены
if [ -n "$HTTP_PROXY" ]; then
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTPS_PROXY"
    echo "📡 Используется proxy: $HTTP_PROXY"
else
    echo "📡 Proxy: none"
fi

# Отключаем лишние прокси переменные
export PYTHONWARNINGS="ignore"
unset ftp_proxy
unset FTP_PROXY
unset all_proxy
unset ALL_PROXY

# Настройка путей
export RAMALAMA_MODELS_PATH="${RAMALAMA_MODELS_PATH:-/workspace/models}"

# Проверяем и создаем директории
mkdir -p /workspace/models /workspace/data

# Выводим информацию о монтировании
echo "=== Проверка монтирования директорий ==="
echo "Содержимое /workspace/models:"
ls -la /workspace/models/ 2>/dev/null || echo "Директория пуста или не доступна"
echo ""
echo "Содержимое /workspace/data:"
ls -la /workspace/data/ 2>/dev/null || echo "Директория пуста или не доступна"
echo "========================================"
echo ""

# Проверяем, есть ли уже скачанные модели
echo "=== Существующие модели ==="
existing_models=$(find /workspace/models -name "*.gguf" -o -name "*.bin" 2>/dev/null | head -10 || true)
if [ ! -z "$existing_models" ]; then
    echo "$existing_models" | while read model; do
        if [ ! -z "$model" ]; then
            size=$(du -h "$model" 2>/dev/null | cut -f1 || echo "unknown")
            echo "   📦 $(basename "$model") ($size)"
        fi
    done
else
    echo "📭 Моделей не найдено"
fi
echo ""

exec 3>&1
exec 4>&2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3
echo "  RamaLama Docker Environment" >&3
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3
echo "Models path: $RAMALAMA_MODELS_PATH" >&3
echo "Proxy: ${HTTP_PROXY:-none}" >&3
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3

# Запускаем команду
echo "▶️  Выполнение: ramalama $@" >&3
echo "" >&3

# Для команд pull/run добавляем прогресс и проверку результата
if [[ "$1" == "pull" || "$1" == "run" ]]; then
    echo "💾 Скачивание/загрузка модели..." >&3
    echo "   Файлы будут сохранены в: /workspace/models/" >&3
    echo "   Прогресс отображается в логах выше" >&3
    echo "" >&3
    
    # Запускаем команду и сохраняем вывод
    output=$(ramalama "$@" 2>&1)
    exit_code=$?
    
    # Выводим результат
    echo "$output" | grep -v "INFO:ramalama:Using proxy" >&3
    
    # Проверяем результат скачивания
    if [ $exit_code -eq 0 ] && [ "$1" = "pull" ] && [ ! -z "$2" ]; then
        echo "" >&3
        echo "🔍 Проверка результата скачивания:" >&3
        sleep 2  # Даем время файлам записаться
        downloaded_files=$(find /workspace/models -name "*$(basename "$2")*" -type f 2>/dev/null || true)
        if [ ! -z "$downloaded_files" ]; then
            echo "   ✅ Модель успешно скачана!" >&3
            echo "$downloaded_files" | while read file; do
                if [ ! -z "$file" ]; then
                    size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "unknown")
                    echo "      📍 $(basename "$file") ($size)" >&3
                fi
            done
            echo "      📂 Сохранено в: /workspace/models/" >&3
        else
            echo "   ⚠️  Модель не найдена в /workspace/models/" >&3
            echo "      Проверьте логи выше на наличие ошибок" >&3
        fi
    fi
    
    exit $exit_code
else
    # Для остальных команд просто запускаем
    exec ramalama "$@" 2>&1 | grep -v "INFO:ramalama:Using proxy" | cat >&3
fi
