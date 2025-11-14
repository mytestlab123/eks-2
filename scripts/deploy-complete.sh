#!/usr/bin/env bash
set -euo pipefail

echo "=== EKS MongoDB Lab - Complete Deployment ==="
echo "This script deploys everything with all fixes pre-applied"
echo ""

cd "$(dirname "$0")/.."
source scripts/mongo-eks.env

# Verify prerequisites
echo "Checking prerequisites..."
command -v eksctl >/dev/null || { echo "❌ eksctl not found"; exit 1; }
command -v kubectl >/dev/null || { echo "❌ kubectl not found"; exit 1; }
command -v aws >/dev/null || { echo "❌ aws cli not found"; exit 1; }
echo "✅ Prerequisites OK"

# Step 1: Verify and configure subnets
echo ""
echo "Step 1: Configuring subnets..."
for SUBNET in ${SUBNET_A} ${SUBNET_B}; do
  echo "  Enabling auto-assign public IP on ${SUBNET}..."
  aws ec2 modify-subnet-attribute \
    --subnet-id ${SUBNET} \
    --map-public-ip-on-launch \
    --region ${AWS_REGION}
done
echo "✅ Subnets configured"

# Step 2: Create EKS cluster
echo ""
echo "Step 2: Creating EKS cluster (15-20 min)..."
if eksctl get cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} >/dev/null 2>&1; then
  echo "⚠️  Cluster already exists, skipping creation"
else
  eksctl create cluster -f eksctl-mongo-lab.yaml
  echo "✅ EKS cluster created"
fi

# Step 3: Update kubeconfig
echo ""
echo "Step 3: Updating kubeconfig..."
aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${AWS_REGION}
kubectl get nodes
echo "✅ Kubeconfig updated"

# Step 4: Create MongoDB RBAC
echo ""
echo "Step 4: Creating MongoDB RBAC..."
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: mongodb-database
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: mongodb-database
rules:
- apiGroups: [""]
  resources: ["secrets", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch", "patch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: mongodb-database
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: mongodb-database
subjects:
- kind: ServiceAccount
  name: mongodb-database
EOF
echo "✅ MongoDB RBAC created"

# Step 5: Deploy MongoDB Operator
echo ""
echo "Step 5: Deploying MongoDB Operator..."
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/manager/manager.yaml

echo "  Waiting for operator..."
kubectl wait --for=condition=ready pod -l name=mongodb-kubernetes-operator --timeout=120s
echo "✅ MongoDB Operator deployed"

# Step 6: Create MongoDB admin password secret
echo ""
echo "Step 6: Creating MongoDB secrets..."
kubectl create secret generic mongodb-admin-password \
  --from-literal=password="MongoPass123!" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Secrets created"

# Step 7: Deploy MongoDB ReplicaSet
echo ""
echo "Step 7: Deploying MongoDB ReplicaSet..."
cat <<EOF | kubectl apply -f -
apiVersion: mongodbcommunity.mongodb.com/v1
kind: MongoDBCommunity
metadata:
  name: mongodb-lab
spec:
  members: 1
  type: ReplicaSet
  version: "7.0.12"
  security:
    authentication:
      modes: ["SCRAM"]
  users:
    - name: admin
      db: admin
      passwordSecretRef:
        name: mongodb-admin-password
      roles:
        - name: clusterAdmin
          db: admin
        - name: userAdminAnyDatabase
          db: admin
      scramCredentialsSecretName: mongodb-admin-scram
  additionalMongodConfig:
    storage.wiredTiger.engineConfig.journalCompressor: snappy
  statefulSet:
    spec:
      volumeClaimTemplates:
        - metadata:
            name: data-volume
          spec:
            accessModes: ["ReadWriteOnce"]
            storageClassName: gp2
            resources:
              requests:
                storage: 5Gi
        - metadata:
            name: logs-volume
          spec:
            accessModes: ["ReadWriteOnce"]
            storageClassName: gp2
            resources:
              requests:
                storage: 2Gi
EOF

echo "  Waiting for MongoDB pod (2-3 min)..."
kubectl wait --for=condition=ready pod mongodb-lab-0 --timeout=300s
echo "✅ MongoDB deployed"

# Step 8: Create application user
echo ""
echo "Step 8: Creating application user..."
sleep 10
PASSWORD=$(kubectl get secret mongodb-admin-password -o jsonpath='{.data.password}' | base64 -d)
kubectl exec mongodb-lab-0 -c mongod -- mongosh \
  "mongodb://admin:${PASSWORD}@localhost:27017/admin?authSource=admin&directConnection=true" \
  --quiet --eval "
    db.createUser({
      user: 'labuser',
      pwd: 'LabPass123!',
      roles: [
        { role: 'readWriteAnyDatabase', db: 'admin' },
        { role: 'dbAdminAnyDatabase', db: 'admin' }
      ]
    });
    print('✅ User labuser created');
  " || echo "⚠️  User may already exist"

# Step 9: Test MongoDB
echo ""
echo "Step 9: Testing MongoDB..."
kubectl exec mongodb-lab-0 -c mongod -- mongosh \
  "mongodb://labuser:LabPass123!@localhost:27017/ekslab?authSource=admin&directConnection=true" \
  --quiet --eval "
    db.test.insertOne({message: 'Deployment test', timestamp: new Date()});
    print('✅ MongoDB is working!');
    print('Document count:', db.test.countDocuments({}));
  "

# Step 10: Setup S3 backup
echo ""
echo "Step 10: Setting up S3 backup..."
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET="mongo-eks-lab-backup-${ACCOUNT_ID}"

# Create S3 bucket
aws s3 mb s3://${BUCKET} --region ${AWS_REGION} 2>/dev/null || echo "  Bucket exists"

# Create IAM role for backup
OIDC_PROVIDER=$(aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} \
  --query "cluster.identity.oidc.issuer" --output text | sed -e "s/^https:\/\///")

cat > /tmp/trust-policy.json <<EOFTP
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/${OIDC_PROVIDER}"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "${OIDC_PROVIDER}:sub": "system:serviceaccount:default:mongodb-backup",
        "${OIDC_PROVIDER}:aud": "sts.amazonaws.com"
      }
    }
  }]
}
EOFTP

aws iam create-role \
  --role-name mongo-eks-lab-backup-role \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --tags Key=Project,Value=mongo-eks-lab 2>/dev/null || echo "  Role exists"

cat > /tmp/s3-policy.json <<EOFSP
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:GetObject", "s3:ListBucket"],
    "Resource": [
      "arn:aws:s3:::${BUCKET}",
      "arn:aws:s3:::${BUCKET}/*"
    ]
  }]
}
EOFSP

aws iam put-role-policy \
  --role-name mongo-eks-lab-backup-role \
  --policy-name S3BackupAccess \
  --policy-document file:///tmp/s3-policy.json

# Create ServiceAccount
kubectl create serviceaccount mongodb-backup \
  --dry-run=client -o yaml | kubectl apply -f -
kubectl annotate serviceaccount mongodb-backup \
  eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/mongo-eks-lab-backup-role \
  --overwrite

echo "✅ S3 backup configured"

# Step 11: Run test backup
echo ""
echo "Step 11: Running test backup..."
cat <<EOFBACKUP | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: mongodb-backup-test
spec:
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      serviceAccountName: mongodb-backup
      restartPolicy: Never
      containers:
      - name: backup
        image: mongo:7.0.12
        command: ["/bin/bash", "-c"]
        args:
        - |
          apt-get update -qq && apt-get install -y -qq awscli
          TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
          FILE="mongodb-\${TIMESTAMP}.gz"
          mongodump --uri="mongodb://labuser:LabPass123!@mongodb-lab-0.mongodb-lab-svc:27017/?authSource=admin" \
            --db=ekslab --gzip --archive=/tmp/ekslab.gz
          tar -czf /tmp/\${FILE} -C /tmp ekslab.gz
          aws s3 cp /tmp/\${FILE} s3://${BUCKET}/backups/\${FILE}
          echo "✅ Backup complete: \${FILE}"
        resources:
          requests: {cpu: 100m, memory: 256Mi}
EOFBACKUP

echo "  Waiting for backup job..."
sleep 30
kubectl wait --for=condition=complete job/mongodb-backup-test --timeout=120s
echo "✅ Test backup completed"

# Summary
echo ""
echo "=== Deployment Complete ==="
echo ""
echo "Cluster: ${CLUSTER_NAME}"
echo "MongoDB: mongodb-lab-0 (7.0.12)"
echo "User: labuser / LabPass123!"
echo "S3 Bucket: ${BUCKET}"
echo ""
echo "Connection string:"
echo "mongodb://labuser:LabPass123!@mongodb-lab-0.mongodb-lab-svc:27017/?authSource=admin"
echo ""
echo "Next steps:"
echo "1. kubectl get pods"
echo "2. kubectl exec -it mongodb-lab-0 -c mongod -- mongosh 'mongodb://labuser:LabPass123!@localhost:27017/?authSource=admin'"
echo "3. See docs/MONGODB-USAGE.md for more examples"
echo ""
echo "To cleanup: ./scripts/cleanup-all.sh"
