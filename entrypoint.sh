#!/bin/bash
set -euo pipefail

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
chmod 755 "$RAMALAMA_STORE" /workspace/logs /workspace/data 2>/dev/null || true

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

# Проверяем, является ли первая команда llama-server
if [[ "$1" == "llama-server" ]]; then
    echo "▶️  Executing: llama-server with args: ${@:2}"
    echo ""
    exec /usr/local/bin/llama-server "${@:2}"
fi

# Запуск команды с фильтрацией логов прокси
echo "▶️  Executing: ramalama $@"
echo ""

# Фильтруем INFO логи о прокси
exec ramalama "$@" 2>&1 | grep -v "INFO:ramalama:Using proxy" || true
