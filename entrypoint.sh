#!/bin/bash
set -e

# Настройка прокси если переменные заданы
if [ ! -z "$HTTP_PROXY" ]; then
    export http_proxy="$HTTP_PROXY"
    export https_proxy="$HTTP_PROXY"
    echo "✓ Proxy configured: $HTTP_PROXY"
fi

# Расширенный no_proxy
export no_proxy="localhost,127.0.0.0/8,::1,host.docker.internal"
export NO_PROXY="$no_proxy"

# Отключаем лишние прокси переменные
export PYTHONWARNINGS="ignore"
unset ftp_proxy
unset FTP_PROXY
unset all_proxy
unset ALL_PROXY

# Настройка путей
export RAMALAMA_MODELS_PATH="${RAMALAMA_MODELS_PATH:-/workspace/models}"

exec 3>&1
exec 4>&2

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3
echo "  RamaLama Docker Environment" >&3
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3
echo "Models path: $RAMALAMA_MODELS_PATH" >&3
echo "Proxy: ${HTTP_PROXY:-none}" >&3
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&3

# Фильтруем логи прокси
exec ramalama "$@" 2>&1 | grep -v "INFO:ramalama:Using proxy" | cat >&3
