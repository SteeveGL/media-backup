# AWS CLI Only Backup

Pure AWS CLI backup scripts with **zero** Python/Node.js/Ruby dependencies.

## Files

- **`backup-aws.bat`** – Windows batch script
- **`backup-aws.ps1`** – Windows PowerShell script (recommended for Windows)
- **`backup-aws.sh`** – Linux/macOS bash script

## Installation

1. **Install AWS CLI only**:
   ```bash
   # Windows: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
   # macOS: brew install awscli
   # Linux: sudo apt install awscli  (or pip install awscli)
   ```

2. **Configure credentials**:
   ```bash
   aws configure
   ```

3. **Edit the script** and update:
   - `S3_BUCKET` – your bucket name
   - `BACKUPS` – your directories

## Usage

### Windows (Batch)
```bash
backup-aws.bat
```

### Windows (PowerShell) - Recommended
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\backup-aws.ps1
```

### macOS/Linux
```bash
chmod +x backup-aws.sh
./backup-aws.sh
```

## Configuration Examples

### Batch (backup-aws.bat)
```batch
REM Edit these lines:
set S3_BUCKET=my-backup-bucket
echo [%date% %time%] Syncing: D:\Pictures -> s3://%S3_BUCKET%/pictures
aws s3 sync "D:\Pictures" "s3://%S3_BUCKET%/pictures" --delete ^
    --exclude "Thumbs.db" ^
    --exclude "*.tmp"
```

### PowerShell (backup-aws.ps1)
```powershell
$S3_BUCKET = "my-backup-bucket"
$Backups = @(
    @{
        source = "D:\Pictures"
        destination = "pictures"
        exclude = @("Thumbs.db", "*.tmp")
    }
)
```

### Bash (backup-aws.sh)
```bash
S3_BUCKET="my-backup-bucket"
BACKUPS=(
    "/home/user/Pictures:pictures:*.tmp"
)
```

## Why No Config File?

Since there's no scripting language runtime, loading external config files gets complex. Instead:

- **Edit the script directly** – simple and transparent
- **Or create multiple scripts** – `backup-aws-daily.bat`, `backup-aws-weekly.bat`, etc.
- **Or use AWS CLI aliases** – combine multiple backups into one command

## Example: Multiple Backup Scripts

Create separate scripts for different backup needs:

```batch
REM backup-photos.bat
aws s3 sync "D:\Pictures" "s3://my-bucket/photos" --delete

REM backup-docs.bat
aws s3 sync "D:\Documents" "s3://my-bucket/docs" --delete

REM Run all
call backup-photos.bat
call backup-docs.bat
```

## Scheduling

### Windows Task Scheduler
1. `Win + R` → `taskschd.msc`
2. Create Basic Task
3. Action: `C:\full\path\backup-aws.bat`

### macOS/Linux Cron
```bash
crontab -e
# Daily at 2 AM:
0 2 * * * /path/to/backup-aws.sh
```

## Dry Run (Test Without Uploading)

```bash
# Add --dryrun to test first:
aws s3 sync "D:\Pictures" "s3://bucket/photos" --dryrun
```

## Advanced AWS CLI Options

Add these to the sync command for more control:

```bash
# Progress bar
--no-progress

# Keep files on S3 even if deleted locally
# (remove --delete flag)

# Only delete after successful sync
--delete-only-on-exit

# Exclude all .tmp files
--exclude "*.tmp"

# Include only .jpg files
--include "*" --exclude "*" --include "*.jpg"

# Use reduced redundancy storage (cheaper)
--storage-class REDUCED_REDUNDANCY
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Cannot execute .ps1 | Run `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| "aws: command not found" | Install/reinstall AWS CLI |
| Permission denied on .sh | Run `chmod +x backup-aws.sh` |
| Slow uploads | Exclude unnecessary files, increase `--max-concurrent-requests` |

## Performance Tips

```bash
# For large backups, increase parallel uploads:
aws configure set default.s3.max_concurrent_requests 20

# Use transfer acceleration (if enabled in bucket):
aws s3 sync ... --region us-east-1 --endpoint-url https://s3-accelerate.amazonaws.com
```

## Security

- Never commit AWS credentials
- Use IAM user with S3-only permissions
- Store credentials in `~/.aws/credentials` (Linux/macOS) or `%USERPROFILE%\.aws\credentials` (Windows)
- Enable S3 server-side encryption

---

**That's it!** Just AWS CLI, no runtime dependencies needed.
