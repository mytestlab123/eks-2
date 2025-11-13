# MongoDB S3 Backup Solution

## Overview

Kubernetes Job-based backup solution that uses `mongodump` to backup MongoDB databases and uploads to S3.

## Components

### S3 Bucket
- **Name:** `mongo-eks-lab-backup-273828039634`
- **Region:** ap-southeast-1
- **Path:** `s3://mongo-eks-lab-backup-273828039634/backups/`

### IAM Role (IRSA)
- **Role:** `mongo-eks-lab-backup-role`
- **ServiceAccount:** `mongodb-backup`
- **Permissions:** S3 PutObject, GetObject, ListBucket

### Backup Job
- **Image:** mongo:7.0.12
- **Method:** mongodump with gzip compression
- **Databases:** ekslab, testdb (excludes admin)
- **Format:** Compressed tar.gz archive
- **Naming:** `mongodb-YYYYMMDD-HHMMSS.gz`

## Usage

### Manual Backup
```bash
kubectl apply -f /tmp/mongodb-backup-simple.yaml
kubectl logs -l app=mongodb-backup -f
```

### Check Backups
```bash
aws s3 ls s3://mongo-eks-lab-backup-273828039634/backups/
```

### Download Backup
```bash
aws s3 cp s3://mongo-eks-lab-backup-273828039634/backups/mongodb-TIMESTAMP.gz ./
```

### Restore from Backup
```bash
# Extract backup
tar -xzf mongodb-TIMESTAMP.gz

# Restore specific database
mongorestore --uri="mongodb://labuser:LabPass123!@mongodb-lab-0.mongodb-lab-svc:27017/?authSource=admin" \
  --gzip --archive=ekslab.gz
```

## Test Results

### Backup Test ✅
- **File:** mongodb-20251113-030724.gz
- **Size:** 886 bytes
- **Contents:** ekslab.gz (581B), testdb.gz (115B)
- **Duration:** 54 seconds
- **Status:** Success

### Restore Test ✅
- **Source:** ekslab database
- **Target:** ekslab_restored database
- **Documents restored:** 4 (3 products + 1 test)
- **Indexes restored:** 1 (category_1)
- **Duration:** 52 seconds
- **Status:** Success

## Automation (Optional)

### CronJob for Daily Backups
```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: mongodb-daily-backup
spec:
  schedule: "0 2 * * *"  # 2 AM daily
  jobTemplate:
    spec:
      template:
        # Same spec as backup job
```

### Retention Policy
Add to backup script:
```bash
# Keep only last 7 days
aws s3 ls s3://mongo-eks-lab-backup-273828039634/backups/ | \
  awk '{print $4}' | sort | head -n -7 | \
  xargs -I {} aws s3 rm s3://mongo-eks-lab-backup-273828039634/backups/{}
```

## Troubleshooting

### Backup Fails with Auth Error
- Ensure `labuser` has `readWriteAnyDatabase` role
- Check connection string includes `?authSource=admin`

### S3 Upload Fails
- Verify IAM role is attached to ServiceAccount
- Check OIDC provider is configured on cluster
- Verify S3 bucket permissions

### Restore Fails
- Ensure target database doesn't exist or use `--drop` flag
- Check MongoDB version compatibility
- Verify backup file integrity

## Cleanup

```bash
# Delete backup job
kubectl delete job mongodb-backup

# Delete S3 bucket (careful!)
aws s3 rb s3://mongo-eks-lab-backup-273828039634 --force

# Delete IAM role
aws iam delete-role-policy --role-name mongo-eks-lab-backup-role --policy-name S3BackupAccess
aws iam delete-role --role-name mongo-eks-lab-backup-role
```
