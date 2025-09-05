# EKS MongoDB Lab (DEV) — Plan & Context

## Inputs (from Amit)
- Env: single DEV
- Region: `ap-southeast-1`
- VPC: `vpc-06814ea8b57b55627` (private)
- Cluster: private-only API endpoint + SSM bastion
- Nodes: 2x Spot (t3.small)
- Backup: S3 OK
- Tooling: prefer `eksctl` + `kubectl` + `just` (no Terraform)

## Current AWS Context (checked)
- Using `AWS_PROFILE=dev`.
- Verified VPC exists and is non-default.
- Private subnets discovered:
  - `subnet-0791f110f66224a90` (ap-southeast-1a)
  - `subnet-07fdd948aef38d72f` (ap-southeast-1b)
  - `subnet-0bdb0912b1c5850a7` (ap-southeast-1c)
- NAT Gateway: not present in this VPC.
- Route tables for these subnets have no `0.0.0.0/0` egress; a Gateway Endpoint route exists (likely S3).

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
