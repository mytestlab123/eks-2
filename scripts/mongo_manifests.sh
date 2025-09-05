#!/usr/bin/env bash
set -euo pipefail

: "${AWS_PROFILE:?set in scripts/mongo-eks.env}"
: "${AWS_REGION:?set in scripts/mongo-eks.env}"
: "${ECR_REPO_PREFIX:?set in scripts/mongo-eks.env}"
: "${S3_BACKUP_BUCKET:?set in scripts/mongo-eks.env}"

OUT=/tmp/mongo-manifests
mkdir -p "$OUT"

if [[ -z "${OPERATOR_TAG:-}" || "${OPERATOR_TAG}" == "" ]]; then
  OPERATOR_TAG=v0.9.2
fi

# Fetch CRD and operator manifest (new unified operator)
fetch() { # url dest
  local url=$1 dest=$2
  http=$(curl -sSLo "$dest" -w '%{http_code}' "$url") || return 1
  [[ "$http" == "200" ]] || return 1
  [[ $(wc -c < "$dest") -gt 500 ]] || return 1
}

K8S_OPERATOR_VER=${K8S_OPERATOR_VER:-1.0.0}
fetch "https://raw.githubusercontent.com/mongodb/mongodb-kubernetes/${K8S_OPERATOR_VER}/public/crds.yaml" "$OUT/crds.yaml" || {
  echo "error: failed to fetch CRDs for ${K8S_OPERATOR_VER}" >&2; exit 1; }
fetch "https://raw.githubusercontent.com/mongodb/mongodb-kubernetes/${K8S_OPERATOR_VER}/public/mongodb-kubernetes.yaml" "$OUT/operator.yaml" || {
  echo "error: failed to fetch operator for ${K8S_OPERATOR_VER}" >&2; exit 1; }

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO_PREFIX}"

# Rewrite image(s) to ECR
sed -i "s|quay.io/mongodb/mongodb-kubernetes:[^\"]\+|${REGISTRY}/mongodb-kubernetes:1.0.0|g" "$OUT/operator.yaml"

# Sample MongoDBCommunity resource
cat > "$OUT/sample-mongodbcommunity.yaml" <<YAML
apiVersion: v1
kind: Secret
metadata:
  name: my-user-password
  namespace: mongodb
type: Opaque
stringData:
  password: ChangeMe123!
---
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: sample-mongo
  namespace: mongodb
spec:
  members: 1
  type: ReplicaSet
  version: "${MONGODB_VERSION:-7.0.12}"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
    - name: my-user
      db: admin
      passwordSecretRef:
        name: my-user-password
      roles:
        - db: admin
          name: clusterAdmin
  statefulSet:
    spec:
      template:
        spec:
          containers:
            - name: mongod
              image: ${REGISTRY}/mongodb-community-server:${MONGODB_VERSION:-7.0.12}
      volumeClaimTemplates:
        - metadata:
            name: data-volume
          spec:
            accessModes: ["ReadWriteOnce"]
            storageClassName: gp3
            resources:
              requests:
                storage: 10Gi
YAML

# Backup Job using IRSA-bound SA (to be created separately)
cat > "$OUT/backup-job.yaml" <<'YAML'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mongo-backup
  namespace: mongodb
  annotations:
    eks.amazonaws.com/role-arn: REPLACE_WITH_IRSA_ROLE
---
apiVersion: batch/v1
kind: Job
metadata:
  name: mongo-backup
  namespace: mongodb
spec:
  template:
    spec:
      serviceAccountName: mongo-backup
      restartPolicy: Never
      containers:
        - name: backup
          image: REPLACE_REGISTRY/mongodb-tools:7
          command: ["bash","-lc"]
          env:
            - name: S3_URI
              value: REPLACE_S3_URI
          args:
            - >-
              mongodump -u my-user -p "ChangeMe123!" --authenticationDatabase admin \
              --host sample-mongo-svc.mongodb.svc.cluster.local:27017 --archive=/tmp/backup.archive && \
              aws s3 cp /tmp/backup.archive "$S3_URI"
YAML

aws s3 sync "$OUT/" "${S3_BACKUP_BUCKET%/}/manifests/"
echo "Uploaded manifests to ${S3_BACKUP_BUCKET%/}/manifests/"
