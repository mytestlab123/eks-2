# EKS MongoDB Lab - Complete Documentation

> **Last Updated**: 2025-11-14  
> **Status**: Production-ready private EKS cluster setup with ECR image mirroring

---

## 📚 Documentation Index

### Quick Start
- [README.md](README.md) - Project overview and quick start
- [NEXT-SESSION.md](NEXT-SESSION.md) - Next task: Production deployment

### Setup Guides
- [PRIVATE-EKS-SETUP.md](PRIVATE-EKS-SETUP.md) - Private-only EKS cluster setup (RECOMMENDED)
- [DELETION-PLAN.md](DELETION-PLAN.md) - Complete cleanup procedures

### Operational Guides
- [AGENTS.md](AGENTS.md) - AI agent instructions and context
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues and solutions

### Configuration Files
- [private-cluster.yaml](private-cluster.yaml) - Private EKS cluster config
- [mongodb-private.yaml](mongodb-private.yaml) - MongoDB with ECR images
- [hybrid-cluster.yaml](hybrid-cluster.yaml) - Hybrid VPC cluster config (reference)

### Scripts
- [deploy-private-complete.sh](deploy-private-complete.sh) - One-command deployment
- [cleanup-private.sh](cleanup-private.sh) - One-command cleanup

---

## 🎯 Architecture Overview

### Current Implementation: Private-Only EKS

```
┌─────────────────────────────────────────────────────────────┐
│ Cloud9 (stata-vpc: 10.0.0.0/16)                            │
│  └─ VPC Peering ──────────────────────┐                    │
└───────────────────────────────────────┼────────────────────┘
                                        │
┌───────────────────────────────────────┼────────────────────┐
│ Private EKS VPC (10.2.0.0/16)         │                    │
│                                       │                    │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Private Subnets (10.2.64.0/19, 10.2.96.0/19)       │  │
│  │                                                     │  │
│  │  ┌──────────────┐  ┌──────────────┐               │  │
│  │  │ EKS Node 1   │  │ EKS Node 2   │               │  │
│  │  │ t3.small     │  │ t3.small     │               │  │
│  │  └──────────────┘  └──────────────┘               │  │
│  │                                                     │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │ MongoDB Operator + MongoDB 7.0.12           │  │  │
│  │  │ Images from ECR (no internet access)        │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                            │
│  VPC Endpoints: S3, ECR-API, ECR-DKR, EC2, STS, Logs, SSM │
└────────────────────────────────────────────────────────────┘
```

**Key Features**:
- ✅ No internet access (no NAT Gateway)
- ✅ Private API endpoint only
- ✅ VPC peering for management access
- ✅ All images mirrored to ECR
- ✅ VPC endpoints for AWS services

---

## 🚀 Quick Commands

### Deploy Private Cluster
```bash
./deploy-private-complete.sh
```

### Cleanup Everything
```bash
./cleanup-private.sh
```

### Verify Deployment
```bash
kubectl get nodes
kubectl get mongodbcommunity,pods,pvc
kubectl exec mongodb-test-0 -c mongod -- mongosh --eval "db.version()"
```

---

## 📊 Cost Analysis

| Component | Monthly Cost |
|-----------|--------------|
| EKS Control Plane | $73 |
| 2× t3.small nodes | $30 |
| EBS Storage (14GB) | $1.12 |
| VPC Endpoints (7) | $51.10 |
| ECR Storage (2GB) | $0.20 |
| **Total** | **~$155/month** |

---

## 🔧 AWS CLI & MCP Integration

### Using AWS CLI MCP Server

All AWS operations use the **aws-cli-mcp** server for:
- EKS cluster management
- VPC configuration
- ECR operations
- IAM role management

### Command Pattern
```bash
# Via MCP tool: call_aws
aws eks describe-cluster --name dev-private-cluster --region ap-southeast-1

# Via MCP tool: suggest_aws_commands (when uncertain)
# Query: "List all EKS clusters in ap-southeast-1"
```

### Best Practices
1. **Always use MCP tools** instead of direct CLI commands
2. **Use `call_aws`** when you know the exact command
3. **Use `suggest_aws_commands`** when exploring options
4. **Check AWS Knowledge Base** for troubleshooting

---

## 📖 Agentic Workflow

### Session Pattern
1. **Context Loading**: Review AGENTS.md and previous session summary
2. **Task Planning**: Break down into atomic steps
3. **Execution**: Use MCP tools for all AWS operations
4. **Validation**: Verify each step before proceeding
5. **Documentation**: Update docs and create PR

### Git Workflow
1. Create feature branch: `feat/<task-name>`
2. Make changes and commit
3. Push and create PR
4. Wait for approval
5. Merge and cleanup

### Tools Priority
1. **AWS CLI MCP** - All AWS operations
2. **kubectl** - Kubernetes operations
3. **eksctl** - EKS cluster lifecycle
4. **docker** - Image operations
5. **gh** - GitHub operations

---

## 🎓 Learning Resources

### AWS Documentation
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [VPC Endpoints Guide](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [ECR User Guide](https://docs.aws.amazon.com/ecr/latest/userguide/)

### MongoDB on Kubernetes
- [MongoDB Operator Docs](https://docs.mongodb.com/kubernetes-operator/)
- [Production Notes](https://docs.mongodb.com/kubernetes-operator/stable/tutorial/plan-k8s-operator-architecture/)

### MCP Resources
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [AWS CLI MCP Server](https://github.com/aws/aws-cli-mcp)

---

## 🔄 Version History

### v3.0 (2025-11-14) - Private-Only Architecture
- Private EKS cluster with VPC peering
- ECR image mirroring (5 repositories)
- One-command deployment and cleanup
- Complete documentation

### v2.0 (2025-11-13) - Automated Deployment
- Consolidated documentation (12 → 3 files)
- Automated deployment script (100% success rate)
- 81% faster deployment (18 min vs 95 min)

### v1.0 (2025-09-05) - Initial Setup
- Basic EKS cluster with MongoDB
- Manual deployment steps
- Troubleshooting documentation

---

## 📝 Next Steps

See [NEXT-SESSION.md](NEXT-SESSION.md) for the next task:
- Production deployment in "prod" AWS profile
- 3-AZ high availability setup
- Automated backups and monitoring
- Security hardening

---

## 🤝 Contributing

Follow the agentic workflow:
1. Review [AGENTS.md](AGENTS.md) for AI agent instructions
2. Create feature branch
3. Use MCP tools for all operations
4. Update documentation
5. Create PR with detailed description

---

## 📞 Support

- **Issues**: Create GitHub issue
- **Questions**: Check [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **Updates**: Follow commit history

---

**Built with**: AWS EKS, MongoDB Operator, eksctl, kubectl, AWS CLI MCP
