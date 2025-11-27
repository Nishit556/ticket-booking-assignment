# Flink Setup Diagnostic Script
# This script checks your Flink/Dataproc setup and identifies issues

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flink Setup Diagnostic Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check GCP Configuration
Write-Host "Step 1: Checking GCP Configuration..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\gcp"
try {
    $gcpProject = terraform output -raw gcp_project_id 2>$null
    $gcsBucket = terraform output -raw gcp_bucket_name 2>$null
    $clusterName = terraform output -raw dataproc_cluster_name 2>$null
    $region = terraform output -raw gcp_region 2>$null
    
    if ($gcpProject -and $gcsBucket -and $clusterName -and $region) {
        Write-Host "✅ GCP Project: $gcpProject" -ForegroundColor Green
        Write-Host "✅ GCS Bucket: $gcsBucket" -ForegroundColor Green
        Write-Host "✅ Cluster Name: $clusterName" -ForegroundColor Green
        Write-Host "✅ Region: $region" -ForegroundColor Green
    } else {
        Write-Host "❌ ERROR: Could not get GCP configuration from Terraform" -ForegroundColor Red
        Write-Host "   Make sure you've run 'terraform apply' in infrastructure/gcp" -ForegroundColor Yellow
        Pop-Location
        exit 1
    }
} catch {
    Write-Host "❌ ERROR: Failed to read Terraform outputs" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

Write-Host ""

# Step 2: Check if gcloud is available
Write-Host "Step 2: Checking gcloud CLI..." -ForegroundColor Yellow
$gcloudPath = Get-Command gcloud -ErrorAction SilentlyContinue
if ($gcloudPath) {
    Write-Host "✅ gcloud CLI found" -ForegroundColor Green
    $gcloudVersion = gcloud --version 2>$null | Select-Object -First 1
    Write-Host "   $gcloudVersion" -ForegroundColor Gray
} else {
    Write-Host "❌ ERROR: gcloud CLI not found!" -ForegroundColor Red
    Write-Host "   Install from: https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 3: Check if cluster exists and is running
Write-Host "Step 3: Checking Dataproc cluster status..." -ForegroundColor Yellow
try {
    # Use --format=value to avoid JSON parsing issues and Python path problems
    $clusterStatus = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(status.state)" 2>&1 | Out-String
    $clusterStatus = $clusterStatus.Trim()
    
    if ($LASTEXITCODE -eq 0 -and $clusterStatus) {
        if ($clusterStatus -eq "RUNNING") {
            Write-Host "✅ Cluster is RUNNING" -ForegroundColor Green
            # Get additional info without JSON parsing
            $masterCount = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(config.masterConfig.numInstances)" 2>&1 | Out-String
            $workerCount = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(config.workerConfig.numInstances)" 2>&1 | Out-String
            if ($masterCount) { Write-Host "   Master: $($masterCount.Trim()) instance(s)" -ForegroundColor Gray }
            if ($workerCount) { Write-Host "   Workers: $($workerCount.Trim()) instance(s)" -ForegroundColor Gray }
        } else {
            Write-Host "⚠️  Cluster status: $clusterStatus" -ForegroundColor Yellow
            Write-Host "   Cluster must be RUNNING to submit jobs" -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ ERROR: Cluster '$clusterName' not found or not accessible!" -ForegroundColor Red
        Write-Host "   Run: cd infrastructure\gcp && terraform apply" -ForegroundColor Yellow
        Write-Host "   Or check if gcloud is properly authenticated: gcloud auth login" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not check cluster status (may be a gcloud configuration issue)" -ForegroundColor Yellow
    Write-Host "   Try: gcloud auth login && gcloud config set project $gcpProject" -ForegroundColor Gray
}

Write-Host ""

# Step 4: Check if job file exists
Write-Host "Step 4: Checking job file..." -ForegroundColor Yellow
# Check in current directory (script should be run from analytics-service directory)
$currentDir = Get-Location
$jobFile = Join-Path $currentDir "analytics_job.py"
if (Test-Path $jobFile) {
    Write-Host "✅ analytics_job.py found" -ForegroundColor Green
    $fileSize = (Get-Item $jobFile).Length
    Write-Host "   Size: $fileSize bytes" -ForegroundColor Gray
    Write-Host "   Location: $jobFile" -ForegroundColor Gray
} else {
    Write-Host "❌ ERROR: analytics_job.py not found!" -ForegroundColor Red
    Write-Host "   Current directory: $currentDir" -ForegroundColor Yellow
    Write-Host "   Make sure you're running this from the services/analytics-service directory" -ForegroundColor Yellow
    Write-Host "   Expected location: $jobFile" -ForegroundColor Yellow
}

Write-Host ""

# Step 5: Check if job file is uploaded to GCS
Write-Host "Step 5: Checking if job file is in GCS..." -ForegroundColor Yellow
try {
    $gcsPath = "gs://$gcsBucket/flink-jobs/analytics_job.py"
    # Try gcloud storage first (works with newer Python versions)
    $gcsCheck = gcloud storage ls $gcsPath 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        # Fallback to gsutil
        $gcsCheck = gsutil ls $gcsPath 2>&1 | Out-String
    }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Job file exists in GCS: $gcsPath" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Job file not found in GCS" -ForegroundColor Yellow
        Write-Host "   Will be uploaded during submission" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️  Could not check GCS (will upload during submission)" -ForegroundColor Yellow
}

Write-Host ""

# Step 6: Check for running Flink jobs
Write-Host "Step 6: Checking for running Flink jobs..." -ForegroundColor Yellow
try {
    # Get cluster zone (use simpler format to avoid Python issues)
    $zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(config.gceClusterConfig.zoneUri)" 2>&1 | Out-String
    $zoneUri = $zoneUri.Trim()
    
    if ($LASTEXITCODE -eq 0 -and $zoneUri) {
        $zone = $zoneUri.Split('/')[-1]
        $masterNode = "$clusterName-m"
        
        Write-Host "   Attempting to check YARN applications on $masterNode..." -ForegroundColor Gray
        # Check YARN applications
        $yarnApps = gcloud compute ssh $masterNode --zone=$zone --project=$gcpProject --command="yarn application -list 2>/dev/null" 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $yarnApps -and $yarnApps -match "Flink") {
            Write-Host "✅ Flink job(s) found running on YARN" -ForegroundColor Green
            Write-Host $yarnApps -ForegroundColor Gray
        } elseif ($LASTEXITCODE -eq 0) {
            Write-Host "⚠️  No Flink jobs currently running" -ForegroundColor Yellow
            Write-Host "   This is normal if you haven't submitted a job yet" -ForegroundColor Gray
        } else {
            Write-Host "⚠️  Could not access cluster via SSH (may need to wait for cluster to be fully ready)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "⚠️  Could not get cluster zone (cluster may not be fully initialized)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not check for running jobs (cluster may not be accessible or still initializing)" -ForegroundColor Yellow
}

Write-Host ""

# Step 7: Check Kafka brokers
Write-Host "Step 7: Checking Kafka brokers..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\aws"
try {
    $kafkaBrokers = terraform output -raw msk_brokers 2>$null
    if ($kafkaBrokers) {
        Write-Host "✅ Kafka Brokers: $kafkaBrokers" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Could not get Kafka brokers from Terraform" -ForegroundColor Yellow
        Write-Host "   You'll need to provide them manually" -ForegroundColor Gray
    }
} catch {
    Write-Host "⚠️  Could not get Kafka brokers" -ForegroundColor Yellow
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Diagnostic Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. If cluster is not RUNNING, wait for it to start" -ForegroundColor White
Write-Host "2. Run the submission script: .\SUBMIT_FLINK_JOB_FIXED.ps1" -ForegroundColor White
Write-Host "3. Check job status with: gcloud dataproc jobs list --cluster=$clusterName --region=$region" -ForegroundColor White
Write-Host ""

