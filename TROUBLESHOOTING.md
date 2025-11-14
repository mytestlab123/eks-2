# EKS MongoDB Lab - Troubleshooting

Quick reference for common issues and solutions.

---

## Deployment Issues

### ❌ Nodes Not Joining Cluster
**Error:** `Instances failed to join the kubernetes cluster`

**Cause:** Subnet doesn't have auto-assign public IP enabled

**Fix:**
```bash
aws ec2 modify-subnet-attribute \
  --subnet-id subnet-0b46281c758264ee6 \
  --map-public-ip-on-launch
```

**Verify:**
```bash
aws ec2 describe-subnets --subnet-ids subnet-0b46281c758264ee6 \
  --query 'Subnets[0].MapPublicIpOnLaunch'
# Should return: true
```

---

### ❌ MongoDB Agent Container Not Ready
**Error:** Pod shows `1/2 Running`, agent container not ready

**Cause:** Missing RBAC permissions (pods patch verb)

**Fix:**
```bash
kubectl patch role mongodb-database --type='json' -p='[
  {"op": "add", "path": "/rules/-", "value": {
    "apiGroups": [""],
    "resources": ["pods"],
    "verbs": ["get", "list", "watch", "patch"]
  }}
]'
```

**Verify:**
```bash
kubectl get role mongodb-database -o yaml | grep -A 5 "resources.*pods"
# Should show: patch in verbs list
```

---

### ❌ Backup Authentication Error
**Error:** `not authorized on admin to execute command`

**Cause:** Trying to backup admin database with non-admin user

**Fix:** Use database-specific backups
```bash
# ❌ Wrong
mongodump --uri="mongodb://labuser:...@host/?authSource=admin"

# ✅ Correct
mongodump --uri="mongodb://labuser:...@host/?authSource=admin" --db=myapp
```

---

### ❌ Can't Connect to MongoDB
**Error:** `Authentication failed` or `Connection refused`

**Cause:** Missing authSource parameter

**Fix:**
```bash
# ❌ Wrong
mongodb://labuser:LabPass123!@mongodb-lab-0:27017/

# ✅ Correct
mongodb://labuser:LabPass123!@mongodb-lab-0:27017/?authSource=admin
```

---

### ❌ Subnet IP Exhaustion
**Error:** `no available IP addresses in subnet`

**Cause:** Using TRUST VPC with /28 subnets (only 11 usable IPs)

**Fix:** Use stata-vpc instead
```bash
# Update scripts/mongo-eks.env
export VPC_ID=vpc-035eb12babd9ca798
export SUBNET_A=subnet-0b46281c758264ee6
export SUBNET_B=subnet-0d13ba2dcbb0f6d46
```

---

## MongoDB Issues

### ❌ User Can't Insert/Update
**Error:** `not authorized on <database> to execute command`

**Cause:** Using operator-created admin user (incomplete roles)

**Fix:** Create labuser with full permissions
```javascript
db.createUser({
  user: 'labuser',
  pwd: 'LabPass123!',
  roles: [
    { role: 'readWriteAnyDatabase', db: 'admin' },
    { role: 'dbAdminAnyDatabase', db: 'admin' }
  ]
});
```

---

### ❌ MongoDB Pod Stuck in Pending
**Error:** Pod shows `Pending` status

**Cause:** PVC waiting for pod (WaitForFirstConsumer)

**Check:**
```bash
kubectl describe pod mongodb-lab-0 | grep -A 5 Events
kubectl get pvc
```

**Fix:** Usually resolves automatically. If not, check:
1. Storage class exists: `kubectl get sc`
2. EBS CSI driver running: `kubectl get pods -n kube-system | grep ebs`

---

### ❌ MongoDB Logs Volume Has No StorageClass
**Error:** `logs-volume PVC pending, no storage class`

**Cause:** Operator creates logs-volume without storageClassName

**Fix:** Already handled in deployment script (adds gp2 to both volumes)

---

## Backup/Restore Issues

### ❌ S3 Upload Permission Denied
**Error:** `Access Denied` when uploading to S3

**Cause:** IRSA not configured correctly

**Check:**
```bash
# Verify ServiceAccount annotation
kubectl get sa mongodb-backup -o yaml | grep eks.amazonaws.com/role-arn

# Verify IAM role exists
aws iam get-role --role-name mongo-eks-lab-backup-role

# Verify role policy
aws iam get-role-policy --role-name mongo-eks-lab-backup-role --policy-name S3BackupAccess
```

**Fix:** Re-run S3 backup setup from deploy script

---

### ❌ Backup Job Fails Immediately
**Error:** Job shows `Error` status quickly

**Cause:** Usually AWS CLI installation or connection issue

**Check logs:**
```bash
kubectl logs -l app=mongodb-backup --tail=50
```

**Common fixes:**
- Ensure ServiceAccount has IRSA annotation
- Check MongoDB connection string
- Verify S3 bucket exists

---

## Cluster Issues

### ❌ kubectl Commands Fail
**Error:** `The connection to the server was refused`

**Cause:** kubeconfig not updated or cluster deleted

**Fix:**
```bash
aws eks update-kubeconfig --name mongo-eks-lab --region ap-southeast-1
```

---

### ❌ Nodes Show NotReady
**Error:** Nodes in `NotReady` state

**Check:**
```bash
kubectl describe node <node-name> | grep -A 10 Conditions
```

**Common causes:**
- Network issues (check VPC/subnet config)
- Disk pressure (check node disk usage)
- Memory pressure (check node memory)

**Fix:** Usually resolves automatically. If persistent:
```bash
# Restart node (will be replaced by ASG)
kubectl delete node <node-name>
```

---

## Quick Diagnostics

### Check Everything
```bash
# Cluster
kubectl get nodes
eksctl get cluster --name mongo-eks-lab --region ap-southeast-1

# MongoDB
kubectl get pods -l app=mongodb-lab-svc
kubectl get mongodbcommunity mongodb-lab

# Storage
kubectl get pvc

# Events
kubectl get events --sort-by='.lastTimestamp' | tail -20

# Logs
kubectl logs mongodb-lab-0 -c mongod --tail=50
kubectl logs mongodb-lab-0 -c mongodb-agent --tail=50
```

### Test MongoDB Connection
```bash
kubectl exec mongodb-lab-0 -c mongod -- mongosh \
  "mongodb://labuser:LabPass123!@localhost:27017/?authSource=admin" \
  --quiet --eval "
    print('Version:', db.version());
    print('Status:', db.serverStatus().ok);
    db.test.insertOne({test: 1});
    print('Test insert:', db.test.countDocuments({}));
  "
```

### Check Resource Usage
```bash
kubectl top nodes
kubectl top pods
```

---

## Recovery Procedures

### Restart MongoDB Pod
```bash
kubectl delete pod mongodb-lab-0
# Will be recreated automatically by StatefulSet
```

### Recreate MongoDB (keeps data)
```bash
kubectl delete mongodbcommunity mongodb-lab
# Wait for cleanup
kubectl apply -f <mongodb-manifest>
```

### Full Cleanup and Redeploy
```bash
./scripts/cleanup-all.sh
./scripts/deploy-complete.sh
```

---

## Prevention Checklist

Before deployment:
- [ ] Subnet auto-assign public IP enabled
- [ ] VPC has sufficient IP addresses
- [ ] AWS credentials valid
- [ ] Tools installed (eksctl, kubectl, aws)

After MongoDB deployment:
- [ ] RBAC includes pods patch permission
- [ ] labuser created with full permissions
- [ ] Test connection works
- [ ] Backup job configured

---

## Getting Help

1. **Check logs first:**
   ```bash
   kubectl logs <pod-name> --all-containers --tail=100
   ```

2. **Check events:**
   ```bash
   kubectl describe pod <pod-name>
   ```

3. **Check this guide:** Look for similar error messages

4. **Check AGENTS.md:** For detailed deployment steps

5. **Check README.md:** For usage examples

---

## Common Error Messages

| Error | Cause | Fix |
|-------|-------|-----|
| `Instances failed to join` | Subnet config | Enable auto-assign public IP |
| `not authorized on admin` | Backup strategy | Use database-specific backups |
| `Authentication failed` | Missing authSource | Add `?authSource=admin` |
| `pod has unbound PVC` | Storage issue | Check EBS CSI driver |
| `Access Denied` (S3) | IRSA config | Verify IAM role and annotation |
| `readiness probe failed` | RBAC missing | Add pods patch permission |

---

## Emergency Commands

```bash
# Force delete stuck pod
kubectl delete pod <pod-name> --force --grace-period=0

# Delete all MongoDB resources
kubectl delete mongodbcommunity --all
kubectl delete pvc --all

# Reset cluster (keeps nodes)
kubectl delete deployment mongodb-kubernetes-operator
kubectl delete mongodbcommunity --all

# Full cleanup
./scripts/cleanup-all.sh
```
