# Next Session: Production Deployment in "prod" Profile

## Objective
Deploy private-only EKS cluster to production AWS profile with production-ready features.

## Prerequisites
- ECR repositories with MongoDB images (already exists)
- Access to "prod" AWS profile
- VPC peering or bastion setup for cluster access

## Tasks

### 1. Production VPC Setup
- **CIDR**: 10.3.0.0/16 (production range)
- **Subnets**: Private only across 3 AZs (ap-southeast-1a/b/c)
- **VPC Endpoints**: S3, ECR, EKS, EC2, STS, CloudWatch, SSM
- **No NAT Gateway**: Zero internet access

### 2. EKS Cluster Configuration
- **Name**: `prod-mongodb-cluster`
- **Version**: 1.33
- **Nodes**: 3× t3.medium (production sizing)
- **API Endpoint**: Private only
- **Logging**: All control plane logs enabled
- **Encryption**: Secrets encryption with KMS

### 3. MongoDB Production Setup
- **Topology**: 3-member ReplicaSet (high availability)
- **Storage**: 20Gi data + 5Gi logs per member (gp3)
- **Backup**: Automated S3 backups every 6 hours
- **Monitoring**: CloudWatch dashboards + alarms

### 4. Security Hardening
- **Network Policies**: Restrict pod-to-pod communication
- **Pod Security Standards**: Enforce restricted policy
- **Secrets Management**: AWS Secrets Manager integration
- **IRSA**: Fine-grained IAM roles for pods
- **Audit Logging**: CloudWatch Logs Insights queries

### 5. Operational Features
- **HPA**: Horizontal Pod Autoscaler for workloads
- **Cluster Autoscaler**: Node scaling based on demand
- **Metrics Server**: Resource metrics collection
- **Prometheus/Grafana**: Optional monitoring stack

## Files to Create

### Configuration Files
- `prod-cluster.yaml` - eksctl config for production
- `mongodb-prod.yaml` - 3-member ReplicaSet with production settings
- `backup-cronjob.yaml` - Automated backup schedule
- `network-policies.yaml` - Pod network restrictions
- `monitoring-dashboard.json` - CloudWatch dashboard

### Scripts
- `deploy-prod-complete.sh` - Full production deployment
- `backup-mongodb.sh` - Manual backup script
- `restore-mongodb.sh` - Restore from backup
- `cleanup-prod.sh` - Production cleanup (with safeguards)

### Documentation
- `PRODUCTION-SETUP.md` - Complete production guide
- `BACKUP-RESTORE.md` - Backup and restore procedures
- `MONITORING.md` - Monitoring and alerting guide
- `RUNBOOK.md` - Operational runbook

## Success Criteria

- [ ] Cluster deployed in prod profile
- [ ] 3-node MongoDB ReplicaSet running
- [ ] Automated backups working
- [ ] CloudWatch dashboards showing metrics
- [ ] Alarms configured and tested
- [ ] Network policies enforced
- [ ] Secrets encrypted with KMS
- [ ] Documentation complete
- [ ] Runbook validated

## Estimated Time
- Setup: 30-40 minutes
- Testing: 20-30 minutes
- Documentation: 30 minutes
- **Total**: ~2 hours

## Cost Estimate (Monthly)

| Resource | Quantity | Unit Cost | Total |
|----------|----------|-----------|-------|
| EKS Control Plane | 1 | $73 | $73 |
| t3.medium nodes | 3 | $30 | $90 |
| EBS gp3 (75GB) | 1 | $6 | $6 |
| VPC Endpoints | 7 | $7.30 | $51 |
| CloudWatch Logs | ~5GB | $2.50 | $2.50 |
| S3 Backups | ~10GB | $0.23 | $0.23 |
| **Total** | | | **~$223/month** |

## References
- [PRIVATE-EKS-SETUP.md](PRIVATE-EKS-SETUP.md) - Base private cluster setup
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [MongoDB Production Notes](https://docs.mongodb.com/kubernetes-operator/stable/tutorial/plan-k8s-operator-architecture/)

## Notes
- Use existing ECR images (no need to re-mirror)
- Consider multi-region backup replication
- Test disaster recovery procedures
- Document RTO/RPO requirements
