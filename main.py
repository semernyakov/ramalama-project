#!/usr/bin/env python3
"""
RamaLama Project Main Entry Point
Provides utility functions and CLI interface for the RamaLama Docker project.
"""

import argparse
import os
import sys
import json
import subprocess
import logging
from pathlib import Path
from typing import Dict, List, Optional


class RamaLamaManager:
    """Main manager class for RamaLama operations"""
    
    def __init__(self):
        self.project_root = Path(__file__).parent
        self.models_dir = self.project_root / "models"
        self.logs_dir = self.project_root / "logs"
        self.data_dir = self.project_root / "data"
        self.config_dir = self.project_root / "config"
        
        # Setup logging
        self.setup_logging()
        
    def setup_logging(self):
        """Setup centralized logging configuration"""
        self.logs_dir.mkdir(exist_ok=True)
        log_file = self.logs_dir / "ramalama_manager.log"
        
        logging.basicConfig(
            level=logging.INFO,
            format='[%(asctime)s] [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler(log_file),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
        
    def check_docker_status(self) -> bool:
        """Check if Docker is running and accessible"""
        try:
            result = subprocess.run(
                ["docker", "ps"],
                capture_output=True,
                text=True,
                check=True
            )
            self.logger.info("Docker is running and accessible")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            self.logger.error(f"Docker check failed: {e}")
            return False
            
    def check_compose_status(self) -> bool:
        """Check if docker-compose is available"""
        try:
            result = subprocess.run(
                ["docker-compose", "--version"],
                capture_output=True,
                text=True,
                check=True
            )
            self.logger.info("docker-compose is available")
            return True
        except (subprocess.CalledProcessError, FileNotFoundError) as e:
            self.logger.error(f"docker-compose check failed: {e}")
            return False
            
    def list_models(self) -> List[Dict[str, str]]:
        """List available models in the models directory"""
        models = []
        
        if not self.models_dir.exists():
            self.logger.warning("Models directory does not exist")
            return models
            
        for model_file in self.models_dir.rglob("*.gguf"):
            size = model_file.stat().st_size if model_file.exists() else 0
            models.append({
                "name": model_file.name,
                "path": str(model_file.relative_to(self.models_dir)),
                "size": f"{size / (1024*1024):.1f} MB" if size > 0 else "Unknown"
            })
            
        self.logger.info(f"Found {len(models)} models")
        return models
        
    def check_disk_space(self) -> Dict[str, float]:
        """Check available disk space"""
        try:
            stat = os.statvfs(str(self.project_root))
            total = stat.f_blocks * stat.f_frsize
            free = stat.f_bavail * stat.f_frsize
            used = total - free
            
            return {
                "total_gb": total / (1024**3),
                "used_gb": used / (1024**3),
                "free_gb": free / (1024**3),
                "usage_percent": (used / total) * 100
            }
        except Exception as e:
            self.logger.error(f"Failed to check disk space: {e}")
            return {}
            
    def run_container_command(self, command: str) -> bool:
        """Run a command inside the RamaLama container"""
        try:
            cmd = ["docker-compose", "exec", "-T", "ramalama"] + command.split()
            result = subprocess.run(cmd, check=True)
            self.logger.info(f"Successfully executed: {command}")
            return True
        except subprocess.CalledProcessError as e:
            self.logger.error(f"Failed to execute command '{command}': {e}")
            return False
            
    def health_check(self) -> Dict[str, bool]:
        """Perform comprehensive health check"""
        checks = {
            "docker": self.check_docker_status(),
            "docker_compose": self.check_compose_status(),
            "models_directory": self.models_dir.exists(),
            "logs_directory": self.logs_dir.exists(),
            "data_directory": self.data_dir.exists(),
            "config_directory": self.config_dir.exists(),
        }
        
        return checks
        
    def show_status(self):
        """Display comprehensive system status"""
        print("🚀 RamaLama Project Status")
        print("=" * 50)
        
        # Health checks
        health = self.health_check()
        print("\n📋 Health Checks:")
        for check, status in health.items():
            status_icon = "✅" if status else "❌"
            print(f"  {status_icon} {check.replace('_', ' ').title()}")
            
        # Disk space
        disk_info = self.check_disk_space()
        if disk_info:
            print(f"\n💾 Disk Space:")
            print(f"  Total: {disk_info['total_gb']:.1f} GB")
            print(f"  Used: {disk_info['used_gb']:.1f} GB ({disk_info['usage_percent']:.1f}%)")
            print(f"  Free: {disk_info['free_gb']:.1f} GB")
            
        # Models
        models = self.list_models()
        print(f"\n📦 Models ({len(models)} found):")
        for model in models[:5]:  # Show first 5 models
            print(f"  • {model['name']} ({model['size']})")
        if len(models) > 5:
            print(f"  ... and {len(models) - 5} more")
            
        print("\n" + "=" * 50)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="RamaLama Project Manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py status          # Show system status
  python main.py list-models     # List available models
  python main.py run "ramalama info"  # Run command in container
  python main.py health          # Perform health checks
        """
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # Status command
    subparsers.add_parser('status', help='Show system status')
    
    # List models command
    subparsers.add_parser('list-models', help='List available models')
    
    # Health check command
    subparsers.add_parser('health', help='Perform health checks')
    
    # Run command
    run_parser = subparsers.add_parser('run', help='Run command in container')
    run_parser.add_argument('command', help='Command to run in container')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
        
    manager = RamaLamaManager()
    
    try:
        if args.command == 'status':
            manager.show_status()
        elif args.command == 'list-models':
            models = manager.list_models()
            if models:
                print("Available Models:")
                for model in models:
                    print(f"  • {model['name']} - {model['size']}")
            else:
                print("No models found")
        elif args.command == 'health':
            health = manager.health_check()
            all_good = all(health.values())
            print("Health Check Results:")
            for check, status in health.items():
                status_icon = "✅" if status else "❌"
                print(f"  {status_icon} {check.replace('_', ' ').title()}")
            sys.exit(0 if all_good else 1)
        elif args.command == 'run':
            if len(sys.argv) < 3:
                print("Error: Please provide a command to run")
                sys.exit(1)
            command = ' '.join(sys.argv[3:])
            success = manager.run_container_command(command)
            sys.exit(0 if success else 1)
        else:
            print(f"Unknown command: {args.command}")
            parser.print_help()
            sys.exit(1)
            
    except KeyboardInterrupt:
        print("\nOperation cancelled by user")
        sys.exit(1)
    except Exception as e:
        print(f"Error: {e}")
        manager.logger.error(f"Unexpected error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
