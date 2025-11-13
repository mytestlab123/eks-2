#!/usr/bin/env bash
set -euo pipefail

: "${AWS_PROFILE:?set in scripts/mongo-eks.env}"
: "${AWS_REGION:?set in scripts/mongo-eks.env}"
: "${ECR_REPO_PREFIX:?set in scripts/mongo-eks.env}"

# Resolve operator tag if empty
if [[ -z "${OPERATOR_TAG:-}" || "${OPERATOR_TAG}" == "" ]]; then
  OPERATOR_TAG=$(curl -s https://api.github.com/repos/mongodb/mongodb-kubernetes-operator/releases/latest | jq -r .tag_name)
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

repos=(
  "${ECR_REPO_PREFIX}/mongodb-kubernetes-operator"
  "${ECR_REPO_PREFIX}/mongodb-kubernetes"
  "${ECR_REPO_PREFIX}/mongodb-agent"
  "${ECR_REPO_PREFIX}/mongodb-readinessprobe"
  "${ECR_REPO_PREFIX}/mongodb-community-server"
  "${ECR_REPO_PREFIX}/mongodb-tools"
)

for r in "${repos[@]}"; do
  aws ecr describe-repositories --repository-names "$r" >/dev/null 2>&1 || aws ecr create-repository --repository-name "$r" >/dev/null
done

aws ecr get-login-password | docker login --username AWS --password-stdin "$REGISTRY"

pull_push() {
  local src=$1 dst_repo=$2 dst_tag=$3
  local dst="${REGISTRY}/${dst_repo}:${dst_tag}"
  docker pull "$src"
  docker tag "$src" "$dst"
  docker push "$dst"
}

# Images and tags
# Try OPERATOR_TAG first; fallback to a known stable tag if missing on quay (legacy operator)
if docker pull "quay.io/mongodb/mongodb-kubernetes-operator:${OPERATOR_TAG}"; then
  pull_push "quay.io/mongodb/mongodb-kubernetes-operator:${OPERATOR_TAG}" "${ECR_REPO_PREFIX}/mongodb-kubernetes-operator" "${OPERATOR_TAG}"
else
  echo "warn: operator tag ${OPERATOR_TAG} not found on quay; falling back to v0.9.2"
  OPERATOR_TAG=v0.9.2
  pull_push "quay.io/mongodb/mongodb-kubernetes-operator:${OPERATOR_TAG}" "${ECR_REPO_PREFIX}/mongodb-kubernetes-operator" "${OPERATOR_TAG}"
fi
pull_push "quay.io/mongodb/mongodb-agent:2.0.0.0" "${ECR_REPO_PREFIX}/mongodb-agent" "2.0.0.0"
pull_push "quay.io/mongodb/mongodb-kubernetes-readinessprobe:1.0.11" "${ECR_REPO_PREFIX}/mongodb-readinessprobe" "1.0.11"
pull_push "mongodb/mongodb-community-server:${MONGODB_VERSION:-7.0.12}" "${ECR_REPO_PREFIX}/mongodb-community-server" "${MONGODB_VERSION:-7.0.12}"

# Tiny tools image with mongodump; fallback: mirror upstream tools image if present
# For speed, reuse mongodb community server for tools (contains mongosh), but mongodump may be absent.
# Prefer upstream mongo:7 tools image for mongodump.
pull_push "mongo:7" "${ECR_REPO_PREFIX}/mongodb-tools" "7"

# New unified operator (mongodb-kubernetes) v1.0.0
pull_push "quay.io/mongodb/mongodb-kubernetes:1.0.0" "${ECR_REPO_PREFIX}/mongodb-kubernetes" "1.0.0"

echo "Mirrored to $REGISTRY under ${ECR_REPO_PREFIX}/"
