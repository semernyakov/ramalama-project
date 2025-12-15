# RamaLama + llama.cpp Microservices

Production-ready микросервисная архитектура для LLM inference.

## Архитектура

```
┌──────────────────────────────────────────────────────┐
│  Host Machine                                        │
│  ┌────────────────────────────────────────────────┐  │
│  │  Docker Network: ramalama-net (172.20.0.0/16)  │  │
│  │                                                │  │
│  │  ┌──────────────────┐      ┌─────────────────┐ │  │
│  │  │   ramalama       │──────│  llama-cpp      │ │  │
│  │  │   (Python CLI)   │ HTTP │  (Inference)    │ │  │
│  │  │                  │ 8080 │                 │ │  │
│  │  │ - Orchestrator   │      │  - CPU/CUDA     │ │  │
│  │  │ - Model mgmt     │      │  - GGUF models  │ │  │
│  │  │ - HF integration │      │  - OpenAI API   │ │  │
│  │  └──────────────────┘      └─────────────────┘ │  │
│  │           │                         │          │  │
│  │           └────── Shared volumes ───┘          │  │
│  │                    /models                     │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  Exposed: localhost:8080 → llama-cpp:8080            │
└──────────────────────────────────────────────────────┘
```

## Компоненты

### 1. ramalama (Orchestrator)
- **Base**: `python:3.11-slim-bookworm` (~250MB)
- **Роль**: CLI для управления, загрузки моделей, HuggingFace интеграция
- **Подключение**: HTTP client к llama-cpp
- **Build**: Собирается локально с uv (10-20s cached)

### 2. llama.cpp (Inference Server)
- **Base**: `ghcr.io/ggml-org/llama.cpp:full` (официальный)
- **Роль**: CPU inference, OpenAI-compatible API
- **Port**: 8080 (внутренний + внешний)
- **Build**: Pull готового образа

### 3. llama.cpp-cuda (GPU Inference)
- **Base**: `ghcr.io/ggml-org/llama.cpp:full-cuda` (официальный)
- **Роль**: CUDA inference, все слои на GPU
- **Port**: 8080 (внутренний + внешний)
- **Build**: Pull готового образа

## Quick Start

### 1. Setup
```bash
# Создать структуру
mkdir -p ramalama models cache logs data config

# Скопировать конфигурацию
cp config/env.example config/.env

# Отредактировать (опционально)
nano config/.env
```

### 2. Build
```bash
# Собрать ramalama + pull llama.cpp
make build
make pull-llama

# Или быстрее (если уже собирали)
make fast
```

### 3. Run

**CPU mode:**
```bash
make up-cpu
# Запускает: ramalama + llama-cpp
```

**CUDA mode (с GPU):**
```bash
make up-cuda
# Запускает: ramalama + llama-cpp-cuda
```

### 4. Verify
```bash
make verify

# Output:
# ════════════════════════════════════════
# Verifying services...
# 
# RamaLama image:
#   Size: 280MB
# 
# RamaLama health:
#   ✓ ramalama 0.x.x
# 
# llama.cpp health:
#   ✓ {"status":"ok"}
# 
# Network connectivity:
#   ✓ ramalama → llama-cpp OK
# ════════════════════════════════════════
```

## Usage

### Загрузка модели
```bash
# Через ramalama
make shell-rama
ramalama pull tinyllama

# Или напрямую скачать GGUF
wget -P ./models https://huggingface.co/.../model.gguf
```

### Запуск inference
```bash
# 1. Убедитесь, что модель загружена
ls ./models/

# 2. Обновите config/.env
nano config/.env
# LLAMA_MODEL=/models/your-model.gguf

# 3. Перезапустите
make restart

# 4. Проверьте
curl http://localhost:8080/v1/models
```

### Работа с API
```bash
# OpenAI-compatible endpoint
curl http://localhost:8080/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Once upon a time",
    "max_tokens": 100
  }'

# Chat completion
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello!"}
    ]
  }'
```

### Shell access
```bash
# RamaLama shell
make shell-rama

# llama.cpp shell
make shell-llama
```

### Logs
```bash
# Все сервисы
make logs

# Только ramalama
make logs-rama

# Только llama.cpp
make logs-llama
```

## Configuration

### Profiles

**CPU (default):**
- ramalama + llama-cpp
- 4 CPU, 8GB RAM
- Для разработки, тестирования

**CUDA (GPU):**
- ramalama + llama-cpp-cuda
- 8 CPU, 16GB RAM
- Все слои на GPU
- Требует nvidia-docker

### Environment Variables

**config/.env:**
```bash
# llama.cpp настройки
LLAMA_MODEL=/models/model.gguf
LLAMA_CTX_SIZE=2048
LLAMA_THREADS=4
LLAMA_GPU_LAYERS=99  # CUDA mode

# Resources
CPU_LIMIT=4
MEMORY_LIMIT=8g
```

### Networking

- **Internal**: `ramalama-net` (172.20.0.0/16)
- **External**: `localhost:8080` → llama-cpp
- **Service discovery**: `http://llama-cpp:8080` внутри сети

## Commands

### Build
```bash
make build          # Full build (10-20s cached)
make fast           # Ultra-fast (5-10s)
make rebuild        # Clean rebuild
make pull-llama     # Pull llama.cpp images
```

### Run
```bash
make up-cpu         # Start CPU stack
make up-cuda        # Start CUDA stack
make down           # Stop all
make restart        # Restart CPU
make restart-cuda   # Restart CUDA
```

### Shell
```bash
make shell-rama     # RamaLama bash
make shell-llama    # llama.cpp bash
```

### Logs
```bash
make logs           # All services
make logs-rama      # RamaLama only
make logs-llama     # llama.cpp only
```

### Maintenance
```bash
make verify         # Health check
make prune          # Clean cache
make clean          # Full cleanup
```

## Performance

### Build Times
```
First build:        2-3 min (ramalama)
Cached build:       10-20 sec
Fast build:         5-10 sec
Pull llama.cpp:     30-60 sec (depends on network)
```

### Image Sizes
```
ramalama:           ~250-280MB
llama.cpp:full:     ~400MB (official)
llama.cpp:full-cuda: ~2GB (official)
```

### Runtime
```
Startup (CPU):      10-20 sec
Startup (CUDA):     15-30 sec
Inference (CPU):    Depends on model
Inference (CUDA):   5-10x faster than CPU
```

## Troubleshooting

### llama.cpp not responding
```bash
# Check logs
make logs-llama

# Check health
curl http://localhost:8080/health

# Restart
make restart
```

### ramalama can't connect
```bash
# Verify network
make verify

# Check connectivity from ramalama
make shell-rama
curl http://llama-cpp:8080/health
```

### GPU not detected (CUDA)
```bash
# Check nvidia-docker
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Check compose
make shell-llama
nvidia-smi
```

### Model not loading
```bash
# Check model path
ls -lh ./models/

# Check llama.cpp logs
make logs-llama

# Verify config
cat config/.env | grep LLAMA_MODEL
```

## Production Considerations

### Security
- ✅ Non-root users (1000:100)
- ✅ Read-only config mount
- ✅ Isolated network
- ✅ No exposed credentials

### Scaling
- Horizontal: Deploy multiple llama-cpp instances
- Vertical: Increase CPU_LIMIT, MEMORY_LIMIT
- Load balancing: nginx/traefik in front

### Monitoring
- Health checks: `/health` endpoint
- Logs: Centralized logging (ELK, Loki)
- Metrics: Prometheus exporter (custom)

### Backup
- Models: `./models/` directory
- Cache: `./cache/` (regenerable)
- Config: `./config/.env`

## Architecture Benefits

✅ **Separation of concerns**
- ramalama: orchestration, model management
- llama.cpp: pure inference

✅ **Independent scaling**
- Scale llama.cpp instances independently
- Different resource profiles (CPU/GPU)

✅ **Easy upgrades**
- Update ramalama: rebuild only ramalama
- Update llama.cpp: pull new official image

✅ **Flexibility**
- Swap backends (vLLM, TGI, etc.)
- Different inference servers per model

✅ **Development-friendly**
- Fast rebuilds (ramalama only)
- Isolated testing
- Easy debugging

## License

MIT
