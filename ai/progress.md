# AI Progress Log

2025-09-05
- Added top-level repo helpers: `justfile`, `docs/TASKS.md`, `issues.md`, `tests/smoke.sh`.
- Secured env handling: added `.env.example` and gitignored `.env`.
- Suggested rotating any committed tokens and moving secrets to SSM.
- Verified DEV VPC `vpc-06814ea8b57b55627` (ap-southeast-1); found 3 private subnets and no NAT gateway; S3 gateway endpoint present.
- Captured EKS Mongo lab plan and options in `docs/EKS-Mongo-Lab.md`.
- Provision attempt: control plane up; nodegroups blocked by missing 1a/1c endpoints and /28 IPs in 1b.
- Added headless flow (S3 for kubectl/kubeconfig/manifests); documented unblock paths.
- Cleanup done: deleted EKS cluster, nodegroups, bastions, IAM roles/profiles/policies (lab), ECR repos, OIDC provider. Left untagged VPC endpoints in 1b untouched by design.
