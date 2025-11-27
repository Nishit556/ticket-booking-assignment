# Quick script to verify Flink job is running

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Verifying Flink Job Status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Push-Location "..\..\infrastructure\gcp"
try {
    $clusterName = terraform output -raw dataproc_cluster_name
    $region = terraform output -raw gcp_region
    $project = terraform output -raw gcp_project_id
    
    $zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --project=$project --format="value(config.gceClusterConfig.zoneUri)" 2>&1 | Out-String
    $zone = $zoneUri.Trim().Split('/')[-1]
    
    Write-Host "Cluster: $clusterName" -ForegroundColor Green
    Write-Host "Zone: $zone" -ForegroundColor Green
    Write-Host ""
    Write-Host "Checking YARN applications..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check YARN applications
    $yarnOutput = gcloud compute ssh "$clusterName-m" --zone=$zone --project=$project --command="yarn application -list" 2>&1
    
    if ($yarnOutput -match "Flink" -or $yarnOutput -match "application_") {
        Write-Host "✅ Flink job is RUNNING!" -ForegroundColor Green
        Write-Host ""
        Write-Host "YARN Applications:" -ForegroundColor Cyan
        # Filter out error messages and show only YARN output
        $yarnOutput | Where-Object { $_ -notmatch "python.exe" -and $_ -notmatch "CategoryInfo" -and $_ -notmatch "RemoteException" } | ForEach-Object { Write-Host $_ }
    } else {
        Write-Host "⚠️  Checking job status..." -ForegroundColor Yellow
        Write-Host $yarnOutput -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  Your Demo Commands" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Command 1 (Show Flink job):" -ForegroundColor Yellow
    Write-Host "  gcloud compute ssh $clusterName-m --zone=$zone --command='yarn application -list'" -ForegroundColor White
    Write-Host ""
    Write-Host "Command 2 (Show cluster status):" -ForegroundColor Yellow
    Write-Host "  gcloud dataproc clusters describe $clusterName --region=$region" -ForegroundColor White
    Write-Host ""
    Write-Host "Command 3 (Show Kafka data):" -ForegroundColor Yellow
    Push-Location "..\..\infrastructure\aws"
    $kafkaBrokers = terraform output -raw msk_brokers 2>$null
    Pop-Location
    $firstBroker = ($kafkaBrokers -split ',')[0]
    Write-Host "  kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server '$firstBroker' --topic ticket-bookings --from-beginning --max-messages 5" -ForegroundColor White
    Write-Host ""
    
} finally {
    Pop-Location
}

