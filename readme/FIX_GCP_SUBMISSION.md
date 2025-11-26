# 🔧 Fix GCP Job Submission - Quick Guide

**Issue Found:** PowerShell script had bash-style syntax that doesn't work in PowerShell

**Status:** ✅ FIXED

---

## ✅ The Fix

The `submit-flink-job.ps1` script has been updated. Run it again!

---

## 🚀 Complete Steps to Submit Job

### Step 1: Get the Correct Security Group ID

The error shows the old security group doesn't exist. Get the current one:

```powershell
# Navigate to AWS infrastructure directory
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\aws"

# Get current security group ID
$SG_ID = terraform output -raw msk_security_group_id

# Verify it's not empty
if ([string]::IsNullOrWhiteSpace($SG_ID)) {
    Write-Host "ERROR: No security group found. Is AWS infrastructure deployed?" -ForegroundColor Red
    exit 1
}

Write-Host "Security Group ID: $SG_ID" -ForegroundColor Green
```

### Step 2: Configure MSK Security Group

```powershell
# Add ingress rule (if not already added)
aws ec2 authorize-security-group-ingress `
  --group-id $SG_ID `
  --protocol tcp `
  --port 9092 `
  --cidr 0.0.0.0/0 `
  --region us-east-1

# Note: If you get "already exists" error, that's OK! Rule is already there.

# Verify the rule
aws ec2 describe-security-groups `
  --group-ids $SG_ID `
  --region us-east-1 `
  --query "SecurityGroups[0].IpPermissions[?FromPort==\`9092\`]"
```

### Step 3: Get MSK Brokers

```powershell
# Still in infrastructure/aws directory
$MSK_BROKERS = terraform output -raw msk_brokers
Write-Host "MSK Brokers: $MSK_BROKERS" -ForegroundColor Green
```

### Step 4: Submit the Flink Job (Using Fixed Script)

```powershell
# Navigate to analytics service directory
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\analytics-service"

# Run the FIXED PowerShell script
.\submit-flink-job.ps1 `
  -ProjectId "YOUR_GCP_PROJECT_ID" `
  -ClusterName "flink-analytics-cluster" `
  -Region "us-central1" `
  -GcsBucket "YOUR_GCP_PROJECT_ID-flink-jobs" `
  -KafkaBrokers $MSK_BROKERS
```

---

## ✅ Expected Output

You should see:

```
==========================================
🚀 Submitting Flink Job to Dataproc
==========================================
Project ID: YOUR_GCP_PROJECT_ID
Cluster: flink-analytics-cluster
Region: us-central1
GCS Bucket: YOUR_GCP_PROJECT_ID-flink-jobs
Kafka Brokers: b-1...amazonaws.com:9092,b-2...amazonaws.com:9092
==========================================

📤 Step 1: Uploading job file to GCS...
✅ Upload complete: gs://YOUR_GCP_PROJECT_ID-flink-jobs/flink-jobs/analytics_job.py

📝 Step 2: Submitting Flink job to cluster...
Executing: gcloud dataproc jobs submit pyspark ...

Job [xxxxx-xxxxx-xxxxx] submitted.
Waiting for job output...
...

==========================================
✅ Job Submitted Successfully!
==========================================
```

---

## 🐛 If You Still Get Errors

### Error: "Cluster not found"

**Check if cluster exists:**
```powershell
gcloud dataproc clusters list --region=us-central1 --project=YOUR_GCP_PROJECT_ID
```

**If empty, deploy cluster:**
```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\gcp"
terraform apply
```

### Error: "gsutil: command not found"

**Add Google Cloud SDK to PATH:**
```powershell
# Find where gcloud is installed
$gcloudPath = (Get-Command gcloud).Source
$sdkPath = Split-Path (Split-Path $gcloudPath)

# Add to PATH for current session
$env:Path += ";$sdkPath\bin"

# Verify
gsutil --version
```

### Error: "Permission denied"

**Re-authenticate:**
```powershell
gcloud auth login
gcloud auth application-default login
```

---

## 🧪 Verify Job is Running

```powershell
# List jobs
gcloud dataproc jobs list `
  --cluster=flink-analytics-cluster `
  --region=us-central1 `
  --project=YOUR_GCP_PROJECT_ID

# Expected: STATUS = RUNNING or DONE
```

### Get Job Details

```powershell
# Get latest job ID
$JOB_ID = gcloud dataproc jobs list `
  --cluster=flink-analytics-cluster `
  --region=us-central1 `
  --project=YOUR_GCP_PROJECT_ID `
  --format="value(reference.jobId)" `
  --limit=1

Write-Host "Job ID: $JOB_ID"

# View job details
gcloud dataproc jobs describe $JOB_ID `
  --region=us-central1 `
  --project=YOUR_GCP_PROJECT_ID
```

### View in GCP Console

```powershell
# Open in browser
Start-Process "https://console.cloud.google.com/dataproc/jobs?project=YOUR_GCP_PROJECT_ID&region=us-central1"
```

---

## 📊 Test the Analytics Pipeline

### 1. Make Some Bookings

```powershell
# Get frontend URL
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
$FRONTEND_URL = kubectl get svc frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Write-Host "Open: http://$FRONTEND_URL"
Start-Process "http://$FRONTEND_URL"

# Make 3-5 bookings
# Wait 1 minute for the window to close
```

### 2. Check Analytics Results

```powershell
# Check if results are appearing in Kafka
kubectl run -it --rm kafka-test --image=confluentinc/cp-kafka:latest --restart=Never -- bash

# Inside the pod:
kafka-console-consumer \
  --bootstrap-server b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092 \
  --topic analytics-results \
  --from-beginning \
  --max-messages 10
```

**Expected Output:**
```json
{"event_id":"event-001","window_end":"2025-11-23T10:01:00.000Z","total_tickets":5}
{"event_id":"event-002","window_end":"2025-11-23T10:01:00.000Z","total_tickets":3}
```

---

## ✅ Success Checklist

- [ ] Security group rule added (or already exists)
- [ ] Job submitted without errors
- [ ] Job status shows RUNNING or DONE
- [ ] Can see job in GCP Console
- [ ] Made test bookings via frontend
- [ ] Analytics results appear in `analytics-results` topic

---

**Last Updated:** 2025-11-23  
**Status:** ✅ Ready to use!

