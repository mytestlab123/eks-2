#!/usr/bin/env bash
set -euo pipefail

: "${AWS_PROFILE:?set in scripts/mongo-eks.env}"
: "${AWS_REGION:?set in scripts/mongo-eks.env}"
: "${VPC_ID:?set in scripts/mongo-eks.env}"
: "${SUBNET_A:?set in scripts/mongo-eks.env}"

ROLE=EKSAdminBastionRole
PROFILE=${ROLE}Profile

ACTION=${1:-}

case "$ACTION" in
  create)
    aws iam get-role --role-name $ROLE --query Role.Arn --output text >/dev/null 2>&1 || {
      aws iam create-role --role-name $ROLE --assume-role-policy-document '{
        "Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}' >/dev/null
      aws iam attach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
      aws iam attach-role-policy --role-name $ROLE --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
    }
    aws iam get-instance-profile --instance-profile-name $PROFILE >/dev/null 2>&1 || {
      aws iam create-instance-profile --instance-profile-name $PROFILE >/dev/null
      aws iam add-role-to-instance-profile --instance-profile-name $PROFILE --role-name $ROLE >/dev/null
    }
    AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64 --query 'Parameters[0].Value' --output text)
    BASTION_SG=$(aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC_ID Name=group-name,Values=eks-bastion-sg --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo none)
    if [[ "$BASTION_SG" == "None" || "$BASTION_SG" == "none" ]]; then
      BASTION_SG=$(aws ec2 create-security-group --group-name eks-bastion-sg --description "SSM bastion" --vpc-id $VPC_ID --query GroupId --output text)
      aws ec2 authorize-security-group-egress --group-id $BASTION_SG --ip-permissions '[{"IpProtocol":"-1","IpRanges":[{"CidrIp":"0.0.0.0/0"}]}]'
    fi
    aws ec2 run-instances --image-id $AMI_ID --instance-type t3.micro \
      --iam-instance-profile Name=$PROFILE \
      --network-interfaces "DeviceIndex=0,SubnetId=$SUBNET_A,Groups=$BASTION_SG,AssociatePublicIpAddress=false" \
      --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=mongo-eks-bastion},{Key=Project,Value=mongo-eks-lab}]' --count 1 \
      --query 'Instances[0].InstanceId' --output text
    ;;
  delete)
    IID=$(aws ec2 describe-instances --filters Name=tag:Name,Values=mongo-eks-bastion Name=instance-state-name,Values=pending,running,stopping,stopped --query 'Reservations[].Instances[].InstanceId' --output text)
    if [[ -n "$IID" ]]; then aws ec2 terminate-instances --instance-ids $IID >/dev/null; fi
    ;;
  *) echo "usage: $0 {create|delete}"; exit 2;;
esac
