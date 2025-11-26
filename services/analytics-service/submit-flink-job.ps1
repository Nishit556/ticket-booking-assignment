# PowerShell script to submit Flink job to GCP Dataproc
# Recommended for Windows users

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClusterName,
    
    [Parameter(Mandatory=$false)]
    [string]$Region = "us-central1",
    
    [Parameter(Mandatory=$true)]
    [string]$GcsBucket,
    
    [Parameter(Mandatory=$true)]
    [string]$KafkaBrokers
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "🚀 Submitting Flink Job to Dataproc" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Project ID: $ProjectId"
Write-Host "Cluster: $ClusterName"
Write-Host "Region: $Region"
Write-Host "GCS Bucket: $GcsBucket"
Write-Host "Kafka Brokers: $KafkaBrokers"
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check if gcloud and gsutil are available
$gcloudPath = Get-Command gcloud -ErrorAction SilentlyContinue
$gsutilPath = Get-Command gsutil -ErrorAction SilentlyContinue

if (-not $gcloudPath -or -not $gsutilPath) {
    Write-Host "❌ Error: gcloud or gsutil not found!" -ForegroundColor Red
    Write-Host "Please install Google Cloud SDK:" -ForegroundColor Yellow
    Write-Host "https://cloud.google.com/sdk/docs/install" -ForegroundColor Yellow
    exit 1
}

# Step 1: Upload job file to GCS
$jobFile = "analytics_job.py"
$gcsJobPath = "gs://$GcsBucket/flink-jobs/$jobFile"

Write-Host "📤 Step 1: Uploading job file to GCS..." -ForegroundColor Cyan
try {
    gsutil cp $jobFile $gcsJobPath
    Write-Host "✅ Upload complete: $gcsJobPath" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to upload job file!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

Write-Host ""

# Step 2: Submit the Flink job
Write-Host "📝 Step 2: Submitting Flink job to cluster..." -ForegroundColor Cyan
Write-Host ""

try {
    # Execute gcloud command directly (most reliable method)
    # Note: Using Start-Process to properly handle arguments
    
    $arguments = "dataproc jobs submit pyspark `"$gcsJobPath`" --cluster=`"$ClusterName`" --region=`"$Region`" --project=`"$ProjectId`" --properties=`"spark.pyspark.python=python3`" -- --kafka-brokers=`"$KafkaBrokers`""
    
    Write-Host "Executing:" -ForegroundColor Yellow
    Write-Host "gcloud $arguments" -ForegroundColor Gray
    Write-Host ""
    
    # Use cmd to execute (more reliable for complex commands)
    # Note: Use --kafka-brokers= (with equals sign) to pass as single argument
    $output = cmd /c "gcloud dataproc jobs submit pyspark `"$gcsJobPath`" --cluster=$ClusterName --region=$Region --project=$ProjectId --properties=spark.pyspark.python=python3 -- --kafka-brokers=$KafkaBrokers 2>&1"
    
    # Display output
    $output | ForEach-Object { Write-Host $_ }
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host "✅ Job Submitted Successfully!" -ForegroundColor Green
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        
        Write-Host "📊 Check job status:" -ForegroundColor Cyan
        Write-Host "  gcloud dataproc jobs list --cluster=$ClusterName --region=$Region --project=$ProjectId" -ForegroundColor White
        Write-Host ""
        
        Write-Host "📄 Get latest job ID:" -ForegroundColor Cyan
        Write-Host "  `$JOB_ID = gcloud dataproc jobs list --cluster=$ClusterName --region=$Region --project=$ProjectId --format='value(reference.jobId)' --limit=1" -ForegroundColor White
        Write-Host ""
        
        Write-Host "📋 View job logs:" -ForegroundColor Cyan
        Write-Host "  gcloud dataproc jobs describe `$JOB_ID --region=$Region --project=$ProjectId" -ForegroundColor White
        Write-Host ""
    } else {
        throw "gcloud command failed with exit code $LASTEXITCODE"
    }
    
} catch {
    Write-Host ""
    Write-Host "❌ Job submission failed!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Yellow
    Write-Host "1. Verify cluster is running:" -ForegroundColor White
    Write-Host "   gcloud dataproc clusters describe $ClusterName --region=$Region --project=$ProjectId" -ForegroundColor Gray
    Write-Host "2. Check cluster logs in GCP Console" -ForegroundColor White
    Write-Host "3. Verify init script ran successfully" -ForegroundColor White
    exit 1
}

