#!/bin/bash

# Скрипт бэкапа моделей и данных RamaLama

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Настройки
BACKUP_DIR="${BACKUP_DIR:-./backups}"
MODELS_DIR="./models"
DATA_DIR="./data"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="ramalama_backup_${TIMESTAMP}"

# Функции
print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║        RamaLama Backup Utility             ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
    echo ""
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

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

# Проверка наличия директорий
check_directories() {
    local missing=0
    
    if [ ! -d "$MODELS_DIR" ]; then
        print_error "Models directory not found: $MODELS_DIR"
        missing=1
    fi
    
    if [ ! -d "$DATA_DIR" ]; then
        print_info "Data directory not found: $DATA_DIR (skipping)"
    fi
    
    return $missing
}

# Создание бэкапа
create_backup() {
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    
    print_step "Creating backup directory..."
    mkdir -p "$backup_path"
    
    # Бэкап моделей
    if [ -d "$MODELS_DIR" ] && [ "$(ls -A $MODELS_DIR 2>/dev/null)" ]; then
        print_step "Backing up models..."
        
        local model_count=$(find "$MODELS_DIR" -type f | wc -l)
        local model_size=$(du -sh "$MODELS_DIR" | cut -f1)
        
        print_info "Found $model_count files ($model_size)"
        
        cp -r "$MODELS_DIR" "$backup_path/"
        print_success "Models backed up"
    else
        print_info "No models to backup"
    fi
    
    # Бэкап данных
    if [ -d "$DATA_DIR" ] && [ "$(ls -A $DATA_DIR 2>/dev/null)" ]; then
        print_step "Backing up data..."
        
        local data_size=$(du -sh "$DATA_DIR" | cut -f1)
        print_info "Data size: $data_size"
        
        cp -r "$DATA_DIR" "$backup_path/"
        print_success "Data backed up"
    else
        print_info "No data to backup"
    fi
    
    # Бэкап конфигурационных файлов
    print_step "Backing up configuration..."
    
    local config_files=(
        "docker-compose.yml"
        ".env"
        "ramalama.sh"
        "entrypoint.sh"
    )
    
    for file in "${config_files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$backup_path/"
            print_info "Copied: $file"
        fi
    done
    
    print_success "Configuration backed up"
    
    # Создание манифеста
    print_step "Creating backup manifest..."
    
    cat > "$backup_path/MANIFEST.txt" << EOF
RamaLama Backup Manifest
========================
Date: $(date)
Backup Name: $BACKUP_NAME
Host: $(hostname)

Contents:
---------
EOF
    
    if [ -d "$backup_path/models" ]; then
        echo "Models:" >> "$backup_path/MANIFEST.txt"
        find "$backup_path/models" -type f -name "*.gguf" | while read model; do
            local name=$(basename "$model")
            local size=$(du -h "$model" | cut -f1)
            echo "  - $name ($size)" >> "$backup_path/MANIFEST.txt"
        done
    fi
    
    if [ -d "$backup_path/data" ]; then
        echo "" >> "$backup_path/MANIFEST.txt"
        echo "Data:" >> "$backup_path/MANIFEST.txt"
        echo "  - $(du -sh "$backup_path/data" | cut -f1)" >> "$backup_path/MANIFEST.txt"
    fi
    
    print_success "Manifest created"
    
    # Архивирование
    if command -v tar &> /dev/null; then
        print_step "Creating archive..."
        
        cd "$BACKUP_DIR"
        tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
        
        local archive_size=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
        print_success "Archive created: ${BACKUP_NAME}.tar.gz ($archive_size)"
        
        # Удаление временной директории
        rm -rf "$BACKUP_NAME"
        
        cd - > /dev/null
        
        echo ""
        echo -e "${GREEN}Backup completed successfully!${NC}"
        echo -e "${BLUE}Location:${NC} $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    else
        echo ""
        echo -e "${GREEN}Backup completed successfully!${NC}"
        echo -e "${BLUE}Location:${NC} $backup_path"
        print_info "Install 'tar' for compressed backups"
    fi
}

# Восстановление из бэкапа
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        print_error "Backup file not specified"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        print_error "Backup file not found: $backup_file"
        return 1
    fi
    
    print_step "Restoring from backup: $backup_file"
    
    # Распаковка
    if [[ "$backup_file" == *.tar.gz ]]; then
        print_step "Extracting archive..."
        
        local temp_dir=$(mktemp -d)
        tar -xzf "$backup_file" -C "$temp_dir"
        
        local extracted=$(ls "$temp_dir")
        backup_file="$temp_dir/$extracted"
    fi
    
    # Подтверждение
    echo ""
    print_info "This will overwrite existing models and data!"
    read -p "Continue? (y/N): " confirm
    
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        print_info "Restore cancelled"
        return 0
    fi
    
    # Восстановление моделей
    if [ -d "$backup_file/models" ]; then
        print_step "Restoring models..."
        
        mkdir -p "$MODELS_DIR"
        cp -r "$backup_file/models/"* "$MODELS_DIR/"
        
        print_success "Models restored"
    fi
    
    # Восстановление данных
    if [ -d "$backup_file/data" ]; then
        print_step "Restoring data..."
        
        mkdir -p "$DATA_DIR"
        cp -r "$backup_file/data/"* "$DATA_DIR/"
        
        print_success "Data restored"
    fi
    
    # Восстановление конфигурации
    if [ -f "$backup_file/docker-compose.yml" ]; then
        print_step "Restoring configuration..."
        
        # Создаем бэкап текущей конфигурации
        if [ -f "docker-compose.yml" ]; then
            cp "docker-compose.yml" "docker-compose.yml.backup"
        fi
        
        cp "$backup_file/docker-compose.yml" .
        
        if [ -f "$backup_file/.env" ]; then
            cp "$backup_file/.env" .
        fi
        
        print_success "Configuration restored"
    fi
    
    echo ""
    echo -e "${GREEN}Restore completed successfully!${NC}"
}

# Список бэкапов
list_backups() {
    print_step "Available backups:"
    echo ""
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A $BACKUP_DIR 2>/dev/null)" ]; then
        print_info "No backups found"
        return
    fi
    
    local backups=($(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    
    if [ ${#backups[@]} -eq 0 ]; then
        # Проверяем директории
        backups=($(ls -td "$BACKUP_DIR"/ramalama_backup_* 2>/dev/null))
    fi
    
    if [ ${#backups[@]} -eq 0 ]; then
        print_info "No backups found"
        return
    fi
    
    local index=1
    for backup in "${backups[@]}"; do
        local name=$(basename "$backup")
        local size=$(du -h "$backup" | cut -f1)
        local date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$backup" 2>/dev/null || \
                    stat -c "%y" "$backup" 2>/dev/null | cut -d'.' -f1)
        
        echo -e "${BLUE}$index.${NC} $name"
        echo "   Size: $size"
        echo "   Date: $date"
        echo ""
        
        ((index++))
    done
}

# Очистка старых бэкапов
cleanup_backups() {
    local keep=${1:-5}
    
    print_step "Cleaning up old backups (keeping last $keep)..."
    
    if [ ! -d "$BACKUP_DIR" ]; then
        print_info "No backup directory found"
        return
    fi
    
    local backups=($(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    local count=${#backups[@]}
    
    if [ $count -le $keep ]; then
        print_info "Nothing to clean (have $count, keeping $keep)"
        return
    fi
    
    local to_remove=$((count - keep))
    print_info "Removing $to_remove old backup(s)..."
    
    for ((i=keep; i<count; i++)); do
        local backup="${backups[$i]}"
        local name=$(basename "$backup")
        
        rm -f "$backup"
        print_success "Removed: $name"
    done
    
    echo ""
    print_success "Cleanup completed"
}

# Справка
show_help() {
    cat << EOF
RamaLama Backup Utility

Использование:
  ./backup.sh [command] [options]

Команды:
  create              Создать новый бэкап (по умолчанию)
  restore <file>      Восстановить из бэкапа
  list                Показать список бэкапов
  cleanup [N]         Удалить старые бэкапы (оставить последние N)
  
Опции:
  --backup-dir <dir>  Директория для бэкапов (по умолчанию: ./backups)
  -h, --help          Показать эту справку

Примеры:
  ./backup.sh                                    # Создать бэкап
  ./backup.sh create                             # То же самое
  ./backup.sh list                               # Показать бэкапы
  ./backup.sh restore backups/ramalama_backup_*.tar.gz
  ./backup.sh cleanup 3                          # Оставить 3 последних
  ./backup.sh --backup-dir /mnt/backup create    # Бэкап в другую директорию

Расположение:
  Модели:   $MODELS_DIR
  Данные:   $DATA_DIR
  Бэкапы:   $BACKUP_DIR
EOF
}

# Основная логика
main() {
    local command="create"
    
    # Обработка опций
    while [ $# -gt 0 ]; do
        case "$1" in
            --backup-dir)
                BACKUP_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            create|restore|list|cleanup)
                command="$1"
                shift
                break
                ;;
            *)
                command="$1"
                shift
                break
                ;;
        esac
    done
    
    print_header
    
    case "$command" in
        create)
            check_directories || exit 1
            create_backup
            ;;
        restore)
            restore_backup "$1"
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_backups "$1"
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
