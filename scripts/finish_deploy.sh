#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/mongo-eks.env"

log=/tmp/finish-deploy.log
exec > >(tee -a "$log") 2>&1

echo "[finish] start $(date -Iseconds)"

echo "[finish] waiting for nodegroup ACTIVE"
for i in {1..60}; do
  st=$(aws eks describe-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name ng-spot-a --query nodegroup.status --output text 2>/dev/null || echo none)
  echo "[finish] nodegroup status: $st ($i)"
  if [[ "$st" == ACTIVE ]]; then break; fi
  sleep 10
done

echo "[finish] sending SSM to bastion"
IID=$(aws ec2 describe-instances \
  --filters Name=tag:Name,Values=mongo-eks-bastion Name=instance-state-name,Values=running \
  --query Reservations[0].Instances[0].InstanceId --output text)

aws ssm send-command --instance-ids "$IID" --document-name AWS-RunShellScript \
  --parameters commands="aws s3 cp ${S3_BACKUP_BUCKET%/}/bin/bastion-ops.sh /tmp/bastion-ops.sh --only-show-errors","bash /tmp/bastion-ops.sh" \
  --query Command.CommandId --output text

echo "[finish] done $(date -Iseconds)"

