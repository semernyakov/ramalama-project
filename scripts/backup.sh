#!/bin/bash

# ============================================
# RamaLama Backup Utility (Variant B optimized)
# Резервное копирование моделей - kritical component
# ============================================

set -euo pipefail

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Настройки для Variant B
BACKUP_DIR="${BACKUP_DIR:-./backups}"
MODELS_DIR="./models"                    # Единственное на хосте
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="ramalama_models_${TIMESTAMP}"
KEEP_BACKUPS="${KEEP_BACKUPS:-5}"

# Функции логирования
log_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_info() { echo -e "${CYAN}ℹ${NC} $1"; }
log_step() { echo -e "${BLUE}▶${NC} $1"; }
log_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

format_size() {
    numfmt --to=iec-i --suffix=B "$1" 2>/dev/null || echo "$1 bytes"
}

# Проверка наличия моделей
check_models() {
    if [ ! -d "$MODELS_DIR" ]; then
        log_error "Models directory not found: $MODELS_DIR"
        return 1
    fi
    
    local model_count=$(find "$MODELS_DIR" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l)
    
    if [ $model_count -eq 0 ]; then
        log_warning "No models found in $MODELS_DIR"
        return 1
    fi
    
    return 0
}

# Создание бэкапа
create_backup() {
    log_header "🔄 Creating Backup (Variant B - Models Only)"
    
    # Проверка наличия моделей
    if ! check_models; then
        log_error "Cannot create backup without models"
        return 1
    fi
    
    local backup_path="$BACKUP_DIR/$BACKUP_NAME"
    
    # Создаем директорию бэкапа
    log_step "Creating backup directory..."
    mkdir -p "$backup_path"
    log_success "Backup directory created: $backup_path"
    
    # Бэкап моделей (единственное, что нужно)
    log_step "Backing up models from $MODELS_DIR..."
    
    local model_count=$(find "$MODELS_DIR" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l)
    local model_size=$(du -sb "$MODELS_DIR" 2>/dev/null | cut -f1)
    
    log_info "Found $model_count models ($(format_size "$model_size"))"
    
    cp -r "$MODELS_DIR"/* "$backup_path/" 2>/dev/null || true
    log_success "Models backed up successfully"
    
    # Создание манифеста
    log_step "Creating backup manifest..."
    
    cat > "$backup_path/MANIFEST.txt" << EOF
RamaLama Backup Manifest (Variant B)
====================================

Date: $(date)
Backup Name: $BACKUP_NAME
Host: $(hostname)
Type: Models Only (Variant B)

Contents:
---------
EOF
    
    find "$backup_path" -maxdepth 1 -type f | while read model; do
        local name=$(basename "$model")
        local size=$(stat -c%s "$model" 2>/dev/null || stat -f%z "$model")
        echo " - $name ($(format_size "$size"))" >> "$backup_path/MANIFEST.txt"
    done
    
    # Итого
    {
        echo ""
        echo "Total:"
        echo " - Models: $model_count"
        echo " - Size: $(format_size "$model_size")"
        echo ""
        echo "Restore with:"
        echo " ./backup.sh restore $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    } >> "$backup_path/MANIFEST.txt"
    
    log_success "Manifest created"
    
    # Архивирование
    if command -v tar &> /dev/null; then
        log_step "Creating compressed archive..."
        
        cd "$BACKUP_DIR"
        tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME" 2>/dev/null
        local archive_size=$(stat -c%s "${BACKUP_NAME}.tar.gz" 2>/dev/null || stat -f%z "${BACKUP_NAME}.tar.gz")
        
        log_success "Archive created: ${BACKUP_NAME}.tar.gz ($(format_size "$archive_size"))"
        
        # Удаляем временную директорию
        rm -rf "$BACKUP_NAME"
        cd - > /dev/null
    else
        log_warning "tar not found - backup directory not compressed"
    fi
    
    echo ""
    log_success "Backup completed successfully!"
    log_info "Location: $BACKUP_DIR/${BACKUP_NAME}.tar.gz"
    echo ""
}

# Восстановление из бэкапа
restore_backup() {
    local backup_file="$1"
    
    if [ -z "$backup_file" ]; then
        log_error "Backup file not specified"
        return 1
    fi
    
    if [ ! -f "$backup_file" ]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    log_header "📥 Restoring from Backup"
    log_info "Backup file: $backup_file"
    
    # Распаковка если нужно
    local temp_dir
    if [[ "$backup_file" == *.tar.gz ]]; then
        log_step "Extracting archive..."
        temp_dir=$(mktemp -d)
        tar -xzf "$backup_file" -C "$temp_dir" 2>/dev/null
        backup_file="$temp_dir/$(ls "$temp_dir")"
        log_success "Archive extracted"
    fi
    
    # Проверка манифеста
    if [ -f "$backup_file/MANIFEST.txt" ]; then
        echo ""
        log_info "Backup contents:"
        cat "$backup_file/MANIFEST.txt" | head -20
        echo ""
    fi
    
    # Подтверждение
    log_warning "This will OVERWRITE existing models in $MODELS_DIR!"
    read -p "Continue? Type 'yes' to confirm: " confirm
    
    if [ "$confirm" != "yes" ]; then
        log_info "Restore cancelled"
        [ -n "$temp_dir" ] && rm -rf "$temp_dir"
        return 0
    fi
    
    # Восстановление моделей
    log_step "Restoring models..."
    mkdir -p "$MODELS_DIR"
    cp -r "$backup_file"/*.{gguf,bin} "$MODELS_DIR/" 2>/dev/null || true
    
    local restored=$(find "$MODELS_DIR" -type f \( -name "*.gguf" -o -name "*.bin" \) 2>/dev/null | wc -l)
    log_success "Restored $restored models"
    
    # Очистка
    [ -n "$temp_dir" ] && rm -rf "$temp_dir"
    
    echo ""
    log_success "Restore completed successfully!"
    echo ""
}

# Список бэкапов
list_backups() {
    log_header "📋 Available Backups"
    
    if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]; then
        log_info "No backups found in $BACKUP_DIR"
        return
    fi
    
    echo ""
    
    local index=1
    # Ищем архивы
    for backup in $(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null); do
        if [ -f "$backup" ]; then
            local name=$(basename "$backup")
            local size=$(stat -c%s "$backup" 2>/dev/null || stat -f%z "$backup")
            local date=$(stat -c '%y' "$backup" 2>/dev/null | cut -d'.' -f1 || \
                        stat -f '%Sm' "$backup")
            
            echo -e "${BLUE}$index.${NC} $name"
            echo "   Size: $(format_size "$size")"
            echo "   Date: $date"
            echo ""
            
            ((index++))
        fi
    done
    
    # Ищем директории без архивов
    for backup in $(ls -td "$BACKUP_DIR"/ramalama_models_* 2>/dev/null | grep -v ".tar.gz"); do
        if [ -d "$backup" ]; then
            local name=$(basename "$backup")
            local size=$(du -sb "$backup" 2>/dev/null | cut -f1)
            local date=$(stat -c '%y' "$backup" 2>/dev/null | cut -d'.' -f1 || \
                        stat -f '%Sm' "$backup")
            
            echo -e "${BLUE}$index.${NC} $name (directory)"
            echo "   Size: $(format_size "$size")"
            echo "   Date: $date"
            echo ""
            
            ((index++))
        fi
    done
    
    if [ $index -eq 1 ]; then
        log_info "No backups found"
    else
        log_info "Total backups: $((index - 1))"
    fi
    echo ""
}

# Очистка старых бэкапов
cleanup_backups() {
    local keep=${1:-$KEEP_BACKUPS}
    
    log_header "🧹 Cleaning Old Backups"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        log_info "Backup directory not found: $BACKUP_DIR"
        return
    fi
    
    local backups=($(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    local count=${#backups[@]}
    
    if [ $count -le $keep ]; then
        log_info "Nothing to clean (have $count, keeping $keep)"
        return
    fi
    
    local to_remove=$((count - keep))
    log_step "Removing $to_remove old backup(s), keeping $keep..."
    
    for ((i=keep; i < count; i++)); do
        local backup="${backups[$i]}"
        local name=$(basename "$backup")
        log_info "Removing: $name"
        rm -f "$backup"
    done
    
    log_success "Cleanup completed!"
    echo ""
}

# Поиск бэкапа для восстановления
find_backup() {
    if [ -d "$BACKUP_DIR" ]; then
        local latest=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
        if [ -n "$latest" ]; then
            echo "$latest"
        fi
    fi
}

# Справка
show_help() {
    cat << 'EOF'
RamaLama Backup Utility - Model Storage Management (Variant B)

Usage:
  ./backup.sh [command] [options]

Commands:
  create              Create new backup (default)
  restore <file>      Restore from backup file
  list                List all available backups
  cleanup [N]         Remove old backups (keep last N)
  help                Show this help

Options:
  --backup-dir PATH   Backup directory (default: ./backups)
  --keep N            Keep last N backups (default: 5)

Examples:
  ./backup.sh                      # Create new backup
  ./backup.sh list                 # List backups
  ./backup.sh restore backups/ramalama_models_*.tar.gz
  ./backup.sh cleanup 3            # Keep last 3 backups
  ./backup.sh --backup-dir /mnt/backup create

Features:
  ✓ Variant B optimized (only models backed up)
  ✓ Automatic tar.gz compression
  ✓ Manifest generation with model details
  ✓ Automatic cleanup of old backups
  ✓ Easy restore with confirmation

Storage Locations:
  Models on host: ./models
  Backups:        ./backups
  Manifest:       ./backups/ramalama_models_*/MANIFEST.txt

Typical Workflow:
  1. Daily:   ./backup.sh create
  2. Weekly:  ./backup.sh list
  3. Monthly: ./backup.sh cleanup 5
  4. Restore: ./backup.sh restore <latest-backup>

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
            --keep)
                KEEP_BACKUPS="$2"
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
    
    # Выполнение команды
    case "$command" in
        create)
            create_backup
            ;;
        restore)
            restore_backup "$1"
            ;;
        list)
            list_backups
            ;;
        cleanup)
            cleanup_backups "${1:-$KEEP_BACKUPS}"
            ;;
        help)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
