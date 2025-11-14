#!/bin/bash
set -e

echo "=== Deploying Hybrid VPC EKS Cluster ==="
echo "Start: $(date)"

# Create cluster
eksctl create cluster -f hybrid-cluster.yaml

# Wait for nodes
kubectl wait --for=condition=Ready nodes --all --timeout=300s

# Install MongoDB Operator
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/crd/bases/mongodbcommunity.mongodb.com_mongodbcommunity.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/service_account.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/rbac/role_binding.yaml
kubectl apply -f https://raw.githubusercontent.com/mongodb/mongodb-kubernetes-operator/master/config/manager/manager.yaml

# Wait for operator
kubectl wait --for=condition=Available deployment/mongodb-kubernetes-operator -n default --timeout=300s

echo "=== Cluster Ready ==="
echo "End: $(date)"
