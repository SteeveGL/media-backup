# Scheduling Your Backups

## AWS Credentials (No Token Needed)

You **don't** need an AWS "token". You need **AWS Access Key credentials** which you already configured:

```powershell
aws configure
```

This stored your credentials in: `%USERPROFILE%\.aws\credentials`

Example:
```
[default]
aws_access_key_id = AKIA1234567890ABCDE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG+39QDJSTEZQZXC/3KEY
region = ca-central-1
```

**These credentials are persistent** – they survive computer reboots and are used by AWS CLI automatically.

## Setup Scheduled Task (Windows Task Scheduler)

### Option 1: Using the Helper Script (Recommended)

1. **Configure schedule in backup-config.json:**
   ```json
   "schedule": {
     "enabled": false,
     "task_name": "Media Backup",
     "frequency": "Daily",
     "hour": 2,
     "minute": 0,
     "day_of_week": "Sunday"
   }
   ```
   - `frequency`: "Daily", "Weekly", or "Monthly"
   - `hour`: 0-23 (24-hour format)
   - `minute`: 0-59
   - `day_of_week`: Used for weekly backups (Sunday-Saturday)

2. **Run the script:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   .\\scheduled-task.ps1
   ```

3. **Examples (change in backup-config.json):**
   ```json
   // Daily at 2 AM (default)
   "schedule": {
     "frequency": "Daily",
     "hour": 2,
     "minute": 0
   }

   // Weekly on Sunday at 3 AM
   "schedule": {
     "frequency": "Weekly",
     "hour": 3,
     "minute": 0,
     "day_of_week": "Sunday"
   }

   // Daily at 11 PM
   "schedule": {
     "frequency": "Daily",
     "hour": 23,
     "minute": 0
   }

   // Monthly at 1:30 AM
   "schedule": {
     "frequency": "Monthly",
     "hour": 1,
     "minute": 30
   }
   ```

4. **Verify it works:**
   ```powershell
   # Test immediately
   Start-ScheduledTask -TaskName "Media Backup"

   # Check if it ran
   Get-ScheduledTaskInfo -TaskName "Media Backup"
   ```

### Option 2: Manual Setup (Task Scheduler GUI)

1. **Open Task Scheduler:**
   ```
   taskschd.msc
   ```

2. **Create Basic Task:**
   - Right-click "Task Scheduler Library" → "Create Basic Task"
   - Name: "Media Backup"
   - Trigger: Daily at 2:00 AM

3. **Configure Action:**
   - Action: "Start a program"
   - Program: `C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe`
   - Arguments:
     ```
     -NoProfile -ExecutionPolicy RemoteSigned -WindowStyle Hidden -Command "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; & 'C:\path\to\backup.ps1'"
     ```
   - Replace `C:\path\to\backup.ps1` with actual path

4. **Configure Settings:**
   - Check "Run with highest privileges"
   - Check "Run whether user is logged in or not"

## Important: AWS Credentials & Task Scheduler

### ✓ How It Works

The scheduled task runs under your user account with your stored AWS credentials:

```
Task Scheduler runs at 2 AM
    ↓
PowerShell starts backup.ps1
    ↓
Script reads backup-config.json
    ↓
AWS CLI uses credentials from ~/.aws/credentials
    ↓
Backup to S3
```

### ✓ Requirements

1. **AWS credentials must be configured:**
   ```powershell
   aws configure
   # Enter credentials when prompted
   ```

2. **Task must run as your user account:**
   - Task Scheduler properties → General → "Run as" user
   - Should be your Windows username

3. **PowerShell execution policy must allow scripts:**
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

### ⚠️ Common Issues

**"Unable to locate credentials"**
- Run `aws configure` with your credentials
- Verify: `cat $env:USERPROFILE\.aws\credentials`

**"Access Denied" when task runs**
- Check credentials have S3 permissions
- Verify task runs under correct user account
- Run with "highest privileges" enabled

**Script doesn't run at scheduled time**
- Check task is enabled in Task Scheduler
- Verify computer was not in sleep mode
- Check event logs: Event Viewer → Windows Logs → System

## Monitoring Your Scheduled Tasks

### View Task Status
```powershell
Get-ScheduledTask -TaskName "Media Backup"
Get-ScheduledTaskInfo -TaskName "Media Backup"
```

### View Last Run Result
```powershell
$task = Get-ScheduledTaskInfo -TaskName "Media Backup"
"Last Run: {0}" -f $task.LastRunTime
"Result: {0}" -f $task.LastTaskResult  # 0 = success
```

### View Event Logs
```powershell
# PowerShell script errors
Get-EventLog -LogName Application -Source PowerShell -Newest 5

# Task Scheduler logs
Get-WinEvent -LogName "Microsoft-Windows-TaskScheduler/Operational" -MaxEvents 5
```

### Verify Backup Ran
```powershell
# List recent uploads to S3
aws s3 ls s3://your-bucket/ --recursive --human-readable --summarize
```

## Example Schedules

### Daily Backup at 2 AM
```powershell
.\scheduled-task.ps1 -Frequency Daily -Hour 2
```

### Weekly Backup (Sunday 11 PM)
```powershell
.\scheduled-task.ps1 -Frequency Weekly -Hour 23 -DayOfWeek Sunday
```

### Multiple Tasks (Daily + Weekly Full)
```powershell
# Daily incremental
.\scheduled-task.ps1 -TaskName "Backup Daily" -Frequency Daily -Hour 2

# Weekly full backup
.\scheduled-task.ps1 -TaskName "Backup Weekly" -Frequency Weekly -DayOfWeek Sunday -Hour 22
```

## Cost Optimization with Scheduled Backups

- **Daily backups** = ~30 GB/month
- **Weekly backups** = ~8 GB/month
- **Monthly backups** = ~2 GB/month

With archive tiering (configured in backup-config.json):
- First month: $23 for 1 TB
- After 90 days: $1/month for 1 TB (96% savings!)

## Backup Tips

1. **Run first backup manually** to verify it works:
   ```powershell
   .\backup.ps1
   ```

2. **Test scheduled task immediately:**
   ```powershell
   Start-ScheduledTask -TaskName "Media Backup"
   ```

3. **Monitor first few runs** to ensure no errors

4. **Set multiple schedules** for different backup needs:
   - Hourly for critical data
   - Daily for active projects
   - Weekly for archives

## Removing/Editing Tasks

### Disable temporarily
```powershell
Disable-ScheduledTask -TaskName "Media Backup"
```

### Enable again
```powershell
Enable-ScheduledTask -TaskName "Media Backup"
```

### Delete task
```powershell
Unregister-ScheduledTask -TaskName "Media Backup" -Confirm:$false
```

### Edit task
```powershell
# Use Task Scheduler GUI or delete and recreate
taskschd.msc
```
