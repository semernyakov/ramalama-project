#!/usr/bin/env python3
"""
llama.cpp API Manager
Manages llama-cpp server via HTTP API from ramalama container
"""

import os
import sys
import json
import time
import requests
from typing import Optional, Dict, Any


class LlamaManager:
    def __init__(self, server_url: Optional[str] = None):
        self.server_url = server_url or os.getenv(
            "LLAMA_CPP_SERVER", "http://llama-cpp:8080"
        )
        self.timeout = 10
        self.retry_count = 3
        self.retry_delay = 2

    def _request(self, method: str, endpoint: str, **kwargs) -> requests.Response:
        """Make HTTP request with retry logic"""
        url = f"{self.server_url}{endpoint}"
        
        for attempt in range(self.retry_count):
            try:
                response = requests.request(
                    method, url, timeout=self.timeout, **kwargs
                )
                response.raise_for_status()
                return response
            except requests.exceptions.RequestException as e:
                if attempt == self.retry_count - 1:
                    raise
                print(f"Retry {attempt + 1}/{self.retry_count}: {e}", file=sys.stderr)
                time.sleep(self.retry_delay)

    def health(self) -> bool:
        """Check llama-cpp server health"""
        try:
            response = self._request("GET", "/health")
            return response.status_code == 200
        except:
            return False

    def props(self) -> Dict[str, Any]:
        """Get server properties"""
        response = self._request("GET", "/props")
        return response.json()

    def models(self) -> Dict[str, Any]:
        """List loaded models (OpenAI compatible)"""
        response = self._request("GET", "/v1/models")
        return response.json()

    def load_model(self, model_path: str) -> Dict[str, Any]:
        """Load model into llama-cpp server"""
        payload = {"model": model_path}
        response = self._request("POST", "/load", json=payload)
        return response.json()

    def unload_model(self) -> Dict[str, Any]:
        """Unload current model"""
        response = self._request("POST", "/unload")
        return response.json()

    def completion(self, prompt: str, **kwargs) -> Dict[str, Any]:
        """Generate completion (OpenAI compatible)"""
        payload = {"prompt": prompt, **kwargs}
        response = self._request("POST", "/v1/completions", json=payload)
        return response.json()

    def chat_completion(self, messages: list, **kwargs) -> Dict[str, Any]:
        """Chat completion (OpenAI compatible)"""
        payload = {"messages": messages, **kwargs}
        response = self._request("POST", "/v1/chat/completions", json=payload)
        return response.json()


def main():
    """CLI interface"""
    if len(sys.argv) < 2:
        print("Usage: llama_manager.py <command> [args]")
        print("\nCommands:")
        print("  health              - Check server health")
        print("  props               - Get server properties")
        print("  models              - List loaded models")
        print("  load <path>         - Load model")
        print("  unload              - Unload model")
        print("  completion <prompt> - Generate completion")
        sys.exit(1)

    manager = LlamaManager()
    command = sys.argv[1]

    try:
        if command == "health":
            healthy = manager.health()
            print(json.dumps({"healthy": healthy}, indent=2))
            sys.exit(0 if healthy else 1)

        elif command == "props":
            result = manager.props()
            print(json.dumps(result, indent=2))

        elif command == "models":
            result = manager.models()
            print(json.dumps(result, indent=2))

        elif command == "load":
            if len(sys.argv) < 3:
                print("Error: model path required", file=sys.stderr)
                sys.exit(1)
            result = manager.load_model(sys.argv[2])
            print(json.dumps(result, indent=2))

        elif command == "unload":
            result = manager.unload_model()
            print(json.dumps(result, indent=2))

        elif command == "completion":
            if len(sys.argv) < 3:
                print("Error: prompt required", file=sys.stderr)
                sys.exit(1)
            prompt = " ".join(sys.argv[2:])
            result = manager.completion(prompt, max_tokens=100)
            print(json.dumps(result, indent=2))

        else:
            print(f"Error: unknown command '{command}'", file=sys.stderr)
            sys.exit(1)

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
