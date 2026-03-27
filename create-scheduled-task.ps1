# PowerShell script to create a Windows Task Scheduler task for backup
# Reads schedule configuration from backup-config.json

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Create Scheduled Backup Task" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$ScriptPath = Join-Path $PSScriptRoot "backup-aws.ps1"
$ConfigPath = Join-Path $PSScriptRoot "backup-config.json"

if (-not (Test-Path $ScriptPath)) {
    Write-Host "Error: backup-aws.ps1 not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $ConfigPath)) {
    Write-Host "Error: backup-config.json not found" -ForegroundColor Red
    exit 1
}

# Load JSON config
$config = $null
try
{
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
}
catch
{
    Write-Host "Error reading config: $_" -ForegroundColor Red
    exit 1
}

# Read schedule settings
$TaskName = $config.schedule.task_name
$Frequency = $config.schedule.frequency
$Hour = $config.schedule.hour
$Minute = $config.schedule.minute
$DayOfWeek = $config.schedule.day_of_week

if (-not $TaskName) { $TaskName = "Media Backup" }
if (-not $Frequency) { $Frequency = "Daily" }
if ($Hour -eq $null) { $Hour = 2 }
if ($Minute -eq $null) { $Minute = 0 }
if (-not $DayOfWeek) { $DayOfWeek = "Sunday" }

Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Task Name:     $TaskName"
Write-Host "  Frequency:     $Frequency"
Write-Host "  Time:          $($Hour):$($Minute.ToString('00'))"
if ($Frequency -eq "Weekly") {
    Write-Host "  Day:           $DayOfWeek"
}
Write-Host ""

# Check existing task
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Warning: Task already exists" -ForegroundColor Yellow
    $response = Read-Host "Delete and recreate? (y/n)"
    if ($response.ToLower() -ne "y") {
        Write-Host "Cancelled"
        exit 0
    }
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Old task deleted" -ForegroundColor Green
}

# Build task components
$psCmd = "Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force; & '$ScriptPath'"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -Command `"$psCmd`""

switch ($Frequency)
{
    "Daily" { $trigger = New-ScheduledTaskTrigger -Daily -At "$($Hour):$($Minute.ToString('00'))" }
    "Weekly" { $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At "$($Hour):$($Minute.ToString('00'))" }
    "Monthly" { $trigger = New-ScheduledTaskTrigger -Monthly -At "$($Hour):$($Minute.ToString('00'))" }
}

$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -Compatibility Win8 -ExecutionTimeLimit (New-TimeSpan -Hours 12)

# Create task
$user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
Write-Host "Creating task..." -ForegroundColor Cyan

try
{
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -RunLevel Highest -User $user -ErrorAction Stop
    Write-Host "[OK] Task created!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next: Start-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Yellow
}
catch
{
    Write-Host "[ERROR] Error: $_" -ForegroundColor Red
    exit 1
}
