# 🚀 Quick Start Guide

**For students who have already set up once and need to quickly verify/demo.**

---

## ⚡ Prerequisites Check

```powershell
# Check tools are installed
aws --version
kubectl version --client
terraform --version
gcloud --version
k6 version

# Set variables
$AWS_REGION = "us-east-1"
$GCP_PROJECT_ID = "YOUR_GCP_PROJECT_ID"
$GCP_REGION = "us-central1"
```

---

## 🔍 Quick Verification (5 minutes)

### 1. Check AWS Resources

```powershell
# EKS Cluster
aws eks list-clusters --region $AWS_REGION

# Connect to EKS
aws eks update-kubeconfig --region $AWS_REGION --name ticket-booking-cluster

# Check all pods
kubectl get pods
kubectl get svc
kubectl get hpa
```

### 2. Check Monitoring

```powershell
# Check monitoring pods
kubectl get pods -n monitoring

# Get Grafana URL
$GRAFANA_URL = kubectl get svc -n monitoring monitoring-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Grafana: http://$GRAFANA_URL"

# Get Grafana password
$GRAFANA_PASSWORD = kubectl get secret -n monitoring monitoring-stack-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "Username: admin"
Write-Host "Password: $GRAFANA_PASSWORD"
```

### 3. Check Logging

```powershell
# Check Loki and Promtail
kubectl get pods -n monitoring | Select-String "loki|promtail"
```

### 4. Check GCP Dataproc

```powershell
# List Dataproc clusters
gcloud dataproc clusters list --project=$GCP_PROJECT_ID --region=$GCP_REGION

# List Flink jobs
gcloud dataproc jobs list --project=$GCP_PROJECT_ID --region=$GCP_REGION --cluster=flink-analytics-cluster
```

### 5. Get Application URL

```powershell
$FRONTEND_URL = kubectl get svc frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Frontend: http://$FRONTEND_URL"
```

---

## 🧪 Run Load Test (15 minutes)

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\load-testing"

# Terminal 1: Run load test
.\run-load-test.ps1

# Terminal 2: Watch HPA scaling
kubectl get hpa --watch

# Terminal 3: Watch pods
kubectl get pods --watch
```

---

## 🎬 Demo Checklist

For recording your demo video:

### Part 1: Infrastructure Overview
- [ ] Show AWS resources (EKS, MSK, RDS, S3, Lambda) in AWS Console
- [ ] Show GCP resources (Dataproc, GCS) in GCP Console
- [ ] Show Terraform state: `terraform show` in both aws/ and gcp/

### Part 2: Kubernetes & GitOps
- [ ] `kubectl get nodes` - Show EKS nodes
- [ ] `kubectl get pods` - Show all services running
- [ ] `kubectl get svc` - Show services and LoadBalancers
- [ ] `kubectl get hpa` - Show HPAs configured
- [ ] `kubectl get applications -n argocd` - Show ArgoCD apps

### Part 3: Application Demo
- [ ] Open frontend URL
- [ ] Register a user
- [ ] View events
- [ ] Book a ticket
- [ ] Generate ticket (Demo Ticket button)
- [ ] Show ticket appears in "Generated Tickets" panel

### Part 4: Monitoring & Logging
- [ ] Open Grafana
- [ ] Show Prometheus metrics dashboard
- [ ] Show pod CPU/memory graphs
- [ ] Open Explore > Loki
- [ ] Show logs from services: `{namespace="default", app="booking-service"}`
- [ ] Show error logs: `{namespace="default"} |= "error"`

### Part 5: GCP Analytics
- [ ] Show Dataproc cluster in GCP Console
- [ ] Show Flink job running: `gcloud dataproc jobs list`
- [ ] Explain windowed aggregation (1-minute tumbling window)
- [ ] Show Kafka topics: `ticket-bookings` (input) and `analytics-results` (output)

### Part 6: Load Testing & HPA
- [ ] Run `.\run-load-test.ps1`
- [ ] Show HPA scaling: `kubectl get hpa --watch`
- [ ] Show pods increasing from 2 → 8-10
- [ ] Show load test results (p95 latency, error rate)
- [ ] Show Grafana metrics during load test

### Part 7: Code Walkthrough
- [ ] Show Terraform files (infrastructure/)
- [ ] Show microservice code (services/)
- [ ] Show K8s manifests (k8s-gitops/)
- [ ] Show Flink job (analytics_job.py)
- [ ] Explain architecture and design choices

---

## 🔧 Common Issues & Quick Fixes

### Issue: Pods Not Running

```powershell
# Check pod status
kubectl describe pod <pod-name>

# Check logs
kubectl logs <pod-name>

# Restart deployment
kubectl rollout restart deployment/<deployment-name>
```

### Issue: Frontend Not Accessible

```powershell
# Check service
kubectl get svc frontend-service

# Check if LoadBalancer has external IP
kubectl describe svc frontend-service

# If pending, wait 2-3 minutes for AWS to provision LoadBalancer
```

### Issue: Grafana Dashboard Error

```powershell
# Already fixed! ServiceMonitors are now in correct namespace
# If still having issues, resync the GitOps app:
argocd app sync monitoring-stack
argocd app wait monitoring-stack --timeout 300
```

### Issue: Loki Not Showing Logs

```powershell
# Check Loki is running
kubectl get pods -n monitoring -l app=loki

# Check Promtail is running on all nodes
kubectl get pods -n monitoring -l app=promtail

# Restart Loki if needed
kubectl rollout restart statefulset/loki -n monitoring
```

### Issue: Dataproc Job Failed

```powershell
# Check cluster status
gcloud dataproc clusters describe flink-analytics-cluster --project=$GCP_PROJECT_ID --region=$GCP_REGION

# Check job logs
gcloud dataproc jobs describe <JOB_ID> --project=$GCP_PROJECT_ID --region=$GCP_REGION

# Resubmit job
cd services/analytics-service
python submit-dataproc-job.py --project-id $GCP_PROJECT_ID --cluster-name flink-analytics-cluster --region $GCP_REGION --gcs-bucket <bucket-name> --kafka-brokers <broker-endpoints>
```

### Issue: HPA Not Scaling

```powershell
# Check metrics server is working
kubectl top nodes
kubectl top pods

# If metrics not available, install metrics server:
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Check HPA status
kubectl describe hpa booking-hpa
```

---

## 📊 Assignment Requirements - Quick Check

Run these commands to verify all requirements are met:

```powershell
# (a) IaC - Terraform
cd infrastructure/aws && terraform show
cd ../gcp && terraform show

# (b) 6 Microservices
kubectl get pods                                    # Shows 4 services
aws lambda list-functions                          # Shows Lambda
gcloud dataproc clusters list                      # Shows Dataproc

# (c) K8s + 2 HPAs
kubectl get hpa                                     # Shows 2 HPAs

# (d) GitOps
kubectl get applications -n argocd                  # Shows ArgoCD apps

# (e) Flink + Kafka
gcloud dataproc jobs list --cluster=flink-analytics-cluster

# (f) 4 Storage Products
aws s3 ls | Select-String "ticket-booking"         # S3
aws rds describe-db-instances                      # RDS
aws dynamodb list-tables                           # DynamoDB
gsutil ls | Select-String "flink-jobs"             # GCS

# (g.1) Prometheus + Grafana
kubectl get pods -n monitoring | Select-String "prometheus|grafana"

# (g.2) Centralized Logging
kubectl get pods -n monitoring | Select-String "loki|promtail"

# (h) Load Testing
cd load-testing && ls *.json                       # Check results exist
```

---

## 💾 Save Demo Evidence

Create a folder for screenshots:

```powershell
mkdir Demo-Evidence
cd Demo-Evidence

# Take screenshots of:
# 1. AWS Console - EKS, MSK, RDS, Lambda, S3
# 2. GCP Console - Dataproc, GCS
# 3. kubectl get pods
# 4. kubectl get hpa (before and during load test)
# 5. Grafana dashboards
# 6. Loki logs in Grafana
# 7. Load test results
# 8. Frontend working (register, book, ticket generation)
```

---

## 📝 Final Checklist

Before submitting:

- [ ] All services running
- [ ] Load test completed successfully
- [ ] HPA scaling demonstrated
- [ ] Screenshots saved
- [ ] Demo video recorded
- [ ] Code walkthrough video recorded
- [ ] Design document completed
- [ ] GitHub repository updated
- [ ] All code committed and pushed

---

**Quick Access URLs:**
- Frontend: Check with `kubectl get svc frontend-service`
- Grafana: Check with `kubectl get svc -n monitoring monitoring-stack-grafana`
- GitHub: https://github.com/Nishit556/ticket-booking-assignment

**Last Updated:** 2025-11-23

