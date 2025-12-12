FROM python:3.11-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Установка ramalama
RUN pip install --no-cache-dir ramalama

# Создание рабочих директорий
RUN mkdir -p /workspace/models /workspace/data

WORKDIR /workspace

# Копирование entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]
