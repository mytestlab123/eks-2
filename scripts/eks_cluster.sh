#!/usr/bin/env bash
set -euo pipefail

: "${AWS_PROFILE:?set in scripts/mongo-eks.env}"
: "${AWS_REGION:?set in scripts/mongo-eks.env}"
: "${VPC_ID:?set in scripts/mongo-eks.env}"
: "${CLUSTER_NAME:?set in scripts/mongo-eks.env}"
: "${EKS_VERSION:?set in scripts/mongo-eks.env}"
: "${SUBNET_A:?set in scripts/mongo-eks.env}"
: "${SUBNET_B:?set in scripts/mongo-eks.env}"

CFG=/tmp/${CLUSTER_NAME}.yaml
ACTION=${1:-}

render() {
  cat >"$CFG" <<YAML
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: ${CLUSTER_NAME}
  region: ${AWS_REGION}
  version: "${EKS_VERSION}"
vpc:
  id: ${VPC_ID}
  subnets:
    private:
      ${AWS_REGION}a: { id: ${SUBNET_A} }
      ${AWS_REGION}b: { id: ${SUBNET_B} }
  clusterEndpoints:
    privateAccess: true
    publicAccess: false
iam:
  withOIDC: true
managedNodeGroups:
  - name: ng-spot-small
    instanceTypes: ["t3.small"]
    desiredCapacity: 2
    minSize: 0
    maxSize: 3
    spot: true
    privateNetworking: true
cloudWatch:
  clusterLogging:
    enableTypes: ["api","audit"]
YAML
  echo "wrote $CFG"
}

case "$ACTION" in
  config) render ;;
  create)
    render
    eksctl create cluster -f "$CFG"
    ;;
  delete)
    eksctl delete cluster -f "$CFG" || eksctl delete cluster --name "$CLUSTER_NAME" --region "$AWS_REGION" || true
    ;;
  *) echo "usage: $0 {config|create|delete}"; exit 2;;
esac

