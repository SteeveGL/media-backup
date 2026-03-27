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

## Setup: Create IAM User, Policy, and S3 Bucket

For security, use a dedicated IAM user instead of root credentials.

**Step 1**: Edit [backup-config.json](backup-config.json) with your settings:

```json
{
  "s3_bucket": "steeve-media-backup",
  "region": "ca-central-1",
  "aws_profile": "default",
  "backup_profile_name": "backup-user",
  "retention_days": 0,
  "days_to_glacier": 30,
  "days_to_deep_archive": 90,
  "skip_errors": false,
  "backups": [
    {
      "source": "E:\\Photos",
      "destination": "Photos",
      "exclude": ["*.tmp", "Thumbs.db"]
    }
  ]
}
```

**Configuration fields:**

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `s3_bucket` | string | - | S3 bucket name (globally unique) |
| `region` | string | ca-central-1 | AWS region (ca-central-1, us-east-1, etc.) |
| `aws_profile` | string | (default) | AWS CLI profile to use for setup (for AWS SSO) |
| `backup_profile_name` | string | backup-user | Profile name for saving credentials to ~/.aws/credentials |
| `retention_days` | number | 0 | Days to keep files before deleting (0 = forever) |
| `days_to_glacier` | number | 30 | Days before archiving to Glacier (80% cost reduction) |
| `days_to_deep_archive` | number | 90 | Days before archiving to Deep Archive (99% cost reduction) |
| `skip_errors` | boolean | false | Continue on backup errors |

**Step 2**: Run backup (bucket auto-created on first run):

```powershell
.\backup-aws.ps1
```

**Auto-configured features:**
- ✓ Block all public access
- ✓ Server-side AES-256 encryption
- ✓ Versioning (recover deleted files)
- ✓ Access logging
- ✓ Lifecycle policies (retention & archival)

See [S3-SETUP.md](S3-SETUP.md) for details on retention options and AWS best practices.

See [IAM-SETUP.md](IAM-SETUP.md) for security details about the IAM user and least-privilege access.

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
.\backup-aws.ps1
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

Run backups automatically on a schedule using Windows Task Scheduler:

### Quick Setup
1. **Edit `backup-config.json`** and configure the schedule section:
   ```json
   "schedule": {
     "task_name": "Media Backup",
     "frequency": "Daily",
     "hour": 2,
     "minute": 0,
     "day_of_week": "Sunday"
   }
   ```

2. **Create the scheduled task:**
   ```powershell
   .\create-scheduled-task.ps1
   ```

3. **Test immediately:**
   ```powershell
   Start-ScheduledTask -TaskName "Media Backup"
   ```

### Schedule Examples
- **Daily at 2 AM:** `"frequency": "Daily", "hour": 2`
- **Weekly on Sunday at 11 PM:** `"frequency": "Weekly", "hour": 23, "day_of_week": "Sunday"`
- **Monthly at 1:30 AM:** `"frequency": "Monthly", "hour": 1, "minute": 30`

See [SCHEDULING.md](SCHEDULING.md) for full documentation.

**See [SCHEDULING.md](SCHEDULING.md) for details** on:
- Setting up scheduled tasks
- Monitoring backups
- Troubleshooting credentials
- Multiple backup schedules

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

## Retention Strategies

### Forever (retention_days: 0) - **Recommended for archives**
- ✓ Keeps all files forever
- ✓ Multi-tier archiving for cost efficiency:
  - **0-30 days**: Standard storage (default)
  - **30-90 days**: Glacier (80% cost reduction, default)
  - **90+ days**: Deep Archive (99% cost reduction, default)
- **Cost**: ~$0.001/GB/month after 90 days vs $0.023/GB with Standard
- **Best for**: Important long-term backups, cold storage
- **Customize**: Adjust `days_to_glacier` and `days_to_deep_archive` in config

Example (archive faster):
```json
{
  "retention_days": 0,
  "days_to_glacier": 7,
  "days_to_deep_archive": 30
}
```

### Delete After Days (retention_days: 90) - **For recent backups**
- ✓ Keeps files for specified days, then deletes
- ✓ Automatically archives with tiering:
  - **0-30 days**: Standard storage
  - **30-90 days**: Glacier (80% cost reduction)
  - **90+ days**: Deep Archive (99% cost reduction)
  - **After retention_days**: Permanently deleted
- **Cost**: Minimal after retention period
- **Best for**: Recent backup retention, automatic cleanup
- **Customize**: Set `days_to_glacier`, `days_to_deep_archive`, `retention_days`

Example (keep 180 days with custom archiving):
```json
{
  "retention_days": 180,
  "days_to_glacier": 30,
  "days_to_deep_archive": 90
}
```

## AWS S3 Storage Classes & Cost Savings

The script uses **intelligent tiering** to minimize costs:

| Storage Class | Cost/GB/Month | Speed | Use Case |
|---------------|---------------|-------|----------|
| **Standard** | $0.023 | Immediate | Recent backups (0-30 days) |
| **Glacier Instant** | $0.004 | 1-3 hours | Medium-term (30-90 days) |
| **Deep Archive** | $0.00099 | 12 hours | Long-term (90+ days) |

### Cost Example (1 TB of backup data)
```
Standard storage only:        $23/month
With tiering (months 1-3):    ~$20/month
With tiering (month 4+):      ~$1/month (97% cheaper!)
```

### How It Works
1. **First 30 days**: Files in Standard (fast access for recent backups)
2. **30-90 days**: Moved to Glacier automatically (80% cost reduction)
3. **90+ days**: Moved to Deep Archive automatically (99% cost reduction)

**Note:** Retrieval from Deep Archive takes 12 hours but costs $0. You only pay for storage.

## AWS CLI Options

The tool uses `aws s3 sync` with these defaults:
- `--delete`: Removes files from S3 that are no longer in the local directory

To add advanced options, edit [backup-aws.ps1](backup-aws.ps1) line that builds the `$cmd` array.

Check [AWS S3 sync documentation](https://docs.aws.amazon.com/cli/latest/userguide/cli-services-s3-commands.html#using-s3-commands-managing-objects-sync) for more options.

## Scheduling Backups

### Windows Task Scheduler

1. Open Task Scheduler
2. Create Basic Task
3. Set trigger (e.g., daily at 2 AM)
4. Action: Start a program
   - Program: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
   - Arguments: `-NoProfile -ExecutionPolicy RemoteSigned -File "C:\path\to\backup-aws.ps1"`
   - Start in: `C:\path\to\media-backup`

Example scheduled task with custom config:
```
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File "C:\path\to\backup-aws.ps1" -ConfigFile "C:\path\to\backup-config.json"
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