# 🚀 Run This Right Now - Complete GCP Setup

**Everything you need to run in order**

---

## Step 1: Run Verification Script

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\gcp"

# Run the auto-check script
.\VERIFY_AND_FIX.ps1
```

This will check everything and tell you what's wrong.

---

## Step 2: Apply Terraform (If Needed)

If the verification script says terraform needs to be applied:

```powershell
# Make sure you're in the GCP infrastructure directory
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\gcp"

# Apply
terraform apply

# Type 'yes' when prompted
# Wait 10-15 minutes
```

---

## Step 3: Wait for IAM Permissions (If Cluster Just Created)

```powershell
# Wait 3 minutes for IAM permissions to propagate
Write-Host "Waiting for IAM permissions to propagate..."
Start-Sleep -Seconds 180
Write-Host "Done!"
```

---

## Step 4: Verify Cluster is Running

```powershell
gcloud dataproc clusters describe flink-analytics-cluster `
  --region=us-central1 `
  --project=YOUR_GCP_PROJECT_ID `
  --format="value(status.state)"

# Should output: RUNNING
```

---

## Step 5: Submit the Flink Job

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\services\analytics-service"

# Use the simple script
.\SUBMIT_JOB.ps1
```

---

## Step 6: Check Job Status

```powershell
# List jobs
gcloud dataproc jobs list `
  --cluster=flink-analytics-cluster `
  --region=us-central1 `
  --project=YOUR_GCP_PROJECT_ID

# Should show: STATUS = RUNNING or DONE
```

---

## ✅ Success Checklist

Run through this checklist:

```powershell
# 1. Cluster exists and is RUNNING
gcloud dataproc clusters list --region=us-central1 --project=YOUR_GCP_PROJECT_ID

# 2. Job submitted successfully
gcloud dataproc jobs list --cluster=flink-analytics-cluster --region=us-central1 --project=YOUR_GCP_PROJECT_ID

# 3. View in GCP Console
Start-Process "https://console.cloud.google.com/dataproc/jobs?project=YOUR_GCP_PROJECT_ID&region=us-central1"
```

---

## 🐛 If Something Fails

### Error: "Cluster not found"
**Fix:**
```powershell
cd infrastructure\gcp
terraform apply
```

### Error: "ModuleNotFoundError: No module named 'pyflink'"
**Fix:**
```powershell
# Cluster was created with old init script, recreate it
cd infrastructure\gcp
terraform destroy -target=google_dataproc_cluster.flink_cluster
terraform apply
```

### Error: "Permission denied"  
**Fix:**
```powershell
# Wait for IAM permissions
Start-Sleep -Seconds 180
# Then retry terraform apply
```

### Error: "Cannot connect to Kafka"
**Fix:**
```powershell
cd ..\..\infrastructure\aws
$SG_ID = terraform output -raw msk_security_group_id
aws ec2 authorize-security-group-ingress --group-id $SG_ID --protocol tcp --port 9092 --cidr 0.0.0.0/0 --region us-east-1
```

---

## 📊 Test the Complete Pipeline

After job is running successfully:

### 1. Make Test Bookings

```powershell
# Get frontend URL
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
$FRONTEND_URL = kubectl get svc frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Start-Process "http://$FRONTEND_URL"

# Make 3-5 bookings
# Wait 1 minute
```

### 2. Check Analytics Results

```powershell
# Check Kafka topic for aggregated results
kubectl run -it --rm kafka-test --image=confluentinc/cp-kafka:latest --restart=Never -- bash

# Inside pod:
kafka-console-consumer \
  --bootstrap-server b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092 \
  --topic analytics-results \
  --from-beginning \
  --max-messages 10
```

**Expected Output:**
```json
{"event_id":"event-001","window_end":"2025-11-23T10:01:00.000Z","total_tickets":5}
```

---

## ✅ Done!

If you see analytics results in the Kafka topic, **everything is working correctly**!

Your GCP analytics service is now:
- ✅ Reading from AWS MSK Kafka
- ✅ Performing 1-minute windowed aggregations
- ✅ Writing results back to Kafka
- ✅ Running on GCP Dataproc (different cloud provider)

---

**Questions? Run the verification script again:**
```powershell
cd infrastructure\gcp
.\VERIFY_AND_FIX.ps1
```

