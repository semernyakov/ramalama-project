# RamaLama Troubleshooting Guide

Guide for solving problems when working with RamaLama through Docker.

## 📋 Table of Contents

- [Proxy Issues](#proxy-issues)
- [Docker Issues](#docker-issues)
- [Model Issues](#model-issues)
- [Performance Issues](#performance-issues)
- [Common Errors](#common-errors)
- [Logging and Debugging](#logging-and-debugging)

---

## 🌐 Proxy Issues

### Problem: Infinite loop on `INFO:ramalama:Using proxy` logs

**Symptoms:**
```
INFO:ramalama:Using proxy: ftp=http://127.0.0.1:2080/
INFO:ramalama:Using proxy: https=http://127.0.0.1:2080/
INFO:ramalama:Using proxy: http=http://127.0.0.1:2080/
INFO:ramalama:Using proxy: all=socks://127.0.0.1:2080/
[repeats infinitely...]
```

**Solution:**

✅ **Already fixed in our configuration!**

Verify that our version is being used:
```bash
# In entrypoint.sh should have:
export RAMALAMA_LOG_LEVEL="ERROR"
```

If problem persists:
```bash
# Rebuild image
./ramalama.sh rebuild
```

---

### Problem: Proxy inaccessible from container

**Symptoms:**
```
Connection refused
Unable to connect to proxy
```

**Diagnosis:**
```bash
# 1. Check proxy on host
curl -I --proxy http://127.0.0.1:2080 https://google.com

# 2. Check from container
./ramalama.sh shell
curl -I https://google.com
```

**Solutions:**

1. **Use host network** (already configured in docker-compose.yml):
```yaml
network_mode: host
```

2. **Check that proxy is running:**
```bash
netstat -tuln | grep 2080
# or
lsof -i :2080
```

3. **If proxy is on another host**, change in `.env`:
```bash
HTTP_PROXY=http://192.168.1.100:2080
```

---

### Problem: Working without proxy

**If proxy is not needed:**

```bash
# Option 1: Use no-proxy profile
docker-compose --profile no-proxy run ramalama-no-proxy list

# Option 2: Comment out in docker-compose.yml
environment:
  # - HTTP_PROXY=http://127.0.0.1:2080
  # - HTTPS_PROXY=http://127.0.0.1:2080
```

---

## 🐳 Docker Issues

### Problem: Docker image fails to build

**Symptoms:**
```
ERROR: failed to solve
```

**Solutions:**

1. **Clear cache and rebuild:**
```bash
./ramalama.sh rebuild
```

2. **Check disk space:**
```bash
df -h
docker system df
```

3. **Clean Docker:**
```bash
docker system prune -a
```

---

### Problem: Container won't start

**Diagnosis:**
```bash
# Check logs
docker-compose logs

# Check status
docker ps -a

# Detailed information
docker inspect ramalama
```

**Solutions:**

1. **Check permissions:**
```bash
ls -la models/ data/
chmod -R 755 models/ data/
```

2. **Check entrypoint:**
```bash
chmod +x entrypoint.sh
```

3. **Recreate container:**
```bash
docker-compose down -v
docker-compose up
```

---

### Problem: Volume not mounting

**Symptoms:**
- Models don't persist after restart
- Changes in `models/` not visible in container

**Solutions:**

1. **Check paths in docker-compose.yml:**
```yaml
volumes:
  - ./models:/workspace/models  # Relative path
  # or
  - /absolute/path/models:/workspace/models  # Absolute path
```

2. **Create directories manually:**
```bash
mkdir -p models data
```

3. **Check SELinux (if used):**
```bash
chcon -Rt svirt_sandbox_file_t models/ data/
```

---

## 🤖 Model Issues

### Problem: Model won't download

**Symptoms:**
```
Error downloading model
Connection timeout
```

**Solutions:**

1. **Check proxy:**
```bash
./ramalama.sh shell
curl -I https://huggingface.co
```

2. **Check disk space:**
```bash
df -h ./models
```

3. **Try another model:**
```bash
# Small model for test
./ramalama.sh pull tinyllama
```

4. **Increase timeouts:**
```bash
# In docker-compose.yml add
environment:
  - RAMALAMA_DOWNLOAD_TIMEOUT=600
```

---

### Problem: Model downloaded but won't start

**Diagnosis:**
```bash
# Check model list
./ramalama.sh list

# Check files
ls -lh models/

# Check integrity
./ramalama.sh -- verify <model_name>
```

**Solutions:**

1. **Re-download model:**
```bash
./ramalama.sh rm <model_name>
./ramalama.sh pull <model_name>
```

2. **Check memory:**
```bash
free -h
# Models require RAM minimum 2x size
```

---

### Problem: Slow model loading

**Solutions:**

1. **Use Hugging Face mirrors:**
```bash
export HF_ENDPOINT=https://hf-mirror.com
```

2. **Download via browser and place in models/:**
```bash
# Download manually, then:
cp ~/Downloads/model.gguf models/
./ramalama.sh list  # Should appear
```

3. **Use resume for large models:**
```bash
# RamaLama automatically resumes downloads
```

---

## ⚡ Performance Issues

### Problem: Slow text generation

**Solutions:**

1. **Use smaller model:**
```bash
# Instead of 7B use 1B
./ramalama.sh pull llama3.2:1b
```

2. **Limit context:**
```bash
./ramalama.sh run <model> --context-size 2048
```

3. **Configure batch size:**
```bash
./ramalama.sh run <model> --batch-size 512
```

4. **Allocate more Docker memory:**
```yaml
# docker-compose.yml
deploy:
  resources:
    limits:
      memory: 8G
```

---

### Problem: High CPU usage

**Solutions:**

1. **Use GPU (if available):**
```yaml
# docker-compose.yml
deploy:
  resources:
    reservations:
      devices:
        - driver: nvidia
          count: 1
          capabilities: [gpu]
```

2. **Limit thread count:**
```bash
./ramalama.sh run <model> --threads 4
```

---

### Problem: Out of Memory

**Symptoms:**
```
Out of memory
Killed
137 exit code
```

**Solutions:**

1. **Use smaller model:**
```bash
# Approximate requirements:
# 1B model ~2GB RAM
# 3B model ~4GB RAM
# 7B model ~8GB RAM
```

2. **Increase swap:**
```bash
sudo dd if=/dev/zero of=/swapfile bs=1G count=8
sudo mkswap /swapfile
sudo swapon /swapfile
```

3. **Use quantized models:**
```bash
# Q4 or Q5 instead of Q8
./ramalama.sh pull llama3.2:1b-q4
```

---

## ❌ Common Errors

### `Permission denied`

**Solution:**
```bash
chmod +x ramalama.sh entrypoint.sh quick-test.sh
chmod -R 755 models/ data/
```

---

### `Port already in use`

**Solution:**
```bash
# Find process
lsof -i :8080

# Stop
kill <PID>

# Or use different port
./ramalama.sh serve <model> --port 8081
```

---

### `Image not found`

**Solution:**
```bash
./ramalama.sh build
```

---

### `Cannot connect to Docker daemon`

**Solution:**
```bash
# Start Docker
sudo systemctl start docker

# Add user to group
sudo usermod -aG docker $USER
newgrp docker
```

---

## 🔍 Logging and Debugging

### Enable verbose logs

```bash
# Option 1: Change in docker-compose.yml
environment:
  - RAMALAMA_LOG_LEVEL=DEBUG

# Option 2: Temporarily
docker-compose run -e RAMALAMA_LOG_LEVEL=DEBUG ramalama <command>
```

---

### View container logs

```bash
# All logs
docker-compose logs

# Last 50 lines
docker-compose logs --tail=50

# Real-time
docker-compose logs -f

# Specific container logs
docker logs ramalama
```

---

### Debugging inside container

```bash
# Open shell
./ramalama.sh shell

# Inside container:
ramalama --version
ramalama info
env | grep -i proxy
curl -I https://google.com
```

---

### Save logs for analysis

```bash
# Docker logs
docker-compose logs > docker-logs.txt

# System information
./ramalama.sh info > system-info.txt

# Model list
./ramalama.sh list > models-list.txt

# Send these files when asking for help
```

---

## 🆘 Emergency Recovery

### Complete reinstallation

```bash
# 1. Stop and remove everything
./ramalama.sh clean
docker system prune -a

# 2. Save models (optional)
./backup.sh create

# 3. Reinstall
./ramalama.sh build
./quick-test.sh

# 4. Restore models (if needed)
./backup.sh restore backups/ramalama_backup_*.tar.gz
```

---

### Factory reset

```bash
# WARNING: Will delete all models and data!

rm -rf models/* data/*
./ramalama.sh rebuild
./ramalama.sh info
```

---

## 📞 Get Help

1. **Check logs:**
```bash
./monitor.sh -s > debug-info.txt
```

2. **Run diagnostics:**
```bash
./quick-test.sh > test-results.txt
```

3. **Gather information:**
```bash
echo "=== System Info ===" > support-info.txt
uname -a >> support-info.txt
docker --version >> support-info.txt
docker-compose --version >> support-info.txt
echo "=== Environment ===" >> support-info.txt
env | grep -i proxy >> support-info.txt
```

4. **Check documentation:**
- README.md - main documentation
- examples.sh - usage examples
- Official RamaLama documentation

---

## ✅ Verification Checklist

Before asking for help, verify:

- [ ] Docker is running and working
- [ ] Image built (`docker images | grep ramalama`)
- [ ] Sufficient disk space (`df -h`)
- [ ] Permissions are correct (`ls -la models/`)
- [ ] Proxy configured correctly (if used)
- [ ] Scripts are executable (`ls -l *.sh`)
- [ ] Logs checked (`docker-compose logs`)
- [ ] Tests passed (`./quick-test.sh`)

---

**Last updated:** 2024
---

## 🌐 Translations / Переводы

| Language | Documentation | Translation Status |
|----------|---------------|-------------------|
| 🇺🇸 English | [TROUBLESHOOTING.en.md](TROUBLESHOOTING.en.md) | ✅ Original |
| 🇷🇺 Russian | [TROUBLESHOOTING.md](../test/TROUBLESHOOTING.md) | ✅ Translation |
| 🇺🇸 English | [README.md](../README.md) | ✅ Main documentation |
| 🇷🇺 Russian | [README.ru.md](../logs/README.ru.md) | ✅ Translation |
