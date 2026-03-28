# Media Backup Tool

A minimal PowerShell backup tool for syncing directories to AWS S3 using AWS CLI.

## Features

- **Minimal dependencies**: Only requires PowerShell and AWS CLI (no runtimes)
- **Simple configuration**: JSON config files
- **Selective syncing**: Exclude patterns support (.tmp, node_modules, etc.)
- **Safe deletion**: Optional removal of deleted files from S3
- **Error handling**: Skip errors and continue, or abort on first failure
- **Clear logging**: Timestamped output for each backup

## Prerequisites

1. **PowerShell 5.0+** (built-in on Windows)
   ```powershell
   $PSVersionTable.PSVersion
   ```

2. **AWS CLI** (version 1.x or 2.x)
   ```powershell
   # Install:
   # Windows: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   # Or via Chocolatey: choco install awscli
   # Or via Scoop: scoop install aws
   
   # Verify installation:
   aws --version
   ```

3. **AWS Credentials** configured locally
   ```powershell
   # Run this and enter your AWS Access Key ID and Secret Access Key
   aws configure
   ```

## Installation

Just clone or download this repository. No additional dependencies needed beyond AWS CLI.

## Usage

### 1. Create AWS Resources (Run as Administrator)

First-time setup - creates IAM user, policy, S3 bucket, and configures AWS credentials:

```powershell
# Right-click PowerShell and select "Run as Administrator"
cd c:\path\to\media-backup

# Optional: Edit backup-config.json to customize credentials profile name
# "backup_profile_name": "backup-user"  (default)

.\setup-s3-iam.ps1
```

Done! Credentials are automatically saved to `~/.aws/credentials` under the profile name specified in `backup_profile_name` (default: `backup-user`) and ready to use.

The setup creates:
- IAM user `backup-user` with S3-only permissions
- Access keys (stores securely in AWS and locally)
- S3 bucket with encryption, versioning, and lifecycle policies
- AWS CLI configuration in `~/.aws/credentials` with custom profile name

### 2. Configure your backups

All configuration is in [backup-config.json](backup-config.json):

```json
{
  "s3_bucket": "my-media-backup",
  "region": "ca-central-1",
  "retention_days": 0,
  "days_to_glacier": 30,
  "days_to_deep_archive": 90,
  "skip_errors": false,
  "backups": [
    {
      "source": "C:\\Users\\Me\\Pictures",
      "destination": "pictures",
      "exclude": ["*.tmp", "Thumbs.db"]
    },
    {
      "source": "C:\\Users\\Me\\Documents",
      "destination": "docs",
      "exclude": []
    }
  ]
}
```

### 3. Run backups

```powershell
.\backup.ps1
```

### 4. Verify results

```
========================================
Media Backup Tool
========================================

Checking S3 bucket: my-media-backup
✓ Bucket exists

Starting backup to: s3://my-media-backup
Number of directories: 2
------------------------------------------------------------
[2026-03-26 10:15:32] Syncing: C:\Users\Me\Pictures -> s3://my-media-backup/pictures
✓ Backup successful

[2026-03-26 10:16:15] Syncing: C:\Users\Me\Documents -> s3://my-media-backup/docs
✓ Backup successful

------------------------------------------------------------
Completed: 2 successful, 0 failed
```

## Schedule Automatic Backups

To set up automatic recurring backups using Windows Task Scheduler, see [SCHEDULING.md](SCHEDULING.md) for complete setup instructions and configuration options.

## Configuration

### Config File Format

```json
{
  "s3_bucket": "bucket-name",           // Required: S3 bucket name
  "region": "ca-central-1",             // Optional: AWS region (default: ca-central-1)
  "retention_days": 0,                  // Optional: days to keep (0 = forever, default: 0)
  "days_to_glacier": 30,                // Optional: days to Glacier (default: 30)
  "days_to_deep_archive": 90,           // Optional: days to Deep Archive (default: 90)
  "skip_errors": false,                 // Optional: continue on errors (default: false)
  "backups": [
    {
      "source": "C:\\local\\path",      // Required: local directory path
      "destination": "s3-key",          // Required: S3 path (no "/" prefix)
      "exclude": ["*.tmp", ".git"]      // Optional: exclude patterns
    }
  ]
}
```

### Configuration Options

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `s3_bucket` | string | Yes | AWS S3 bucket name (globally unique) |
| `region` | string | No | AWS region (default: ca-central-1) |
| `retention_days` | number | No | Days to keep files (0 = forever, default: 0) |
| `skip_errors` | boolean | No | Continue on backup failures (default: false) |
| `source` | string | Yes | Local directory path (absolute or relative) |
| `destination` | string | Yes | S3 key/path (no leading slash) |
| `exclude` | array | No | Glob patterns to exclude from sync |

## Cost Optimization & Retention

See [S3-SETUP.md](S3-SETUP.md) for detailed information on:
- **Retention strategies** (keep forever vs. delete after days)
- **Multi-tier archiving** (Glacier, Deep Archive cost savings)
- **Storage class comparison** and pricing
- **Cost examples** (save 97% after 90 days)

## AWS CLI Options

The tool uses `aws s3 sync` with these defaults:
- `--delete`: Removes files from S3 that are no longer in the local directory

To add advanced options, edit [backup.ps1](backup.ps1) line that builds the `$cmd` array.

Check [AWS S3 sync documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-services-s3-commands.html#using-s3-commands-managing-objects-sync) for more options.

## Scheduling Backups

### Windows Task Scheduler

1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (e.g., daily at 2 AM)
4. Action: Start a program
   - Program: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
   - Arguments: `-NoProfile -ExecutionPolicy RemoteSigned -File "C:\path\to\backup.ps1"`
   - Start in: `C:\path\to\media-backup`

Example scheduled task with custom config:
```
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "C:\path\to\backup.ps1" -ConfigFile "C:\path\to\backup-config.json"
```

## Troubleshooting

### "aws: command not found"
- Install AWS CLI: https://aws.amazon.com/cli/
- Verify: `aws --version`
- Restart PowerShell after installation

### "cannot be loaded because running scripts is disabled on this system"
- Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### "Unable to locate credentials"
- Run: `aws configure`
- Or set environment variables:
  ```powershell
  $env:AWS_ACCESS_KEY_ID = "your-key"
  $env:AWS_SECRET_ACCESS_KEY = "your-secret"
  ```

### Slow syncs or timeouts
- Check your internet connection
- Increase concurrent requests:
  ```powershell
  aws configure set default.s3.max_concurrent_requests 20
  ```

## Performance Tips

1. **Exclude unnecessary files** to reduce sync time:
   ```json
   "exclude": [
     "*.tmp",
     "*.log",
     ".git",
     "node_modules",
     "venv"
   ]
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

3. **Keep credentials in `~\.aws\credentials`** (never commit to git)

## License

MIT