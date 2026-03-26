#!/usr/bin/env python3
"""
Minimal backup tool for syncing directories to S3 using AWS CLI.
Dependencies: Python 3.6+, AWS CLI, yaml (optional - can use json instead)
"""

import subprocess
import sys
import os
from pathlib import Path
from datetime import datetime

try:
    import yaml
except ImportError:
    yaml = None


def load_config(config_file):
    """Load configuration from YAML or JSON file."""
    if not os.path.exists(config_file):
        print(f"Error: Config file not found: {config_file}")
        sys.exit(1)
    
    try:
        if yaml:
            with open(config_file, 'r') as f:
                return yaml.safe_load(f)
        else:
            import json
            with open(config_file, 'r') as f:
                return json.load(f)
    except Exception as e:
        print(f"Error reading config: {e}")
        sys.exit(1)


def validate_directory(path):
    """Check if directory exists."""
    if not os.path.isdir(path):
        print(f"Warning: Directory not found: {path}")
        return False
    return True


def backup_to_s3(local_path, s3_path, exclude_patterns=None):
    """Sync a local directory to S3 using AWS CLI."""
    if not validate_directory(local_path):
        return False
    
    cmd = ['aws', 's3', 'sync', local_path, s3_path]
    
    # Add exclude patterns if provided
    if exclude_patterns:
        for pattern in exclude_patterns:
            cmd.extend(['--exclude', pattern])
    
    # Add delete flag to remove deleted files from S3
    cmd.append('--delete')
    
    print(f"[{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] Syncing: {local_path} -> {s3_path}")
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        
        if result.returncode == 0:
            print(f"✓ Backup successful")
            return True
        else:
            print(f"✗ Backup failed: {result.stderr}")
            return False
    except FileNotFoundError:
        print("Error: AWS CLI not found. Install it from https://aws.amazon.com/cli/")
        sys.exit(1)


def main():
    """Main entry point."""
    config_file = sys.argv[1] if len(sys.argv) > 1 else 'backup-config.yaml'
    
    config = load_config(config_file)
    
    if not config or 's3_bucket' not in config or 'backups' not in config:
        print("Error: Config must contain 's3_bucket' and 'backups' sections")
        sys.exit(1)
    
    s3_bucket = config['s3_bucket']
    skip_errors = config.get('skip_errors', False)
    failed_backups = []
    
    print(f"Starting backup to: s3://{s3_bucket}")
    print(f"Number of directories: {len(config['backups'])}")
    print("-" * 60)
    
    for backup_item in config['backups']:
        local_path = backup_item['source']
        s3_key = backup_item.get('destination', Path(local_path).name)
        s3_path = f"s3://{s3_bucket}/{s3_key}"
        exclude = backup_item.get('exclude', [])
        
        success = backup_to_s3(local_path, s3_path, exclude)
        
        if not success:
            failed_backups.append(local_path)
            if not skip_errors:
                sys.exit(1)
        print()
    
    print("-" * 60)
    if failed_backups:
        print(f"Failed backups: {len(failed_backups)}")
        for path in failed_backups:
            print(f"  - {path}")
        sys.exit(1)
    else:
        print("✓ All backups completed successfully")


if __name__ == '__main__':
    main()
