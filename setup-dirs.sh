#!/bin/bash

# Скрипт для создания и проверки структуры директорий RamaLama

set -e

echo "🔧 Проверка структуры директорий RamaLama"
echo ""

# Проверяем и создаем основные директории
directories=("models" "logs" "data" "backups" "config" "cache")

echo "📁 Создание директорий:"
for dir in "${directories[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        echo "  ✅ Создана: $dir/"
    else
        echo "  ℹ️  Существует: $dir/"
    fi
done

echo ""
echo "🔍 Проверка монтирования Docker:"

# Проверяем директории на хосте
if [ -d "models" ]; then
    model_count=$(find models -type f 2>/dev/null | wc -l)
    model_size=$(du -sh models 2>/dev/null | cut -f1)
    echo "  📂 models/ - $model_count файлов ($model_size)"
else
    echo "  ❌ models/ не найдена"
fi

if [ -d "data" ]; then
    data_size=$(du -sh data 2>/dev/null | cut -f1)
    echo "  📂 data/ - размер: $data_size"
else
    echo "  ❌ data/ не найдена"
fi

if [ -d "logs" ]; then
    logs_count=$(find logs -type f 2>/dev/null | wc -l)
    logs_size=$(du -sh logs 2>/dev/null | cut -f1)
    echo "  📂 logs/ - $logs_count файлов ($logs_size)"
else
    echo "  ❌ logs/ не найдена"
fi

if [ -d "config" ]; then
    config_files=$(find config -type f 2>/dev/null | wc -l)
    echo "  📂 config/ - $config_files файлов"
else
    echo "  ❌ config/ не найдена"
fi

if [ -d "cache" ]; then
    cache_size=$(du -sh cache 2>/dev/null | cut -f1)
    echo "  📂 cache/ - размер: $cache_size"
else
    echo "  ❌ cache/ не найдена"
fi

echo ""
echo "🐳 Проверка Docker volumes:"

# Проверяем наличие образов
if docker images | grep -q ramalama; then
    echo "  ✅ Docker образ ramalama найден"
else
    echo "  ⚠️  Docker образ ramalama не найден - запустите ./ramalama.sh build"
fi

echo ""
echo "🔧 Рекомендации:"
echo "  • Директории монтируются в контейнер как volumes"
echo "  • Модели сохраняются в models/ на хосте"
echo "  • Логи сохраняются в logs/ на хосте"
echo "  • Пользовательские данные сохраняются в data/ на хосте"
echo "  • Кэш сохраняется в cache/ на хосте"
echo "  • Конфигурации хранятся в config/ на хосте"
echo "  • Бэкапы сохраняются в backups/ директории"
echo ""
echo "✅ Структура директорий готова к работе!"