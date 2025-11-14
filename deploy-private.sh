#!/bin/bash
set -e

echo "=== Deploying Private-Only VPC EKS Cluster ==="
echo "Start: $(date)"

# Create cluster
eksctl create cluster -f private-cluster.yaml

# Get VPC ID
VPC_ID=$(aws eks describe-cluster --name dev-private-cluster --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.vpcId' --output text)
echo "VPC ID: $VPC_ID"

# Create VPC endpoints
echo "Creating VPC endpoints..."

# Get subnet IDs
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:aws:cloudformation:logical-id,Values=SubnetPrivate*" --query 'Subnets[*].SubnetId' --output text --region ap-southeast-1)

# Get security group
SG_ID=$(aws eks describe-cluster --name dev-private-cluster --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)

# S3 Gateway Endpoint
aws ec2 create-vpc-endpoint --vpc-id $VPC_ID --service-name com.amazonaws.ap-southeast-1.s3 --route-table-ids $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Tags[?Key==`aws:cloudformation:logical-id` && contains(Value, `PrivateRouteTable`)]].RouteTableId' --output text --region ap-southeast-1) --region ap-southeast-1 || true

# Interface Endpoints
for service in ecr.api ecr.dkr ec2 sts logs ssm; do
  aws ec2 create-vpc-endpoint --vpc-id $VPC_ID --vpc-endpoint-type Interface --service-name com.amazonaws.ap-southeast-1.$service --subnet-ids $SUBNET_IDS --security-group-ids $SG_ID --region ap-southeast-1 || true
done

echo "Waiting for cluster to be accessible..."
sleep 60

# Wait for nodes
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install MongoDB Operator
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/manager/manager.yaml

# Wait for operator
kubectl wait --for=condition=Available deployment/mongodb-kubernetes-operator -n default --timeout=300s

echo "=== Cluster Ready ==="
echo "End: $(date)"
