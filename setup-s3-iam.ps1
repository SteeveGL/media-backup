# Setup IAM user, policy, and S3 bucket for backups
# Run as Administrator
# Usage: .\setup-s3-iam.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "AWS S3 Setup - IAM User & Bucket" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check AWS CLI
try {
    aws --version | Out-Null
} catch {
    Write-Host "[ERROR] AWS CLI not found" -ForegroundColor Red
    Write-Host "Install: https://aws.amazon.com/cli/"
    exit 1
}

# Load config
$ConfigFile = "backup-config.json"
if (-not (Test-Path $ConfigFile)) {
    Write-Host "[ERROR] Config file not found: $ConfigFile" -ForegroundColor Red
    exit 1
}

$config = Get-Content $ConfigFile | ConvertFrom-Json
$S3_BUCKET = $config.s3_bucket
$Region = if ($config.region) { $config.region } else { "ca-central-1" }
$AWS_PROFILE = if ($config.aws_profile) { $config.aws_profile } else { "default" }
$BACKUP_PROFILE_NAME = if ($config.credentials_profile_name) { $config.credentials_profile_name } else { if ($config.backup_profile_name) { $config.backup_profile_name } else { "backup-user" } }
$DaysToGlacier = if ($config.days_to_glacier -ne $null) { $config.days_to_glacier } else { 30 }
$DaysToDeepArchive = if ($config.days_to_deep_archive -ne $null) { $config.days_to_deep_archive } else { 90 }
$RetentionDays = if ($config.retention_days -ne $null) { $config.retention_days } else { 0 }

# Build AWS CLI profile parameter
$profileParam = if ($AWS_PROFILE -ne "default") { @("--profile", $AWS_PROFILE) } else { @() }

# Get AWS Account ID
$accountInfo = aws @profileParam sts get-caller-identity | ConvertFrom-Json
$AWS_ACCOUNT_ID = $accountInfo.Account

$IAM_USER = "backup-user"
$POLICY_NAME = "S3-Backup-Policy"

Write-Host "[1/4] Creating IAM user: $IAM_USER (profile: $AWS_PROFILE)" -ForegroundColor Yellow

# Create IAM user
aws @profileParam iam create-user --user-name $IAM_USER 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Note: User might already exist" -ForegroundColor Yellow
}

Write-Host "[OK] IAM user ready" -ForegroundColor Green
Write-Host ""

# Create inline policy with S3-only permissions
Write-Host "[2/4] Creating S3 policy for: $S3_BUCKET" -ForegroundColor Yellow

$policy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Action = @(
                "s3:ListBucket",
                "s3:GetBucketLocation",
                "s3:GetBucketVersioning",
                "s3:GetBucketLifecycleConfiguration"
            )
            Resource = "arn:aws:s3:::$S3_BUCKET"
        },
        @{
            Effect = "Allow"
            Action = @(
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:DeleteObject"
            )
            Resource = "arn:aws:s3:::$S3_BUCKET/*"
        }
    )
} | ConvertTo-Json -Depth 10

# Save policy to temp file (without BOM for AWS CLI compatibility)
$policyFile = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($policyFile, $policy, $utf8NoBom)

# Put user policy using file:// prefix for reliable JSON parsing
aws @profileParam iam put-user-policy --user-name $IAM_USER --policy-name $POLICY_NAME --policy-document "file://$policyFile" 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "[OK] Policy attached" -ForegroundColor Green
} else {
    Write-Host "[ERROR] Failed to create policy" -ForegroundColor Red
    Remove-Item $policyFile
    exit 1
}
Remove-Item $policyFile
Write-Host ""

# Create access keys
Write-Host "[3/4] Creating access keys" -ForegroundColor Yellow

# Check if user already has max access keys (2)
$existingKeys = aws @profileParam iam list-access-keys --user-name $IAM_USER | ConvertFrom-Json
$keyCount = $existingKeys.AccessKeyMetadata.Count
if ($keyCount -ge 2) {
    Write-Host "Note: User already has $keyCount access key(s). Deleting oldest one..." -ForegroundColor Yellow
    
    # Find and delete the oldest key
    $oldestKey = $existingKeys.AccessKeyMetadata | Sort-Object CreateDate | Select-Object -First 1
    $oldKeyId = $oldestKey.AccessKeyId
    
    Write-Host "Deleting old key: $oldKeyId" -ForegroundColor Yellow
    aws @profileParam iam delete-access-key --user-name $IAM_USER --access-key-id $oldKeyId 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Old access key deleted" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] Failed to delete old access key" -ForegroundColor Yellow
    }
}

# Now create new access key
$keyOutput = aws @profileParam iam create-access-key --user-name $IAM_USER 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to create access keys" -ForegroundColor Red
    if ($keyOutput -match "Cannot exceed quota for AccessKeysPerUser") {
        Write-Host ""
        Write-Host "SOLUTION: Unable to manage access keys automatically" -ForegroundColor Yellow
        Write-Host "You need to manually delete an old access key first:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  1. List current keys:" -ForegroundColor Cyan
        Write-Host "     aws @profileParam iam list-access-keys --user-name $IAM_USER" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  2. Delete an old key:" -ForegroundColor Cyan
        Write-Host "     aws @profileParam iam delete-access-key --user-name $IAM_USER --access-key-id <KEY_ID>" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  3. Then re-run this script" -ForegroundColor Cyan
        Write-Host ""
    }
    $AccessKeyId = ""
    $SecretAccessKey = ""
} else {
    $keys = $keyOutput | ConvertFrom-Json
    $AccessKeyId = $keys.AccessKey.AccessKeyId
    $SecretAccessKey = $keys.AccessKey.SecretAccessKey
    Write-Host "[OK] Access keys created" -ForegroundColor Green
}
Write-Host ""

# Configure AWS CLI credentials locally
Write-Host "Configuring AWS credentials..." -ForegroundColor Cyan
$awsDir = Join-Path $env:USERPROFILE ".aws"
if (-not (Test-Path $awsDir)) {
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
}

$credentialsFile = Join-Path $awsDir "credentials"

# Write credentials file (append to preserve other profiles)
if ($AccessKeyId -and $SecretAccessKey) {
    # Only update if we have valid keys (access key creation may have failed)
    if (Test-Path $credentialsFile) {
        # Remove old profile section if it exists
        $content = Get-Content $credentialsFile -Raw
        $content = $content -replace "(?s)\[$BACKUP_PROFILE_NAME\](.*?)(?=\r?\n\[|\r?\n$|$)", ""
        $content = $content.TrimEnd()
    } else {
        $content = ""
    }
    
    # Append new profile
    $credentialsContent = @"
[$BACKUP_PROFILE_NAME]
aws_access_key_id = $AccessKeyId
aws_secret_access_key = $SecretAccessKey
"@
    
    if ($content) { $content += "`n`n" }
    $content += $credentialsContent.Trim()
    $content | Out-File $credentialsFile -Encoding ASCII -Force
    Write-Host "[OK] Credentials saved to: $credentialsFile" -ForegroundColor Green
    Write-Host "    Profile name: [$BACKUP_PROFILE_NAME]" -ForegroundColor Green
} else {
    Write-Host "[WARNING] Access key creation failed - credentials not updated" -ForegroundColor Yellow
    Write-Host "    You may need to manually manage access keys via AWS Console" -ForegroundColor Yellow
}

Write-Host ""

# Create S3 bucket
Write-Host "[4/4] Creating S3 bucket: $S3_BUCKET" -ForegroundColor Yellow

if ($Region -eq "us-east-1") {
    aws @profileParam s3api create-bucket --bucket $S3_BUCKET --region $Region 2>&1 | Out-Null
} else {
    aws @profileParam s3api create-bucket --bucket $S3_BUCKET --region $Region `
        --create-bucket-configuration LocationConstraint=$Region 2>&1 | Out-Null
}

if ($LASTEXITCODE -ne 0) {
    Write-Host "[WARNING] Bucket creation failed (may already exist)" -ForegroundColor Yellow
}

# Configure bucket security
Write-Host "Configuring bucket security..." -ForegroundColor Cyan

# Block public access
aws @profileParam s3api put-public-access-block --bucket $S3_BUCKET `
    --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true 2>&1 | Out-Null

# Enable versioning
aws @profileParam s3api put-bucket-versioning --bucket $S3_BUCKET `
    --versioning-configuration Status=Enabled 2>&1 | Out-Null

# Enable encryption
aws @profileParam s3api put-bucket-encryption --bucket $S3_BUCKET `
    --server-side-encryption-configuration '{
        "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
    }' 2>&1 | Out-Null

# Apply lifecycle policy
$lifecycle = @{
    Rules = @(
        @{
            ID = "archive-lifecycle"
            Status = "Enabled"
            Transitions = @(
                @{Days = $DaysToGlacier; StorageClass = "GLACIER"},
                @{Days = $DaysToDeepArchive; StorageClass = "DEEP_ARCHIVE"}
            )
            NoncurrentVersionTransitions = @(
                @{NoncurrentDays = $DaysToGlacier; StorageClass = "GLACIER"},
                @{NoncurrentDays = $DaysToDeepArchive; StorageClass = "DEEP_ARCHIVE"}
            )
            Filter = @{}
        }
    )
} | ConvertTo-Json -Depth 10

$lifecyleFile = [System.IO.Path]::GetTempFileName()
$lifecycle | Out-File $lifecyleFile -Encoding UTF8

aws @profileParam s3api put-bucket-lifecycle-configuration --bucket $S3_BUCKET `
    --lifecycle-configuration (Get-Content $lifecyleFile -Raw) 2>&1 | Out-Null

Remove-Item $lifecyleFile

Write-Host "[OK] Bucket configured" -ForegroundColor Green
Write-Host ""

# Save account ID to config
$config.aws_account_id = $AWS_ACCOUNT_ID
$config | ConvertTo-Json -Depth 10 | Set-Content $ConfigFile -Encoding UTF8
Write-Host "Account ID saved to config" -ForegroundColor Green
Write-Host ""

# Display credentials
Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "AWS Credentials configured:" -ForegroundColor Yellow
Write-Host "  Profile: [$BACKUP_PROFILE_NAME]" -ForegroundColor Cyan
Write-Host "  File: $credentialsFile" -ForegroundColor Cyan
if ($AccessKeyId) {
    # Show masked access key for security
    $maskedKey = $AccessKeyId.Substring(0, 4) + "*" * ($AccessKeyId.Length - 8) + $AccessKeyId.Substring($AccessKeyId.Length - 4)
    Write-Host "  Access Key: $maskedKey" -ForegroundColor Cyan
} else {
    Write-Host "  Access Key: [FAILED - AWS quota exceeded]" -ForegroundColor Red
    Write-Host "    → Delete unused access keys from AWS Console" -ForegroundColor Yellow
    Write-Host "    → Then re-run this script" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "AWS Account:" -ForegroundColor Yellow
Write-Host "  Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Cyan
Write-Host "  Profile: $AWS_PROFILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bucket Details:" -ForegroundColor Yellow
Write-Host "  Name: $S3_BUCKET" -ForegroundColor Cyan
Write-Host "  Region: $Region" -ForegroundColor Cyan
Write-Host "  IAM User: $IAM_USER" -ForegroundColor Cyan
Write-Host ""
Write-Host "Archive Strategy:" -ForegroundColor Yellow
Write-Host "  Keep in Standard: 0-$DaysToGlacier days (100% cost)" -ForegroundColor Cyan
Write-Host "  Archive to Glacier: $DaysToGlacier-$DaysToDeepArchive days (20% cost)" -ForegroundColor Cyan
Write-Host "  Archive to Deep Archive: $DaysToDeepArchive+ days (1% cost)" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ready to use!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Customize directories in backup-config.json" -ForegroundColor Cyan
Write-Host "  2. Run: .\backup.ps1" -ForegroundColor Cyan
Write-Host "  3. Schedule: .\create-scheduled-task.ps1 (run as admin)" -ForegroundColor Cyan
Write-Host ""
