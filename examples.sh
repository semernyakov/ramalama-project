#!/bin/bash

# Примеры использования RamaLama

set -e

# Цвета
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_example() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Команда:${NC} $2"
    echo ""
}

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   RamaLama - Примеры использования         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""

# ============================================
# БАЗОВЫЕ ПРИМЕРЫ
# ============================================

echo -e "${BLUE}📚 БАЗОВЫЕ ОПЕРАЦИИ${NC}"
echo ""

print_example "Пример 1: Проверка версии" \
    "./ramalama.sh version"

print_example "Пример 2: Информация о системе" \
    "./ramalama.sh info"

print_example "Пример 3: Список локальных моделей" \
    "./ramalama.sh list"

# ============================================
# РАБОТА С МОДЕЛЯМИ
# ============================================

echo -e "${BLUE}🤖 РАБОТА С МОДЕЛЯМИ${NC}"
echo ""

print_example "Пример 4: Скачать маленькую модель" \
    "./ramalama.sh pull tinyllama"

print_example "Пример 5: Скачать модель Llama 3.2 (1B)" \
    "./ramalama.sh pull llama3.2:1b"

print_example "Пример 6: Скачать модель Phi-3 Mini" \
    "./ramalama.sh pull phi3:mini"

print_example "Пример 7: Удалить модель" \
    "./ramalama.sh rm tinyllama"

# ============================================
# ИНТЕРАКТИВНЫЙ РЕЖИМ
# ============================================

echo -e "${BLUE}💬 ИНТЕРАКТИВНЫЙ ЧАТ${NC}"
echo ""

print_example "Пример 8: Запустить модель в интерактивном режиме" \
    "./ramalama.sh run llama3.2:1b"

print_example "Пример 9: Запустить с параметрами температуры" \
    "./ramalama.sh run llama3.2:1b --temperature 0.7"

print_example "Пример 10: Запустить с системным промптом" \
    "./ramalama.sh run llama3.2:1b --system 'You are a helpful coding assistant'"

# ============================================
# РЕЖИМ СЕРВЕРА
# ============================================

echo -e "${BLUE}🌐 РЕЖИМ СЕРВЕРА (API)${NC}"
echo ""

print_example "Пример 11: Запустить сервер на порту 8080" \
    "./ramalama.sh serve llama3.2:1b --port 8080"

print_example "Пример 12: Запустить сервер с ограничением контекста" \
    "./ramalama.sh serve llama3.2:1b --port 8080 --context-size 2048"

echo -e "${YELLOW}После запуска сервера, тестируйте через curl:${NC}"
echo ""
echo -e "${GREEN}# Тест здоровья сервера${NC}"
echo "curl http://localhost:8080/health"
echo ""
echo -e "${GREEN}# Запрос к модели${NC}"
echo 'curl http://localhost:8080/v1/chat/completions \'
echo '  -H "Content-Type: application/json" \'
echo '  -d '"'"'{"messages": [{"role": "user", "content": "Hello!"}]}'"'"
echo ""

# ============================================
# НЕИНТЕРАКТИВНЫЙ РЕЖИМ
# ============================================

echo -e "${BLUE}⚡ НЕИНТЕРАКТИВНЫЙ РЕЖИМ${NC}"
echo ""

print_example "Пример 13: Одноразовый запрос" \
    "echo 'What is the capital of France?' | ./ramalama.sh run llama3.2:1b --no-interactive"

print_example "Пример 14: Обработка файла" \
    "cat input.txt | ./ramalama.sh run llama3.2:1b --no-interactive > output.txt"

print_example "Пример 15: Скрипт для обработки" \
    "./ramalama.sh -- run llama3.2:1b --no-interactive < questions.txt > answers.txt"

# ============================================
# РАБОТА С DOCKER
# ============================================

echo -e "${BLUE}🐳 РАБОТА С DOCKER${NC}"
echo ""

print_example "Пример 16: Открыть bash в контейнере" \
    "./ramalama.sh shell"

print_example "Пример 17: Проверить логи Docker" \
    "docker-compose logs"

print_example "Пример 18: Перезапустить контейнер" \
    "docker-compose restart"

print_example "Пример 19: Остановить все контейнеры" \
    "docker-compose down"

# ============================================
# ПРОДВИНУТЫЕ ПРИМЕРЫ
# ============================================

echo -e "${BLUE}🚀 ПРОДВИНУТОЕ ИСПОЛЬЗОВАНИЕ${NC}"
echo ""

print_example "Пример 20: Прямой вызов ramalama команд" \
    "./ramalama.sh -- list --verbose"

print_example "Пример 21: Использование через make" \
    "make pull MODEL=llama3.2:1b"

print_example "Пример 22: Запуск с make" \
    "make run MODEL=llama3.2:1b"

print_example "Пример 23: Сервер через make" \
    "make serve MODEL=llama3.2:1b PORT=8080"

# ============================================
# МНОЖЕСТВЕННЫЕ МОДЕЛИ
# ============================================

echo -e "${BLUE}🔄 РАБОТА С НЕСКОЛЬКИМИ МОДЕЛЯМИ${NC}"
echo ""

echo -e "${YELLOW}Пример 24: Скачать и протестировать несколько моделей${NC}"
echo ""
cat << 'EOF'
# Скачиваем модели
./ramalama.sh pull tinyllama
./ramalama.sh pull llama3.2:1b
./ramalama.sh pull phi3:mini

# Смотрим список
./ramalama.sh list

# Тестируем каждую
for model in tinyllama llama3.2:1b phi3:mini; do
    echo "Testing $model..."
    echo "What is 2+2?" | ./ramalama.sh run $model --no-interactive
done
EOF
echo ""

# ============================================
# АВТОМАТИЗАЦИЯ
# ============================================

echo -e "${BLUE}🤖 АВТОМАТИЗАЦИЯ${NC}"
echo ""

echo -e "${YELLOW}Пример 25: Скрипт для автоматической обработки${NC}"
echo ""
cat << 'EOF'
#!/bin/bash
# auto-process.sh

MODEL="llama3.2:1b"
INPUT_DIR="./data/input"
OUTPUT_DIR="./data/output"

for file in "$INPUT_DIR"/*.txt; do
    filename=$(basename "$file")
    echo "Processing: $filename"
    
    cat "$file" | \
        ./ramalama.sh run $MODEL --no-interactive \
        > "$OUTPUT_DIR/${filename%.txt}_result.txt"
done

echo "All files processed!"
EOF
echo ""

echo -e "${YELLOW}Пример 26: Мониторинг работы модели${NC}"
echo ""
cat << 'EOF'
#!/bin/bash
# monitor-model.sh

MODEL="llama3.2:1b"
PORT=8080

# Запускаем сервер в фоне
./ramalama.sh serve $MODEL --port $PORT &
SERVER_PID=$!

# Ждем запуска
sleep 5

# Мониторим
while true; do
    if curl -s http://localhost:$PORT/health > /dev/null; then
        echo "✓ Server is running"
    else
        echo "✗ Server is down"
    fi
    sleep 10
done
EOF
echo ""

# ============================================
# ПРАКТИЧЕСКИЕ СЦЕНАРИИ
# ============================================

echo -e "${BLUE}💼 ПРАКТИЧЕСКИЕ СЦЕНАРИИ${NC}"
echo ""

echo -e "${YELLOW}Сценарий 1: Анализ документов${NC}"
echo ""
cat << 'EOF'
# Загрузить модель
./ramalama.sh pull llama3.2:1b

# Анализировать документ
cat report.txt | \
    ./ramalama.sh run llama3.2:1b --no-interactive \
    --system "Summarize this document in 3 key points" \
    > summary.txt
EOF
echo ""

echo -e "${YELLOW}Сценарий 2: Чат-бот для поддержки${NC}"
echo ""
cat << 'EOF'
# Запустить сервер
./ramalama.sh serve llama3.2:1b --port 8080 \
    --system "You are a helpful customer support assistant"

# В другом терминале - интерфейс
while true; do
    read -p "You: " question
    curl -s http://localhost:8080/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"messages\": [{\"role\": \"user\", \"content\": \"$question\"}]}" \
        | jq -r '.choices[0].message.content'
done
EOF
echo ""

echo -e "${YELLOW}Сценарий 3: Генерация кода${NC}"
echo ""
cat << 'EOF'
# Запросить генерацию кода
echo "Write a Python function to calculate fibonacci numbers" | \
    ./ramalama.sh run llama3.2:1b --no-interactive \
    --system "You are an expert programmer. Provide only code, no explanations." \
    > fibonacci.py
EOF
echo ""

# ============================================
# СОВЕТЫ И ХИТРОСТИ
# ============================================

echo -e "${BLUE}💡 СОВЕТЫ И ХИТРОСТИ${NC}"
echo ""

echo -e "${GREEN}Совет 1:${NC} Используйте алиасы для часто используемых команд"
echo "alias rlm='./ramalama.sh'"
echo "alias rlm-run='./ramalama.sh run llama3.2:1b'"
echo ""

echo -e "${GREEN}Совет 2:${NC} Храните промпты в отдельных файлах"
echo "cat prompts/summarize.txt | ./ramalama.sh run llama3.2:1b"
echo ""

echo -e "${GREEN}Совет 3:${NC} Используйте параметры для контроля генерации"
echo "./ramalama.sh run MODEL --temperature 0.7 --top-p 0.9 --max-tokens 500"
echo ""

echo -e "${GREEN}Совет 4:${NC} Логируйте результаты для анализа"
echo "./ramalama.sh run MODEL 2>&1 | tee -a logs/chat-\$(date +%Y%m%d).log"
echo ""

# ============================================
# ЗАКЛЮЧЕНИЕ
# ============================================

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Дополнительная информация                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Документация:${NC}     ./ramalama.sh help"
echo -e "${YELLOW}Быстрый тест:${NC}     ./quick-test.sh"
echo -e "${YELLOW}Все команды make:${NC} make help"
echo ""
echo -e "${CYAN}Приятной работы с RamaLama! 🚀${NC}"
echo ""
