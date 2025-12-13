#!/bin/bash

# ============================================
# RamaLama Quick Examples (Variant B)
# Примеры использования оптимизированные
# ============================================

set -euo pipefail

# Цвета
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_example() {
    echo ""
    echo -e "${YELLOW}▶ $1${NC}"
    echo -e "${GREEN}$ $2${NC}"
}

main() {
    clear
    
    echo -e "${CYAN}"
    cat << "EOF"
╔════════════════════════════════════════════╗
║ RamaLama - Quick Start Examples (Variant B)║
╚════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    
    # ============================================
    # БЫСТРЫЙ СТАРТ
    # ============================================
    
    print_section "🚀 QUICK START"
    
    print_example "Build image (first time)" \
        "make buildx"
    echo "📝 Takes 5-10 min with uv caching"
    
    print_example "Start container" \
        "make up"
    echo "📝 Container runs in background"
    
    print_example "Check health" \
        "make health"
    echo "📝 Verify container is ready"
    
    print_example "Download a model" \
        "make pull MODEL=tinyllama"
    echo "📝 Small model for testing (~2GB)"
    
    print_example "Run interactive chat" \
        "make run MODEL=tinyllama"
    echo "📝 Type your questions in interactive mode"
    
    # ============================================
    # ЗАПУСК СЕРВЕРА
    # ============================================
    
    print_section "🌐 SERVER MODE (API)"
    
    print_example "Start server" \
        "make serve MODEL=tinyllama PORT=8080"
    echo "📝 Accessible at http://localhost:8080"
    
    print_example "Test server health" \
        "curl http://localhost:8080/health"
    echo "📝 Returns JSON with server status"
    
    print_example "Chat via API" \
        "curl -X POST http://localhost:8080/v1/chat/completions \\\\"
    echo "  -H 'Content-Type: application/json' \\\\"
    echo "  -d '{\"messages\": [{\"role\": \"user\", \"content\": \"Hello!\"}]}'"
    
    # ============================================
    # УПРАВЛЕНИЕ МОДЕЛЯМИ
    # ============================================
    
    print_section "🤖 MODEL MANAGEMENT"
    
    print_example "List available models" \
        "make list"
    echo "📝 Shows all downloaded models"
    
    print_example "Download Llama 3.2 (1B)" \
        "make pull MODEL=llama3.2:1b"
    echo "📝 Recommended: good quality/size balance"
    
    print_example "Check model storage" \
        "./check-models.sh"
    echo "📝 Verify Variant B persistence"
    
    print_example "Remove model" \
        "docker-compose exec ramalama ramalama rm tinyllama"
    echo "📝 Frees up space on host"
    
    # ============================================
    # ЛОГИРОВАНИЕ И ОТЛАДКА
    # ============================================
    
    print_section "📋 LOGGING & MONITORING"
    
    print_example "View logs" \
        "make logs"
    echo "📝 Real-time container logs"
    
    print_example "Manage log files" \
        "./log-manager.sh status"
    echo "📝 Check log storage info"
    
    print_example "Monitor system" \
        "./monitor.sh -s"
    echo "📝 One-time snapshot of system state"
    
    print_example "Interactive monitoring" \
        "./monitor.sh -i"
    echo "📝 Auto-refresh dashboard (Ctrl+C to exit)"
    
    # ============================================
    # ИНТЕРАКТИВНАЯ РАБОТА
    # ============================================
    
    print_section "💻 INTERACTIVE SHELL"
    
    print_example "Enter container shell" \
        "make shell"
    echo "📝 Full bash access inside container"
    
    print_example "Example commands in shell:" \
        ""
    echo "  ramalama list           # List models"
    echo "  ramalama info           # Show config"
    echo "  ramalama run tinyllama  # Chat mode"
    
    # ============================================
    # BATCH ОБРАБОТКА
    # ============================================
    
    print_section "⚡ BATCH PROCESSING"
    
    print_example "Process text file" \
        "cat questions.txt | make run MODEL=tinyllama"
    echo "📝 Pipe questions into model"
    
    print_example "Save results to file" \
        "echo 'What is AI?' | make run MODEL=tinyllama > response.txt"
    echo "📝 Redirect output to file"
    
    # ============================================
    # ПОЛЕЗНЫЕ КОМАНДЫ
    # ============================================
    
    print_section "🔧 USEFUL COMMANDS"
    
    print_example "All available commands" \
        "make help"
    echo "📝 Shows all make targets"
    
    print_example "Check config" \
        "make config"
    echo "📝 Display ./config/.env contents"
    
    print_example "Test setup" \
        "make test"
    echo "📝 Quick system sanity checks"
    
    print_example "Stop container" \
        "make down"
    echo "📝 Clean shutdown"
    
    print_example "Rebuild image" \
        "make rebuild"
    echo "📝 Clean build without cache"
    
    # ============================================
    # ВАРИАНТЫ Б ОСОБЕННОСТИ
    # ============================================
    
    print_section "✨ VARIANT B FEATURES"
    
    echo ""
    echo -e "${GREEN}✓ Models${NC} persisted on host ./models (automatic backups)"
    echo -e "${GREEN}✓ Logs${NC}    local in container (no disk clutter on host)"
    echo -e "${GREEN}✓ Data${NC}    local in container (ephemeral)"
    echo -e "${GREEN}✓ Cache${NC}   local in container (fast performance)"
    echo -e "${GREEN}✓ Config${NC}  from ./config/.env (environment variables)"
    echo ""
    echo "🎯 Perfect for: Development, testing, model experimentation"
    echo ""
    
    # ============================================
    # ПРИМЕРЫ СЦЕНАРИЕВ
    # ============================================
    
    print_section "📚 PRACTICAL SCENARIOS"
    
    echo ""
    echo -e "${YELLOW}Scenario 1: Document Summarization${NC}"
    echo "$ cat report.pdf | pdftotext - - | make run MODEL=llama3.2:1b"
    echo ""
    
    echo -e "${YELLOW}Scenario 2: Code Generation${NC}"
    echo "$ echo 'Write Python function to reverse a string' | \\\\"
    echo "  make run MODEL=llama3.2:1b"
    echo ""
    
    echo -e "${YELLOW}Scenario 3: API Server for App${NC}"
    echo "$ make serve MODEL=llama3.2:1b PORT=8000 &"
    echo "$ curl http://localhost:8000/v1/chat/completions -d '{...}'"
    echo ""
    
    echo -e "${YELLOW}Scenario 4: Batch Document Processing${NC}"
    echo "$ for file in documents/*.txt; do"
    echo "    make run MODEL=llama3.2:1b < \"\$file\" > results/\$(basename \$file)"
    echo "  done"
    echo ""
    
    # ============================================
    # TIPS & TRICKS
    # ============================================
    
    print_section "💡 TIPS & TRICKS"
    
    echo ""
    echo -e "${GREEN}Tip 1:${NC} Create shell aliases for faster workflow"
    echo "  alias rlm='docker-compose exec ramalama ramalama'"
    echo "  alias rlm-serve='make serve'"
    echo ""
    
    echo -e "${GREEN}Tip 2:${NC} Use smaller models for faster responses"
    echo "  tinyllama      - Fastest (242M, 2GB)"
    echo "  llama3.2:1b    - Balanced (1B, 3GB)"
    echo "  llama3.2:3b    - Quality (3B, 7GB)"
    echo ""
    
    echo -e "${GREEN}Tip 3:${NC} Monitor system while running"
    echo "  ./monitor.sh -s        # One-time snapshot"
    echo "  ./monitor.sh -i        # Interactive mode"
    echo "  REFRESH_INTERVAL=3 ./monitor.sh -i  # Faster updates"
    echo ""
    
    echo -e "${GREEN}Tip 4:${NC} Save frequently used prompts"
    echo "  mkdir prompts/"
    echo "  echo 'Summarize in 3 bullet points' > prompts/summarize.txt"
    echo "  cat doc.txt prompts/summarize.txt | make run"
    echo ""
    
    # ============================================
    # TROUBLESHOOTING
    # ============================================
    
    print_section "🔍 TROUBLESHOOTING"
    
    echo ""
    echo -e "${YELLOW}Q: Container won't start?${NC}"
    echo "A: Check logs with: make logs"
    echo "   Or rebuild: make rebuild"
    echo ""
    
    echo -e "${YELLOW}Q: Models not persisting?${NC}"
    echo "A: Check with: ./check-models.sh"
    echo "   Verify mount: docker inspect ramalama"
    echo ""
    
    echo -e "${YELLOW}Q: Slow responses?${NC}"
    echo "A: Check system resources: ./monitor.sh -s"
    echo "   Try smaller model: make serve MODEL=tinyllama"
    echo ""
    
    echo -e "${YELLOW}Q: Out of disk space?${NC}"
    echo "A: Clean old logs: ./log-manager.sh clean"
    echo "   Remove unused models: make list && rm models/unused.gguf"
    echo ""
    
    # ============================================
    # ДОПОЛНИТЕЛЬНО
    # ============================================
    
    print_section "📖 MORE HELP"
    
    echo ""
    echo "Documentation files:"
    echo "  README.md              - Full documentation"
    echo "  config/.env            - Configuration"
    echo "  Makefile               - All available targets"
    echo "  Dockerfile             - Image specification"
    echo "  docker-compose.yml     - Container setup"
    echo ""
    
    echo "Quick help:"
    echo "  make help              - Show all make targets"
    echo "  ./log-manager.sh help  - Log management help"
    echo "  ./monitor.sh --help    - Monitor help"
    echo "  ./setup-dirs.sh        - Check workspace structure"
    echo ""
    
    echo -e "${GREEN}🚀 Happy experimenting with RamaLama!${NC}"
    echo ""
}

main "$@"
