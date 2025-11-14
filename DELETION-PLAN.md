# Deletion Plan - Private EKS Cluster

## Pre-Deletion Checklist

- [ ] Backup any data from MongoDB
- [ ] Export any important configurations
- [ ] Verify no production workloads are running
- [ ] Confirm VPC peering can be removed

## Automated Deletion

```bash
./cleanup-private.sh
```

**Duration**: ~15 minutes

## Manual Deletion Steps

### Step 1: Delete EKS Cluster (10-12 min)

```bash
eksctl delete cluster --name dev-private-cluster --region ap-southeast-1 --wait
```

**What gets deleted**:
- EKS control plane
- Managed node group (2 nodes)
- EBS volumes (PVCs)
- VPC endpoints (created by eksctl)
- CloudFormation stacks

### Step 2: Remove VPC Peering (1 min)

```bash
# Get peering ID
PCX_ID=$(aws ec2 describe-vpc-peering-connections \
  --filters "Name=requester-vpc-info.vpc-id,Values=vpc-035eb12babd9ca798" \
            "Name=accepter-vpc-info.vpc-id,Values=vpc-0163e5050f8a259c8" \
  --query 'VpcPeeringConnections[0].VpcPeeringConnectionId' \
  --output text \
  --region ap-southeast-1)

# Remove routes from Cloud9 VPC
for rtb in rtb-0dca97840ad4aacd0 rtb-05279af687e09147a rtb-0ec37afb443a75685 rtb-0abfe460627db2bd9; do
  aws ec2 delete-route --route-table-id $rtb --destination-cidr-block 10.2.0.0/16 --region ap-southeast-1
done

# Delete peering
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PCX_ID --region ap-southeast-1
```

### Step 3: Delete ECR Repositories (2 min)

```bash
for repo in mongodb-kubernetes-operator mongodb-community-server mongodb-agent mongodb-version-upgrade-post-start-hook mongodb-readinessprobe; do
  aws ecr delete-repository --repository-name $repo --force --region ap-southeast-1
done
```

**Storage freed**: ~2GB

### Step 4: Cleanup Local Docker Images (1 min)

```bash
docker rmi $(docker images '273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/*' -q)
docker rmi $(docker images 'quay.io/mongodb/*' -q)
docker rmi mongo:7.0.12
```

## What Gets Preserved

- Cloud9 VPC (stata-vpc) - **NOT DELETED**
- Other VPCs - **NOT DELETED**
- IAM roles not created by eksctl - **NOT DELETED**

## Verification

```bash
# Verify cluster deleted
eksctl get cluster --region ap-southeast-1

# Verify VPC peering removed
aws ec2 describe-vpc-peering-connections --region ap-southeast-1

# Verify ECR repos deleted
aws ecr describe-repositories --region ap-southeast-1

# Verify no orphaned resources
aws ec2 describe-vpcs --region ap-southeast-1
aws ec2 describe-security-groups --filters "Name=group-name,Values=*dev-private-cluster*" --region ap-southeast-1
```

## Cost Impact

After deletion:
- **Saved**: ~$52/month (VPC endpoints)
- **Saved**: ~$60/month (2× t3.small nodes)
- **Total savings**: ~$112/month

## Re-Creation

To recreate the exact same infrastructure:

```bash
./deploy-private-complete.sh
```

**Note**: VPC ID will be different, but CIDR (10.2.0.0/16) will be the same.
