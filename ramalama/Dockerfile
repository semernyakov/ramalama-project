# syntax=docker/dockerfile:1.7

########################
# Base: Python 3.11
########################
FROM python:3.11-slim-bookworm AS base

ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG NO_PROXY
ARG BUILDKIT_INLINE_CACHE=1

ENV DEBIAN_FRONTEND=noninteractive \
    HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

########################
# Build stage
########################
FROM base AS build

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    if [ -n "${HTTP_PROXY:-}" ] && ! printf '%s' "$HTTP_PROXY" | grep -qiE '^https?://'; then \
        if printf '%s' "$HTTP_PROXY" | grep -q '://'; then \
            export HTTP_PROXY="http://$(printf '%s' "$HTTP_PROXY" | sed 's,://,:,')"; \
        else \
            export HTTP_PROXY="http://$HTTP_PROXY"; \
        fi; \
    fi && \
    if [ -n "${HTTPS_PROXY:-}" ] && ! printf '%s' "$HTTPS_PROXY" | grep -qiE '^https?://'; then \
        if printf '%s' "$HTTPS_PROXY" | grep -q '://'; then \
            export HTTPS_PROXY="http://$(printf '%s' "$HTTPS_PROXY" | sed 's,://,:,')"; \
        else \
            export HTTPS_PROXY="http://$HTTPS_PROXY"; \
        fi; \
    fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        build-essential

# Install uv
RUN --mount=type=cache,target=/root/.cache \
    curl -LsSf https://astral.sh/uv/install.sh | sh && \
    mv /root/.local/bin/uv /usr/local/bin/uv && \
    mv /root/.local/bin/uvx /usr/local/bin/uvx

# Install ramalama with optimizations
RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    uv venv /opt/venv && \
    uv pip install --python=/opt/venv/bin/python --compile-bytecode \
        ramalama \
        argcomplete \
        requests && \
    find /opt/venv -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/venv -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true && \
    find /opt/venv -type f -name "*.pyc" -delete && \
    find /opt/venv -type f -name "*.pyo" -delete

########################
# Final stage
########################
FROM base AS final

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    if [ -n "${HTTP_PROXY:-}" ] && ! printf '%s' "$HTTP_PROXY" | grep -qiE '^https?://'; then \
        if printf '%s' "$HTTP_PROXY" | grep -q '://'; then \
            export HTTP_PROXY="http://$(printf '%s' "$HTTP_PROXY" | sed 's,://,:,')"; \
        else \
            export HTTP_PROXY="http://$HTTP_PROXY"; \
        fi; \
    fi && \
    if [ -n "${HTTPS_PROXY:-}" ] && ! printf '%s' "$HTTPS_PROXY" | grep -qiE '^https?://'; then \
        if printf '%s' "$HTTPS_PROXY" | grep -q '://'; then \
            export HTTPS_PROXY="http://$(printf '%s' "$HTTPS_PROXY" | sed 's,://,:,')"; \
        else \
            export HTTPS_PROXY="http://$HTTPS_PROXY"; \
        fi; \
    fi && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        bash && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY --from=build /usr/local/bin/uv /usr/local/bin/uvx /usr/local/bin/
COPY --from=build /opt/venv /opt/venv

RUN useradd -m -u 1000 -g 100 -s /bin/bash ramalama && \
    mkdir -p /workspace/{models,cache,logs,data,config} && \
    chown -R ramalama:users /workspace

ENV PATH="/opt/venv/bin:/usr/local/bin:${PATH}" \
    VIRTUAL_ENV="/opt/venv" \
    RAMALAMA_STORE=/workspace/models \
    RAMALAMA_IN_CONTAINER=1 \
    RAMALAMA_LOG_LEVEL=INFO \
    RAMALAMA_LOG_FILE=/workspace/logs/ramalama.log \
    LLAMA_CPP_SERVER=http://llama-cpp:8080 \
    HF_HOME=/workspace/cache \
    HF_HUB_CACHE=/workspace/cache/huggingface \
    HF_HUB_ENABLE_HF_TRANSFER=1 \
    HF_HUB_DISABLE_PROGRESS_BARS=false \
    HF_HUB_DISABLE_TELEMETRY=1 \
    TRANSFORMERS_NO_ADVISORY_WARNINGS=1

WORKDIR /workspace
USER ramalama

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD ramalama --version || exit 1

CMD ["bash", "-c", "tail -f /dev/null"]
