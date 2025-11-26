# Complete Setup Guide - Start to Finish

This guide contains **every single command** needed to deploy the entire ticket booking microservices application from scratch to cleanup.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [AWS Infrastructure Setup](#aws-infrastructure-setup)
3. [Build and Push Docker Images](#build-and-push-docker-images)
4. [Update Configuration Files](#update-configuration-files)
5. [Deploy to Kubernetes (EKS)](#deploy-to-kubernetes-eks)
6. [Deploy Monitoring Stack](#deploy-monitoring-stack)
7. [Deploy Centralized Logging](#deploy-centralized-logging)
8. [GCP Infrastructure Setup](#gcp-infrastructure-setup)
9. [Deploy Analytics Service (Dataproc)](#deploy-analytics-service-dataproc)
10. [Run Load Testing](#run-load-testing)
11. [Verification Steps](#verification-steps)
12. [Cleanup (Destroy Everything)](#cleanup-destroy-everything)

---

## Prerequisites

### 1. Install Required Tools

```powershell
# Verify AWS CLI is installed
aws --version

# Verify Terraform is installed
terraform --version

# Verify kubectl is installed
kubectl version --client

# Verify Docker is installed
docker --version

# Verify gcloud CLI is installed (for GCP)
gcloud --version
```

### 2. Configure AWS CLI

```powershell
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
# Enter default output format: json
```

### 3. Configure GCP CLI

```powershell
# Authenticate with GCP
gcloud auth login
gcloud auth application-default login

# Set your GCP project
gcloud config set project YOUR_GCP_PROJECT_ID

# Enable required APIs
gcloud services enable dataproc.googleapis.com
gcloud services enable storage-component.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable iam.googleapis.com
```

### 4. Set Variables

```powershell
# Set your AWS account ID (replace with your actual account ID)
$AWS_ACCOUNT_ID = "YOUR_AWS_ACCOUNT_ID"
$AWS_REGION = "us-east-1"
$GCP_PROJECT_ID = "YOUR_GCP_PROJECT_ID"
$GCP_REGION = "us-central1"
$GCP_ZONE = "us-central1-a"
```

---

## AWS Infrastructure Setup

### Step 1: Navigate to AWS Terraform Directory

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\aws"
```

### Step 2: Initialize Terraform

```powershell
terraform init
```

### Step 3: Review Terraform Plan

```powershell
terraform plan
```

### Step 4: Apply AWS Infrastructure

```powershell
terraform apply
# Type 'yes' when prompted
```

**Wait for completion** (this takes 15-20 minutes for EKS, MSK, RDS)

### Step 5: Get AWS Resource Outputs

```powershell
# Get S3 bucket name
$S3_BUCKET = terraform output -raw s3_bucket_name
Write-Host "S3 Bucket: $S3_BUCKET"

# Get MSK broker endpoints
$MSK_BROKERS = terraform output -raw msk_brokers
Write-Host "MSK Brokers: $MSK_BROKERS"

# Get RDS endpoint
$RDS_ENDPOINT = terraform output -raw rds_endpoint
Write-Host "RDS Endpoint: $RDS_ENDPOINT"

# Get EKS cluster name
$CLUSTER_NAME = terraform output -raw cluster_name
Write-Host "Cluster Name: $CLUSTER_NAME"

# Get EKS cluster endpoint
$CLUSTER_ENDPOINT = terraform output -raw cluster_endpoint
Write-Host "Cluster Endpoint: $CLUSTER_ENDPOINT"

# Get MSK cluster ARN (for later use)
$MSK_ARN = terraform output -raw msk_cluster_arn
Write-Host "MSK ARN: $MSK_ARN"
```

### Step 6: Configure kubectl for EKS

```powershell
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Verify connection
kubectl get nodes
```

### Step 7: Get MSK Cluster ARN (for later use)

```powershell
# Method 1: Get from Terraform output (Recommended - most reliable)
$MSK_ARN = terraform output -raw msk_cluster_arn
Write-Host "MSK ARN: $MSK_ARN"

# If empty, try Method 2: List all clusters and filter
if ([string]::IsNullOrWhiteSpace($MSK_ARN)) {
    $MSK_ARN = aws kafka list-clusters --query "ClusterInfoList[?contains(ClusterName, 'ticket-booking')].ClusterArn" --output text
    Write-Host "MSK ARN (Method 2): $MSK_ARN"
}

# If still empty, try Method 3: List all and get first
if ([string]::IsNullOrWhiteSpace($MSK_ARN)) {
    $MSK_ARN = aws kafka list-clusters --query "ClusterInfoList[0].ClusterArn" --output text
    Write-Host "MSK ARN (Method 3): $MSK_ARN"
}

# Verify we have the ARN
if ([string]::IsNullOrWhiteSpace($MSK_ARN)) {
    Write-Host "WARNING: Could not retrieve MSK ARN. You may need to get it manually from AWS Console."
    Write-Host "You can also get it later with: aws kafka list-clusters"
} else {
    Write-Host "MSK ARN: $MSK_ARN"
}
```

---

## Build and Push Docker Images

### Step 1: Login to AWS ECR

```powershell
cmd /c "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
```

### Step 2: Build and Push Frontend Image

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\frontend"

# Build image
docker build -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/frontend:latest" .
# Push image
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/frontend:latest"

### Step 3: Build and Push Booking Service Image

cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\booking-service"

# Build image
docker build -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/booking-service:latest" .

# Push image
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/booking-service:latest"

### Step 4: Build and Push Event Catalog Image

cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\event-catalog"

# Build image
docker build -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/event-catalog:latest" .

# Push image
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/event-catalog:latest"

### Step 5: Build and Push User Service Image

cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\user-service"

# Build image
docker build -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/user-service:latest" .

# Push image
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/user-service:latest"


---

## Update Configuration Files

### Step 1: Update Frontend S3 Bucket Name

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\frontend"

# Edit server.js and update BUCKET_NAME on line 23
# Replace with: const BUCKET_NAME = "$S3_BUCKET";
```

**File:** `services/frontend/server.js`
```javascript
const BUCKET_NAME = "ticket-booking-raw-data-XXXXX";  // Replace XXXXX with actual bucket name
```

### Step 2: Rebuild and Push Frontend (if bucket name changed)
### Step 2: Build and Push Frontend Image

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\frontend"

# Build image
docker build -t "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/frontend:latest" .
# Push image
docker push "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ticket-booking/frontend:latest"

### Step 3: Update Kubernetes YAML Files

**File:** `k8s-gitops/apps/booking-service.yaml`
- Update line 22: `KAFKA_BROKERS` value with `$MSK_BROKERS`

**File:** `k8s-gitops/apps/event-catalog.yaml`
- Update line 23: `DB_HOST` value with `$RDS_ENDPOINT`

**File:** `k8s-gitops/apps/frontend.yaml`
- Verify line 19: Image URL matches your ECR repository

**File:** `k8s-gitops/apps/user-service.yaml`
- Verify image URL matches your ECR repository

---

## Deploy to Kubernetes (EKS)

### Step 1: Enable GitOps Controller (ArgoCD)

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"

# Create namespace once
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD controller (manages all future workloads)
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

> **Why:** Requirement (d) mandates that *all* app/monitoring deployments flow through a GitOps controller. The ArgoCD installation above is the only place `kubectl apply` is used for workloads—it bootstraps the controller itself.

### Step 2: Commit & Push Desired State

```powershell
git add k8s-gitops/ services/frontend/*
git commit -m "Update Kubernetes manifests"
git push origin main
```

ArgoCD will track the Git repository you just updated, so every change must be committed/pushed before it can be deployed.

### Step 3: Register ArgoCD Applications

```powershell
# Application for all stateless services + HPAs
kubectl apply -f argocd-app.yaml

# Applications for monitoring & logging stack
kubectl apply -f monitor-app.yaml
kubectl apply -f loki-app.yaml
kubectl apply -f monitoring-servicemonitors-app.yaml
```

These application CRDs point ArgoCD to `k8s-gitops/apps` and `k8s-gitops/system`. Once applied, **do not** run `kubectl apply` for individual services—ArgoCD handles syncs, pruning, and rollbacks automatically.

### Step 4: Watch GitOps Sync Status

```powershell
# Option A: Via kubectl
kubectl get applications.argoproj.io -n argocd

# Option B: Via ArgoCD CLI (after argocd login)
argocd app list
argocd app sync ticket-booking-app
argocd app sync monitoring-stack

# Wait for sync/health to show Healthy/Synced
argocd app wait ticket-booking-app --timeout 600
argocd app wait monitoring-stack --timeout 600
```

ArgoCD automatically recreates resources if they drift (self-heal) and removes orphaned objects (prune). This satisfies the “no direct kubectl apply” rule from the assignment.

### Step 5: Verify Deployments

```powershell
# Check pods
kubectl get pods

# Check services
kubectl get svc

# Check HPAs
kubectl get hpa

# Wait for all pods to be Running
kubectl wait --for=condition=ready pod -l app=frontend --timeout=300s
kubectl wait --for=condition=ready pod -l app=booking-service --timeout=300s
kubectl wait --for=condition=ready pod -l app=event-catalog --timeout=300s
kubectl wait --for=condition=ready pod -l app=user-service --timeout=300s
```

### Step 3: Get Frontend LoadBalancer URL

```powershell
$FRONTEND_URL = kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Frontend URL: http://$FRONTEND_URL"
```

---

## Deploy Monitoring Stack

### Step 1: Install Prometheus Operator CRDs (REQUIRED FIRST)

ArgoCD cannot create the operator CRDs; install them once manually:

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"

kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_servicemonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_podmonitors.yaml
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_alertmanagers.yaml

# Verify CRDs are installed
kubectl get crd | Select-String "prometheus"
```

### Step 2: Let ArgoCD Deploy Prometheus, Grafana & Loki

Once the CRDs exist, ArgoCD (via `monitor-app.yaml`, `loki-app.yaml`, and `monitoring-servicemonitors-app.yaml`) reconciles the entire observability stack. No direct `kubectl apply` is used for Prometheus, Grafana, Loki, or the ServiceMonitor CRDs.

```powershell
# Trigger/observe sync if needed
argocd app sync monitoring-stack
argocd app wait monitoring-stack --timeout 600

# Inspect pods to confirm
kubectl get pods -n monitoring
```

### Step 3: Get Grafana URL and Password

```powershell
# Wait for LoadBalancer to be ready (may take 2-3 minutes)
Start-Sleep -Seconds 120

$GRAFANA_URL = kubectl get svc -n monitoring monitoring-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Grafana URL: http://$GRAFANA_URL"

# Get Grafana password
$GRAFANA_PASSWORD = kubectl get secret -n monitoring monitoring-stack-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "Username: admin"
Write-Host "Password: $GRAFANA_PASSWORD"
```

---

## Deploy Centralized Logging

**Requirement (g):** Implement centralized logging solution to aggregate logs from all microservices.

### Step 1: Deploy Loki Stack (Managed by ArgoCD)

Loki/Promtail are handled by `loki-app.yaml`, while the custom ServiceMonitor CRDs come from `monitoring-servicemonitors-app.yaml`. No manual `kubectl apply` is necessary—just ensure ArgoCD reports all three apps (`monitoring-stack`, `loki-stack`, `monitoring-servicemonitors`) as Healthy/Synced.

### Step 2: Wait for Loki Pods

```powershell
# Wait for Loki and Promtail to be ready
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki --watch
# Press Ctrl+C when loki-stack-0 shows 1/1 Running

# Check Promtail pods (correct label selector)
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
# Should show loki-stack-promtail-xxxxx pods running on each node
```

### Step 3: Configure Grafana Data Source

```powershell
# The ConfigMap should automatically add Loki as a data source
# Verify in Grafana: Configuration > Data Sources > Loki
Write-Host "Access Grafana: http://$GRAFANA_URL"
Write-Host "Go to: Configuration > Data Sources"
Write-Host "You should see 'Loki' listed as a data source"
```

### Step 4: View Logs in Grafana

1. Open Grafana: `http://$GRAFANA_URL`
2. Login with admin credentials
3. Click **Explore** (compass icon on left sidebar)
4. Select **Loki** as the data source
5. Use Log Browser to filter by:
   - `{namespace="default"}` - All application logs
   - `{app="booking-service"}` - Booking service logs
   - `{app="frontend"}` - Frontend logs

**Common LogQL Queries:**
```logql
# All application logs
{namespace="default"}

# Booking service logs
{namespace="default", app="booking-service"}

# Errors only
{namespace="default"} |= "error" or "Error" or "ERROR"

# Logs from last 5 minutes with keyword "booking"
{namespace="default"} |= "booking"
```

---

## GCP Infrastructure Setup

### Step 1: Navigate to GCP Terraform Directory

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\gcp"
```

### Step 2: Create Terraform Variables File

```powershell
# Copy example file
copy terraform.tfvars.example terraform.tfvars

# Edit terraform.tfvars with your values:
# gcp_project_id = "$GCP_PROJECT_ID"
# gcp_region = "$GCP_REGION"
# gcp_zone = "$GCP_ZONE"
# aws_msk_brokers = "$MSK_BROKERS"
```

**File:** `infrastructure/gcp/terraform.tfvars`
```hcl
gcp_project_id = "your-gcp-project-id"
gcp_region     = "us-central1"
gcp_zone       = "us-central1-a"

# Get this from AWS MSK output
aws_msk_brokers = "b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092"

# Optional: Adjust cluster configuration
dataproc_cluster_name = "flink-analytics-cluster"
dataproc_machine_type = "n1-standard-2"
dataproc_num_workers  = 2
```

### Step 3: Initialize GCP Terraform

```powershell
terraform init
```

### Step 4: Review GCP Terraform Plan

```powershell
terraform plan
```

### Step 5: Apply GCP Infrastructure

```powershell
terraform apply
# Type 'yes' when prompted
```

**Wait for completion** (this takes 10-15 minutes for Dataproc cluster)

### Step 6: Get GCP Resource Outputs

```powershell
$DATAPROC_CLUSTER = terraform output -raw dataproc_cluster_name
Write-Host "Dataproc Cluster: $DATAPROC_CLUSTER"

$GCS_BUCKET = terraform output -raw gcs_bucket_name
Write-Host "GCS Bucket: $GCS_BUCKET"

$SERVICE_ACCOUNT = terraform output -raw service_account_email
Write-Host "Service Account: $SERVICE_ACCOUNT"
```

---

## Deploy Analytics Service (Dataproc)

### Step 1: Configure MSK Security Group for GCP Access

**⚠️ IMPORTANT: This step requires AWS infrastructure to be deployed first!**

```powershell
# Method 1: Get from Terraform output (Recommended - most reliable)
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\aws"
$SG_ID = terraform output -raw msk_security_group_id
Write-Host "Security Group ID: $SG_ID"

# If empty, try Method 2: Query by name (must be in correct region/VPC)
if ([string]::IsNullOrWhiteSpace($SG_ID)) {
    $SG_ID = aws ec2 describe-security-groups --filters "Name=group-name,Values=ticket-booking-kafka-sg" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION
    Write-Host "Security Group ID (Method 2): $SG_ID"
}

# If still empty, try Method 3: Get from MSK cluster directly
if ([string]::IsNullOrWhiteSpace($SG_ID)) {
    $MSK_ARN = terraform output -raw msk_cluster_arn
    $SG_ID = aws kafka describe-cluster --cluster-arn $MSK_ARN --query "ClusterInfo.BrokerNodeGroupInfo.SecurityGroups[0]" --output text --region $AWS_REGION
    Write-Host "Security Group ID (Method 3): $SG_ID"
}

# Verify we have the security group ID
if ([string]::IsNullOrWhiteSpace($SG_ID) -or $SG_ID -eq "None") {
    Write-Host "ERROR: Could not find MSK security group!"
    Write-Host "Make sure AWS infrastructure has been deployed with: terraform apply"
    Write-Host "And you're querying the correct region: $AWS_REGION"
    exit 1
}

Write-Host "Found Security Group ID: $SG_ID"

# Add ingress rule (WARNING: Only for demo - use specific IPs in production)
Write-Host "Adding ingress rule to allow GCP Dataproc access..."
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 9092 --cidr 0.0.0.0/0 --region $AWS_REGION

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Security group rule added successfully!"
} else {
    Write-Host "⚠️ Rule may already exist, or there was an error. Check AWS Console."
}
```

### Step 2: Verify Initialization Script is Uploaded

```powershell
# The script should be automatically uploaded by Terraform
# Verify it exists
gsutil ls gs://$GCS_BUCKET/init-scripts/
```

### Step 3: Submit Flink Job to Dataproc

**⚠️ PREREQUISITE: Ensure Google Cloud SDK is installed and gsutil/gcloud are in PATH!**

```powershell
# Verify gsutil and gcloud are available
gsutil --version
gcloud --version

# If not found, install Google Cloud SDK:
# https://cloud.google.com/sdk/docs/install
# Or add to PATH manually
```

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\analytics-service"

# Submit job using Python script
python submit-dataproc-job.py `
  --project-id $GCP_PROJECT_ID `
  --cluster-name $DATAPROC_CLUSTER `
  --region $GCP_REGION `
  --gcs-bucket $GCS_BUCKET `
  --kafka-brokers $MSK_BROKERS
```

**Alternative: Manual Upload and Submit**

If the Python script fails, you can do it manually:

```powershell
# 1. Upload job file to GCS
gsutil cp analytics_job.py "gs://$GCS_BUCKET/flink-jobs/analytics_job.py"

# 2. Submit job directly
gcloud dataproc jobs submit flink `
  --project=$GCP_PROJECT_ID `
  --region=$GCP_REGION `
  --cluster=$DATAPROC_CLUSTER `
  --py-files="gs://$GCS_BUCKET/flink-jobs/analytics_job.py" `
  --properties="flink.jobmanager.memory.process.size=1024m,flink.taskmanager.memory.process.size=1024m" `
  -- `
  --python "gs://$GCS_BUCKET/flink-jobs/analytics_job.py"
```

**Alternative: Manual Submission**

```powershell
# Upload job file
gsutil cp analytics_job.py gs://$GCS_BUCKET/flink-jobs/

# Submit job
gcloud dataproc jobs submit flink `
  --project=$GCP_PROJECT_ID `
  --region=$GCP_REGION `
  --cluster=$DATAPROC_CLUSTER `
  --py-files=gs://$GCS_BUCKET/flink-jobs/analytics_job.py `
  --properties=flink.jobmanager.memory.process.size=1024m,flink.taskmanager.memory.process.size=1024m `
  -- `
  --python gs://$GCS_BUCKET/flink-jobs/analytics_job.py
```

### Step 4: Verify Job is Running

```powershell
# List all jobs
gcloud dataproc jobs list --project=$GCP_PROJECT_ID --region=$GCP_REGION --cluster=$DATAPROC_CLUSTER

# Get the most recent job ID
$JOB_ID = gcloud dataproc jobs list --project=$GCP_PROJECT_ID --region=$GCP_REGION --cluster=$DATAPROC_CLUSTER --format="value(reference.jobId)" --limit=1
Write-Host "Job ID: $JOB_ID"

# Check job status
gcloud dataproc jobs describe $JOB_ID --project=$GCP_PROJECT_ID --region=$GCP_REGION
```

### Step 5: Monitor Flink Job

```powershell
# Option 1: View logs in Cloud Console
Write-Host "View logs at: https://console.cloud.google.com/dataproc/jobs/$JOB_ID?project=$GCP_PROJECT_ID"

# Option 2: Access Flink UI (requires SSH tunnel)
Write-Host "To access Flink UI, run:"
Write-Host "gcloud compute ssh $DATAPROC_CLUSTER-m --project=$GCP_PROJECT_ID --zone=$GCP_ZONE --ssh-flag='-L 8081:localhost:8081'"
Write-Host "Then open: http://localhost:8081"
```

---

## Run Load Testing

**Requirement (h):** Use a load testing tool to validate system resilience and HPA scaling.

### Step 1: Install k6

```powershell
# Windows (Chocolatey)
choco install k6

# Or Windows (Winget)
winget install k6

# Or download from: https://k6.io/docs/get-started/installation/
```

### Step 2: Verify k6 Installation

```powershell
k6 version
```

### Step 3: Run Load Test

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\load-testing"

# Run the load test
.\run-load-test.ps1
```

**What happens during the test:**
1. Test starts with 10 virtual users
2. Gradually increases to 150 users over 9 minutes
3. HPA should trigger and scale up booking-service and user-service
4. Test maintains peak load for 3 minutes
5. Gradually scales down
6. Total duration: ~15 minutes

### Step 4: Monitor HPA Scaling (During Test)

**Open a second terminal and run:**

```powershell
# Connect to EKS
aws eks update-kubeconfig --region us-east-1 --name ticket-booking-cluster

# Watch HPA scaling in real-time
kubectl get hpa --watch
```

**Expected behavior:**
- At ~50 users: Pods should scale from 2 → 3-4
- At ~100 users: Pods should scale to 5-7
- At peak (150 users): Pods should scale to 8-10

### Step 5: Monitor Pods Scaling (During Test)

**Open a third terminal:**

```powershell
# Watch pod scaling
kubectl get pods --watch | Select-String "booking-service|user-service"
```

### Step 6: View Metrics in Grafana (During Test)

```powershell
# Get Grafana URL
$GRAFANA_URL = kubectl get svc -n monitoring monitoring-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Open Grafana: http://$GRAFANA_URL"
```

**In Grafana:**
1. Go to **Dashboards**
2. Select **Kubernetes / Compute Resources / Pod**
3. Watch CPU, memory, and request metrics increase

### Step 7: Review Load Test Results

After the test completes, check the generated files:

```powershell
cd load-testing

# View summary
cat load-test-summary.json

# View detailed results
cat load-test-results.json
```

**Key metrics to check:**
- ✅ p95 latency < 500ms
- ✅ Error rate < 10%
- ✅ HPA scaled up during high load
- ✅ System recovered after load decreased

---

## Verification Steps

### Step 1: Verify AWS Services

```powershell
# Check all pods are running
kubectl get pods

# Check all services
kubectl get svc

# Check HPAs
kubectl get hpa

# Check frontend is accessible
$FRONTEND_URL = kubectl get svc frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Frontend: http://$FRONTEND_URL"
```

### Step 2: Verify Database Connection

```powershell
# Test RDS connection from a pod
kubectl run -it --rm psql-test --image=postgres:16 --restart=Never -- psql -h $RDS_ENDPOINT -U dbadmin -d ticketdb
# Password: CHANGE_ME_PASSWORD
# Type \q to exit
```

### Step 3: Verify Kafka Topics

**Option A: Using a lightweight Kafka client image (Recommended)**

```powershell
# Use a smaller Kafka client image
kubectl run -it --rm kafka-test --image=confluentinc/cp-kafka:latest --restart=Never --timeout=300s -- bash
# Inside the pod:
# kafka-topics --bootstrap-server $MSK_BROKERS --list
# kafka-console-consumer --bootstrap-server $MSK_BROKERS --topic ticket-bookings --from-beginning --max-messages 5
```

**Option B: Using Python to test Kafka (if Option A times out)**

```powershell
# Use a Python image with kafka-python
kubectl run -it --rm kafka-test --image=python:3.9-slim --restart=Never --timeout=300s -- bash
# Inside the pod:
# pip install kafka-python
# python3 -c "from kafka import KafkaConsumer; c = KafkaConsumer(bootstrap_servers='$MSK_BROKERS'); print(list(c.list_consumer_groups()))"
```

**Option C: Test from an existing pod (if booking-service is running)**

```powershell
# Exec into booking-service pod
$POD_NAME = kubectl get pods -l app=booking-service -o jsonpath='{.items[0].metadata.name}'
kubectl exec -it $POD_NAME -- python3 -c "from kafka import KafkaConsumer; c = KafkaConsumer(bootstrap_servers='$MSK_BROKERS'); print('Topics:', list(c.list_consumer_groups()))"
```

### Step 4: Verify Lambda Function

```powershell
# List Lambda functions
aws lambda list-functions --region us-east-1 --query "Functions[?contains(FunctionName, 'ticket')].FunctionName"
terraform state list | Select-String "aws_lambda_function"

# Test Lambda (upload a file to S3)
aws s3 cp test-id.jpg s3://$S3_BUCKET/
# Check Lambda logs
aws logs tail /aws/lambda/ticket-generator-func --region us-east-1
```

### Step 5: Verify Dataproc Job

```powershell
# Check job status
gcloud dataproc jobs describe $JOB_ID --project=$GCP_PROJECT_ID --region=$GCP_REGION

# Check job logs
gcloud dataproc jobs describe $JOB_ID --project=$GCP_PROJECT_ID --region=$GCP_REGION --format="value(driverOutputResourceUri)"
```

### Step 6: Verify Analytics Results

```powershell
# Check if analytics-results topic has data
# (From a pod with Kafka tools)
kafka-console-consumer `
  --bootstrap-server $MSK_BROKERS `
  --topic analytics-results `
  --from-beginning `
  --max-messages 10
```

### Step 7: Test Application End-to-End

1. **Open Frontend URL** in browser
2. **Register a user**
3. **View events**
4. **Book a ticket**
5. **Generate a ticket** (upload file or click Demo Ticket)
6. **Check booking history**
7. **Check service status**

### Step 8: Verify Monitoring

```powershell
# Access Grafana
$GRAFANA_URL = kubectl get svc -n monitoring monitoring-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Grafana: http://$GRAFANA_URL"

# Get password
$GRAFANA_PASSWORD = kubectl get secret -n monitoring monitoring-stack-grafana -o jsonpath='{.data.admin-password}' | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
Write-Host "Login: admin / $GRAFANA_PASSWORD"
```

### Step 9: Troubleshooting Grafana 500 Errors

**If you see "An error occurred within the plugin" or "connection refused" errors in Grafana:**

#### Issue 1: Prometheus Not Running

**Symptoms:**
- Grafana shows 500 errors when querying data
- Error: "dial tcp 172.20.x.x:9090: connect: connection refused"
- No Prometheus pods running

**Fix:**
```powershell
# 1. Check if Prometheus CRD exists
kubectl get crd prometheuses.monitoring.coreos.com

# 2. If missing, install CRDs (see Step 1 above)
kubectl apply --server-side -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/v0.68.0/example/prometheus-operator-crd/monitoring.coreos.com_prometheuses.yaml

# 3. Check if Prometheus CR exists
kubectl get prometheus.monitoring.coreos.com -n monitoring

# 4. If missing, recreate the ArgoCD application (it will resync monitoring)
kubectl delete application monitoring-stack -n argocd --ignore-not-found
kubectl apply -f monitor-app.yaml
argocd app wait monitoring-stack --timeout 600

# 5. Wait for Prometheus to start (1-2 minutes)
Start-Sleep -Seconds 90
kubectl get pods -n monitoring | Select-String "prometheus" | Select-String -NotMatch "node-exporter|operator"
```

#### Issue 2: Multiple Datasources Marked as Default

**Symptoms:**
- Error: "Only one datasource per organization can be marked as default"
- Grafana fails to load datasources

**Fix:**
```powershell
# The Loki datasource config has been fixed in logging.yaml
# Restart Grafana to pick up the fix
kubectl rollout restart deployment monitoring-stack-grafana -n monitoring

# Wait for Grafana to restart
kubectl get pods -n monitoring | Select-String "grafana"
```

#### Issue 3: "Failed to upgrade legacy queries Datasource was not found"

**Symptoms:**
- Error message: "Failed to upgrade legacy queries Datasource was not found"
- Dashboard shows errors when loading
- Queries fail to execute

**Causes:**
- Dashboard references a datasource by old ID/name that doesn't exist
- Datasource UID changed but dashboard wasn't updated
- Multiple datasource ConfigMaps causing conflicts

**Fix:**
```powershell
# 1. Verify datasources are properly configured (should show both Prometheus and Loki)
kubectl get configmap monitoring-stack-kube-prom-grafana-datasource -n monitoring -o jsonpath='{.data.datasource\.yaml}'

# 2. Ensure only ONE datasource ConfigMap exists (the merged one)
kubectl get configmap -n monitoring -l grafana_datasource="1"

# 3. Restart Grafana to reload datasources
kubectl rollout restart deployment monitoring-stack-grafana -n monitoring

# 4. Wait for Grafana to restart
Start-Sleep -Seconds 30
kubectl get pods -n monitoring | Select-String "grafana"

# 5. If error persists, manually fix dashboard:
#    - Open Grafana UI
#    - Go to Dashboard Settings > Variables (if using templating)
#    - Update datasource references to use UID: "prometheus" or "loki"
#    - Or delete and re-import the problematic dashboard
```

#### Issue 4: Verify Everything is Working

```powershell
# 1. Check Prometheus is running
kubectl get pods -n monitoring | Select-String "prometheus" | Select-String -NotMatch "node-exporter|operator"
# Should show: prometheus-monitoring-stack-kube-prom-prometheus-0 (2/2 Running)

# 2. Check Grafana can reach Prometheus
kubectl exec -n monitoring deployment/monitoring-stack-grafana -c grafana -- wget -qO- http://monitoring-stack-kube-prom-prometheus.monitoring:9090/-/healthy

# 3. Verify both datasources exist
kubectl get configmap monitoring-stack-kube-prom-grafana-datasource -n monitoring -o jsonpath='{.data.datasource\.yaml}' | Select-String -Pattern "name:"

# 4. Check Grafana logs for errors
kubectl logs -n monitoring deployment/monitoring-stack-grafana -c grafana --tail=50 | Select-String "error"
```

### Step 10: Verify Centralized Logging

```powershell
# Check Loki pods
kubectl get pods -n monitoring | Select-String "loki"
# Should show: loki-stack-0 (1/1 Running)

# Check Promtail pods (log collectors on each node)
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail
# OR use: kubectl get pods -n monitoring | Select-String "promtail"
# Should show: loki-stack-promtail-xxxxx (1/1 Running on each node)

# Verify Loki data source in Grafana
Write-Host "1. Open Grafana: http://$GRAFANA_URL"
Write-Host "2. Go to: Explore (compass icon)"
Write-Host "3. Select: Loki data source"
Write-Host "4. Query: {namespace='default'}"
Write-Host "5. You should see logs from all services"
```

### Step 10: Verify Load Test Completed Successfully

```powershell
# Check if load test results exist
if (Test-Path "load-testing\load-test-summary.json") {
    Write-Host "✅ Load test completed successfully"
    Write-Host "Results saved in: load-testing\load-test-summary.json"
} else {
    Write-Host "⚠️  Load test not run yet. Run: cd load-testing; .\run-load-test.ps1"
}

# Verify HPA scaling worked
kubectl get hpa
Write-Host "Check if booking-hpa and user-hpa show REPLICAS > 2 during load test"
```

---

## Cleanup (Destroy Everything)

### Step 1: Stop Dataproc Job

```powershell
# List active jobs
gcloud dataproc jobs list --project=$GCP_PROJECT_ID --region=$GCP_REGION --cluster=$DATAPROC_CLUSTER --filter="status.state=ACTIVE"

# Cancel job if running
gcloud dataproc jobs cancel $JOB_ID --project=$GCP_PROJECT_ID --region=$GCP_REGION
```

### Step 2: Destroy GCP Infrastructure

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\gcp"

terraform destroy
# Type 'yes' when prompted
```

### Step 3: Delete Kubernetes Resources

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"

# Delete all services
kubectl delete -f k8s-gitops/apps/frontend.yaml
kubectl delete -f k8s-gitops/apps/booking-service.yaml
kubectl delete -f k8s-gitops/apps/event-catalog.yaml
kubectl delete -f k8s-gitops/apps/user-service.yaml

# Remove ArgoCD apps (GitOps resources)
argocd app delete ticket-booking-app --yes
argocd app delete monitoring-stack --yes
argocd app delete loki-stack --yes
argocd app delete monitoring-servicemonitors --yes

# Delete ArgoCD manifests (optional if stored elsewhere)
kubectl delete -f argocd-app.yaml --ignore-not-found
kubectl delete -f monitor-app.yaml --ignore-not-found
kubectl delete -f loki-app.yaml --ignore-not-found
kubectl delete -f monitoring-servicemonitors-app.yaml --ignore-not-found

# Delete ArgoCD itself (if installed)
kubectl delete namespace argocd

# Verify everything is deleted
kubectl get all
kubectl get all -n monitoring
```

### Step 4: Remove MSK Security Group Rule (if added)

```powershell
# Get security group ID
$SG_ID = aws ec2 describe-security-groups --filters "Name=group-name,Values=ticket-booking-kafka-sg" --query "SecurityGroups[0].GroupId" --output text

# Remove the ingress rule we added (if you know the rule ID)
# aws ec2 revoke-security-group-ingress --group-id $SG_ID --protocol tcp --port 9092 --cidr 0.0.0.0/0
```

### Step 5: Delete Docker Images from ECR (Optional)

```powershell
# List repositories
aws ecr describe-repositories --query "repositories[?contains(repositoryName, 'ticket-booking')].repositoryName"

# Delete images (optional - Terraform will delete repositories)
# aws ecr batch-delete-image --repository-name ticket-booking/frontend --image-ids imageTag=latest
# aws ecr batch-delete-image --repository-name ticket-booking/booking-service --image-ids imageTag=latest
# aws ecr batch-delete-image --repository-name ticket-booking/event-catalog --image-ids imageTag=latest
# aws ecr batch-delete-image --repository-name ticket-booking/user-service --image-ids imageTag=latest
```

### Step 6: Destroy AWS Infrastructure

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\aws"

terraform destroy
# Type 'yes' when prompted
```

**⚠️ WARNING:** This will delete:
- EKS cluster
- MSK cluster
- RDS database
- S3 bucket
- Lambda function
- ECR repositories
- VPC and all networking
- All other AWS resources

**Wait for completion** (this takes 15-20 minutes)

### Step 7: Verify Everything is Deleted

```powershell
# Check EKS clusters
aws eks list-clusters

# Check MSK clusters
aws kafka list-clusters

# Check RDS instances
aws rds describe-db-instances

# Check S3 buckets
aws s3 ls | Select-String "ticket-booking"

# Check Lambda functions
aws lambda list-functions | Select-String "ticket"

# Check ECR repositories
aws ecr describe-repositories | Select-String "ticket-booking"

# Check GCP Dataproc clusters
gcloud dataproc clusters list --project=$GCP_PROJECT_ID --region=$GCP_REGION

# Check GCS buckets
gsutil ls | Select-String "flink-jobs"
```

---

## Quick Reference Commands

### Get All Outputs at Once

```powershell
# AWS
cd infrastructure\aws
terraform output

# GCP
cd infrastructure\gcp
terraform output
```

### Check Pod Logs

```powershell
# Frontend
kubectl logs -l app=frontend --tail=50

# Booking Service
kubectl logs -l app=booking-service --tail=50

# Event Catalog
kubectl logs -l app=event-catalog --tail=50

# User Service
kubectl logs -l app=user-service --tail=50
```

### Restart a Deployment

```powershell
kubectl rollout restart deployment/frontend
kubectl rollout restart deployment/booking-service
kubectl rollout restart deployment/event-catalog
kubectl rollout restart deployment/user-service
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

### Access Flink Web UI

```powershell
# SSH tunnel to Dataproc master
gcloud compute ssh $DATAPROC_CLUSTER-m `
  --project=$GCP_PROJECT_ID `
  --zone=$GCP_ZONE `
  --ssh-flag="-L 8081:localhost:8081"

# Then open http://localhost:8081 in browser
```

---

## Troubleshooting Commands

### If Terraform State File Not Found

**Error:** `No state file was found! State management commands require a state file.`

**Solution:**

```powershell
# This error occurs when running terraform commands from the wrong directory
# Terraform looks for terraform.tfstate in the current directory

# For AWS resources, you MUST be in the AWS Terraform directory:
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\aws"
terraform state list

# For GCP resources, you MUST be in the GCP Terraform directory:
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\gcp"
terraform state list

# Quick check: Verify you're in the right directory
Get-Location
# Should show: ...\infrastructure\aws (for AWS) or ...\infrastructure\gcp (for GCP)
```

### If kubectl Connection Fails

```powershell
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
kubectl get nodes
```

### If Pods Not Starting

```powershell
# Describe pod
kubectl describe pod <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### If Services Not Accessible

```powershell
# Check endpoints
kubectl get endpoints

# Test from inside cluster
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Inside pod: wget -O- http://frontend-service:80/health
```

### If Lambda Not Triggering

```powershell
# Check S3 bucket notification
aws s3api get-bucket-notification-configuration --bucket $S3_BUCKET

# Check Lambda logs
aws logs tail /aws/lambda/ticket-generator-func --follow
```

### If Dataproc Job Fails

```powershell
# Check cluster status
gcloud dataproc clusters describe $DATAPROC_CLUSTER --project=$GCP_PROJECT_ID --region=$GCP_REGION

# Check job logs
gcloud dataproc jobs describe $JOB_ID --project=$GCP_PROJECT_ID --region=$GCP_REGION
```

### If Python SyntaxError: Non-ASCII character

**Error:** `SyntaxError: Non-ASCII character '\xf0' in file /tmp/analytics_job.py on line 20, but no encoding declared`

**Solution:**

The file contains emojis or special characters. The encoding declaration has been added to `analytics_job.py`. If you still see this error:

1. **Re-upload the fixed file:**
   ```powershell
   cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\analytics-service"
   gsutil cp analytics_job.py "gs://$GCS_BUCKET/flink-jobs/analytics_job.py"
   ```

2. **Or remove emojis from print statements** (if encoding declaration doesn't work):
   - Edit `analytics_job.py`
   - Replace `🚀` with `>>>` or remove it entirely
   - Re-upload and resubmit

### If Cannot Connect to Kafka from Dataproc

```powershell
# Test connectivity
gcloud compute ssh $DATAPROC_CLUSTER-m `
  --project=$GCP_PROJECT_ID `
  --zone=$GCP_ZONE `
  --command="telnet b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com 9092"
```

### If gsutil or gcloud Not Found (Windows)

**Error:** `FileNotFoundError: [WinError 2] The system cannot find the file specified`

**Solution:**

```powershell
# 1. Check if Google Cloud SDK is installed
#    Default locations on Windows:
#    - C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk
#    - C:\Users\<username>\AppData\Local\Google\Cloud SDK\google-cloud-sdk

# 2. Add to PATH (PowerShell - current session only)
$env:Path += ";C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin"
# Or if in user directory:
# $env:Path += ";$env:LOCALAPPDATA\Google\Cloud SDK\google-cloud-sdk\bin"

# 3. Verify
gsutil --version
gcloud --version

# 4. If still not found, install Google Cloud SDK:
#    Download from: https://cloud.google.com/sdk/docs/install
#    Or use: winget install Google.CloudSDK

# 5. Alternative: Use full path
& "C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin\gsutil.cmd" cp analytics_job.py "gs://$GCS_BUCKET/flink-jobs/analytics_job.py"
```

### If kubectl run Times Out

**Error:** `error: timed out waiting for the condition` when running `kubectl run`

**Solution:**

```powershell
# 1. Use a smaller/lighter image
# Instead of bitnami/kafka:latest (large image), use:
kubectl run -it --rm kafka-test --image=confluentinc/cp-kafka:latest --restart=Never --timeout=300s -- bash

# 2. Or use Python image (much smaller)
kubectl run -it --rm kafka-test --image=python:3.9-slim --restart=Never --timeout=300s -- bash

# 3. Check if pod is actually running (in another terminal)
kubectl get pods | Select-String "kafka-test"

# 4. If pod is stuck in ImagePullBackOff, check node resources
kubectl describe nodes

# 5. Alternative: Use an existing pod that already has Kafka libraries
# (e.g., booking-service pod)
$POD_NAME = kubectl get pods -l app=booking-service -o jsonpath='{.items[0].metadata.name}'
kubectl exec -it $POD_NAME -- bash
```

### If MSK Security Group Not Found

**Error:** `Security Group ID: None` or security group not found

**Solution:**

```powershell
# 1. Verify AWS infrastructure is deployed
# IMPORTANT: Must be in the Terraform directory!
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\aws"
terraform output msk_security_group_id

# 2. If output is empty, check if Terraform was applied
# (Must be in infrastructure/aws directory for this to work)
terraform state list | Select-String "kafka"

# 3. If resources don't exist, apply Terraform first
terraform apply

# 4. Verify you're in the correct region
aws configure get region
# Should be: us-east-1

# 5. List all security groups to verify
aws ec2 describe-security-groups --region $AWS_REGION --query "SecurityGroups[*].{Name:GroupName, ID:GroupId, VPC:VpcId}" --output table

# 6. If security group exists but query fails, try filtering by VPC
# First get VPC ID from Terraform
$VPC_ID = terraform output -raw vpc_id  # Add this output if not exists
$SG_ID = aws ec2 describe-security-groups --filters "Name=group-name,Values=ticket-booking-kafka-sg" "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[0].GroupId" --output text --region $AWS_REGION
```

---

## Estimated Time

| Step | Estimated Time |
|------|----------------|
| AWS Infrastructure | 15-20 minutes |
| Build & Push Images | 5-10 minutes |
| Kubernetes Deployment | 5 minutes |
| Monitoring Stack | 3-5 minutes |
| Centralized Logging | 3-5 minutes |
| GCP Infrastructure | 10-15 minutes |
| Dataproc Job Submission | 2-3 minutes |
| Load Testing | 15-20 minutes |
| **Total Setup Time** | **58-83 minutes** |
| Cleanup | 20-30 minutes |

---

## Important Notes

1. **AWS Account ID**: Replace `YOUR_AWS_ACCOUNT_ID` with your actual AWS account ID throughout
2. **GCP Project ID**: Replace `your-gcp-project-id` with your actual GCP project ID
3. **MSK Security Group**: The rule allowing `0.0.0.0/0` is only for demo. In production, use VPN or specific IPs
4. **Database Password**: The password `CHANGE_ME_PASSWORD` is hardcoded for demo. Use Kubernetes Secrets in production
5. **Resource Costs**: Running these resources incurs costs. Destroy when not in use
6. **Region Consistency**: Ensure all resources are in the same region (us-east-1 for AWS, us-central1 for GCP)

---

## Success Checklist

After completing all steps, verify:

### AWS Infrastructure
- [ ] All AWS resources created (EKS, MSK, RDS, S3, Lambda, ECR)
- [ ] All Docker images pushed to ECR
- [ ] All Kubernetes pods running
- [ ] Frontend accessible via LoadBalancer

### Kubernetes & GitOps
- [ ] All services healthy
- [ ] HPAs configured (booking-hpa, user-hpa)
- [ ] ArgoCD deployed and syncing

### Observability (Requirement g)
- [ ] Prometheus deployed and scraping metrics
- [ ] Grafana accessible with dashboards
- [ ] Loki deployed for centralized logging
- [ ] Promtail collecting logs from all pods
- [ ] Can view logs in Grafana Explore

### GCP & Analytics (Requirement e)
- [ ] GCP Dataproc cluster created
- [ ] Flink job submitted and running
- [ ] Analytics results appearing in Kafka topic

### Load Testing (Requirement h)
- [ ] k6 installed
- [ ] Load test executed successfully
- [ ] HPA scaled up during load test (2 → 8-10 pods)
- [ ] p95 latency < 500ms
- [ ] Error rate < 10%
- [ ] Load test results saved

### End-to-End
- [ ] End-to-end application test successful
- [ ] All 6 microservices functioning
- [ ] All assignment requirements satisfied

---

**Last Updated:** 2025-11-23  
**Status:** Complete setup guide with all assignment requirements

---

## 📝 Assignment Requirements Coverage

This setup guide implements ALL assignment requirements:

✅ **(a) IaC:** All infrastructure via Terraform (AWS + GCP)  
✅ **(b) 6 Microservices:** 4 EKS services + Lambda + GCP Dataproc  
✅ **(c) Managed K8s + HPAs:** EKS with 2 HPAs (booking, user)  
✅ **(d) GitOps:** ArgoCD with automated sync  
✅ **(e) Flink Stream Processing:** GCP Dataproc with windowed aggregation  
✅ **(f) Storage:** S3 + RDS + DynamoDB + GCS  
✅ **(g.1) Metrics:** Prometheus + Grafana with dashboards  
✅ **(g.2) Logging:** Loki + Promtail (centralized logging)  
✅ **(h) Load Testing:** k6 with HPA validation  

See `ASSIGNMENT_REQUIREMENTS_CHECKLIST.md` for detailed verification.

