# Runbook — Repo Helpers (KISS)

## Environment Switch
- ENV: `dev` (internet ok) or `prod` (offline-first).
- OS: `Amazon Linux 2023`.
- Load env (non-logging): `source ~/.env` (never commit secrets).

## Quick Commands
- `just env` : print key vars (redacted).
- `just plan`: show this runbook header.
- `just test`: run smoke checks (no destructive ops).
- `just docs`: preview README + this file.
- `just next`: show TODO/DOING/DONE from `issues.md`.
- `just awsi`: print AWS identity (Account, Arn).
- `just aws …`: run `aws` with guard; prompts on PROD (💀🛑).

## Tools (suggest)
- Install faster CLIs (DEV hosts): `rg` (ripgrep), `fd`, `eza`, `bat`.
- Amazon Linux 2023 (DEV):
  - `sudo dnf install -y ripgrep fd-find`  # rg, fd
  - `sudo dnf install -y eza` || echo "install eza via cargo/nix if missing"
  - `sudo dnf install -y bat` || echo "fallback to cat"

## Notes
- Logs/tmp: use absolute paths under `/tmp`.
- Terraform: review before apply. Prefer `plan` + manual review.
- Nextflow (PROD): offline profiles; Nexus/ECR/Quay only; no Docker Hub pulls.
- SSM patching: default `RebootOption=NoReboot`.

### AWS Guard Usage
- Shell function (optional): `source scripts/aws-guard.sh` to get `awsg` & `awsi` in your session.
- Wrapper script (non-interactive friendly): `scripts/awsg <service> <op> [args…]`.
- Via `just`:
  - `just awsi`
  - `just aws ec2 describe-instances --region ap-southeast-1`

## Next Actions (edit in issues.md)
- For Mongo EKS lab:
  - Networking to add Interface VPC Endpoints in 1a or 1c for: `ecr.api`, `ecr.dkr`, `eks`, `ec2`, `logs`, `sts` (S3 gateway exists).
  - Or approve a temporary NAT path for a 2–4h lab window.
  - Then trigger: "Continue with the EKS MongoDB setup".
