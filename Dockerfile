FROM python:3.11-slim

# Установка системных зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    git \
    vim \
    less \
    procps \
    wget \
    build-essential \
    cmake \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Создание рабочих директорий
RUN mkdir -p /workspace/models /workspace/data /workspace/cache

WORKDIR /workspace

# Копирование entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Обновление pip и установка ramalama
RUN pip install --no-cache-dir --upgrade pip wheel setuptools

# Установка ramalama
RUN pip install --no-cache-dir ramalama || \
    pip install --break-system-packages --no-cache-dir ramalama

# Установка llama.cpp для запуска моделей
RUN pip install --no-cache-dir llama-cpp-python || \
    pip install --break-system-packages --no-cache-dir llama-cpp-python

# Создание полноценного llama-server\nRUN cat > /usr/local/bin/llama-server << 'EOF'\n#!/usr/bin/env python3\nimport argparse\nimport sys\nimport json\nfrom http.server import HTTPServer, BaseHTTPRequestHandler\nfrom urllib.parse import urlparse, parse_qs\nimport threading\nimport time\nfrom llama_cpp import Llama\n\nclass LlamaServer:\n    def __init__(self, model_path, host='0.0.0.0', port=8080):\n        self.model_path = model_path\n        self.host = host\n        self.port = port\n        self.model = None\n        \n    def load_model(self):\n        print(f"Loading model: {self.model_path}")\n        self.model = Llama(\n            model_path=self.model_path,\n            n_ctx=2048,\n            n_threads=4,\n            verbose=False\n        )\n        print("Model loaded successfully!")\n        \n    def generate(self, prompt, max_tokens=100, temperature=0.8):\n        if not self.model:\n            return "Model not loaded"\n            \n        response = self.model(\n            prompt=prompt,\n            max_tokens=max_tokens,\n            temperature=temperature,\n            stop=["\\n", "User:", "Assistant:"],\n            echo=False\n        )\n        return response['choices'][0]['text'].strip()\n        \n    def start_server(self):\n        class Handler(BaseHTTPRequestHandler):\n            def __init__(self, *args, **kwargs):\n                self.server_instance = kwargs.pop('server_instance')\n                super().__init__(*args, **kwargs)\n                \n            def do_GET(self):\n                parsed_path = urlparse(self.path)\n                if parsed_path.path == '/health':\n                    self.send_response(200)\n                    self.send_header('Content-type', 'application/json')\n                    self.end_headers()\n                    self.wfile.write(json.dumps({'status': 'ok'}).encode())\n                else:\n                    self.send_response(404)\n                    self.end_headers()\n                    \n            def do_POST(self):\n                parsed_path = urlparse(self.path)\n                if parsed_path.path == '/api/generate':\n                    content_length = int(self.headers['Content-Length'])\n                    post_data = self.rfile.read(content_length)\n                    \n                    try:\n                        data = json.loads(post_data.decode('utf-8'))\n                        prompt = data.get('prompt', '')\n                        max_tokens = data.get('max_tokens', 100)\n                        temperature = data.get('temperature', 0.8)\n                        \n                        response = self.server_instance.generate(prompt, max_tokens, temperature)\n                        \n                        self.send_response(200)\n                        self.send_header('Content-type', 'application/json')\n                        self.send_header('Access-Control-Allow-Origin', '*')\n                        self.end_headers()\n                        \n                        result = {\n                            'response': response,\n                            'model': 'tinyllama',\n                            'created': int(time.time())\n                        }\n                        self.wfile.write(json.dumps(result).encode())\n                        \n                    except Exception as e:\n                        self.send_response(500)\n                        self.send_header('Content-type', 'application/json')\n                        self.end_headers()\n                        error_result = {'error': str(e)}\n                        self.wfile.write(json.dumps(error_result).encode())\n                else:\n                    self.send_response(404)\n                    self.end_headers()\n                    \n            def log_message(self, format, *args):\n                print(f"[{self.log_date_time_string()}] {format % args}")\n                \n        def create_handler_class():\n            class _Handler(Handler):\n                pass\n            _Handler.server_instance = self\n            return _Handler\n            \n        handler_class = create_handler_class()\n        server = HTTPServer((self.host, self.port), handler_class)\n        \n        print(f"Llama server starting on {self.host}:{self.port}")\n        print(f"Health check: http://{self.host}:{self.port}/health")\n        print(f"API endpoint: POST http://{self.host}:{self.port}/api/generate")\n        \n        try:\n            server.serve_forever()\n        except KeyboardInterrupt:\n            print("\\nShutting down server...")\n            server.shutdown()\n            \ndef main():\n    parser = argparse.ArgumentParser(description='Llama.cpp Server')\n    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')\n    parser.add_argument('--port', type=int, default=8080, help='Port to bind to')\n    parser.add_argument('--model', required=True, help='Path to model file')\n    parser.add_argument('--threads', type=int, default=4, help='Number of CPU threads')\n    parser.add_argument('--ctx-size', type=int, default=2048, help='Context size')\n    \n    args = parser.parse_args()\n    \n    server = LlamaServer(\n        model_path=args.model,\n        host=args.host,\n        port=args.port\n    )\n    \n    try:\n        server.load_model()\n        server.start_server()\n    except Exception as e:\n        print(f"Error: {e}")\n        sys.exit(1)\n\nif __name__ == '__main__':\n    main()\nEOF\n\nRUN chmod +x /usr/local/bin/llama-server

# Создаем символические ссылки для совместимости
RUN ln -sf /usr/local/bin/llama-server /usr/local/bin/llama-cpp-server
RUN ln -sf /usr/local/bin/llama-server /usr/local/bin/llama-cli

# Создание конфигурации RamaLama для правильной работы движков
RUN mkdir -p /usr/local/share/ramalama

# Создание конфигурационного файла с настройками движка в формате TOML
RUN cat > /usr/local/share/ramalama/ramalama.conf << 'EOF'
[engine]
type = "docker"

[runtime]
type = "llama.cpp"
EOF

# Создание полноценного llama-server
RUN cat > /usr/local/bin/llama-server << 'EOF'
#!/usr/bin/env python3
import argparse
import sys
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse
import time
from llama_cpp import Llama

# Global server instance for HTTP handlers
_server_instance = None

class LlamaHandler(BaseHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
    def do_GET(self):
        parsed_path = urlparse(self.path)
        if parsed_path.path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok'}).encode())
        else:
            self.send_response(404)
            self.end_headers()
            
    def do_POST(self):
        parsed_path = urlparse(self.path)
        if parsed_path.path == '/api/generate':
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            
            try:
                data = json.loads(post_data.decode('utf-8'))
                prompt = data.get('prompt', '')
                max_tokens = data.get('max_tokens', 100)
                temperature = data.get('temperature', 0.8)
                
                if _server_instance and _server_instance.model:
                    response = _server_instance.model(
                        prompt=prompt,
                        max_tokens=max_tokens,
                        temperature=temperature,
                        stop=["\\n", "User:", "Assistant:"],
                        echo=False
                    )
                    response_text = response['choices'][0]['text'].strip()
                else:
                    response_text = "Model not loaded"
                
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                
                result = {
                    'response': response_text,
                    'model': 'tinyllama',
                    'created': int(time.time())
                }
                self.wfile.write(json.dumps(result).encode())
                
            except Exception as e:
                self.send_response(500)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                error_result = {'error': str(e)}
                self.wfile.write(json.dumps(error_result).encode())
        else:
            self.send_response(404)
            self.end_headers()
            
    def log_message(self, format, *args):
        print(f"[{self.log_date_time_string()}] {format % args}")

class LlamaServer:
    def __init__(self, model_path, host='0.0.0.0', port=8080):
        self.model_path = model_path
        self.host = host
        self.port = port
        self.model = None
        
    def load_model(self):
        print(f"Loading model: {self.model_path}")
        self.model = Llama(
            model_path=self.model_path,
            n_ctx=2048,
            n_threads=4,
            verbose=False
        )
        print("Model loaded successfully!")
        
    def start_server(self):
        global _server_instance
        _server_instance = self
        
        server = HTTPServer((self.host, self.port), LlamaHandler)
        
        print(f"Llama server starting on {self.host}:{self.port}")
        print(f"Health check: http://{self.host}:{self.port}/health")
        print(f"API endpoint: POST http://{self.host}:{self.port}/api/generate")
        
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\\nShutting down server...")
            server.shutdown()
            
def main():
    parser = argparse.ArgumentParser(description='Llama.cpp Server')
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8080, help='Port to bind to')
    parser.add_argument('--model', required=True, help='Path to model file')
    parser.add_argument('--threads', type=int, default=4, help='Number of CPU threads')
    parser.add_argument('--ctx-size', type=int, default=2048, help='Context size')
    
    args = parser.parse_args()
    
    server = LlamaServer(
        model_path=args.model,
        host=args.host,
        port=args.port
    )
    
    try:
        server.load_model()
        server.start_server()
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
EOF

RUN chmod +x /usr/local/bin/llama-server

# Создаем символические ссылки для совместимости
RUN ln -sf /usr/local/bin/llama-server /usr/local/bin/llama-cpp-server
RUN ln -sf /usr/local/bin/llama-server /usr/local/bin/llama-cli

# Настройка Python для работы в контейнере
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PYTHONPATH=/workspace

ENTRYPOINT ["/entrypoint.sh"]
CMD ["--help"]