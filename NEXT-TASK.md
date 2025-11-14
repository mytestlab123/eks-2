# Next Task: Multi-VPC EKS Setup (Dev + Prod Simulation)

## Objective

Create two separate VPC and EKS environments in the **dev** AWS profile to simulate real-world scenarios and prepare for final production deployment in **prod** profile.

## Requirements

### Phase 1: Cleanup Current Environment
- Delete existing EKS cluster from stata-vpc
- Keep stata-vpc intact (don't delete)

### Phase 2: Create Two New Environments (Both in "dev" profile)

#### Environment 1: Public + Private VPC (Dev/Testing)
**Purpose:** Development and testing with internet access

**VPC Configuration:**
- Name: `eks-dev-hybrid-vpc` or similar
- CIDR: TBD
- Subnets:
  - Public subnets (with IGW) - for NAT Gateway, bastion, load balancers
  - Private subnets (with NAT) - for EKS nodes
- Internet Gateway: Yes
- NAT Gateway: Yes (for private subnet egress)
- VPC Endpoints: Optional (can use NAT for AWS services)

**EKS Configuration:**
- Cluster Name: `eks-dev-hybrid` or similar
- API Endpoint: Public + Private
- Nodes: In private subnets
- Egress: Via NAT Gateway
- Use Case: Development, testing, CI/CD

**Tags:**
- Environment: dev
- Type: hybrid
- Internet: enabled
- Project: eks-mongodb-lab

---

#### Environment 2: Private-Only VPC (Prod Simulation)
**Purpose:** Production simulation with no internet access

**VPC Configuration:**
- Name: `eks-dev-private-vpc` or similar
- CIDR: TBD (different from Environment 1)
- Subnets:
  - Private subnets only (no public subnets)
- Internet Gateway: **NO**
- NAT Gateway: **NO**
- VPC Endpoints: **REQUIRED** (all AWS services)
  - S3 (Gateway)
  - ECR API, ECR DKR (Interface)
  - EKS (Interface)
  - EC2 (Interface)
  - CloudWatch Logs (Interface)
  - STS (Interface)
  - SSM, SSM Messages, EC2 Messages (Interface) - for bastion

**EKS Configuration:**
- Cluster Name: `eks-dev-private` or similar
- API Endpoint: Private only
- Nodes: In private subnets
- Egress: **NONE** (all via VPC endpoints)
- Use Case: Production simulation, security testing

**Tags:**
- Environment: dev
- Type: private-only
- Internet: disabled
- Project: eks-mongodb-lab

---

### Phase 3: Deploy MongoDB to Both Environments

**Environment 1 (Hybrid):**
- Standard deployment (can pull images from internet)
- Public load balancer option available
- Easier troubleshooting

**Environment 2 (Private):**
- Images must be in ECR (mirror from public)
- No public load balancers
- Access via bastion/VPN only
- Tests production readiness

---

## Key Differences Summary

| Aspect | Environment 1 (Hybrid) | Environment 2 (Private) |
|--------|------------------------|-------------------------|
| **Internet Access** | Yes (via NAT) | No |
| **Public Subnets** | Yes | No |
| **IGW** | Yes | No |
| **NAT Gateway** | Yes | No |
| **VPC Endpoints** | Optional | Required |
| **EKS API** | Public + Private | Private only |
| **Image Source** | Docker Hub, ECR | ECR only |
| **Troubleshooting** | Easier | Harder |
| **Cost** | Higher (NAT) | Lower (no NAT) |
| **Security** | Medium | High |
| **Use Case** | Dev/Test | Prod simulation |

---

## Final Production (Future - "prod" profile)

After validating both environments in "dev" profile, the final production will be:
- AWS Profile: **prod**
- VPC Type: **Private-only** (like Environment 2)
- No internet access
- All AWS services via VPC endpoints
- Highest security posture

---

## Success Criteria

1. ✅ Both VPCs created with proper naming and tags
2. ✅ Both EKS clusters operational
3. ✅ MongoDB deployed and working in both environments
4. ✅ Backup solution working in both environments
5. ✅ Documentation updated with both architectures
6. ✅ Lessons learned documented (especially for private-only)
7. ✅ Cost comparison between both environments

---

## Expected Challenges

### Environment 1 (Hybrid) - Should be straightforward
- Similar to current stata-vpc setup
- NAT Gateway provides internet access
- Standard deployment process

### Environment 2 (Private) - Will have challenges
- VPC endpoint configuration complexity
- Image mirroring to ECR required
- No internet for troubleshooting
- DNS resolution for VPC endpoints
- Bastion access setup
- Testing without external connectivity

---

## Estimated Timeline

- Phase 1 (Cleanup): 10 minutes
- Phase 2 (VPC + EKS creation): 2-3 hours
  - Environment 1: 1 hour
  - Environment 2: 1.5-2 hours (more complex)
- Phase 3 (MongoDB deployment): 1-2 hours
  - Environment 1: 30 minutes
  - Environment 2: 1-1.5 hours (image mirroring, troubleshooting)
- Documentation: 30 minutes

**Total: 4-6 hours**

---

## Questions to Address Before Starting

1. **CIDR Blocks:** What CIDR ranges for each VPC?
   - Suggestion: 10.1.0.0/16 (hybrid), 10.2.0.0/16 (private)

2. **Subnet Layout:** How many AZs? How many subnets per AZ?
   - Suggestion: 2 AZs, 2 private subnets per VPC (4 total per VPC)
   - Environment 1: Add 2 public subnets

3. **Node Configuration:** Same as current (2× t3.small Spot)?
   - Or different for each environment?

4. **MongoDB Configuration:** Same 1-member ReplicaSet?
   - Or test 3-member in one environment?

5. **VPC Endpoint Costs:** Environment 2 will cost ~$0.12/hour for endpoints
   - Acceptable for learning?

6. **Naming Convention:** Confirm naming pattern
   - Suggestion: `eks-dev-hybrid-vpc`, `eks-dev-private-vpc`
   - Cluster: `eks-dev-hybrid`, `eks-dev-private`

---

## Status

**Current State:** Documented, awaiting approval and detailed planning

**Next Steps:**
1. User will ask to "think and propose" the two VPC and EKS architectures
2. I will provide detailed architecture diagrams and configurations
3. User will approve
4. Implementation will begin

**No action taken yet - waiting for user's next request.**
