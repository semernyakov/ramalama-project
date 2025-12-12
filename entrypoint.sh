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
find /workspace/models -name "*.gguf" -o -name "*.bin" 2>/dev/null | head -10 || echo "Моделей не найдено"
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

# Для команд pull добавляем прогресс
if [[ "$1" == "pull" || "$1" == "run" ]]; then
    echo "💾 Скачивание/загрузка модели..." >&3
    echo "   Файлы будут сохранены в: /workspace/models/" >&3
    echo "   Прогресс отображается в логах выше" >&3
    echo "" >&3
fi

# Фильтруем логи прокси
exec ramalama "$@" 2>&1 | grep -v "INFO:ramalama:Using proxy" | cat >&3
