#!/usr/bin/env bash
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
source "$HERE/mongo-eks.env"

log=/tmp/mongo-eks-teardown.log
exec > >(tee -a "$log") 2>&1
echo "[teardown] start $(date -Iseconds)"

acct=$(aws sts get-caller-identity --query Account --output text)
echo "[teardown] account=$acct region=$AWS_REGION cluster=$CLUSTER_NAME vpc=$VPC_ID"

safe() { "$@" >/dev/null 2>&1 || true; }

# 0) Capture cluster OIDC provider ARN (if present)
OIDC_ARN=""
if aws eks describe-cluster --name "$CLUSTER_NAME" >/dev/null 2>&1; then
  ISSUER=$(aws eks describe-cluster --name "$CLUSTER_NAME" --query 'cluster.identity.oidc.issuer' --output text)
  if [[ "$ISSUER" == https://* ]]; then
    OIDC_ARN="arn:aws:iam::${acct}:oidc-provider/${ISSUER#https://}"
    echo "[teardown] oidc=$OIDC_ARN"
  fi
fi

# 1) Bastion instances
IIDS=$(aws ec2 describe-instances --filters Name=tag:Name,Values=mongo-eks-bastion Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text || true)
if [[ -n "${IIDS:-}" ]]; then
  echo "[teardown] terminate bastions: $IIDS"
  safe aws ec2 terminate-instances --instance-ids $IIDS
  safe aws ec2 wait instance-terminated --instance-ids $IIDS
fi

# 2) Nodegroups (any)
NGS=$(aws eks list-nodegroups --cluster-name "$CLUSTER_NAME" --query 'nodegroups' --output text 2>/dev/null || true)
for ng in $NGS; do
  echo "[teardown] delete nodegroup: $ng"
  safe aws eks delete-nodegroup --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$AWS_REGION"
  safe aws eks wait nodegroup-deleted --cluster-name "$CLUSTER_NAME" --nodegroup-name "$ng" --region "$AWS_REGION"
done

# 3) EKS add-ons (best-effort)
safe aws eks delete-addon --cluster-name "$CLUSTER_NAME" --addon-name aws-ebs-csi-driver --region "$AWS_REGION"

# 4) Delete cluster
echo "[teardown] delete cluster"
safe eksctl delete cluster --region "$AWS_REGION" --name "$CLUSTER_NAME"
safe aws eks delete-cluster --name "$CLUSTER_NAME" --region "$AWS_REGION"

# 5) Delete OIDC provider if captured
if [[ -n "$OIDC_ARN" ]]; then
  echo "[teardown] delete oidc: $OIDC_ARN"
  safe aws iam delete-open-id-connect-provider --open-id-connect-provider-arn "$OIDC_ARN"
fi

# 6) VPC Interface Endpoints created by this lab (tag Project=mongo-eks-lab)
VPCE=$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID Name=tag:Project,Values=mongo-eks-lab --query 'VpcEndpoints[?VpcEndpointType==`Interface`].VpcEndpointId' --output text || true)
if [[ -n "${VPCE:-}" ]]; then
  echo "[teardown] delete vpce: $VPCE"
  safe aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $VPCE
fi

# 7) Security groups created by this lab
for sg in eks-bastion-sg vpce-mongo-eks-sg; do
  SGID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID Name=group-name,Values=$sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo None)
  if [[ "$SGID" != "None" ]]; then
    echo "[teardown] delete sg: $sg $SGID"
    safe aws ec2 delete-security-group --group-id "$SGID"
  fi
done

# 8) IAM: instance profile + bastion role
echo "[teardown] delete bastion role/profile"
safe aws iam remove-role-from-instance-profile --instance-profile-name EKSAdminBastionRoleProfile --role-name EKSAdminBastionRole
safe aws iam delete-instance-profile --instance-profile-name EKSAdminBastionRoleProfile
safe aws iam detach-role-policy --role-name EKSAdminBastionRole --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
safe aws iam detach-role-policy --role-name EKSAdminBastionRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
safe aws iam detach-role-policy --role-name EKSAdminBastionRole --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
safe aws iam delete-role-policy --role-name EKSAdminBastionRole --policy-name EKSAllowDescribeCluster
safe aws iam delete-role --role-name EKSAdminBastionRole

# 9) IAM: node/ebs/backup roles + policy
echo "[teardown] delete lab roles"
safe aws iam detach-role-policy --role-name mongo-eks-lab-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
safe aws iam detach-role-policy --role-name mongo-eks-lab-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
safe aws iam detach-role-policy --role-name mongo-eks-lab-node-role --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
safe aws iam delete-role --role-name mongo-eks-lab-node-role
safe aws iam detach-role-policy --role-name mongo-eks-lab-ebs-csi --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy
safe aws iam delete-role --role-name mongo-eks-lab-ebs-csi
POLICY_ARN=$(aws iam list-policies --scope Local --query "Policies[?PolicyName==\`${CLUSTER_NAME}-mongo-backup-s3\`].Arn | [0]" --output text 2>/dev/null || echo None)
safe aws iam detach-role-policy --role-name ${CLUSTER_NAME}-mongo-backup --policy-arn ${POLICY_ARN}
safe aws iam delete-role --role-name ${CLUSTER_NAME}-mongo-backup
if [[ "$POLICY_ARN" != "None" ]]; then safe aws iam delete-policy --policy-arn ${POLICY_ARN}; fi

# 10) ECR repositories under prefix
echo "[teardown] delete ECR repos"
REPOS=$(aws ecr describe-repositories --query "repositories[?starts_with(repositoryName, \`${ECR_REPO_PREFIX}\`)].repositoryName" --output text 2>/dev/null || true)
for r in $REPOS; do
  echo "[teardown] ecr delete: $r"
  safe aws ecr delete-repository --repository-name "$r" --force
done

echo "[teardown] complete $(date -Iseconds) | log=$log"

