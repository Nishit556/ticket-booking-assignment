# Prepare Demo - Submit Flink Job and Verify Everything Works
# Run this BEFORE your demo to ensure everything is ready

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Preparing for Demo" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Run diagnostic
Write-Host "Step 1: Running diagnostic check..." -ForegroundColor Yellow
.\DIAGNOSE_FLINK.ps1

Write-Host ""
Write-Host "Press Enter to continue with job submission, or Ctrl+C to exit..." -ForegroundColor Yellow
Read-Host

# Step 2: Submit Flink job
Write-Host ""
Write-Host "Step 2: Submitting Flink job..." -ForegroundColor Yellow
Write-Host "This will take a few minutes..." -ForegroundColor Gray
Write-Host ""

.\SUBMIT_FLINK_JOB_FIXED.ps1

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Job submission failed!" -ForegroundColor Red
    Write-Host "Please check the errors above and try again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Job Submitted!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Step 3: Wait a bit for job to start
Write-Host "Step 3: Waiting 30 seconds for job to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Step 4: Verify job is running
Write-Host ""
Write-Host "Step 4: Verifying job is running..." -ForegroundColor Yellow

Push-Location "..\..\infrastructure\gcp"
try {
    $clusterName = terraform output -raw dataproc_cluster_name
    $region = terraform output -raw gcp_region
    $project = terraform output -raw gcp_project_id
    
    $zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --project=$project --format="value(config.gceClusterConfig.zoneUri)" 2>&1 | Out-String
    $zone = $zoneUri.Trim().Split('/')[-1]
    
    Write-Host "   Checking YARN applications..." -ForegroundColor Gray
    $yarnOutput = gcloud compute ssh "$clusterName-m" --zone=$zone --project=$project --command="yarn application -list" 2>&1 | Out-String
    
    if ($yarnOutput -match "Flink") {
        Write-Host "✅ Flink job is RUNNING!" -ForegroundColor Green
        Write-Host ""
        Write-Host "YARN Applications:" -ForegroundColor Cyan
        Write-Host $yarnOutput -ForegroundColor Gray
    } else {
        Write-Host "⚠️  Flink job may still be starting..." -ForegroundColor Yellow
        Write-Host "   Wait a minute and check again with:" -ForegroundColor Gray
        Write-Host "   gcloud compute ssh $clusterName-m --zone=$zone --command='yarn application -list'" -ForegroundColor Gray
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Demo Preparation Complete!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Your demo commands are ready to run:" -ForegroundColor Green
Write-Host ""
Write-Host "1. Show Flink job running:" -ForegroundColor Yellow
Write-Host "   gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-c --command='yarn application -list'" -ForegroundColor White
Write-Host ""
Write-Host "2. Show GCP cluster status:" -ForegroundColor Yellow
Write-Host "   gcloud dataproc clusters describe flink-analytics-cluster --region=us-central1" -ForegroundColor White
Write-Host ""
Write-Host "3. Show real data in Kafka:" -ForegroundColor Yellow
Write-Host "   kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server 'b-1.ticketbookingkafka.o4jsuy.c8.kafka.us-east-1.amazonaws.com:9092' --topic ticket-bookings --from-beginning --max-messages 5" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Make sure the kafka-consumer-test pod exists before the demo!" -ForegroundColor Yellow
Write-Host "   If not, create it with:" -ForegroundColor Gray
Write-Host "   kubectl run kafka-consumer-test --image=bitnami/kafka --rm -it --restart=Never -- sleep 3600" -ForegroundColor Gray
Write-Host ""

