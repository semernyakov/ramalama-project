FROM debian:12-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl wget git gpg lsb-release gnupg apt-transport-https \
    build-essential cmake python3 python3-pip python3-venv python3-dev \
    bash vim nano less file libc6 libgcc1 libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/project-baize/ramalama/main/install.sh | bash

WORKDIR /workspace

RUN mkdir -p /workspace/{models,cache,logs,data,config} && chmod -R 755 /workspace

ENV RAMALAMA_STORE=/workspace/models
ENV HF_HOME=/workspace/cache
ENV RAMALAMA_IN_CONTAINER=1
ENV RAMALAMA_LOG_LEVEL=INFO
ENV PYTHONUNBUFFERED=1
ENV PIP_NO_CACHE_DIR=1

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

EXPOSE 8080
CMD ["tail", "-f", "/dev/null"]