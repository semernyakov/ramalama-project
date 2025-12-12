# RamaLama Test Suite

This directory contains all testing utilities and scripts for the RamaLama Docker project.

## Test Files

### Shell Scripts
- **`test-cache.sh`** - Cache testing and validation script
- **`quick-test.sh`** - Quick system validation and health checks

### Python Testing
- **`__init__.py`** - Makes this directory a Python package for test imports

## Usage

### Running Individual Tests

```bash
# Run cache test
./test/test-cache.sh

# Run quick system test
./test/quick-test.sh
```

### Using main.py for Testing

The project also includes a comprehensive testing interface through `main.py`:

```bash
# Show system status
python3 main.py status

# Perform health checks
python3 main.py health

# List available models
python3 main.py list-models

# Run command in container
python3 main.py run "ramalama info"
```

## Test Categories

### 1. System Health Tests
- Docker daemon availability
- docker-compose functionality
- Directory structure validation
- Disk space monitoring

### 2. Container Tests
- Container startup/shutdown
- Health check endpoints
- Resource limits validation
- Network connectivity

### 3. Model Tests
- Model file detection
- Model file integrity
- Storage space validation

### 4. Integration Tests
- End-to-end workflow testing
- API endpoint validation
- Log management testing

## Test Environment

All tests assume the following directory structure:
```
/home/master/ai-workspace/ramalama-project/
├── models/          # Model files storage
├── logs/            # Application logs
├── data/            # User data
├── cache/           # Cache directory
├── config/          # Configuration files
└── test/            # Test scripts (this directory)
```

## Prerequisites

- Docker and docker-compose installed
- Python 3.11+ available
- Sufficient disk space for models
- Proper file permissions

## Continuous Integration

These tests are designed to be used in CI/CD pipelines:
```bash
#!/bin/bash
# CI test runner
set -euo pipefail

echo "Running RamaLama test suite..."
python3 main.py health || exit 1
./test/quick-test.sh || exit 1
echo "All tests passed!"
```

## Troubleshooting

If tests fail, check:
1. Docker daemon is running
2. All directories exist with proper permissions
3. Sufficient disk space is available
4. Network connectivity is working

For detailed logs, check:
- `logs/ramalama_manager.log` - Main application logs
- `logs/` directory - Container logs
---

## 🌐 Translations / Переводы

| Language | Documentation | Translation Status |
|----------|---------------|-------------------|
| 🇺🇸 English | [test/README.md](test/README.md) | ✅ Original |
| 🇷🇺 Russian | [test/README.ru.md](test/README.ru.md) | ✅ Translation |
| 🇺🇸 English | [README.md](../README.md) | ✅ Main documentation |
| 🇷🇺 Russian | [README.ru.md](../logs/README.ru.md) | ✅ Translation |
