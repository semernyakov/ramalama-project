#!/bin/bash

# Скрипт для настройки автоматической ротации логов RamaLama
# Настраивает как logrotate, так и ручную ротацию через cron

set -e

PROJECT_DIR="$(pwd)"
LOG_DIR="$PROJECT_DIR/logs"
CONFIG_DIR="$PROJECT_DIR/config"

echo "🔧 Настройка автоматической ротации логов RamaLama"
echo "=================================================="

# 1. Создаем директорию для централизованного логирования
echo "📁 Создание директории /var/log/ramalama/..."
sudo mkdir -p /var/log/ramalama
sudo mkdir -p /var/log/ramalama/sessions

# 2. Создаем символические ссылки
echo "🔗 Создание символических ссылок..."
sudo rm -f /var/log/ramalama/ramalama.log
sudo rm -f /var/log/ramalama/monitor.log
sudo ln -sf "$LOG_DIR/ramalama.log" /var/log/ramalama/ramalama.log
sudo ln -sf "$LOG_DIR/monitor.log" /var/log/ramalama/monitor.log
sudo ln -sf "$LOG_DIR/sessions" /var/log/ramalama/sessions

# 3. Настраиваем права доступа
echo "🔐 Настройка прав доступа..."
sudo chown -R root:adm /var/log/ramalama
sudo chmod 755 /var/log/ramalama
sudo chmod 644 /var/log/ramalama/*.log
sudo chmod 755 /var/log/ramalama/sessions

# 4. Устанавливаем конфигурацию logrotate
echo "⚙️ Установка конфигурации logrotate..."
sudo cp config/logrotate-ramalama.conf /etc/logrotate.d/ramalama
sudo chmod 644 /etc/logrotate.d/ramalama

# 5. Создаем cron задачу для ручной ротации (дополнительно)
echo "⏰ Создание cron задачи..."
cat > /tmp/ramalama-logrotate-cron << 'EOF'
# RamaLama Log Rotation - Daily at 2:30 AM
30 2 * * * root cd /home/master/ai-workspace/ramalama-project && ./log-manager.sh clean >> /var/log/ramalama/cron.log 2>&1

# Weekly logrotate check (Sunday at 3:00 AM)
0 3 * * 0 root /usr/sbin/logrotate /etc/logrotate.d/ramalama --state /var/lib/logrotate/ramalama-status
EOF

sudo cp /tmp/ramalama-logrotate-cron /etc/cron.d/ramalama-logrotate
sudo chmod 644 /etc/cron.d/ramalama-logrotate
rm -f /tmp/ramalama-logrotate-cron

# 6. Перезапускаем cron daemon
echo "🔄 Перезапуск cron daemon..."
sudo systemctl reload cron

# 7. Тестируем конфигурацию
echo "🧪 Тестирование конфигурации..."
echo ""

echo "=== Тест logrotate (debug mode) ==="
sudo /usr/sbin/logrotate -d /etc/logrotate.d/ramalama 2>&1 | head -20

echo ""
echo "=== Проверка cron задач ==="
sudo crontab -l | grep ramalama

echo ""
echo "=== Проверка символических ссылок ==="
ls -la /var/log/ramalama/

echo ""
echo "✅ Настройка завершена!"
echo ""
echo "📋 Резюме настроек:"
echo "  • Централизованное логирование: /var/log/ramalama/"
echo "  • Символические ссылки созданы"
echo "  • Конфигурация logrotate: /etc/logrotate.d/ramalama"
echo "  • Cron задачи настроены"
echo ""
echo "🔍 Проверка работы:"
echo "  • logrotate -d /etc/logrotate.d/ramalama"
echo "  • sudo systemctl status cron"
echo "  • sudo crontab -l | grep ramalama"
echo ""
echo "📝 Мониторинг:"
echo "  • tail -f /var/log/ramalama/ramalama.log"
echo "  • tail -f /var/log/ramalama/monitor.log"
echo "  • tail -f /var/log/ramalama/cron.log"