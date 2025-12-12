# 📋 RamaLama Log Rotation Guide

## 🎯 Log Rotation System Overview

The RamaLama log rotation system consists of three components:

1. **Logrotate** - System tool for automatic rotation
2. **Log-manager.sh** - Script for manual log management  
3. **Cron** - Task scheduler for automatic execution

## 📁 Log Structure

```
./logs/
├── ramalama.log              # Main system log
├── monitor.log               # Monitoring log  
└── sessions/                 # Sessions directory
    ├── ramalama_session_*.log    # Individual session logs
```

## ⚙️ Automatic Rotation Setup

### Step 1: Run Setup Script

```bash
# Make script executable
chmod +x setup-logrotate.sh

# Run setup
sudo ./setup-logrotate.sh
```

### What the script does:

1. **Creates centralized logging** in `/var/log/ramalama/`
2. **Configures symbolic links** for system integration
3. **Installs logrotate configuration** in `/etc/logrotate.d/ramalama`
4. **Creates cron tasks** for automatic execution
5. **Restarts system services**

## 🔧 Manual Log Management

### Using log-manager.sh

```bash
# Initialize logging system
./log-manager.sh init

# View last 100 lines
./log-manager.sh show

# View last 50 lines
./log-manager.sh show 50

# Monitor logs in real-time
./log-manager.sh tail

# Show all sessions
./log-manager.sh sessions

# Clean old logs
./log-manager.sh clean

# Logging status
./log-manager.sh status

# Run command with session logging
./log-manager.sh run <command>
```

### Manual logrotate execution

```bash
# Configuration check (without execution)
logrotate -d config/logrotate-ramalama.conf

# Force rotation
logrotate -f config/logrotate-ramalama.conf

# Rotation with verbose output
logrotate -v config/logrotate-ramalama.conf
```

## ⏰ Automatic Rotation

### Cron Setup

Cron tasks are configured automatically when running `setup-logrotate.sh`:

```bash
# View cron tasks
sudo crontab -l | grep ramalama

# Edit cron tasks
sudo crontab -e
```

### Standard tasks:

- **Daily cleanup**: 02:30 (via log-manager.sh clean)
- **Weekly check**: Sunday 03:00 (logrotate verification)

### System logrotate rotation

Logrotate automatically runs via `/etc/cron.daily/logrotate`:
- **Time**: Usually at 06:25 AM
- **Configuration**: `/etc/logrotate.conf`
- **Additional configs**: `/etc/logrotate.d/`

## 📊 Rotation Parameters

### Settings in `config/logrotate-ramalama.conf`:

- **Frequency**: Daily (`daily`)
- **Retention**: 30 archived copies (`rotate 30`)
- **Compression**: Automatic (`compress`)
- **Create new files**: Enabled (`create`)
- **Security**: 
  - `missingok` - ignores missing files
  - `notifempty` - doesn't rotate empty files
- **Post-rotate scripts**: Logging rotation completion

## 🧪 System Testing

### logrotate configuration verification

```bash
# Debug (shows what will be done)
logrotate -d config/logrotate-ramalama.conf

# Test run (doesn't perform rotation)
logrotate --debug config/logrotate-ramalama.conf

# System configuration check
sudo logrotate -d /etc/logrotate.d/ramalama
```

### Cron tasks verification

```bash
# Cron daemon status
sudo systemctl status cron

# List active tasks
sudo crontab -l

# Cron logs
sudo tail -f /var/log/cron.log
```

### Creating test file for rotation

```bash
# Create test file
echo "Test log entry $(date)" > logs/test.log

# Setup temporary configuration for test
cat > /tmp/test-logrotate.conf << 'EOF'
logs/test.log {
    daily
    rotate 2
    compress
    missingok
    notifempty
}
EOF

# Run test rotation
logrotate -f /tmp/test-logrotate.conf

# Check result
ls -la logs/test.log*
```

## 🔍 Rotation Monitoring

### Viewing rotation logs

```bash
# Main system log
tail -f logs/ramalama.log

# Monitoring log
tail -f logs/monitor.log

# System cron logs
sudo tail -f /var/log/cron.log

# logrotate logs (if configured)
sudo tail -f /var/log/syslog | grep logrotate
```

### File status verification

```bash
# Log file sizes
du -sh logs/*

# Number of files in each category
find logs/ -name "*.log" | wc -l
find logs/sessions/ -name "*.log" | wc -l

# Oldest files
find logs/ -name "*.log" -type f -printf '%T@ %p\n' | sort -n | head -5
```

## 🛠️ Troubleshooting

### Problem: Logs not rotating

```bash
# Check permissions
ls -la logs/

# Check configuration
logrotate -d config/logrotate-ramalama.conf

# Force rotation
logrotate -f config/logrotate-ramalama.conf
```

### Problem: Cron tasks not executing

```bash
# Check cron status
sudo systemctl status cron

# Check crontab syntax
sudo crontab -l

# Check system logs
sudo journalctl -u cron
```

### Problem: Insufficient space

```bash
# Find largest files
find logs/ -type f -exec du -h {} + | sort -rh | head -10

# Manually clean old archives
find logs/ -name "*.gz" -mtime +30 -delete

# Use log-manager.sh clean
./log-manager.sh clean
```

## 📋 Quick Access Commands

```bash
# Check logging system status
./log-manager.sh status

# Clean old logs
./log-manager.sh clean

# Force rotation via logrotate
logrotate -f config/logrotate-ramalama.conf

# Monitor logs in real-time
./log-manager.sh tail

# logrotate configuration check
logrotate -d config/logrotate-ramalama.conf

# Cron and tasks status
sudo systemctl status cron && sudo crontab -l | grep ramalama
```

## 🎯 Result

After setup, the log rotation system will work automatically:

- **Daily**: Log rotation via system logrotate
- **Daily at 02:30**: Additional cleanup via cron
- **Weekly**: System status check
- **On-demand**: Manual cleanup and rotation

All logs will automatically:
- Archive with timestamp
- Compress to save space  
- Store for 30 days
- Delete when limit exceeded
---

## 🌐 Translations / Переводы

| Language | Documentation | Translation Status |
|----------|---------------|-------------------|
| 🇺🇸 English | [LOGROTATION_GUIDE.en.md](LOGROTATION_GUIDE.en.md) | ✅ Original |
| 🇷🇺 Russian | [LOGROTATION_GUIDE.md](LOGROTATION_GUIDE.md) | ✅ Translation |
| 🇺🇸 English | [README.md](../README.md) | ✅ Main documentation |
| 🇷🇺 Russian | [README.ru.md](../logs/README.ru.md) | ✅ Translation |
