# 🔧 ПРАКТИЧЕСКИЙ ГАЙД - Backup Integration

## Быстрый старт

### Шаг 1: Добавить backup.sh в проект

```bash
# Скопировать файл
cp backup.sh scripts/backup.sh

# Дать права на выполнение
chmod +x scripts/backup.sh

# Проверить
./scripts/backup.sh help
```

### Шаг 2: Обновить Makefile

Добавить эти цели в `Makefile`:

```makefile
# ============================================
# 📦 BACKUP & RESTORE
# ============================================

.PHONY: backup backup-list backup-restore backup-cleanup

BACKUP_FILE ?=
KEEP ?= 5

backup:                                    ## Create backup of models
	@echo "Creating backup..."
	@./scripts/backup.sh create
	@echo ""

backup-list:                               ## List all backups
	@./scripts/backup.sh list

backup-restore:                            ## Restore from backup (BACKUP_FILE=path/to/file.tar.gz)
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "Usage: make backup-restore BACKUP_FILE=path/to/backup.tar.gz"; \
		./scripts/backup.sh list; \
		exit 1; \
	fi
	@./scripts/backup.sh restore "$(BACKUP_FILE)"

backup-cleanup:                            ## Cleanup old backups (KEEP=5)
	@./scripts/backup.sh cleanup $(KEEP)

backup-full:                               ## Create backup and cleanup old ones
	@make backup
	@make backup-cleanup KEEP=$(KEEP)
```

### Шаг 3: Использование

```bash
# Создать бэкап
make backup

# Список бэкапов
make backup-list

# Очистить старые (оставить 3)
make backup-cleanup KEEP=3

# Восстановить (после просмотра списка)
make backup-restore BACKUP_FILE=./backups/ramalama_models_20251213_070500.tar.gz

# Все вместе
make backup-full KEEP=7
```

---

## 📋 Рекомендуемая стратегия резервного копирования

### ЕЖЕДНЕВНОiever

```bash
# Добавить в crontab
0 2 * * * cd /opt/ramalama && make backup >> /var/log/ramalama-backup.log 2>&1
```

### ЕЖЕНЕДЕЛЬНО

```bash
# Проверить наличие бэкапов
make backup-list

# Или в crontab
0 3 * * 0 cd /opt/ramalama && make backup-list >> /var/log/ramalama-backup.log 2>&1
```

### ЕЖЕМЕСЯЧНО

```bash
# Оставить 8 последних бэкапов
make backup-cleanup KEEP=8

# Или в crontab
0 4 1 * * cd /opt/ramalama && make backup-cleanup KEEP=8 >> /var/log/ramalama-backup.log 2>&1
```

### ПЕРЕД ВАЖНЫМИ ОПЕРАЦИЯМИ

```bash
# Перед обновлением моделей
make backup
make pull MODEL=mistral

# Перед обновлением инфраструктуры
make backup
make down
make buildx
make up
```

---

## 🎯 Сценарии использования

### Сценарий 1: Ежедневное резервное копирование

```bash
#!/bin/bash
# scripts/backup-daily.sh

cd $(dirname "$0")/..

# Создать бэкап
make backup

# Проверить размер
du -sh backups/ | tail -1

# Список последних 3
make backup-list | head -10

# Оставить 7 последних
make backup-cleanup KEEP=7
```

```bash
# Добавить в crontab:
0 2 * * * /opt/ramalama/scripts/backup-daily.sh
```

### Сценарий 2: Аварийное восстановление

```bash
#!/bin/bash
# scripts/restore-emergency.sh

# Если что-то сломалось в моделях

cd $(dirname "$0")/..

echo "🚨 Emergency Restore Mode"
echo ""

# Список бэкапов
make backup-list
echo ""

# Попросить выбрать
read -p "Enter backup file path to restore: " backup_file

if [ -z "$backup_file" ]; then
    echo "Cancelled"
    exit 1
fi

# Подтверждение
read -p "This will overwrite models. Continue? (type 'yes'): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Cancelled"
    exit 1
fi

# Восстановление
make backup-restore BACKUP_FILE="$backup_file"

# Перезапуск контейнера
echo ""
echo "Restarting container..."
make down
make up
make health

echo "✅ Restore complete!"
```

### Сценарий 3: Миграция на новый сервер

```bash
# На старом сервере:
cd /opt/ramalama
make backup

# Передать бэкап
scp backups/ramalama_models_*.tar.gz user@newserver:/tmp/

# На новом сервере:
cd /opt/ramalama
cp /tmp/ramalama_models_*.tar.gz backups/
make backup-restore BACKUP_FILE=./backups/ramalama_models_*.tar.gz

# Проверка
make health
./scripts/check-models.sh
```

---

## 📊 Мониторинг размера

### Проверка размера бэкапов

```bash
# Одна команда
du -sh backups/

# Детально
du -sh backups/* | sort -h

# Отслеживание
watch -n 60 'du -sh backups/*'
```

### Расчет хранилища

```bash
# Примерные размеры:
# TinyLlama:     5MB  × 7 = 35MB
# Mistral:       30MB × 7 = 210MB
# Llama2-7B:     4GB  × 7 = 28GB
# Llama2-13B:    8GB  × 7 = 56GB

# Рекомендация:
# Минимум 50GB для 7 бэкапов Llama2-7B
# Или 20GB для 7 бэкапов Mistral
```

### Автоматическая очистка при нехватке места

```bash
#!/bin/bash
# scripts/backup-cleanup-smart.sh

DISK_THRESHOLD=80  # % заполнения

used=$(df /opt/ramalama | awk 'NR==2 {print $5}' | sed 's/%//')

if [ $used -gt $DISK_THRESHOLD ]; then
    echo "⚠️  Disk usage: ${used}% (threshold: ${DISK_THRESHOLD}%)"
    
    # Оставить только 3 бэкапа
    make backup-cleanup KEEP=3
    
    # Проверка
    new_used=$(df /opt/ramalama | awk 'NR==2 {print $5}' | sed 's/%//')
    echo "✅ After cleanup: ${new_used}%"
fi
```

---

## 🔐 Безопасность

### Проверка целостности бэкапа

```bash
# После восстановления
./scripts/check-models.sh

# Или вручную
ls -la models/
find models -type f -name "*.gguf" | wc -l

# Проверить размер
du -sh models/
```

### Шифрование бэкапов (опционально)

```bash
#!/bin/bash
# Encrypt backup
gpg --symmetric --cipher-algo AES256 backups/ramalama_models_*.tar.gz

# Decrypt backup
gpg --decrypt backups/ramalama_models_*.tar.gz.gpg > backup.tar.gz
```

### Удаленное хранилище

```bash
# После создания бэкапа
make backup

# Загрузить на S3
aws s3 cp backups/ramalama_models_*.tar.gz \
    s3://my-bucket/ramalama-backups/ \
    --region us-east-1

# Или на Google Drive
rclone copy backups/ gdrive:RamaLama-Backups/
```

---

## 🐛 Решение проблем

### Проблема: "Backup file not found"

```bash
# Решение: Создать сначала бэкап
make backup

# Затем проверить
make backup-list

# Потом восстановить
make backup-restore BACKUP_FILE=./backups/ramalama_models_*.tar.gz
```

### Проблема: "No models to backup"

```bash
# Проверить структуру
./scripts/setup-dirs.sh

# Загрузить модели
make pull MODEL=tinyllama

# Проверить
./scripts/check-models.sh

# Затем бэкапить
make backup
```

### Проблема: "Disk space full"

```bash
# Проверить размер
du -sh models/
du -sh backups/

# Очистить старые бэкапы
make backup-cleanup KEEP=2

# Или удалить большие модели
rm models/llama2-70b.gguf

# Сжать существующие бэкапы
gzip -9 backups/ramalama_models_*/ -r
```

### Проблема: "Restore fails with permission error"

```bash
# Проверить права
ls -la models/
ls -la backups/

# Установить правильно
chmod 755 models/
chmod 644 models/*.gguf

# Затем восстановить
make backup-restore BACKUP_FILE=...
```

---

## ✅ CHECKLIST: Когда бэкапить?

- [ ] После загрузки новой модели
  ```bash
  make pull MODEL=mistral && make backup
  ```

- [ ] Перед обновлением инфраструктуры
  ```bash
  make backup && make down && make buildx && make up
  ```

- [ ] Перед экспериментами
  ```bash
  make backup && make run-experiment
  ```

- [ ] Ежедневно автоматически
  ```bash
  # В crontab: 0 2 * * * make backup
  ```

- [ ] Перед перемещением на новый сервер
  ```bash
  make backup && scp backups/* newserver:/
  ```

---

## 📈 Мониторинг в реальном времени

### Dashboard shell script

```bash
#!/bin/bash
# scripts/monitor-backups.sh

echo "🔍 RamaLama Backup Monitor"
echo "========================="
echo ""

echo "📦 Backups directory:"
du -sh backups/
echo ""

echo "📋 Recent backups:"
ls -lh backups/*.tar.gz 2>/dev/null | tail -3 | awk '{print $9, "(" $5 ")"}'
echo ""

echo "🗂️  Models in repository:"
du -sh models/
find models -type f -name "*.gguf" | wc -l | xargs echo "  Files:"
echo ""

echo "💾 Disk usage:"
df -h . | tail -1 | awk '{print "  Used: " $3 " / " $2 " (" $5 ")"}'
echo ""

echo "🕐 Last backup:"
ls -t backups/*.tar.gz 2>/dev/null | head -1 | xargs ls -lh | awk '{print "  " $6, $7, $8, "(" $5 ")"}'
```

---

## 🚀 Integration Example

### Complete setup script

```bash
#!/bin/bash
# scripts/setup-backup-automation.sh

echo "🔧 Setting up backup automation..."

# 1. Ensure backup.sh is executable
chmod +x ./scripts/backup.sh

# 2. Create backups directory
mkdir -p ./backups

# 3. Create first backup
echo "Creating initial backup..."
./scripts/backup.sh create

# 4. Check crontab
echo ""
echo "To enable automatic daily backups, add this to your crontab:"
echo "0 2 * * * cd $(pwd) && make backup >> /var/log/ramalama-backup.log 2>&1"
echo ""
echo "To set it up now, run:"
echo "(crontab -l; echo '0 2 * * * cd $(pwd) && make backup') | crontab -"

# 5. Verify
echo ""
echo "✅ Backup system ready!"
make backup-list
```

---

**Status: ГОТОВО К ИСПОЛЬЗОВАНИЮ ✅**

Используйте этот гайд вместе с `backup.sh` для надежного резервного копирования моделей.

*Last Updated: 2025-12-13 07:08 MSK*
