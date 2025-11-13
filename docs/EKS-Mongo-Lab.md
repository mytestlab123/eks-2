# EKS MongoDB Lab (DEV) — Plan & Context

## Inputs (from Amit)
- Env: single DEV
- Region: `ap-southeast-1`
- VPC: `vpc-035eb12babd9ca798` (stata-vpc) - default for labs
- Cluster: private-only API endpoint + SSM bastion
- Nodes: 2x Spot (t3.small)
- Backup: S3 OK
- Tooling: prefer `eksctl` + `kubectl` + `just` (no Terraform)

## VPC Policy
- **Default:** Use `stata-vpc` (vpc-035eb12babd9ca798) for all labs
- **Restricted:** TRUST VPC (vpc-06814ea8b57b55627) requires explicit approval
  - Private subnets only, limited IPs
  - See `docs/VPC-POLICY.md` for details

## Current AWS Context (checked)
- Using `AWS_PROFILE=dev`.
- Verified VPC exists and is non-default.
- Private subnets discovered:
  - `subnet-0791f110f66224a90` (ap-southeast-1a)
  - `subnet-07fdd948aef38d72f` (ap-southeast-1b)
  - `subnet-0bdb0912b1c5850a7` (ap-southeast-1c)
- NAT Gateway: not present in this VPC.
- Route tables for these subnets have no `0.0.0.0/0` egress; a Gateway Endpoint route exists (likely S3).

2025‑11‑13 — S3 Backup Testing SUCCESS ✅
- **S3 Bucket:** mongo-eks-lab-backup-273828039634
- **IAM Role:** mongo-eks-lab-backup-role (IRSA)
- **Backup Method:** Kubernetes Job with mongodump
- **Backup Size:** 886 bytes (compressed)
- **Databases Backed Up:** ekslab, testdb
- **Backup Duration:** 54 seconds
- **Restore Test:** ✅ Successfully restored 4 documents with indexes
- **Restore Duration:** 52 seconds

**Files:**
- Backup manifest: `/tmp/mongodb-backup-simple.yaml`
- Restore manifest: `/tmp/mongodb-restore-job.yaml`
- Documentation: `docs/MONGODB-BACKUP.md`

2025‑11‑13 — MongoDB Deployment SUCCESS ✅
- **Operator:** MongoDB Community Operator v0.9.0+
- **MongoDB Version:** 7.0.12
- **Deployment:** 1-member ReplicaSet (mongodb-lab)
- **Storage:** 5Gi data volume + 2Gi logs volume (EBS gp2)
- **Pod Status:** 2/2 containers ready (mongod + mongodb-agent)
- **Phase:** Running

**RBAC Fix Required:**
- ServiceAccount `mongodb-database` needs permissions: secrets, configmaps, pods (get/list/watch/patch)
- Created Role and RoleBinding to grant required permissions

**User Configuration:**
- Admin user (from operator): Limited roles (clusterAdmin, userAdminAnyDatabase)
- Created `labuser`: Full read/write access (readWriteAnyDatabase, dbAdminAnyDatabase)
- Password: LabPass123! (for lab only)

**Tested Operations:**
- ✅ Insert documents
- ✅ Query with filters
- ✅ Update documents
- ✅ Aggregation pipelines
- ✅ Index creation
- ✅ Database statistics

**Connection String:**
```
mongodb://labuser:LabPass123!@mongodb-lab-0.mongodb-lab-svc.default.svc.cluster.local:27017/?authSource=admin
```

2025‑11‑13 — Cluster Testing ✅
- **Pods:** Deployed 2× nginx pods, both running on separate nodes
- **Networking:** Pod-to-pod communication works, Service DNS resolution works
- **LoadBalancer:** AWS ELB provisioned successfully
- **Storage:** EBS CSI driver works, PVC bound and writable
- **Result:** All core functionality verified, ready for MongoDB deployment

2025‑11‑13 — Cluster Creation SUCCESS ✅
- **VPC:** stata-vpc (vpc-035eb12babd9ca798)
- **Version:** EKS 1.33 (latest)
- **Subnets:** Public subnets (1a, 1b) with auto-assign public IP enabled
- **Nodes:** 2× t3.small Spot instances (Ready)
- **API:** Public endpoint (publicAccess=true, privateAccess=false)
- **Addons:** vpc-cni, coredns, kube-proxy, ebs-csi-driver, metrics-server
- **Time:** 15 minutes total
- **Key Fix:** Used public subnets instead of private (no NAT/VPC endpoints needed)

2025‑11‑12 — Cluster Creation Attempt #1 (FAILED)
- **VPC:** stata-vpc (vpc-035eb12babd9ca798)
- **Version:** EKS 1.33 (latest)
- **Issue:** Configured `privateCluster: enabled` but stata-vpc has no VPC endpoints
- **Result:** Nodes failed to join - "NodeCreationFailure: Instances failed to join the kubernetes cluster"
- **Root cause:** Private subnets with no NAT + private API = nodes can't reach EKS/ECR/EC2 APIs
- **Fix:** Removed `privateCluster: enabled` to allow public API access (nodes in private subnets can reach public endpoints via NAT/IGW)
- **Lesson:** Private EKS clusters require either VPC endpoints OR NAT Gateway for node communication

2025‑11‑12 — VPC Policy Update
- **Changed VPC:** Now using `stata-vpc` (vpc-035eb12babd9ca798) as default for labs
- Previous TRUST VPC (vpc-06814ea8b57b55627) is private-only with limited IPs
- Policy: Always use stata-vpc unless explicit approval given for TRUST VPC
- stata-vpc has public + private subnets with 4000+ available IPs per subnet
- Updated: `eksctl-mongo-lab.yaml`, `scripts/mongo-eks.env`, created `docs/VPC-POLICY.md`

2025‑11‑12 — VPC Endpoints Created
- Created Interface Endpoints in AZ 1a and 1c for: `ecr.api`, `ecr.dkr`, `ec2`, `eks`, `logs`, `sts`.
- All endpoints in "pending" state (will become "available" in ~5 minutes).
- Security group `vpce-mongo-eks-sg` allows HTTPS (443) from VPC CIDR.
- SSM endpoints (ssm, ssmmessages, ec2messages) already existed and are available.
- Ready to proceed with cluster creation once endpoints are "available".

2025‑09‑05 — Session Outcome
- Control plane created: `mongo-eks-lab` ACTIVE, v1.29 (private endpoint only).
- No worker nodes running; nodegroup creation failed due to missing Interface Endpoints in AZ 1a/1c and tight /28 IPs in 1b.
- VPC endpoints currently exist in 1b only (ecr.api, ecr.dkr, ec2, eks, logs, sts). 1b has 0 free IPs.
- Bastion (SSM) created and verified; offline flow via S3 for kubectl/kubeconfig/manifests prepared.
- ECR repos created for operator/images; manifests uploaded to `s3://trust-dev-team2/mongodb/`.

Why Nodes Failed
- With private-only API and no NAT, nodes must resolve/pull via Interface Endpoints in their AZ.
- Endpoints exist only in 1b (zero free IPs). Attempts to attach 1a/1c were blocked by an Org SCP (explicit deny on `ec2:ModifyVpcEndpoint`).

Next Session — Unblock Then Proceed
- Option 1 (preferred): add Interface Endpoints in AZ 1a or 1c (networking-admin action).
  - Services: `ecr.api`, `ecr.dkr`, `eks`, `ec2`, `logs`, `sts`.
  - Attach to one of: `subnet-0791f110f66224a90` (1a, 7 IPs free) or `subnet-0bdb0912b1c5850a7` (1c, 7 IPs free).
  - Then: create 1‑node SPOT nodegroup in that AZ, deploy operator + sample, run S3 backup job.
- Option 2 (fallback fast): temporary NAT + route 1a/1c to NAT; run lab; delete NAT same day.

One‑Liner To Resume (after endpoints/NAT ready)
- "Continue with the EKS MongoDB setup"
- I will: create nodegroup (1 node), apply CRDs/operator/sample, run backup job to S3, and tear down per TTL.
## Design
- EKS: `mongo-eks-lab`, version 1.29, private endpoint only.
- Node group: 2x Spot `t3.small`, private networking, gp3 volumes.
- Add-ons: EBS CSI.
- Access: SSM bastion (t3.micro) in a private subnet.
- Mongo: MongoDB Community Operator + 1-member ReplicaSet for learning.
- Backup: simple Job/pod writes archive to S3.
- Cost: run a few hours and delete cluster + bastion (and any temporary egress infra).

## Network Options (choose)
- Option A — Temporary NAT (fastest):
  - Create one Internet Gateway, one small public subnet, one NAT Gateway, and add `0.0.0.0/0` via NAT to the three private subnets.
  - Pros: minimal changes to operator manifests; pull images from the internet; SSM works without extra endpoints.
  - Cons: NAT hourly cost while running.

- Option B — Endpoint-only (no NAT):
  - Create Interface Endpoints: `ssm`, `ssmmessages`, `ec2messages`, `ecr.api`, `ecr.dkr`, `logs`, `sts` (and keep S3 Gateway endpoint).
  - Mirror required Mongo/operator images to private ECR and patch manifests.
  - Pros: no internet egress from VPC.
  - Cons: more setup time; image mirroring required.

Recommendation: Option A (Temporary NAT) for speed. Delete all added egress infra in cleanup.

Selected: Option B (Endpoint-only, no NAT) — per user input on 2025-09-05. Backup bucket: `s3://trust-dev-team2/mongodb/`. TTL target: 2–4 hours.

## Variables
- `AWS_PROFILE=dev`
- `AWS_REGION=ap-southeast-1`
- `VPC_ID=vpc-06814ea8b57b55627`
- `CLUSTER_NAME=mongo-eks-lab`
- `SUBNETS_PRIVATE=(1a 1b)` → pick two from the list above
- `S3_BACKUP_BUCKET=<provide>` (e.g., `s3://trust-dev-team/eks-mongo-lab`)

## High-Level Steps
1) If Option A: create IGW + public subnet + NAT GW; update private RTs for egress.
   If Option B (selected): create required VPC Interface Endpoints; mirror public images into private ECR; use S3 gateway for backups.
2) Create EKS with eksctl (private API only, OIDC on, nodegroup 2x Spot).
3) Create SSM bastion (t3.micro) with role `AmazonSSMManagedInstanceCore` + `AmazonEKSReadOnlyAccess`.
4) Install EBS CSI add-on (IRSA role via eksctl) and verify PVC provisioning.
5) Deploy MongoDB Operator (pinned tag) and sample `MongoDBCommunity` CR (1 member).
6) Run backup Job to write `mongodump` archive to `S3_BACKUP_BUCKET`.
7) Validate basic ops (connect, insert, dump/restore).
8) Cleanup: delete cluster, bastion, and any lab‑tagged endpoints/roles/repos.

2025‑09‑05 — Cleanup Performed
- Deleted: EKS cluster `mongo-eks-lab` (and nodegroups), bastion instances, ECR repos under `eks-mongo-lab/*`, IAM roles (bastion/node/ebs/backup) and backup policy, OIDC provider (cluster‑scoped).
- Left in place: existing untagged Interface VPC Endpoints in 1b (ecr.api/ecr.dkr/eks/ec2/logs/sts/ssm/ssmmessages/ec2messages). These may predate this session and are shared; do not remove without networking confirmation.

Resume Checklist (next session)
- Ensure Interface Endpoints exist in 1a or 1c (or provide a temporary NAT).
- I will: recreate cluster/nodegroup → deploy operator/sample → run S3 backup → tear down.

## Next Actions (by Codex)
- Generate create/delete scripts for required endpoints (B): `ecr.api`, `ecr.dkr`, `ec2`, `eks`, `logs`, `sts` (S3 Gateway already present).
- Identify and mirror required images to ECR (operator, agent, readinessprobe, community server, tools).
- Create eksctl config using two private subnets (default: 1a + 1b) and private API.
- Add `just` targets for create → kubeconfig → EBS CSI → operator → sample → backup → delete.

## Notes
- Keep everything tagged with `Project=mongo-eks-lab` + TTL tag.
- All commands will use `AWS_PROFILE=dev` and `AWS_REGION=ap-southeast-1` explicitly.
