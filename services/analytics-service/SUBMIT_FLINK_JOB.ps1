# Quick Flink Job Submission Script for Windows
# This script automates the job submission process

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flink Analytics Job Submission" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get Kafka Brokers from AWS
Write-Host "Step 1: Getting AWS Kafka Brokers..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\aws"
try {
    $kafkaBrokers = terraform output -raw msk_brokers
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get Kafka brokers"
    }
    Write-Host "✅ Kafka Brokers: $kafkaBrokers" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 2: Get GCP Configuration
Write-Host ""
Write-Host "Step 2: Getting GCP Configuration..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\gcp"
try {
    $gcpProject = terraform output -raw gcp_project_id
    $gcsBucket = terraform output -raw gcp_bucket_name
    $clusterName = terraform output -raw dataproc_cluster_name
    $region = terraform output -raw gcp_region
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get GCP configuration"
    }
    
    Write-Host "✅ GCP Project: $gcpProject" -ForegroundColor Green
    Write-Host "✅ GCS Bucket: $gcsBucket" -ForegroundColor Green
    Write-Host "✅ Cluster Name: $clusterName" -ForegroundColor Green
    Write-Host "✅ Region: $region" -ForegroundColor Green
} finally {
    Pop-Location
}

# Step 3: Verify analytics_job.py exists
Write-Host ""
Write-Host "Step 3: Verifying job file..." -ForegroundColor Yellow
if (-not (Test-Path "analytics_job.py")) {
    Write-Host "❌ ERROR: analytics_job.py not found!" -ForegroundColor Red
    Write-Host "Make sure you're running this from the analytics-service directory" -ForegroundColor Red
    exit 1
}
Write-Host "✅ Job file found" -ForegroundColor Green

# Step 4: Submit the job
Write-Host ""
Write-Host "Step 4: Submitting Flink job..." -ForegroundColor Yellow
Write-Host "This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

try {
    python submit-dataproc-job.py `
        --project-id "$gcpProject" `
        --cluster-name "$clusterName" `
        --region "$region" `
        --gcs-bucket "$gcsBucket" `
        --kafka-brokers "$kafkaBrokers"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Job submission failed"
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  ✅ Job Submitted Successfully!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Cyan
    Write-Host "1. Check Flink UI: Get master node IP from GCP Console" -ForegroundColor White
    Write-Host "   Access: http://<master-ip>:8081" -ForegroundColor White
    Write-Host ""
    Write-Host "2. Check job status:" -ForegroundColor White
    Write-Host "   gcloud dataproc jobs list --cluster=$clusterName --region=$region" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. Test by booking tickets through your frontend!" -ForegroundColor White
    
} catch {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  ❌ Job Submission Failed" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure gcloud CLI is installed and configured" -ForegroundColor White
    Write-Host "2. Check if Dataproc cluster is running in GCP Console" -ForegroundColor White
    Write-Host "3. Verify you have permissions to submit jobs" -ForegroundColor White
    exit 1
}

