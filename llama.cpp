#!/usr/bin/env python3
"""
Llama.cpp wrapper for RamaLama Docker container
This script intercepts llama.cpp commands and redirects them to our Python server
"""

import sys
import subprocess
import os
import argparse
from pathlib import Path
import re

def main():
    # Remove the script name from sys.argv
    args = sys.argv[1:]
    
    # Print what we're receiving for debugging
    print(f"🔄 Llamacpp wrapper received: {' '.join(args)}")
    
    # Parse the arguments to find what we need
    parser = argparse.ArgumentParser()
    parser.add_argument('--rm', action='store_true', help='Remove container after execution')
    parser.add_argument('--label', action='append', help='Docker labels')
    parser.add_argument('--security-opt', action='append', help='Security options')
    parser.add_argument('--cap-drop', help='Drop capabilities')
    parser.add_argument('--pull', help='Pull policy')
    parser.add_argument('-p', '--publish', help='Port mapping')
    parser.add_argument('--name', help='Container name')
    parser.add_argument('--env', action='append', help='Environment variables')
    parser.add_argument('--init', action='store_true', help='Use init')
    parser.add_argument('--mount', action='append', help='Mount options')
    parser.add_argument('command', nargs='+', help='Command to execute')
    
    try:
        parsed_args, remaining_args = parser.parse_known_args(args)
    except SystemExit:
        # If parsing fails, just pass all args through
        remaining_args = args
        parsed_args = argparse.Namespace()
    
    # Check if this is a server command (look for llama-server in the command args)
    if 'llama-server' in remaining_args:
        # Find the position of llama-server in the command
        llama_server_idx = remaining_args.index('llama-server')
        
        # Extract server arguments (everything after llama-server)
        server_args = remaining_args[llama_server_idx + 1:]
        
        # Look for model path, host, and port
        model_path = None
        host = '0.0.0.0'
        port = 8080
        threads = 4
        temp = 0.8
        chat_template = ''
        
        i = 0
        while i < len(server_args):
            arg = server_args[i]
            if arg == '--model' and i + 1 < len(server_args):
                model_path = server_args[i + 1]
                i += 2
            elif arg == '--host' and i + 1 < len(server_args):
                host = server_args[i + 1]
                i += 2
            elif arg == '--port' and i + 1 < len(server_args):
                port = server_args[i + 1]
                i += 2
            elif arg == '--threads' and i + 1 < len(server_args):
                threads = server_args[i + 1]
                i += 2
            elif arg == '--temp' and i + 1 < len(server_args):
                temp = server_args[i + 1]
                i += 2
            elif arg == '--chat-template-file' and i + 1 < len(server_args):
                chat_template = server_args[i + 1]
                i += 2
            else:
                i += 1
        
        # If we found a model path, start our server
        if model_path:
            print(f"🚀 Starting llama-server with model: {model_path}")
            
            # The model file should be directly available at the mounted path
            if not os.path.exists(model_path):
                print(f"📂 Model path does not exist: {model_path}")
                
                # Create the parent directory if it doesn't exist
                model_dir = os.path.dirname(model_path)
                try:
                    os.makedirs(model_dir, exist_ok=True)
                    print(f"✅ Created directory: {model_dir}")
                    
                    # Check if the file exists now
                    if os.path.exists(model_path):
                        print(f"✅ Model file found at: {model_path}")
                    else:
                        print(f"❌ Model file still not found at: {model_path}")
                        print(f"🔍 Debugging - checking mount points...")
                        
                        # List mount points to see what's available
                        try:
                            result = subprocess.run(['mount'], capture_output=True, text=True)
                            print(f"🔧 Current mounts:")
                            for line in result.stdout.split('\n'):
                                if '/mnt' in line:
                                    print(f"  {line}")
                        except Exception as e:
                            print(f"❌ Error listing mounts: {e}")
                        
                        # List the workspace directory to see what's available
                        try:
                            print(f"📁 Listing /workspace directory:")
                            if os.path.exists('/workspace'):
                                contents = os.listdir('/workspace')
                                print(f"  Contents: {contents}")
                            else:
                                print(f"  /workspace does not exist")
                        except Exception as e:
                            print(f"❌ Error listing /workspace: {e}")
                        
                        sys.exit(1)
                except Exception as e:
                    print(f"❌ Error creating directory {model_dir}: {e}")
                    sys.exit(1)
            else:
                print(f"✅ Model file found at: {model_path}")
            
            # Build the command for our Python server
            server_cmd = [
                '/opt/venv/bin/python3', '/usr/local/bin/llama-server.py',
                '--model', model_path,
                '--host', host,
                '--port', str(port),
                '--threads', str(threads)
            ]
            
            if temp != '0.8':
                server_cmd.extend(['--temp', str(temp)])
            if chat_template:
                server_cmd.extend(['--chat-template-file', chat_template])
            
            print(f"Executing: {' '.join(server_cmd)}")
            
            # Execute our server
            try:
                os.execv('/opt/venv/bin/python3', server_cmd)
            except Exception as e:
                print(f"Error starting server: {e}")
                sys.exit(1)
        else:
            print("❌ No model path found in arguments")
            sys.exit(1)
    else:
        # For non-server commands, try to execute directly or show help
        print("🔧 Non-server command detected")
        print("Available commands:")
        print("  llama-server --model <path> --host <host> --port <port>")
        sys.exit(1)

if __name__ == '__main__':
    main()