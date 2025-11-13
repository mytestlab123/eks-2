# MongoDB on EKS - Usage Guide

## Cluster Information

- **Cluster Name:** mongo-eks-lab
- **MongoDB Version:** 7.0.12
- **Deployment:** 1-member ReplicaSet
- **Namespace:** default
- **Pod:** mongodb-lab-0

## Connection Details

### Internal (from within cluster)
```bash
mongodb://labuser:LabPass123!@mongodb-lab-0.mongodb-lab-svc.default.svc.cluster.local:27017/?authSource=admin
```

### From Pod
```bash
kubectl exec -it mongodb-lab-0 -c mongod -- mongosh \
  "mongodb://labuser:LabPass123!@localhost:27017/?authSource=admin"
```

## Users

### labuser (recommended for applications)
- Username: `labuser`
- Password: `LabPass123!`
- Roles: `readWriteAnyDatabase`, `dbAdminAnyDatabase`
- Use for: Application connections, testing

### admin (operator-managed)
- Username: `admin`
- Password: Stored in secret `mongodb-admin-password`
- Roles: `clusterAdmin`, `userAdminAnyDatabase`
- Use for: User management only

## Common Operations

### Connect to MongoDB
```bash
kubectl exec -it mongodb-lab-0 -c mongod -- mongosh \
  "mongodb://labuser:LabPass123!@localhost:27017/mydb?authSource=admin"
```

### Insert Document
```javascript
db.collection.insertOne({
  name: "test",
  timestamp: new Date()
})
```

### Query Documents
```javascript
db.collection.find({name: "test"})
```

### Create Index
```javascript
db.collection.createIndex({name: 1})
```

### Show Databases
```javascript
show dbs
```

### Show Collections
```javascript
show collections
```

## Troubleshooting

### Check Pod Status
```bash
kubectl get pods -l app=mongodb-lab-svc
```

### View Logs
```bash
# MongoDB logs
kubectl logs mongodb-lab-0 -c mongod --tail=50

# Agent logs
kubectl logs mongodb-lab-0 -c mongodb-agent --tail=50
```

### Check Replica Set Status
```bash
kubectl exec mongodb-lab-0 -c mongod -- mongosh \
  "mongodb://labuser:LabPass123!@localhost:27017/?authSource=admin" \
  --quiet --eval "rs.status()"
```

### Check Storage
```bash
kubectl get pvc
kubectl describe pvc data-volume-mongodb-lab-0
```

## Backup (Next Step)

See backup procedures in main lab documentation.
