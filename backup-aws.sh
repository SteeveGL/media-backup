#!/bin/bash
# Pure AWS CLI backup script (Bash) - no Python required
# Only dependency: AWS CLI
# Usage: ./backup-aws.sh

set -e

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI not found"
    echo "Install from: https://aws.amazon.com/cli/"
    exit 1
fi

# Configuration
S3_BUCKET="my-backup-bucket"
SKIP_ERRORS=false

# Define your backups here
# Format: "local/path:s3-destination:exclude1:exclude2:..."
BACKUPS=(
    "/home/user/Pictures:pictures:*.tmp"
    "/home/user/Documents:docs:.git:node_modules"
    "/home/user/Videos:videos:*.partial"
)

echo "Starting backup to: s3://$S3_BUCKET"
echo "Number of directories: ${#BACKUPS[@]}"
echo "------------------------------------------------------------"
echo ""

SUCCESS=0
FAILED=0

# Backup each directory
for backup_entry in "${BACKUPS[@]}"; do
    # Parse entry
    IFS=':' read -r source dest excludes_str <<< "$backup_entry"
    
    # Convert exclude string to array
    IFS=':' read -ra EXCLUDES <<< "$excludes_str"
    
    S3_PATH="s3://$S3_BUCKET/$dest"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Syncing: $source -> $S3_PATH"
    
    # Build AWS CLI command
    cmd="aws s3 sync \"$source\" \"$S3_PATH\" --delete"
    
    # Add exclude patterns
    for exclude in "${EXCLUDES[@]}"; do
        if [ -n "$exclude" ]; then
            cmd="$cmd --exclude \"$exclude\""
        fi
    done
    
    # Run sync
    if eval "$cmd" 2>&1; then
        echo "✓ Backup successful"
        ((SUCCESS++))
    else
        echo "✗ Backup failed"
        ((FAILED++))
        if [ "$SKIP_ERRORS" != "true" ]; then
            exit 1
        fi
    fi
    echo ""
done

echo "------------------------------------------------------------"
echo "Completed: $SUCCESS successful, $FAILED failed"

if [ $FAILED -gt 0 ]; then
    exit 1
fi
