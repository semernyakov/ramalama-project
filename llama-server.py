j,yjdbnm ljr#!/usr/bin/env python3
"""
Llama Server - A simple HTTP server for running LLM inference
"""

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
    """HTTP request handler for the Llama server"""
    
    def do_GET(self):
        """Handle GET requests (health check)"""
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
        """Handle POST requests (generate text)"""
        parsed_path = urlparse(self.path)
        if parsed_path.path == '/api/generate':
            try:
                content_length = int(self.headers['Content-Length'])
                post_data = self.rfile.read(content_length)
                
                data = json.loads(post_data.decode('utf-8'))
                prompt = data.get('prompt', '')
                max_tokens = data.get('max_tokens', 100)
                temperature = data.get('temperature', 0.8)
                
                if _server_instance and _server_instance.model:
                    response = _server_instance.model(
                        prompt=prompt,
                        max_tokens=max_tokens,
                        temperature=temperature,
                        stop=["\n", "User:", "Assistant:"],
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
        """Custom log message formatting"""
        print(f"[{self.log_date_time_string()}] {format % args}")


class LlamaServer:
    """Main server class for handling LLM inference"""
    
    def __init__(self, model_path, host='0.0.0.0', port=8080):
        self.model_path = model_path
        self.host = host
        self.port = port
        self.model = None
        
    def load_model(self):
        """Load the LLM model"""
        print(f"Loading model: {self.model_path}")
        self.model = Llama(
            model_path=self.model_path,
            n_ctx=2048,
            n_threads=4,
            verbose=False
        )
        print("Model loaded successfully!")
        
    def start_server(self):
        """Start the HTTP server"""
        global _server_instance
        _server_instance = self
        
        server = HTTPServer((self.host, self.port), LlamaHandler)
        
        print(f"Llama server starting on {self.host}:{self.port}")
        print(f"Health check: http://{self.host}:{self.port}/health")
        print(f"API endpoint: POST http://{self.host}:{self.port}/api/generate")
        
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server...")
            server.shutdown()
            
            
def main():
    """Main entry point"""
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