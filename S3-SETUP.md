# S3 Bucket Setup Guide

This guide explains how to create and configure your S3 bucket with AWS best practices using the `setup-s3-iam.ps1` script.

## Quick Start

```powershell
# Run setup (uses configuration from backup-config.json)
.\setup-s3-iam.ps1
```

## Configuration

All settings are in [backup-config.json](backup-config.json):

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `s3_bucket` | string | - | S3 bucket name (globally unique, 3-63 chars, lowercase) |
| `retention_days` | int | 0 | Days to keep files before deleting (0 = forever) |
| `region` | string | ca-central-1 | AWS region (us-east-1, us-west-2, eu-west-1, etc.) |
| `days_to_glacier` | int | 30 | Days before archiving to Glacier (80% cost reduction) |
| `days_to_deep_archive` | int | 90 | Days before archiving to Deep Archive (99% cost reduction) |

## S3 Bucket Name Rules

✓ Must be globally unique across all AWS accounts
✓ 3-63 characters long
✓ Start and end with lowercase letter or number
✓ Can contain lowercase letters, numbers, periods (.), hyphens (-)
✓ Cannot contain uppercase letters or underscores

Good names:
- `company-media-backup-2026`
- `steeve-photos-archive`
- `backup.media.001`

❌ Bad names:
- `My-Backup` (uppercase)
- `backup_files` (underscore)
- `backup` (too short, might be taken)

## AWS Best Practices Implemented

### 1. **Block All Public Access** 🔒
- Ensures bucket is private by default
- Prevents accidental public file exposure
- Cannot be overridden by ACLs or policies

### 2. **Server-Side Encryption** 🔐
- Uses AES-256 encryption
- All objects encrypted at rest
- No additional cost
- Transparent to applications

### 3. **Versioning** 📑
- Keep all versions of files
- Recover deleted or corrupted files
- Enable accidental deletion recovery
- Old versions stored in S3 (storage cost applies)

### 4. **Access Logging** 📊
- Track who accesses what files
- Logs stored in bucket with `logs/` prefix
- Useful for audit trails and debugging
- Minimal storage and no extra cost

### 5. **Lifecycle Policies with Multi-Tier Archiving** ♻️
- Automatically manage files across storage tiers
- Reduces storage costs from 97% (after 90 days)
- Two strategies:

#### Strategy A: Delete After Retention
```
RetentionDays: 90 days
├─ Days 0-30:  Standard storage (fast access)
├─ Days 30-90: Glacier (80% cost reduction)
├─ After 90:   Deep Archive (99% cost reduction)
└─ Then:       Permanently deleted
```
**Best for:** Recent backups, automatic cleanup
**Cost:** ~$0.023/GB first month, ~$1/month by month 4

#### Strategy B: Keep Forever (RetentionDays=0)
```
RetentionDays: Forever
├─ Days 0-30:  Standard storage (fast access)
├─ Days 30-90: Glacier (80% cost reduction)
└─ 90+ days:   Deep Archive (99% cost reduction)
```
**Best for:** Long-term archival, cost optimization
**Cost:** ~$0.023/GB first month, ~$1/month after 3 months

### 6. **Tags** 🏷️
- Organize and track resources
- Enable cost allocation reports
- Default tags:
  - `Environment: Production`
  - `Purpose: Media Backup`
  - `ManagedBy: PowerShell`

### 7. **MFA Delete** (Optional) 🔑
- Require MFA code to permanently delete
- Needs AWS root credentials
- Can enable after bucket creation

## Cost Considerations

### S3 Storage Classes & Pricing
| Storage Class | Cost/GB/Month | Retrieval Time | Best For |
|----------------|--------------|-----------------|----------|
| Standard | $0.023 | Immediate | Recent backups (0-30 days) |
| Glacier Instant | $0.004 | 1-3 hours | Medium-term (30-90 days) |
| Deep Archive | $0.00099 | 12 hours | Long-term (90+ days) |

### Cost Example: 1 TB Monthly Backup
```
Month 1-3 (Standard):           $23/month
Month 4 (Glacier):              $4/month  (83% savings)
Month 4+ (Deep Archive):        $1/month  (96% savings)
```

**No Configuration Needed!** The script automatically transitions your files through all tiers.

### Transfer Costs
- Upload: Free
- Download: $0.09 per GB (after free tier)
- Cross-region: Varies

### How to Optimize Costs

1. **Use Default Settings** (script already does this)
   - Multi-tier archiving: Standard → Glacier → Deep Archive
   - Maximum cost savings

2. **Monitor with AWS Console**
   ```powershell
   aws s3 ls s3://bucket-name --recursive --summarize --human-readable
   aws s3api get-bucket-tagging --bucket bucket-name
   ```

3. **Set appropriate retention_days**
   - 0 (forever): Best for important archives, lowest long-term cost
   - 90 (3 months): Balances retention and cost

4. **Enable CloudWatch Monitoring** (optional):
   ```powershell
   aws cloudwatch put-metric-alarm --alarm-name backup-size --alarm-description "Monitor backup size"
   ```

## Region Selection

| Region | Use Case | Latency from US |
|--------|----------|-----------------|
| `us-east-1` | Default, most services | Low |
| `us-west-2` | US West Coast | Medium |
| `ca-central-1` | Canada | Medium-Prime |
| `eu-west-1` | Europe | High |
| `ap-northeast-1` | Japan | Very High |

**Recommended**: Choose closest to your location for best performance.

## Verification Commands

```powershell
# Check bucket encryption
aws s3api get-bucket-encryption --bucket my-media-backup

# Check versioning status
aws s3api get-bucket-versioning --bucket my-media-backup

# Check lifecycle policy
aws s3api get-bucket-lifecycle-configuration --bucket my-media-backup

# Check public access block
aws s3api get-public-access-block --bucket my-media-backup

# Check bucket tags
aws s3api get-bucket-tagging --bucket my-media-backup

# List all buckets
aws s3 ls

# Check bucket size
aws s3 ls s3://my-media-backup --recursive --summarize --human-readable
```

## After Bucket Creation

1. **Update Configuration**
   ```json
   {
     "s3_bucket": "my-media-backup",  ← Update this
     "backups": [...]
   }
   ```

2. **Run Your First Backup**
   ```powershell
   .\backup.ps1
   ```

3. **Verify Upload**
   ```powershell
   aws s3 ls s3://my-media-backup --recursive
   ```

4. **Monitor Costs**
   - AWS Console → Billing → S3
   - Check monthly usage and cost
   - Monitor with CloudWatch (optional)

## Security Recommendations

### ✓ DO:
- Use IAM user (not root) with S3-only permissions
- Enable versioning for accidental deletion recovery
- Enable access logging for audit trails
- Use bucket encryption
- Apply least-privilege permissions

### ✗ DON'T:
- Store credentials in bucket
- Make bucket public
- Use root AWS credentials
- Skip encryption
- Ignore access logs

## Troubleshooting

### "BucketAlreadyOwnedByYou"
- Bucket already exists in your account
- Use different bucket name

### "BucketAlreadyExists"
- Bucket name is taken by another AWS account
- S3 bucket names are globally unique
- Try: `my-backup-2026`, `backup-media-123`, etc.

### "InvalidBucketName"
- Bucket name violates S3 rules
- Check: lowercase, no underscores, 3-63 chars

### "NoCredentials" / "Unable to locate credentials"
- Run: `aws configure`
- Enter AWS Access Key ID and Secret

## Advanced: Custom IAM Policy

Create IAM user with minimal S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-media-backup",
        "arn:aws:s3:::my-media-backup/*"
      ]
    }
  ]
}
```

## References

- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/BestPractices.html)
- [S3 Security Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 Lifecycle Configuration](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lifecycle-mgmt.html)
- [S3 Pricing](https://aws.amazon.com/s3/pricing/)
