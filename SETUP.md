# Quick Start Guide

## 5-Minute Setup

### Step 1: Install Prerequisites

```bash
# Windows - install AWS CLI
# https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

# macOS - install AWS CLI via Homebrew
brew install awscli

# Linux - install AWS CLI via package manager
# Ubuntu/Debian:
sudo apt-get install awscli

# Or use pip (any OS):
pip install awscli
```

Verify installation:
```bash
aws --version
python --version  # or python3 on macOS/Linux
```

### Step 2: Configure AWS Credentials

```bash
aws configure
```

When prompted, enter:
- AWS Access Key ID: `your_access_key`
- AWS Secret Access Key: `your_secret_key`
- Default region: `us-east-1` (or your preferred region)
- Default output format: `json`

### Step 3: Configure Your Backups

Edit `backup-config.yaml` with your directories:

```yaml
s3_bucket: "my-media-bucket"  # Create this bucket in AWS first!

backups:
  - source: "D:\\Pictures"     # Your folder path
    destination: "pictures"     # S3 folder name
    exclude:
      - "Thumbs.db"

  - source: "D:\\Videos"
    destination: "videos"
```

### Step 4: Test the Backup

```bash
# Windows
backup.bat

# macOS/Linux
./backup.sh
```

### Step 5: Schedule It (Optional)

#### Windows - Task Scheduler

1. Press `Win + R`, type `taskschd.msc`
2. Right-click "Task Scheduler Library" → "Create Basic Task"
3. Name: "Media Backup"
4. Trigger: Daily at 2:00 AM
5. Action:
   - Program: `cmd.exe`
   - Arguments: `/k cd D:\path\to\media-backup && backup.bat`

#### macOS/Linux - Cron

```bash
# Edit crontab
crontab -e

# Add this line to run daily at 2 AM:
0 2 * * * cd /path/to/media-backup && ./backup.sh
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "aws: command not found" | Install AWS CLI and restart terminal |
| "python: command not found" | Install Python 3 and restart terminal |
| "Unable to locate credentials" | Run `aws configure` |
| No files uploaded | Check source paths exist and S3 bucket name is correct |
| Slow upload | Exclude large or unnecessary files in config |

---

## Next Steps

- Review [README.md](README.md) for full documentation
- Check [AWS security best practices](https://docs.aws.amazon.com/cli/latest/userguide/cli-security.html)
- Consider enabling S3 versioning for accidental delete protection
