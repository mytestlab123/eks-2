# Next Session: Private-Only EKS Cluster Testing in "dev" Profile

**Status**: ✅ APPROVED - Branch created: `feat/dev-private-test`  
**Started**: 2025-11-14 18:32 SGT

## Objective
Deploy and test private-only EKS cluster in "dev" AWS profile with a new non-internet VPC to validate the architecture before production deployment.

## Prerequisites
- ECR repositories with MongoDB images (already exists)
- Access to "dev" AWS profile
- VPC peering from Cloud9 (stata-vpc) for cluster access

## Tasks

### 1. Development VPC Setup
- **CIDR**: 10.3.0.0/16 (new VPC, separate from previous 10.2.0.0/16)
- **Subnets**: Private only across 2 AZs (ap-southeast-1a/b)
- **VPC Endpoints**: S3, ECR, EKS, EC2, STS, CloudWatch, SSM
- **No NAT Gateway**: Zero internet access
- **VPC Peering**: Connect to stata-vpc (10.0.0.0/16) for management

### 2. EKS Cluster Configuration
- **Name**: `dev-private-test-cluster`
- **Version**: 1.33
- **Nodes**: 2× t3.small (dev sizing)
- **API Endpoint**: Private only
- **Logging**: Control plane logs enabled
- **Profile**: dev (not prod)

### 3. MongoDB Development Setup
- **Topology**: 1-member ReplicaSet (dev/test)
- **Storage**: 5Gi data + 2Gi logs (gp2)
- **Images**: From ECR (already mirrored)
- **Testing**: Connection, backup, restore

### 4. Testing & Validation
- **Network Isolation**: Verify no internet access
- **VPC Peering**: Test kubectl access from Cloud9
- **MongoDB**: Deploy and test operator
- **Backup**: Test S3 backup functionality
- **Performance**: Basic load testing

### 5. Documentation
- **Setup Guide**: Document deployment steps
- **Test Results**: Record validation outcomes
- **Lessons Learned**: Note any issues or improvements
- **Production Readiness**: Checklist for prod deployment
## Files to Create

### Configuration Files
- `dev-private-test-cluster.yaml` - eksctl config for dev testing
- `mongodb-dev-test.yaml` - 1-member ReplicaSet for testing
- `test-validation.sh` - Automated validation script

### Scripts
- `deploy-dev-test.sh` - Full dev cluster deployment
- `test-network-isolation.sh` - Verify no internet access
- `test-mongodb.sh` - MongoDB functionality tests
- `cleanup-dev-test.sh` - Dev cluster cleanup

### Documentation
- `DEV-TEST-RESULTS.md` - Test results and validation
- `PRODUCTION-READINESS.md` - Checklist for prod deployment

## Success Criteria

- [ ] Cluster deployed in dev profile (not prod)
- [ ] New VPC (10.3.0.0/16) with no internet access
- [ ] VPC peering working from Cloud9
- [ ] MongoDB operator deployed with ECR images
- [ ] 1-member MongoDB running successfully
- [ ] Network isolation verified (no internet)
- [ ] Backup to S3 tested
- [ ] All tests documented
- [ ] Production readiness checklist complete

## Estimated Time
- Setup: 20-30 minutes
- Testing: 30-40 minutes
- Documentation: 20 minutes
- **Total**: ~1.5 hours

## Cost Estimate (Monthly)

| Resource | Quantity | Unit Cost | Total |
|----------|----------|-----------|-------|
| EKS Control Plane | 1 | $73 | $73 |
| t3.small nodes | 2 | $15 | $30 |
| EBS gp2 (14GB) | 1 | $1.12 | $1.12 |
| VPC Endpoints | 7 | $7.30 | $51 |
| CloudWatch Logs | ~2GB | $1 | $1 |
| **Total** | | | **~$156/month** |

## References
- [PRIVATE-EKS-SETUP.md](PRIVATE-EKS-SETUP.md) - Previous private cluster setup
- [DOCS.md](DOCS.md) - Architecture and patterns

## Notes
- This is a TEST deployment in dev profile
- Use existing ECR images (no need to re-mirror)
- Focus on validation and testing
- Document everything for production deployment
- After successful testing, plan production deployment in prod profile
