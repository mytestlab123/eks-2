#!/bin/bash
set -e

echo "=== Private-Only EKS Cluster - Complete Cleanup ==="
echo "Start: $(date)"

# Get VPC peering ID
PCX_ID=$(aws ec2 describe-vpc-peering-connections \
  --filters "Name=requester-vpc-info.vpc-id,Values=vpc-035eb12babd9ca798" \
            "Name=accepter-vpc-info.vpc-id,Values=vpc-0163e5050f8a259c8" \
            "Name=status-code,Values=active" \
  --query 'VpcPeeringConnections[0].VpcPeeringConnectionId' \
  --output text \
  --region ap-southeast-1 2>/dev/null || echo "")

# Delete EKS cluster
echo "Step 1/4: Deleting EKS cluster..."
eksctl delete cluster --name dev-private-cluster --region ap-southeast-1 --wait

# Delete VPC peering
if [ "$PCX_ID" != "" ] && [ "$PCX_ID" != "None" ]; then
  echo "Step 2/4: Deleting VPC peering..."
  
  # Remove routes from Cloud9 VPC
  for rtb in rtb-0dca97840ad4aacd0 rtb-05279af687e09147a rtb-0ec37afb443a75685 rtb-0abfe460627db2bd9; do
    aws ec2 delete-route --route-table-id $rtb --destination-cidr-block 10.2.0.0/16 --region ap-southeast-1 2>&1 || true
  done
  
  # Delete peering connection
  aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PCX_ID --region ap-southeast-1 || true
else
  echo "Step 2/4: No VPC peering found"
fi

# Delete ECR repositories
echo "Step 3/4: Deleting ECR repositories..."
for repo in mongodb-kubernetes-operator mongodb-community-server mongodb-agent mongodb-version-upgrade-post-start-hook mongodb-readinessprobe; do
  aws ecr delete-repository --repository-name $repo --force --region ap-southeast-1 2>&1 || true
done

# Cleanup local Docker images
echo "Step 4/4: Cleaning up local Docker images..."
docker rmi $(docker images '273828039634.dkr.ecr.ap-southeast-1.amazonaws.com/*' -q) 2>/dev/null || true
docker rmi $(docker images 'quay.io/mongodb/*' -q) 2>/dev/null || true
docker rmi mongo:7.0.12 2>/dev/null || true

echo "=== Cleanup Complete ==="
echo "End: $(date)"
