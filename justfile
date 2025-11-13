set shell := ["bash","-cu"]
set dotenv-load := true
set dotenv-filename := "scripts/mongo-eks.env"

# KISS repo helpers (non-destructive)

plan:
    @set -euo pipefail; \
    if [ -f docs/TASKS.md ]; then sed -n '1,120p' docs/TASKS.md; else echo "No docs/TASKS.md yet"; fi

apply:
    @echo "Review Terraform/Nextflow changes first; no auto-apply here"

test:
    tests/smoke.sh

docs:
    @set -euo pipefail; \
    if [ -f README.md ]; then sed -n '1,80p' README.md; fi; \
    if [ -f docs/TASKS.md ]; then echo; echo '--- docs/TASKS.md ---'; sed -n '1,120p' docs/TASKS.md; fi

next:
    @set -euo pipefail; \
    if [ -f issues.md ]; then rg -n "^(TODO|DOING|DONE)" -n issues.md || sed -n '1,120p' issues.md; else echo "No issues.md yet"; fi

env:
    @set -euo pipefail; \
    echo "ENV=${ENV:-unset}"; \
    echo "OS_VERSION=${OS_VERSION:-unset}"; \
    echo "NXF_VER=${NXF_VER:-unset}"; \
    echo "NXF_OFFLINE=${NXF_OFFLINE:-unset}"; \
    echo "AWS_DEFAULT_PROFILE=${AWS_DEFAULT_PROFILE:-unset}"; \
    echo "(Secrets redacted. Load with 'source ~/.env' but never commit.)"

# AWS helpers (guarded for PROD)
awsi:
    AWS_PAGER= aws sts get-caller-identity | jq -r '"\(.Account) \(.Arn)"'

aws +ARGS:
    scripts/awsg {{ARGS}}
eks_endpoints_create:
    scripts/eks_endpoints.sh create

eks_endpoints_list:
    scripts/eks_endpoints.sh list

eks_endpoints_delete:
    scripts/eks_endpoints.sh delete

eks_config:
    scripts/eks_cluster.sh config

eks_create:
    eksctl create cluster -f eksctl-mongo-lab.yaml

eks_delete:
    eksctl delete cluster -f eksctl-mongo-lab.yaml --wait

eks_status:
    eksctl get cluster --name mongo-eks-lab --region ap-southeast-1

eks_nodes:
    eksctl get nodegroup --cluster mongo-eks-lab --region ap-southeast-1

eks_kubeconfig:
    aws eks update-kubeconfig --name mongo-eks-lab --region ap-southeast-1

eks_old_create:
    scripts/eks_cluster.sh create

eks_old_delete:
    scripts/eks_cluster.sh delete

eks_bastion_create:
    scripts/eks_bastion.sh create

eks_bastion_delete:
    scripts/eks_bastion.sh delete

ecr_mirror:
    scripts/ecr_mirror.sh

destroy:
    scripts/teardown.sh
