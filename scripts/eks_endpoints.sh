#!/usr/bin/env bash
set -euo pipefail

: "${AWS_PROFILE:?set in scripts/mongo-eks.env}"
: "${AWS_REGION:?set in scripts/mongo-eks.env}"
: "${VPC_ID:?set in scripts/mongo-eks.env}"

ACTION=${1:-}
case "$ACTION" in
  create)
    VPC_CIDR=$(aws ec2 describe-vpcs --vpc-ids "$VPC_ID" --query 'Vpcs[0].CidrBlock' --output text)
    SG_NAME=vpce-mongo-eks-sg
    SG_ID=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID Name=group-name,Values=$SG_NAME --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo none)
    if [[ "$SG_ID" == "None" || "$SG_ID" == "none" ]]; then
      SG_ID=$(aws ec2 create-security-group --group-name $SG_NAME --description "EKS lab interface endpoints" --vpc-id $VPC_ID \
        --tag-specifications 'ResourceType=security-group,Tags=[{Key=Project,Value=mongo-eks-lab}]' --query GroupId --output text)
      aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 443 --cidr "$VPC_CIDR"
    fi
    # Use AZ 1a and 1c (where nodes will run)
    SUBNETS=( ${SUBNET_A:-subnet-0791f110f66224a90} ${SUBNET_C:-subnet-0bdb0912b1c5850a7} )
    for svc in ssm ssmmessages ec2messages ecr.api ecr.dkr ec2 eks logs sts; do
      exists=$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID Name=service-name,Values=com.amazonaws.${AWS_REGION}.${svc} \
        --query 'length(VpcEndpoints[])' --output text)
      if [[ "$exists" == "0" ]]; then
        aws ec2 create-vpc-endpoint \
          --vpc-id $VPC_ID --vpc-endpoint-type Interface \
          --service-name com.amazonaws.${AWS_REGION}.${svc} \
          --subnet-ids ${SUBNETS[*]} \
          --security-group-ids "$SG_ID" --private-dns-enabled \
          --tag-specifications 'ResourceType=vpc-endpoint,Tags=[{Key=Project,Value=mongo-eks-lab}]'
      else
        echo "vpce for ${svc} exists"
      fi
    done
    ;;
  list)
    aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID \
      --query 'VpcEndpoints[].{Id:VpcEndpointId,Service:ServiceName,Type:VpcEndpointType,State:State}' --output table
    ;;
  delete)
    # Interface Endpoints cost hourly; delete to save cost
    IDS=$(aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=$VPC_ID \
      --query 'VpcEndpoints[?VpcEndpointType==`Interface`].VpcEndpointId' --output text)
    if [[ -n "$IDS" ]]; then aws ec2 delete-vpc-endpoints --vpc-endpoint-ids $IDS; fi
    ;;
  *) echo "usage: $0 {create|list|delete}"; exit 2;;
esac
