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
$BACKUP_PROFILE_NAME = if ($config.backup_profile_name) { $config.backup_profile_name } else { "backup-user" }
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

# Save policy to temp file
$policyFile = [System.IO.Path]::GetTempFileName()
$policy | Out-File $policyFile -Encoding UTF8

# Put user policy
aws @profileParam iam put-user-policy --user-name $IAM_USER --policy-name $POLICY_NAME --policy-document (Get-Content $policyFile -Raw) 2>&1 | Out-Null

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

$keys = aws @profileParam iam create-access-key --user-name $IAM_USER | ConvertFrom-Json
$AccessKeyId = $keys.AccessKey.AccessKeyId
$SecretAccessKey = $keys.AccessKey.SecretAccessKey

Write-Host "[OK] Access keys created" -ForegroundColor Green
Write-Host ""

# Configure AWS CLI credentials locally
Write-Host "Configuring AWS credentials..." -ForegroundColor Cyan
$awsDir = Join-Path $env:USERPROFILE ".aws"
if (-not (Test-Path $awsDir)) {
    New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
}

$credentialsFile = Join-Path $awsDir "credentials"
$configFile = Join-Path $awsDir "config"

# Write credentials file
$credentialsContent = @"
[$BACKUP_PROFILE_NAME]
aws_access_key_id = $AccessKeyId
aws_secret_access_key = $SecretAccessKey
"@

$credentialsContent | Out-File $credentialsFile -Encoding UTF8 -Force
Write-Host "[OK] Credentials saved to: $credentialsFile" -ForegroundColor Green
Write-Host "    Profile name: [$BACKUP_PROFILE_NAME]" -ForegroundColor Green

# Write config file if it doesn't exist
if (-not (Test-Path $configFile)) {
    $configContent = @"
[default]
region = $Region
output = json
"@
    $configContent | Out-File $configFile -Encoding UTF8 -Force
    Write-Host "[OK] Config saved to: $configFile" -ForegroundColor Green
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
Write-Host "  Access Key: $AccessKeyId" -ForegroundColor Cyan
Write-Host ""
Write-Host "AWS Account:" -ForegroundColor Yellow
Write-Host "  Account ID: $AWS_ACCOUNT_ID" -ForegroundColor Cyan
Write-Host "  Profile: $AWS_PROFILE" -ForegroundColor Cyan
Write-Host ""
Write-Host "AWS Config:" -ForegroundColor Yellow
Write-Host "  File: $configFile" -ForegroundColor Cyan
Write-Host "  Region: $Region" -ForegroundColor Cyan
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
Write-Host "  2. Run: .\backup-aws.ps1" -ForegroundColor Cyan
Write-Host "  3. Schedule: .\create-scheduled-task.ps1 (run as admin)" -ForegroundColor Cyan
Write-Host ""
