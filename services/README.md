# Ticket Booking Microservices - Complete Setup & Execution Guide

**Status:** ✅ Terraform applied | ✅ Docker images pushed | ⏳ Deploying to Kubernetes

---

## 📋 Prerequisites Checklist

- [x] AWS CLI configured (`aws configure`)
- [x] kubectl authenticated to EKS cluster
- [x] Docker logged into ECR
- [x] Terraform applied successfully
- [x] All Docker images built and pushed to ECR

---

## 🔍 Step 1: Verify AWS Resource Values

Your current configuration values (already set correctly):

| Resource | Current Value | Location |
|----------|--------------|----------|
| **S3 Bucket** | `ticket-booking-raw-data-1f8db074` | `services/frontend/server.js:23` |
| **MSK Brokers** | `b-2.ticketbookingkafka.u5orzl.c8.kafka.us-east-1.amazonaws.com:9092,b-1.ticketbookingkafka.u5orzl.c8.kafka.us-east-1.amazonaws.com:9092` | `k8s-gitops/apps/booking-service.yaml:22` |
| **RDS Endpoint** | `terraform-20251120151945012200000013.cov0iwq0wygo.us-east-1.rds.amazonaws.com` | `k8s-gitops/apps/event-catalog.yaml:23` |

**✅ All values are correct - no changes needed!**

If you need to update them later, use these commands:

```powershell
# Get S3 bucket name
aws s3 ls | Select-String "ticket-booking-raw-data"

# Get MSK broker endpoints
aws kafka get-bootstrap-brokers --cluster-arn "arn:aws:kafka:us-east-1:YOUR_AWS_ACCOUNT_ID:cluster/ticket-booking-kafka/549f9ffd-860f-40ae-bcf5-63b3e807bc52-8"

# Get RDS endpoint
aws rds describe-db-instances --query "DBInstances[?contains(DBInstanceIdentifier, 'terraform')].Endpoint.Address" --output text
```

---

## 🚀 Step 2: Deploy to Kubernetes (GitOps Required)

Requirement **(d)** forbids `kubectl apply` for application workloads. All deployments and updates **must** flow through ArgoCD.

1. **Commit and push desired state**
   ```powershell
   cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
   git add k8s-gitops/apps/*.yaml services/frontend/*
   git commit -m "Deploy microservices to EKS"
   git push origin main
   ```

2. **Ensure ArgoCD applications exist**
   ```powershell
   kubectl apply -f argocd-app.yaml      # ticket-booking workloads
   kubectl apply -f monitor-app.yaml     # monitoring + logging stack
   ```

3. **Trigger/monitor sync**
   ```powershell
   # Via kubectl
   kubectl get applications.argoproj.io -n argocd

   # Via ArgoCD CLI
   argocd app sync ticket-booking-app
   argocd app sync monitoring-stack
   argocd app wait ticket-booking-app --timeout 600
   argocd app wait monitoring-stack --timeout 600
   ```

---

## ✅ Step 3: Verify Deployment

### Check Pod Status

```powershell
kubectl get pods
```

**Expected output:**
```
NAME                              READY   STATUS    RESTARTS   AGE
frontend-xxxxxxxxxx-xxxxx         1/1     Running   0          2m
booking-service-xxxxxxxxxx-xxxxx  1/1     Running   0          2m
event-catalog-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
user-service-xxxxxxxxxx-xxxxx    1/1     Running   0          2m
```

### Check Services

```powershell
kubectl get svc
```

**Expected output:**
```
NAME              TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
frontend-service  LoadBalancer   10.100.x.x      a1b2c3d4e5f6g7h8.us-east-1.elb.amazonaws.com                          80:3xxxx/TCP   2m
booking-service   ClusterIP      10.100.x.x      <none>                                                                   5000/TCP       2m
event-catalog     ClusterIP      10.100.x.x      <none>                                                                   5000/TCP       2m
user-service      ClusterIP      10.100.x.x      <none>                                                                   3000/TCP       2m
```

### Check HPAs

```powershell
kubectl get hpa
```

**Expected output:**
```
NAME          REFERENCE                TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
booking-hpa   Deployment/booking-service   0%/50%   2         10        2         2m
user-hpa      Deployment/user-service     0%/50%   2         10        2         2m
```

### Check Logs (if pods are not running)

```powershell
# Check specific pod logs
kubectl logs <pod-name>

# Check all pods in a deployment
kubectl logs -l app=frontend --tail=50
```

---

## 🌐 Step 4: Access the Application

### Get Frontend LoadBalancer URL

```powershell
kubectl get svc frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Or check the full service:

```powershell
kubectl get svc frontend-service
```

**Copy the EXTERNAL-IP value** and open it in your browser.

### Test the Application

1. **Open the LoadBalancer URL** in your browser
2. **Register a user:**
   - Enter name and email
   - Click "Register User"
   - Note the User ID displayed
3. **View events:**
   - Events should auto-load
   - You should see 3 sample events
4. **Book a ticket:**
   - Click "Book Now" on any event
   - Check the "Booking History" panel - it should show your booking
5. **Generate a ticket:**
   - Click "Demo Ticket" button (or upload a file)
   - Check the "Generated Tickets" panel - it should show the ticket file after Lambda runs
6. **Check service status:**
   - The "Service Status" panel should show all services as "Healthy"

---

## 📊 Step 5: Verify Observability

### Access Grafana

**Grafana LoadBalancer URL:** `http://a0b290f92f26546da960c8a80342b05b-680390527.us-east-1.elb.amazonaws.com`

**Login Credentials:**
- Username: `admin`
- Password: `prom-operator`

To get the URL again:
```powershell
kubectl get svc -n monitoring monitoring-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

To get the password again:
```powershell
kubectl get secret -n monitoring monitoring-stack-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
```

---

## 🔧 Troubleshooting

### kubectl Connection Issues

If you get `EOF` or connection errors:

1. **Reconnect to cluster:**
   ```powershell
   aws eks update-kubeconfig --region us-east-1 --name ticket-booking-cluster
   ```

2. **Test connection:**
   ```powershell
   kubectl get nodes
   ```

3. **If still failing:**
   - Check your VPN/network connection
   - Verify EKS cluster is in `ACTIVE` state: `aws eks describe-cluster --name ticket-booking-cluster --region us-east-1`
   - Wait a few minutes if cluster was just created

### Pods Not Starting

1. **Check pod status:**
   ```powershell
   kubectl describe pod <pod-name>
   ```

2. **Common issues:**
   - **ImagePullBackOff:** Check ECR image name matches YAML
   - **CrashLoopBackOff:** Check pod logs for errors
   - **Pending:** Check node resources: `kubectl describe nodes`

### Services Not Accessible

1. **Check service endpoints:**
   ```powershell
   kubectl get endpoints
   ```

2. **Test internal connectivity:**
   ```powershell
   kubectl run -it --rm debug --image=busybox --restart=Never -- sh
   # Inside the pod:
   wget -O- http://frontend-service:80/health
   ```

### Lambda Not Triggering

1. **Check S3 bucket notification:**
   ```powershell
   aws s3api get-bucket-notification-configuration --bucket ticket-booking-raw-data-1f8db074
   ```

2. **Check Lambda logs:**
   ```powershell
   aws logs tail /aws/lambda/ticket-generator-func --follow
   ```

### Database Connection Issues

1. **Verify RDS security group allows EKS nodes:**
   ```powershell
   aws ec2 describe-security-groups --group-ids <rds-sg-id>
   ```

2. **Test connection from a pod:**
   ```powershell
   kubectl run -it --rm psql-test --image=postgres:16 --restart=Never -- psql -h terraform-20251120151945012200000013.cov0iwq0wygo.us-east-1.rds.amazonaws.com -U dbadmin -d ticketdb
   ```

---

## 📝 Step 6: Update Configuration (If Needed)

If Terraform recreates resources, update these files:

### 1. Update S3 Bucket Name

**File:** `services/frontend/server.js`
```javascript
const BUCKET_NAME = "ticket-booking-raw-data-<NEW-HEX>";  // Line 23
```

Then rebuild and push:
```powershell
cd services/frontend
docker build -t YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ticket-booking/frontend:latest .
docker push YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ticket-booking/frontend:latest
```

### 2. Update MSK Brokers

**File:** `k8s-gitops/apps/booking-service.yaml`
```yaml
- name: KAFKA_BROKERS
  value: "b-1.new-broker.amazonaws.com:9092,b-2.new-broker.amazonaws.com:9092"  # Line 22
```

Then commit the change and let ArgoCD roll it out:
```powershell
git add k8s-gitops/apps/booking-service.yaml
git commit -m "Update MSK broker endpoints"
git push origin main
argocd app sync ticket-booking-app
```

### 3. Update RDS Endpoint

**File:** `k8s-gitops/apps/event-catalog.yaml`
```yaml
- name: DB_HOST
  value: "new-rds-endpoint.rds.amazonaws.com"  # Line 23
```

Then commit the change and let ArgoCD roll it out:
```powershell
git add k8s-gitops/apps/event-catalog.yaml
git commit -m "Update RDS endpoint"
git push origin main
argocd app sync ticket-booking-app
```

---

## 🎯 Step 7: Demo Checklist

Before recording your demo video, verify:

- [ ] All pods are running (`kubectl get pods`)
- [ ] Frontend LoadBalancer is accessible
- [ ] User registration works
- [ ] Events are displayed
- [ ] Booking creates entry in history panel
- [ ] Ticket generation works (Lambda creates file in S3)
- [ ] Service status panel shows all healthy
- [ ] Grafana dashboard is accessible
- [ ] HPAs are configured and visible

---

## 🔄 Step 8: Rebuild & Redeploy (After Code Changes)

If you make code changes:

```powershell
# 1. Rebuild and push image (use a new tag when possible)
cd services/<service-name>
docker build -t YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ticket-booking/<service-name>:v2 .
docker push YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ticket-booking/<service-name>:v2

# 2. Update the manifest to reference the new tag
git add k8s-gitops/apps/<service-name>.yaml
git commit -m "Bump <service-name> image"
git push origin main

# 3. Let ArgoCD roll out the change
argocd app sync ticket-booking-app
argocd app wait ticket-booking-app --timeout 600
```

> If you absolutely must reuse the `:latest` tag, run `argocd app sync ticket-booking-app --revision HEAD` to force a redeploy instead of using `kubectl rollout restart`.

---

## 📚 Additional Commands

### View All Resources

```powershell
kubectl get all
```

### Delete Everything (Cleanup)

```powershell
kubectl delete -f k8s-gitops/apps/
kubectl delete -f argocd-app.yaml
```

### Port Forward for Local Testing

```powershell
# Frontend
kubectl port-forward svc/frontend-service 3000:80

# Booking Service
kubectl port-forward svc/booking-service 5000:5000

# Event Catalog
kubectl port-forward svc/event-catalog 5001:5000

# User Service
kubectl port-forward svc/user-service 3001:3000
```

---

## 🎬 Next Steps (GCP Integration)

Once AWS deployment is verified:

1. Create GCP Terraform in `infrastructure/gcp/`
2. Deploy Flink job to Dataproc
3. Connect to MSK from GCP
4. Update frontend to display analytics results

---

## 📞 Quick Reference

| Command | Purpose |
|---------|---------|
| `kubectl get pods` | List all pods |
| `kubectl get svc` | List all services |
| `kubectl get hpa` | List HPAs |
| `kubectl logs <pod>` | View pod logs |
| `kubectl describe pod <pod>` | Detailed pod info |
| `kubectl rollout restart deployment/<name>` | Restart deployment |
| `aws s3 ls` | List S3 buckets |
| `aws kafka list-clusters` | List MSK clusters |
| `aws rds describe-db-instances` | List RDS instances |

---

**Last Updated:** 2025-11-20  
**Status:** Ready for deployment

