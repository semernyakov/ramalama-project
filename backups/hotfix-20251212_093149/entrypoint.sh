#!/bin/bash
set -e

# Настройка прокси если переменные заданы
# Используем только HTTP/HTTPS прокси, убираем socks чтобы избежать конфликтов
if [ ! -z "$HTTP_PROXY" ]; then
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTP_PROXY"
    echo "✓ Proxy configured: $HTTP_PROXY"
fi

# Расширенный no_proxy для избежания проблем с локальными соединениями
export no_proxy="localhost,127.0.0.0/8,::1,host.docker.internal"
export NO_PROXY="$no_proxy"

# Отключаем избыточное логирование ramalama
export RAMALAMA_LOG_LEVEL="${RAMALAMA_LOG_LEVEL:-ERROR}"

# Настройка путей для моделей
export RAMALAMA_MODELS_PATH="${RAMALAMA_MODELS_PATH:-/workspace/models}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  RamaLama Docker Environment"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Models path: $RAMALAMA_MODELS_PATH"
echo "Log level: $RAMALAMA_LOG_LEVEL"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Запуск ramalama с переданными аргументами
exec ramalama "$@"
