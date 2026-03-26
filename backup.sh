#!/bin/bash
# Linux/macOS shell script to run media-backup
# Usage: ./backup.sh [config_file]
# Example: ./backup.sh backup-config.yaml

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if Python is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: Python 3 is not installed or not in PATH"
    echo "Please install Python 3 from https://www.python.org/"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed or not in PATH"
    echo "Please install from https://aws.amazon.com/cli/"
    echo "Or run: pip install awscli"
    exit 1
fi

# Determine config file
CONFIG_FILE="${1:-backup-config.yaml}"

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Config file not found: $CONFIG_FILE"
    echo "Please create a config file or check the path"
    exit 1
fi

echo "Running backup with config: $CONFIG_FILE"
echo ""

python3 backup.py "$CONFIG_FILE"
EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -ne 0 ]; then
    echo "Backup completed with errors (exit code: $EXIT_CODE)"
else
    echo "Backup completed successfully"
fi

exit $EXIT_CODE
