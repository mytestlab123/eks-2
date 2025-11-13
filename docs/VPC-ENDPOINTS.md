# VPC Endpoints for Private EKS Cluster

## Why Required

Private EKS clusters (no public API endpoint) require VPC Interface Endpoints for:
- **Nodes to join cluster**: `eks`, `ec2`, `ecr.api`, `ecr.dkr`
- **Logging**: `logs`
- **IAM authentication**: `sts`
- **SSM bastion access**: `ssm`, `ssmmessages`, `ec2messages`

Without these, nodes cannot:
- Authenticate to EKS API
- Pull container images from ECR
- Send logs to CloudWatch
- Register with Systems Manager

## Required Endpoints

### For EKS Nodes (Critical)
- `com.amazonaws.ap-southeast-1.ecr.api` - ECR API calls
- `com.amazonaws.ap-southeast-1.ecr.dkr` - ECR image pulls
- `com.amazonaws.ap-southeast-1.eks` - EKS API
- `com.amazonaws.ap-southeast-1.ec2` - EC2 metadata/API
- `com.amazonaws.ap-southeast-1.logs` - CloudWatch Logs
- `com.amazonaws.ap-southeast-1.sts` - IAM role assumption

### For SSM Bastion (Optional but recommended)
- `com.amazonaws.ap-southeast-1.ssm` - Systems Manager
- `com.amazonaws.ap-southeast-1.ssmmessages` - Session Manager
- `com.amazonaws.ap-southeast-1.ec2messages` - SSM Agent

### For S3 (Already exists)
- `com.amazonaws.ap-southeast-1.s3` - Gateway Endpoint (free)

## Deployment Strategy

**Target Subnets**: Create endpoints in AZ 1a and 1c (where nodes will run)
- `subnet-0791f110f66224a90` (ap-southeast-1a) - 7 free IPs
- `subnet-0bdb0912b1c5850a7` (ap-southeast-1c) - 7 free IPs

**Why not 1b?** Existing endpoints in 1b have 0 free IPs.

## Cost Estimate

- Interface Endpoints: $0.01/hour × 6 endpoints × 2 AZs = **$0.12/hour**
- Data transfer: $0.01/GB (minimal for lab)
- **Total for 4-hour lab: ~$0.50**

## Security Groups

Endpoints need inbound HTTPS (443) from:
- VPC CIDR: `172.31.0.0/16`
- Or specific subnet CIDRs

## Verification

After creation, check:
```bash
aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-06814ea8b57b55627" \
  --query 'VpcEndpoints[*].[ServiceName,State,SubnetIds]' \
  --output table
```

## Cleanup

Delete endpoints after lab to stop charges:
```bash
just eks_endpoints_delete
```
