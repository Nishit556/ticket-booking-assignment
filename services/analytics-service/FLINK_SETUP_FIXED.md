# Flink Job Setup - Fixed Issues

## 🔧 What Was Fixed

### Issue 1: Job Not Executing
**Problem:** The `analytics_job.py` was defining SQL statements but not actually executing them.

**Fix:** Added `table_result.wait()` to keep the streaming job running. The `execute_sql()` method for INSERT statements returns a `TableResult` object, and calling `wait()` on it keeps the job running for streaming applications.

### Issue 2: Incorrect Submission Method
**Problem:** Some scripts were using `gcloud dataproc jobs submit pyspark` which is for Spark, not Flink.

**Fix:** Created `SUBMIT_FLINK_JOB_FIXED.ps1` which uses the correct method:
- SSH to master node
- Use `flink run -m yarn-cluster` command
- Properly passes Kafka broker arguments

### Issue 3: Missing Diagnostic Tools
**Problem:** No easy way to check if setup is correct before submitting.

**Fix:** Created `DIAGNOSE_FLINK.ps1` to check:
- GCP configuration
- Cluster status
- Job file existence
- Network connectivity

## 🚀 How to Use

### Step 1: Run Diagnostic
```powershell
cd services\analytics-service
.\DIAGNOSE_FLINK.ps1
```

This will tell you if everything is ready.

### Step 2: Submit Job
```powershell
.\SUBMIT_FLINK_JOB_FIXED.ps1
```

This will:
1. Get all configuration from Terraform
2. Upload job file to GCS
3. SSH to master node
4. Download Kafka connector (if needed)
5. Submit Flink job correctly

### Step 3: Verify Job is Running
```powershell
# Get cluster info
cd ..\..\infrastructure\gcp
$clusterName = terraform output -raw dataproc_cluster_name
$region = terraform output -raw gcp_region
$project = terraform output -raw gcp_project_id

# Get zone
$zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --project=$project --format="value(config.gceClusterConfig.zoneUri)"
$zone = $zoneUri.Split('/')[-1]

# Check YARN applications
gcloud compute ssh "$clusterName-m" --zone=$zone --project=$project --command="yarn application -list"
```

You should see a Flink application in RUNNING state.

## 📋 Key Changes Made

### analytics_job.py
- ✅ Added `table_result.wait()` to keep streaming job running
- ✅ Added print statements for better debugging

### SUBMIT_FLINK_JOB_FIXED.ps1 (NEW)
- ✅ Uses correct `flink run` command via SSH
- ✅ Automatically gets all config from Terraform
- ✅ Handles errors gracefully
- ✅ Provides clear next steps

### DIAGNOSE_FLINK.ps1 (NEW)
- ✅ Comprehensive diagnostic checks
- ✅ Clear error messages
- ✅ Suggests fixes for common issues

## 🔍 Troubleshooting

### "Cluster not found"
```powershell
cd infrastructure\gcp
terraform apply
```

### "Job submission fails"
1. Check cluster is RUNNING: `gcloud dataproc clusters list`
2. Check SSH access: `gcloud compute ssh <cluster-name>-m --zone=<zone>`
3. Check Kafka connectivity from GCP (MSK security group)

### "Job runs but no output"
1. Verify Kafka topics exist
2. Book tickets through frontend
3. Wait 1 minute for window to close
4. Check analytics-results topic

## 📚 Additional Resources

- **Quick Start Guide:** `QUICK_START_FLINK.md`
- **Full Documentation:** `README.md`
- **Demo Script:** `FLINK_AND_KAFKA_DEMO_SCRIPT.md`

## ✅ Success Checklist

- [ ] Diagnostic script shows all green checkmarks
- [ ] Cluster is in RUNNING state
- [ ] Job file uploaded to GCS
- [ ] Job submission completes without errors
- [ ] YARN shows Flink application running
- [ ] Flink UI accessible (optional)
- [ ] Data flows: ticket-bookings → analytics-results

## 🎯 Next Steps

1. Run diagnostic: `.\DIAGNOSE_FLINK.ps1`
2. Submit job: `.\SUBMIT_FLINK_JOB_FIXED.ps1`
3. Verify: Check YARN applications
4. Test: Book tickets and check analytics-results topic

Good luck! 🚀

