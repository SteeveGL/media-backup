# Media Backup Tool

A minimal, lightweight backup tool for syncing directories to AWS S3 using AWS CLI.

## Features

- **Minimal dependencies**: Only requires Python 3.6+ and AWS CLI
- **Simple configuration**: YAML or JSON config files
- **Selective syncing**: Exclude patterns support (.tmp, node_modules, etc.)
- **Safe deletion**: Optional removal of deleted files from S3
- **Error handling**: Skip errors and continue, or abort on first failure
- **Clear logging**: Timestamped output for each backup

## Prerequisites

1. **Python 3.6+**
   ```bash
   python --version
   ```

2. **AWS CLI** (version 1.x or 2.x)
   ```bash
   # Install or update AWS CLI:
   # Windows: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   # macOS/Linux: pip install --upgrade awscli
   
   # Verify installation:
   aws --version
   ```

3. **AWS Credentials** configured locally
   ```bash
   # Run this and enter your AWS Access Key ID and Secret Access Key
   aws configure
   ```

## Installation

1. **Clone or download this repository**

2. (**Optional**) Install PyYAML for YAML support:
   ```bash
   pip install -r requirements.txt
   ```
   > Without PyYAML, the tool will automatically fall back to JSON format

## Usage

### 1. Configure your backups

Edit [backup-config.yaml](backup-config.yaml) and specify:
- Your S3 bucket name
- Source directories to backup
- Optional: exclude patterns and S3 destination paths

Example:
```yaml
s3_bucket: "my-media-backup"

backups:
  - source: "C:\\Users\\Me\\Pictures"
    destination: "pictures"
    exclude:
      - "*.tmp"
      - "Thumbs.db"

  - source: "C:\\Users\\Me\\Documents"
    destination: "docs"
```

### 2. Run the backup

```bash
# Use default config file (backup-config.yaml)
python backup.py

# Or specify a custom config file
python backup.py my-backup-config.yaml
```

### 3. Monitor the output

```
Starting backup to: s3://my-media-backup
Number of directories: 2
------------------------------------------------------------
[2026-03-26 10:15:32] Syncing: C:\Users\Me\Pictures -> s3://my-media-backup/pictures
✓ Backup successful

[2026-03-26 10:16:15] Syncing: C:\Users\Me\Documents -> s3://my-media-backup/docs
✓ Backup successful

------------------------------------------------------------
✓ All backups completed successfully
```

## Configuration

### Config File Format

```yaml
s3_bucket: "bucket-name"          # Required: S3 bucket name
skip_errors: false                # Optional: continue on errors (default: false)

backups:
  - source: "/local/path"         # Required: local directory path
    destination: "s3-key"          # Optional: S3 path (defaults to directory name)
    exclude:                       # Optional: exclude patterns
      - "*.tmp"
      - ".git"
      - "node_modules"
```

### Configuration Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `s3_bucket` | string | Yes | AWS S3 bucket name |
| `skip_errors` | boolean | No | Continue on backup failures (default: false) |
| `source` | string | Yes | Local directory path (absolute or relative) |
| `destination` | string | No | S3 key/path (defaults to directory name) |
| `exclude` | list | No | Glob patterns to exclude from sync |

## AWS CLI Options

The tool uses `aws s3 sync` with these defaults:
- `--delete`: Removes files from S3 that are no longer in the local directory
- Custom exclude patterns per backup

To see advanced options, check [AWS S3 sync documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-services-s3-commands.html#using-s3-commands-managing-objects-sync).

## Scheduling Backups

### Windows Task Scheduler

1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (e.g., daily at 2 AM)
4. Action: Start a program
   - Program: `C:\Python311\python.exe` (your Python path)
   - Arguments: `C:\path\to\backup.py C:\path\to\backup-config.yaml`
   - Start in: `C:\path\to\media-backup`

### Linux/macOS Cron

```bash
# Daily backup at 2 AM
0 2 * * * cd /path/to/media-backup && /usr/bin/python3 backup.py
```

## Troubleshooting

### "AWS CLI not found"
- Install AWS CLI: https://aws.amazon.com/cli/
- Verify: `aws --version`

### "Error reading config: No module named 'yaml'"
- Install PyYAML: `pip install PyYAML`
- Or convert config to JSON format

### "Unable to locate credentials"
- Run: `aws configure`
- Or set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables

### Slow syncs or timeouts
- Check your internet connection
- Increase timeout using AWS CLI: `aws configure set default.s3.max_concurrent_requests 20`
- Sync smaller batches of directories

## Performance Tips

1. **Exclude unnecessary files** to reduce sync time:
   ```yaml
   exclude:
     - "*.tmp"
     - "*.log"
     - ".git"
     - "node_modules"
     - "venv"
   ```

2. **First sync takes longer** - subsequent syncs only upload changed files

3. **Update AWS CLI** regularly for performance improvements

## Limitations

- Does not encrypt files (configure S3 bucket encryption separately)
- Does not compress files (S3 storage still charges for full size)
- Requires AWS credentials with S3 access

## Security Recommendations

1. **Use IAM user with S3-only permissions**:
   ```json
   {
     "Version": "2012-10-17",
     "Statement": [
       {
         "Effect": "Allow",
         "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"],
         "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
       }
     ]
   }
   ```

2. **Enable S3 bucket encryption**

3. **Keep credentials in `~/.aws/credentials`** (never commit to git)

## License

MIT

## Support

For issues or questions, check the AWS CLI documentation or open an issue.