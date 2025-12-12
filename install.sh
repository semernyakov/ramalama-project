#!/bin/bash

# Скрипт автоматической установки RamaLama Docker проекта

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ASCII Art
print_logo() {
    echo -e "${CYAN}"
    cat << "EOF"
    ____                        __                        
   / __ \____ _____ ___  ____ _/ /   ____ _____ ___  ____ 
  / /_/ / __ `/ __ `__ \/ __ `/ /   / __ `/ __ `__ \/ __ \
 / _, _/ /_/ / / / / / / /_/ / /___/ /_/ / / / / / / /_/ /
/_/ |_|\__,_/_/ /_/ /_/\__,_/_____/\__,_/_/ /_/ /_/\__,_/ 
                                                           
           Docker Installation & Setup
EOF
    echo -e "${NC}"
}

# Функции вывода
print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC} ${BOLD}$1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
}

print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Проверка системных требований
check_requirements() {
    print_header "Проверка системных требований"
    
    local missing_requirements=0
    
    # Проверка Docker
    print_step "Проверка Docker..."
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        print_success "Docker установлен: $docker_version"
        
        # Проверка запуска Docker
        if docker info &> /dev/null; then
            print_success "Docker daemon запущен"
        else
            print_error "Docker daemon не запущен"
            print_info "Запустите: sudo systemctl start docker"
            missing_requirements=1
        fi
    else
        print_error "Docker не установлен"
        print_info "Установите Docker: https://docs.docker.com/get-docker/"
        missing_requirements=1
    fi
    
    # Проверка Docker Compose
    print_step "Проверка Docker Compose..."
    if command -v docker-compose &> /dev/null; then
        local compose_version=$(docker-compose --version | cut -d' ' -f4 | tr -d ',')
        print_success "Docker Compose установлен: $compose_version"
    else
        print_error "Docker Compose не установлен"
        print_info "Установите: sudo apt install docker-compose"
        missing_requirements=1
    fi
    
    # Проверка прав доступа
    print_step "Проверка прав доступа к Docker..."
    if docker ps &> /dev/null; then
        print_success "Доступ к Docker есть"
    else
        print_warning "Нет прав для запуска Docker без sudo"
        print_info "Добавьте пользователя в группу: sudo usermod -aG docker \$USER"
        print_info "Затем перелогиньтесь: newgrp docker"
    fi
    
    # Проверка места на диске
    print_step "Проверка места на диске..."
    local available_space=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ $available_space -gt 10 ]; then
        print_success "Свободно: ${available_space}GB"
    else
        print_warning "Мало места: ${available_space}GB (рекомендуется минимум 10GB)"
    fi
    
    # Проверка памяти
    print_step "Проверка памяти..."
    if command -v free &> /dev/null; then
        local total_mem=$(free -g | grep Mem: | awk '{print $2}' 2>/dev/null || echo "0")
        if [ ! -z "$total_mem" ] && [ "$total_mem" -gt 4 ] 2>/dev/null; then
            print_success "Память: ${total_mem}GB"
        else
            print_warning "Мало памяти: ${total_mem}GB (рекомендуется минимум 4GB)"
        fi
    fi
    
    return $missing_requirements
}

# Проверка и настройка прокси
check_proxy() {
    print_header "Проверка настроек прокси"
    
    if [ ! -z "$HTTP_PROXY" ] || [ ! -z "$http_proxy" ]; then
        print_success "Обнаружены настройки прокси"
        echo ""
        print_info "HTTP_PROXY: ${HTTP_PROXY:-$http_proxy}"
        print_info "HTTPS_PROXY: ${HTTPS_PROXY:-$https_proxy}"
        print_info "NO_PROXY: ${NO_PROXY:-$no_proxy}"
        echo ""
        
        read -p "Использовать эти настройки для Docker? (Y/n): " use_proxy
        
        if [[ ! "$use_proxy" =~ ^[Nn]$ ]]; then
            return 0
        fi
    else
        print_info "Прокси не настроен (это нормально если не требуется)"
    fi
    
    return 1
}

# Создание .env файла
create_env_file() {
    print_header "Создание конфигурационного файла"
    
    if [ -f "config/.env" ]; then
        print_warning "config/.env файл уже существует"
        read -p "Перезаписать? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            print_info "Пропускаем создание config/.env"
            return
        fi
    fi
    
    print_step "Создание config/.env файла..."
    
    cat > config/.env << EOF
# RamaLama Environment Configuration
# Сгенерировано: $(date)

# НАСТРОЙКИ ПРОКСИ
HTTP_PROXY=${HTTP_PROXY:-}
HTTPS_PROXY=${HTTPS_PROXY:-}
NO_PROXY=${NO_PROXY:-localhost,127.0.0.0/8,::1}

# НАСТРОЙКИ RAMALAMA
RAMALAMA_MODELS_PATH=/workspace/models
RAMALAMA_LOG_LEVEL=ERROR

# НАСТРОЙКИ DOCKER
IMAGE_NAME=ramalama
IMAGE_TAG=latest
CONTAINER_NAME=ramalama

# МОДЕЛЬ ПО УМОЛЧАНИЮ
DEFAULT_MODEL=llama3.2:1b
DEFAULT_SERVE_PORT=8080
EOF
    
    print_success "config/.env файл создан"
}

# Создание структуры директорий
create_directories() {
    print_header "Создание структуры директорий"
    
    local dirs=("models" "logs" "data" "backups" "config")
    
    for dir in "${dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir"
            print_success "Создана: $dir/"
        else
            print_info "Существует: $dir/"
        fi
    done
    
    # Создаем дополнительные поддиректории
    print_step "Создание поддиректорий..."
    mkdir -p logs/.archived 2>/dev/null || true
    mkdir -p data/cache 2>/dev/null || true
    print_success "Поддиректории созданы"
}

# Установка прав доступа
set_permissions() {
    print_header "Установка прав доступа"
    
    local scripts=("ramalama.sh" "quick-test.sh" "entrypoint.sh" "examples.sh" "monitor.sh" "backup.sh" "log-manager.sh" "debug-download.sh" "fix-volumes.sh")
    
    for script in "${scripts[@]}"; do
        if [ -f "$script" ]; then
            chmod +x "$script"
            print_success "Права установлены: $script"
        else
            print_info "Файл не найден: $script"
        fi
    done
    
    # Права на директории
    chmod -R 755 models/ logs/ data/ config/ backups/ 2>/dev/null || true
    print_success "Права на директории установлены"
}

# Сборка Docker образа
build_image() {
    print_header "Сборка Docker образа"
    
    print_step "Запуск сборки..."
    print_info "Это может занять несколько минут..."
    
    if ./ramalama.sh build; then
        print_success "Образ успешно собран"
        return 0
    else
        print_error "Ошибка при сборке образа"
        return 1
    fi
}

# Запуск тестов
run_tests() {
    print_header "Запуск тестов"
    
    print_step "Выполнение quick-test.sh..."
    
    if ./quick-test.sh; then
        print_success "Все тесты пройдены"
        return 0
    else
        print_warning "Некоторые тесты провалены"
        print_info "Проверьте вывод выше для деталей"
        return 1
    fi
}

# Показать следующие шаги
show_next_steps() {
    print_header "Установка завершена!"
    
    echo ""
    echo -e "${GREEN}${BOLD}✓ RamaLama успешно установлен и готов к работе!${NC}"
    echo ""
    echo -e "${CYAN}Следующие шаги:${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} Проверьте работу:"
    echo "   ./ramalama.sh version"
    echo "   ./ramalama.sh info"
    echo "   ./setup-dirs.sh             - Проверка директорий"
    echo ""
    echo -e "${YELLOW}2.${NC} Скачайте модель (например, маленькую для теста):"
    echo "   ./ramalama.sh pull tinyllama"
    echo "   или"
    echo "   ./ramalama.sh pull llama3.2:1b"
    echo ""
    echo -e "${YELLOW}3.${NC} Запустите модель:"
    echo "   ./ramalama.sh run tinyllama"
    echo ""
    echo -e "${YELLOW}4.${NC} Или запустите как сервер:"
    echo "   ./ramalama.sh serve tinyllama --port 8080"
    echo ""
    echo -e "${CYAN}Полезные команды:${NC}"
    echo "   ./ramalama.sh help          - Справка"
    echo "   ./ramalama.sh list          - Список моделей"
    echo "   ./setup-dirs.sh             - Проверка структуры директорий"
    echo "   ./examples.sh               - Примеры использования"
    echo "   ./monitor.sh                - Мониторинг системы"
    echo "   ./backup.sh create          - Создать бэкап"
    echo "   ./log-manager.sh            - Управление логами"
    echo "   make help                   - Команды Make"
    echo ""
    echo -e "${CYAN}Документация:${NC}"
    echo "   README.md                   - Основная документация"
    echo "   TROUBLESHOOTING.md          - Решение проблем"
    echo ""
    echo -e "${GREEN}Приятной работы с RamaLama! 🚀${NC}"
    echo ""
}

# Показать ошибку установки
show_installation_error() {
    print_header "Ошибка установки"
    
    echo ""
    print_error "Установка не завершена из-за ошибок"
    echo ""
    echo -e "${YELLOW}Что делать:${NC}"
    echo "1. Проверьте вывод выше для деталей ошибки"
    echo "2. Исправьте проблемы (см. системные требования)"
    echo "3. Запустите install.sh снова"
    echo ""
    echo -e "${CYAN}Полезные команды:${NC}"
    echo "   docker --version            - Проверить Docker"
    echo "   docker-compose --version    - Проверить Docker Compose"
    echo "   docker info                 - Информация о Docker"
    echo "   df -h                       - Проверить место на диске"
    echo ""
    echo -e "${CYAN}Помощь:${NC}"
    echo "   См. TROUBLESHOOTING.md для решения частых проблем"
    echo ""
}

# Интерактивная установка
interactive_install() {
    local skip_tests=false
    
    # Аргументы командной строки
    while [ $# -gt 0 ]; do
        case "$1" in
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --help|-h)
                cat << EOF
RamaLama Docker Installation Script

Использование:
  ./install.sh [опции]

Опции:
  --skip-tests    Пропустить тесты после установки
  --help, -h      Показать эту справку

Установка выполняет:
  1. Проверку системных требований
  2. Создание конфигурации
  3. Настройку директорий и прав
  4. Сборку Docker образа
  5. Запуск тестов (опционально)

EOF
                exit 0
                ;;
            *)
                print_error "Неизвестная опция: $1"
                exit 1
                ;;
        esac
    done
    
    clear
    print_logo
    
    echo -e "${BOLD}Добро пожаловать в установщик RamaLama Docker!${NC}"
    echo ""
    echo "Этот скрипт настроит окружение для работы с RamaLama через Docker."
    echo ""
    read -p "Продолжить установку? (Y/n): " continue_install
    
    if [[ "$continue_install" =~ ^[Nn]$ ]]; then
        echo "Установка отменена."
        exit 0
    fi
    
    # Шаг 1: Проверка требований
    if ! check_requirements; then
        echo ""
        print_warning "Обнаружены проблемы с системными требованиями"
        read -p "Продолжить несмотря на это? (y/N): " force_continue
        
        if [[ ! "$force_continue" =~ ^[Yy]$ ]]; then
            show_installation_error
            exit 1
        fi
    fi
    
    # Шаг 2: Проверка прокси
    check_proxy
    local use_proxy=$?
    
    # Шаг 3: Создание конфигурации
    if [ $use_proxy -eq 0 ]; then
        create_env_file
    else
        print_info "Создание базового .env без прокси"
        create_env_file
    fi
    
    # Шаг 4: Создание директорий
    create_directories
    
    # Шаг 5: Установка прав
    set_permissions
    
    # Шаг 6: Сборка образа
    if ! build_image; then
        show_installation_error
        exit 1
    fi
    
    # Шаг 7: Тесты
    if [ "$skip_tests" = false ]; then
        run_tests || true  # Не прерываем установку при провале тестов
    else
        print_info "Тесты пропущены (--skip-tests)"
    fi
    
    # Завершение
    show_next_steps
}

# Главная функция
main() {
    # Проверка, что запущен в правильной директории
    if [ ! -f "Dockerfile" ] || [ ! -f "docker-compose.yml" ]; then
        print_error "Запустите скрипт из директории проекта ramalama-project/"
        exit 1
    fi
    
    # Запуск установки
    interactive_install "$@"
}

# Точка входа
main "$@"
