#!/bin/bash

# Скрипт управления RamaLama через Docker
# Использование: ./ramalama.sh <команда> [аргументы]

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для красивого вывода
print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# Проверка наличия Docker
check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker не установлен!"
        exit 1
    fi
}

# Проверка наличия образа
check_image() {
    if ! docker image inspect ramalama:latest &> /dev/null; then
        print_info "Образ ramalama:latest не найден. Выполняется сборка..."
        docker-compose build
    fi
}

# Создание необходимых директорий
ensure_dirs() {
    mkdir -p models data
    print_success "Директории models и data готовы"
}

# Функция для запуска команд ramalama
run_ramalama() {
    docker-compose run --rm ramalama "$@"
}

# Справка
show_help() {
    cat << EOF
Управление RamaLama через Docker

Использование:
  ./ramalama.sh <команда> [аргументы]

Команды управления:
  build           - Собрать Docker образ
  rebuild         - Пересобрать образ с нуля
  shell           - Открыть bash в контейнере
  clean           - Очистить контейнеры и образы

Команды RamaLama:
  info            - Показать информацию о системе
  list            - Список локальных моделей
  pull <model>    - Скачать модель
  run <model>     - Запустить модель в интерактивном режиме
  serve <model>   - Запустить модель как сервер
  rm <model>      - Удалить модель
  version         - Показать версию ramalama

Примеры:
  ./ramalama.sh build
  ./ramalama.sh info
  ./ramalama.sh list
  ./ramalama.sh pull llama3.2:1b
  ./ramalama.sh run llama3.2:1b
  ./ramalama.sh serve llama3.2:1b --port 8080

Прямой запуск:
  ./ramalama.sh -- <любая команда ramalama>
  Пример: ./ramalama.sh -- --version

EOF
}

# Основная логика
main() {
    check_docker
    ensure_dirs

    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    case "$1" in
        help|--help|-h)
            show_help
            ;;
        
        build)
            print_header "Сборка Docker образа"
            docker-compose build
            print_success "Образ успешно собран"
            ;;
        
        rebuild)
            print_header "Пересборка Docker образа"
            docker-compose build --no-cache
            print_success "Образ успешно пересобран"
            ;;
        
        shell|bash)
            print_header "Открытие bash в контейнере"
            docker-compose run --rm ramalama bash
            ;;
        
        clean)
            print_header "Очистка"
            docker-compose down -v
            docker rmi ramalama:latest 2>/dev/null || true
            print_success "Очистка выполнена"
            ;;
        
        info)
            print_header "Информация о системе"
            check_image
            run_ramalama info
            ;;
        
        list|ls)
            print_header "Список локальных моделей"
            check_image
            run_ramalama list
            ;;
        
        pull)
            if [ -z "$2" ]; then
                print_error "Укажите модель для скачивания"
                echo "Пример: ./ramalama.sh pull llama3.2:1b"
                exit 1
            fi
            print_header "Скачивание модели: $2"
            check_image
            run_ramalama pull "$2"
            print_success "Модель успешно скачана"
            ;;
        
        run)
            if [ -z "$2" ]; then
                print_error "Укажите модель для запуска"
                echo "Пример: ./ramalama.sh run llama3.2:1b"
                exit 1
            fi
            print_header "Запуск модели: $2"
            check_image
            shift
            run_ramalama run "$@"
            ;;
        
        serve)
            if [ -z "$2" ]; then
                print_error "Укажите модель для запуска сервера"
                echo "Пример: ./ramalama.sh serve llama3.2:1b --port 8080"
                exit 1
            fi
            print_header "Запуск сервера с моделью: $2"
            check_image
            shift
            run_ramalama serve "$@"
            ;;
        
        rm|remove)
            if [ -z "$2" ]; then
                print_error "Укажите модель для удаления"
                echo "Пример: ./ramalama.sh rm llama3.2:1b"
                exit 1
            fi
            print_header "Удаление модели: $2"
            check_image
            run_ramalama rm "$2"
            print_success "Модель удалена"
            ;;
        
        version)
            check_image
            run_ramalama version
            ;;
        
        --)
            # Прямая передача команд ramalama
            shift
            check_image
            run_ramalama "$@"
            ;;
        
        *)
            print_error "Неизвестная команда: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
