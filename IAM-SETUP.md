# IAM Setup Guide

## Overview

This setup creates a dedicated AWS IAM user with **S3-only permissions** (least-privilege access) instead of using root credentials.

## What Gets Created

### 1. IAM User: `backup-user`
- Dedicated user for backup operations only
- Cannot access other AWS services
- Cannot modify AWS settings or policies
- Cannot delete the IAM user itself

### 2. IAM Policy: `S3-Backup-Policy`
Permissions limited to one S3 bucket:
```
s3:ListBucket          - List objects in bucket
s3:GetBucketLocation   - Determine bucket region
s3:GetObject           - Download files
s3:PutObject           - Upload files
s3:DeleteObject        - Delete files
```

### 3. S3 Bucket with Best Practices
- ✓ Public access blocked
- ✓ Server-side AES-256 encryption
- ✓ Versioning enabled (recover deleted files)
- ✓ Access logging enabled
- ✓ Automatic archive lifecycle:
  - 0-30 days: Standard (full cost)
  - 30-90 days: Glacier (80% cost reduction)
  - 90+ days: Deep Archive (99% cost reduction)

## Running the Setup

**Prerequisites:**
- Administrator access to run PowerShell
- AWS account with permissions to create IAM users and S3 buckets
- AWS CLI installed and configured with root/admin credentials (for initial setup only)

**Steps:**

1. **Right-click PowerShell** → "Run as Administrator"

2. **Navigate to the project:**
   ```powershell
   cd c:\path\to\media-backup
   ```

3. **Configure credentials profile name (optional):**
   Edit `backup-config.json` and set `backup_profile_name`:
   ```json
   {
     "aws_profile": "sglcontenetiste",
     "backup_profile_name": "backup-user",
     ...
   }
   ```
   - `aws_profile`: AWS SSO profile to use for setup (default: default profile)
   - `backup_profile_name`: Name to use when saving backup credentials (default: "backup-user")
   - Use different names if managing multiple backup users

4. **Run setup script:**
   ```powershell
   .\setup-s3-iam.ps1
   ```

Done! The script automatically:
- Creates IAM user `backup-user`
- Generates access keys securely
- Creates S3 bucket with best practices
- Writes credentials to `~/.aws/credentials` under the specified profile
- Configures AWS CLI

You're ready to use `./backup.ps1` immediately!

## Security Features

### Least Privilege Access
The IAM user can **only**:
- List and access files in the backup bucket
- Cannot create new buckets
- Cannot modify bucket settings
- Cannot access other AWS services
- Cannot see AWS account settings

### Access Key Security
- Keys are generated securely by AWS
- Store them in `~/.aws/credentials`
- Never commit credentials to git
- Can be rotated anytime via setup script

### Bucket Protection
- Public access completely blocked
- Files encrypted at rest with AES-256
- All changes logged and recoverable via versioning
- Access logs stored in bucket for audit trail

## Revoking Access

If access keys are compromised:

```powershell
# Delete the IAM user (removes all access immediately)
aws iam delete-user --user-name backup-user

# Then re-run setup to create new user and keys
.\setup-s3-iam.ps1
```

## File Retention & Lifecycle

### Default Behavior (Retention = 0)
- Keep all backups indefinitely
- Automatically archive old files to save 99% on storage

### With Retention Days
Specify `retention_days` in `backup-config.json`:
```json
"retention_days": 365
```
- Delete files older than 365 days
- Archive intermediate versions to reduce costs
- Automatic deletion via S3 lifecycle rules

## Cost Optimization

With multi-tier archival:

| Timeline | Storage | Cost per TB/mo |
|----------|---------|---|
| 0-30 days | Standard | $23 |
| 30-90 days | Glacier | $4 (80% reduction) |
| 90+ days | Deep Archive | $0.23 (99% reduction) |

Example: 1 TB backup over 12 months = **~$156** (vs $276 without archival)

## Troubleshooting

### "User already exists"
The IAM user already exists from a previous setup. That's fine - the script will update the policy.

### "Access Denied" when creating bucket
The IAM user (from previous setup) cannot create buckets. Delete and recreate:
```powershell
aws iam delete-user --user-name backup-user
.\setup-s3-iam.ps1
```

### "Invalid credentials" when backup runs
Check that credentials were configured:
```powershell
cat $env:USERPROFILE\.aws\credentials
```

Should show a profile section with your credentials (default: `[backup-user]`):
```
[backup-user]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

Or if you configured a custom profile name:
```
[your-profile-name]
aws_access_key_id = AKIA...
aws_secret_access_key = ...
```

If missing, re-run setup:
```powershell
.\setup-s3-iam.ps1
```

### S3 bucket already exists
The setup script detects existing buckets and configures them. Just re-run setup.

## What Happens Inside setup-s3-iam.ps1

1. **Checks AWS CLI** is installed and accessible
2. **Reads configuration** from `backup-config.json`
3. **Creates IAM user** `backup-user`
4. **Attaches policy** with S3-only permissions
5. **Generates access keys** (stored securely by AWS)
6. **Writes credentials locally** to `~/.aws/credentials`
7. **Writes AWS config** to `~/.aws/config` (sets region)
8. **Creates S3 bucket** with specified settings
9. **Configures security**:
   - Blocks public access
   - Enables encryption
   - Enables versioning
   - Applies lifecycle policies
10. **Displays summary** of what was created

## Next Steps

After setup:
1. Customize: Edit `backup-config.json` with your directories
2. Test: Run `./backup.ps1` manually
3. Verify: Check S3 console or run `aws s3 ls`
4. Schedule: Run `./scheduled-task.ps1` to automate

## References

- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS S3 Security](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security.html)
- [S3 Lifecycle Policies](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
