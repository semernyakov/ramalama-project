# syntax=docker/dockerfile:1.4

# ============================================
# BUILDER STAGE
# ============================================
FROM python:3.11-slim as builder

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    cmake \
    pkg-config \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv (fast Python dependency resolver)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv"

# Install Python packages with uv (much faster than pip)
# uv can act as a drop-in replacement for pip
RUN --mount=type=cache,target=/root/.cache/pip \
    uv pip install --upgrade pip setuptools wheel && \
    uv pip install --no-cache-dir \
    llama-cpp-python==0.3.0 \
    ramalama==0.1.2

# ============================================
# PRODUCTION STAGE
# ============================================
FROM python:3.11-slim

# Install only runtime dependencies (minimal footprint)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    vim \
    less \
    procps \
    wget \
    libgomp1 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user BEFORE changing ownership
RUN useradd -m -u 1000 ramalama || true

# Copy virtual environment from builder (lightweight copy)
COPY --from=builder --chown=ramalama:ramalama /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH" \
    VIRTUAL_ENV="/opt/venv" \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/workspace

# Create unified workspace hierarchy
RUN mkdir -p /workspace/{models,logs,data,cache,config,tmp} && \
    chown -R ramalama:ramalama /workspace && \
    chmod -R 755 /workspace

WORKDIR /workspace

# Copy wrapper scripts
COPY --chown=ramalama:ramalama llama.cpp /usr/local/bin/llama.cpp
RUN chmod +x /usr/local/bin/llama.cpp

# COPY --chown=ramalama:ramalama llama-server.py /usr/local/bin/llama-server.py
# RUN chmod +x /usr/local/bin/llama-server.py

# Copy entrypoint
COPY --chown=ramalama:ramalama scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Environment variables from docker-compose.yml will override these
ENV RAMALAMA_MODELS_PATH=/workspace/models \
    RAMALAMA_DATA_PATH=/workspace/data \
    RAMALAMA_LOG_FILE=/workspace/logs/ramalama.log \
    RAMALAMA_ENGINE=llama.cpp \
    RAMALAMA_LOG_LEVEL=ERROR \
    HF_HUB_DISABLE_PROGRESS_BARS=false \
    HF_HUB_ENABLE_HF_TRANSFER=1

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Switch to non-root user
USER ramalama

# Default entrypoint
ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]