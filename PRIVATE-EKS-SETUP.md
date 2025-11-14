# Private-Only EKS Cluster Setup Guide

## Architecture Overview

**Private EKS Cluster**: `dev-private-cluster`
- **VPC**: 10.2.0.0/16 (vpc-0163e5050f8a259c8)
- **Subnets**: Private only (10.2.64.0/19, 10.2.96.0/19)
- **API Endpoint**: Private only (no public access)
- **Internet**: None (no NAT Gateway)
- **Access**: Via VPC Peering from Cloud9 (stata-vpc: 10.0.0.0/16)

**VPC Endpoints**:
- S3 (Gateway)
- ECR API, ECR DKR (Interface)
- EC2, STS, CloudWatch Logs, SSM (Interface)

**Cost**: ~$52/month (7 Interface endpoints)

## Prerequisites

- Cloud9 instance in stata-vpc (10.0.0.0/16)
- Docker installed for image mirroring
- kubectl and eksctl installed

## One-Command Deployment

```bash
./deploy-private-complete.sh
```

## Manual Deployment Steps

### 1. Create Private EKS Cluster

```bash
eksctl create cluster -f private-cluster.yaml
```

**Wait**: ~17 minutes

### 2. Setup VPC Peering

```bash
# Create peering
PCX_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-035eb12babd9ca798 \
  --peer-vpc-id vpc-0163e5050f8a259c8 \
  --region ap-southeast-1 \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

# Accept peering
aws ec2 accept-vpc-peering-connection \
  --vpc-peering-connection-id $PCX_ID \
  --region ap-southeast-1

# Add routes to Cloud9 VPC
for rtb in rtb-0dca97840ad4aacd0 rtb-05279af687e09147a rtb-0ec37afb443a75685 rtb-0abfe460627db2bd9; do
  aws ec2 create-route \
    --route-table-id $rtb \
    --destination-cidr-block 10.2.0.0/16 \
    --vpc-peering-connection-id $PCX_ID \
    --region ap-southeast-1
done

# Add routes to EKS VPC
VPC_ID=vpc-0163e5050f8a259c8
for rtb in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[*].RouteTableId' --output text --region ap-southeast-1); do
  aws ec2 create-route \
    --route-table-id $rtb \
    --destination-cidr-block 10.0.0.0/16 \
    --vpc-peering-connection-id $PCX_ID \
    --region ap-southeast-1
done

# Update security group
SG_ID=$(aws eks describe-cluster --name dev-private-cluster --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
aws ec2 authorize-security-group-ingress \
  --group-id $SG_ID \
  --protocol tcp \
  --port 443 \
  --cidr 10.0.0.0/16 \
  --region ap-southeast-1
```

### 3. Mirror Images to ECR

```bash
# Login to ECR
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com

# Create repositories
for repo in mongodb-kubernetes-operator mongodb-community-server mongodb-agent mongodb-version-upgrade-post-start-hook mongodb-readinessprobe; do
  aws ecr create-repository --repository-name $repo --region ap-southeast-1 || true
done

# Mirror images
docker pull quay.io/mongodb/mongodb-kubernetes-operator:0.13.0
docker tag quay.io/mongodb/mongodb-kubernetes-operator:0.13.0 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-kubernetes-operator:0.13.0
docker push 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-kubernetes-operator:0.13.0

docker pull mongo:7.0.12
docker tag mongo:7.0.12 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-community-server:7.0.12
docker push 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-community-server:7.0.12

docker pull quay.io/mongodb/mongodb-agent-ubi:108.0.6.8796-1
docker tag quay.io/mongodb/mongodb-agent-ubi:108.0.6.8796-1 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-agent:108.0.6.8796-1
docker push 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-agent:108.0.6.8796-1

docker pull quay.io/mongodb/mongodb-kubernetes-operator-version-upgrade-post-start-hook:1.0.10
docker tag quay.io/mongodb/mongodb-kubernetes-operator-version-upgrade-post-start-hook:1.0.10 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-version-upgrade-post-start-hook:1.0.10
docker push 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-version-upgrade-post-start-hook:1.0.10

docker pull quay.io/mongodb/mongodb-kubernetes-readinessprobe:1.0.23
docker tag quay.io/mongodb/mongodb-kubernetes-readinessprobe:1.0.23 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-readinessprobe:1.0.23
docker push 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-readinessprobe:1.0.23
```

### 4. Deploy MongoDB Operator

```bash
# Install CRDs and RBAC
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding.yaml

# Deploy operator with ECR image
curl -sL https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/manager/manager.yaml | \
  sed 's|quay.io/mongodb/mongodb-kubernetes-operator:0.13.0|273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-kubernetes-operator:0.13.0|g' | \
  kubectl apply -f -

# Configure operator to use ECR images
kubectl set env deployment/mongodb-kubernetes-operator \
  AGENT_IMAGE=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-agent:108.0.6.8796-1 \
  VERSION_UPGRADE_HOOK_IMAGE=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-version-upgrade-post-start-hook:1.0.10 \
  READINESS_PROBE_IMAGE=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-readinessprobe:1.0.23 \
  MONGODB_IMAGE=mongodb-community-server \
  MONGODB_REPO_URL=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com

# Create service account
kubectl create serviceaccount mongodb-database
```

### 5. Deploy MongoDB

```bash
kubectl apply -f mongodb-private.yaml
```

## Validation

```bash
# Check nodes
kubectl get nodes

# Check MongoDB
kubectl get mongodbcommunity,pods,pvc

# Test MongoDB
kubectl exec mongodb-test-0 -c mongod -- mongosh --eval "db.version()"

# Verify no internet access
kubectl run test-no-internet --rm -i --restart=Never --image=busybox:1.36 --command -- timeout 5 wget -qO- https://ifconfig.me
```

## Files

- `private-cluster.yaml` - eksctl cluster config
- `mongodb-private.yaml` - MongoDB deployment with ECR images
- `deploy-private-complete.sh` - Full automated deployment
- `cleanup-private.sh` - Complete cleanup script

## Key Differences from Hybrid Cluster

| Feature | Hybrid | Private-Only |
|---------|--------|--------------|
| VPC CIDR | 10.1.0.0/16 | 10.2.0.0/16 |
| NAT Gateway | Yes | No |
| Internet Access | Yes | No |
| API Endpoint | Public + Private | Private only |
| Image Source | Internet | ECR only |
| Access Method | Direct | VPC Peering |
| Cost/month | $32 | $52 |

## Troubleshooting

**Cannot access API**: Check VPC peering and security group rules
**ImagePullBackOff**: Ensure all images are mirrored to ECR and operator env vars are set
**Timeout errors**: Verify VPC endpoints are available and DNS resolution works
