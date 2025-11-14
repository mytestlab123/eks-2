#!/usr/bin/env bash
set -euo pipefail

echo "=== EKS MongoDB Lab - Complete Cleanup ==="
echo "This will delete ALL lab resources"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Cleanup cancelled"
  exit 0
fi

cd "$(dirname "$0")/.."
source scripts/mongo-eks.env

echo ""
echo "1. Deleting MongoDB resources..."
kubectl delete mongodbcommunity mongodb-lab --ignore-not-found=true
kubectl delete deployment mongodb-kubernetes-operator --ignore-not-found=true
kubectl delete serviceaccount mongodb-database --ignore-not-found=true
kubectl delete serviceaccount mongodb-backup --ignore-not-found=true
kubectl delete role mongodb-database --ignore-not-found=true
kubectl delete rolebinding mongodb-database --ignore-not-found=true
kubectl delete job mongodb-backup --ignore-not-found=true
kubectl delete job mongodb-restore-test --ignore-not-found=true
kubectl delete pvc --all --ignore-not-found=true
kubectl delete secret mongodb-admin-password --ignore-not-found=true
echo "✅ MongoDB resources deleted"

echo ""
echo "2. Deleting EKS cluster..."
if eksctl get cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} >/dev/null 2>&1; then
  eksctl delete cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --wait
  echo "✅ EKS cluster deleted"
else
  echo "⚠️  Cluster not found, skipping"
fi

echo ""
echo "3. Deleting IAM roles..."
aws iam delete-role-policy \
  --role-name mongo-eks-lab-backup-role \
  --policy-name S3BackupAccess 2>/dev/null || echo "⚠️  Backup policy not found"
aws iam delete-role \
  --role-name mongo-eks-lab-backup-role 2>/dev/null || echo "⚠️  Backup role not found"
echo "✅ IAM roles deleted"

echo ""
echo "4. Cleaning up S3 backups..."
read -p "Delete S3 backups? (yes/no): " DELETE_S3
if [ "$DELETE_S3" = "yes" ]; then
  BUCKET="mongo-eks-lab-backup-$(aws sts get-caller-identity --query Account --output text)"
  aws s3 rm s3://${BUCKET}/backups/ --recursive 2>/dev/null || true
  aws s3 rb s3://${BUCKET} 2>/dev/null || echo "⚠️  Bucket not found"
  echo "✅ S3 backups deleted"
else
  echo "⚠️  S3 backups preserved"
fi

echo ""
echo "5. Cleaning up VPC endpoints (optional)..."
read -p "Delete VPC endpoints? (yes/no): " DELETE_ENDPOINTS
if [ "$DELETE_ENDPOINTS" = "yes" ]; then
  IDS=$(aws ec2 describe-vpc-endpoints \
    --filters "Name=vpc-id,Values=${VPC_ID}" "Name=tag:Project,Values=mongo-eks-lab" \
    --query 'VpcEndpoints[].VpcEndpointId' --output text --region ${AWS_REGION})
  if [ -n "$IDS" ]; then
    aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $IDS --region ${AWS_REGION}
    echo "✅ VPC endpoints deleted"
  else
    echo "⚠️  No endpoints found"
  fi
else
  echo "⚠️  VPC endpoints preserved"
fi

echo ""
echo "6. Cleaning up local files..."
rm -f /tmp/mongodb-*.yaml
rm -f /tmp/mongodb-*.gz
rm -f /tmp/*.pr_body.md
rm -f /tmp/trust-policy.json
rm -f /tmp/s3-policy.json
echo "✅ Local temp files deleted"

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Summary:"
echo "- MongoDB resources: Deleted"
echo "- EKS cluster: Deleted"
echo "- IAM roles: Deleted"
echo "- S3 backups: ${DELETE_S3}"
echo "- VPC endpoints: ${DELETE_ENDPOINTS}"
echo ""
echo "Your AWS account is now clean!"
