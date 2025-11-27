# Quick Fix for gcloud Authentication Issue

## The Problem
The diagnostic script shows: "Could not check cluster status (may be a gcloud configuration issue)"

## Quick Fix Steps

### Option 1: Run the Fix Script (Easiest)
```powershell
cd services\analytics-service
.\FIX_GCLOUD_AUTH.ps1
```

This script will:
- Check your authentication
- Set the correct project
- Test cluster access
- Tell you if the cluster is ready

### Option 2: Manual Fix

#### Step 1: Authenticate
```powershell
gcloud auth login
```

#### Step 2: Set the Project
```powershell
gcloud config set project YOUR_GCP_PROJECT_ID
```

#### Step 3: Verify Cluster Exists
```powershell
gcloud dataproc clusters list --region=us-central1
```

If you see `flink-analytics-cluster` in the list, you're good!

If the cluster doesn't exist, create it:
```powershell
cd infrastructure\gcp
terraform apply
```

## After Fixing

Once authentication is fixed, run the diagnostic again:
```powershell
.\DIAGNOSE_FLINK.ps1
```

Then submit the job:
```powershell
.\SUBMIT_FLINK_JOB_FIXED.ps1
```

## Common Issues

### "No active authentication"
**Fix:** Run `gcloud auth login` and follow the browser prompt

### "Cluster not found"
**Fix:** The cluster may not exist. Run:
```powershell
cd infrastructure\gcp
terraform apply
```

### "Permission denied"
**Fix:** You may need additional IAM roles. Check with your GCP admin or add:
- `roles/dataproc.worker`
- `roles/compute.instanceAdmin.v1`
- `roles/storage.objectAdmin`

