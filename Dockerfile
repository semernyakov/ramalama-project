# Multi-stage build for security and optimization
FROM python:3.11-slim as builder

# Install build dependencies in builder stage
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip and install Python packages
RUN pip install --no-cache-dir --upgrade pip wheel setuptools
RUN pip install --no-cache-dir ramalama llama-cpp-python

# Production stage
FROM python:3.11-slim

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    curl \
    git \
    vim \
    less \
    procps \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create working directories with proper permissions
RUN mkdir -p /workspace/models /workspace/data /workspace/cache
RUN useradd -m -u 1000 ramalama || true

WORKDIR /workspace

# Copy llama-server script
COPY llama-server.py /usr/local/bin/llama-server
RUN chmod +x /usr/local/bin/llama-server

# Copy entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create symlinks for compatibility
RUN ln -sf /usr/local/bin/llama-server /usr/local/bin/llama-cpp-server
RUN ln -sf /usr/local/bin/llama-server /usr/local/bin/llama-cli

# Create configuration directory
RUN mkdir -p /usr/local/share/ramalama

# Create configuration file
RUN cat > /usr/local/share/ramalama/ramalama.conf << 'EOF'
[engine]
type = "docker"

[runtime]
type = "llama.cpp"
EOF

# Set proper permissions
RUN chown -R ramalama:ramalama /workspace

# Environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/workspace

# Switch to non-root user
USER ramalama

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]