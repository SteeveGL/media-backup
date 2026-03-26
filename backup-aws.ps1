# Pure AWS CLI backup script (PowerShell) - no Python required
# Only dependency: AWS CLI
# Usage: .\backup-aws.ps1 [config-file]
# Example: .\backup-aws.ps1 backup-config.json

param(
    [string]$ConfigFile = "backup-config.json"
)

# Check if AWS CLI is installed
try {
    aws --version | Out-Null
} catch {
    Write-Host "Error: AWS CLI not found"
    Write-Host "Install from: https://aws.amazon.com/cli/"
    exit 1
}

# Load configuration from JSON
if (-not (Test-Path $ConfigFile)) {
    Write-Host "Error: Config file not found: $ConfigFile"
    Write-Host "Create a config file or specify a different path"
    Write-Host "Example: .\backup-aws.ps1 backup-config.json"
    exit 1
}

try {
    $config = Get-Content $ConfigFile | ConvertFrom-Json
} catch {
    Write-Host "Error: Failed to parse config file: $_"
    exit 1
}

if (-not $config.s3_bucket -or -not $config.backups) {
    Write-Host "Error: Config must contain 's3_bucket' and 'backups'"
    exit 1
}

$S3_BUCKET = $config.s3_bucket
$SKIP_ERRORS = $config.skip_errors -eq $true
$Backups = $config.backups

Write-Host "Starting backup to: s3://$S3_BUCKET"
Write-Host "Number of directories: $($Backups.Count)"
Write-Host "------------------------------------------------------------"
Write-Host ""

$successCount = 0
$failedCount = 0

# Backup each directory
foreach ($backup in $Backups) {
    $source = $backup.source
    $dest = $backup.destination
    $s3path = "s3://$S3_BUCKET/$dest"
    
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] Syncing: $source -> $s3path"
    
    # Build AWS CLI command
    $cmd = @("s3", "sync", $source, $s3path, "--delete")
    
    # Add exclude patterns
    if ($backup.exclude) {
        foreach ($pattern in $backup.exclude) {
            $cmd += @("--exclude", $pattern)
        }
    }
    
    # Run sync
    & aws $cmd 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✓ Backup successful"
        $successCount++
    } else {
        Write-Host "✗ Backup failed"
        $failedCount++
        if (-not $SKIP_ERRORS) {
            exit 1
        }
    }
    Write-Host ""
}

Write-Host "------------------------------------------------------------"
Write-Host "Completed: $successCount successful, $failedCount failed"

if ($failedCount -gt 0) {
    exit 1
}
