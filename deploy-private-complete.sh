#!/bin/bash
set -e

echo "=== Private-Only EKS Cluster - Complete Deployment ==="
echo "Start: $(date)"

# 1. Create cluster
echo "Step 1/5: Creating EKS cluster..."
eksctl create cluster -f private-cluster.yaml

# 2. Setup VPC peering
echo "Step 2/5: Setting up VPC peering..."
PCX_ID=$(aws ec2 create-vpc-peering-connection \
  --vpc-id vpc-035eb12babd9ca798 \
  --peer-vpc-id vpc-0163e5050f8a259c8 \
  --region ap-southeast-1 \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' \
  --output text)

aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PCX_ID --region ap-southeast-1

# Add routes
for rtb in rtb-0dca97840ad4aacd0 rtb-05279af687e09147a rtb-0ec37afb443a75685 rtb-0abfe460627db2bd9; do
  aws ec2 create-route --route-table-id $rtb --destination-cidr-block 10.2.0.0/16 --vpc-peering-connection-id $PCX_ID --region ap-southeast-1 || true
done

VPC_ID=vpc-0163e5050f8a259c8
for rtb in $(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[*].RouteTableId' --output text --region ap-southeast-1); do
  aws ec2 create-route --route-table-id $rtb --destination-cidr-block 10.0.0.0/16 --vpc-peering-connection-id $PCX_ID --region ap-southeast-1 || true
done

# Update security group
SG_ID=$(aws eks describe-cluster --name dev-private-cluster --region ap-southeast-1 --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 443 --cidr 10.0.0.0/16 --region ap-southeast-1 || true

# 3. Mirror images to ECR
echo "Step 3/5: Mirroring images to ECR..."
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin 273828039634.dkr.ecr.ap-southeast-1.amazonaws.com

for repo in mongodb-kubernetes-operator mongodb-community-server mongodb-agent mongodb-version-upgrade-post-start-hook mongodb-readinessprobe; do
  aws ecr create-repository --repository-name $repo --region ap-southeast-1 2>&1 || true
done

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

# 4. Deploy MongoDB operator
echo "Step 4/5: Deploying MongoDB operator..."
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding.yaml

curl -sL https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/manager/manager.yaml | \
  sed 's|quay.io/mongodb/mongodb-kubernetes-operator:0.13.0|273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-kubernetes-operator:0.13.0|g' | \
  kubectl apply -f -

kubectl wait --for=condition=Available deployment/mongodb-kubernetes-operator --timeout=180s

kubectl set env deployment/mongodb-kubernetes-operator \
  AGENT_IMAGE=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-agent:108.0.6.8796-1 \
  VERSION_UPGRADE_HOOK_IMAGE=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-version-upgrade-post-start-hook:1.0.10 \
  READINESS_PROBE_IMAGE=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/mongodb-readinessprobe:1.0.23 \
  MONGODB_IMAGE=mongodb-community-server \
  MONGODB_REPO_URL=273828039634.dkr.ecr.ap-southeast-1.amazonaws.com

kubectl create serviceaccount mongodb-database || true

kubectl rollout status deployment/mongodb-kubernetes-operator --timeout=120s

# 5. Deploy MongoDB
echo "Step 5/5: Deploying MongoDB..."
kubectl apply -f mongodb-private.yaml

echo "=== Deployment Complete ==="
echo "End: $(date)"
echo ""
echo "Validation:"
echo "  kubectl get nodes"
echo "  kubectl get mongodbcommunity,pods,pvc"
echo "  kubectl exec mongodb-test-0 -c mongod -- mongosh --eval 'db.version()'"
