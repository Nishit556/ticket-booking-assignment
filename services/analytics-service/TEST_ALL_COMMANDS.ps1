# Test All Three Demo Commands

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Testing All Demo Commands" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get configuration
Push-Location "..\..\infrastructure\gcp"
$clusterName = terraform output -raw dataproc_cluster_name
$region = terraform output -raw gcp_region
$zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --format="value(config.gceClusterConfig.zoneUri)" 2>&1 | Out-String
$zone = $zoneUri.Trim().Split('/')[-1]
Pop-Location

Push-Location "..\..\infrastructure\aws"
$kafkaBrokers = terraform output -raw msk_brokers 2>$null
$firstBroker = ($kafkaBrokers -split ',')[0]
Pop-Location

# Command 1
Write-Host "Command 1: Checking Flink job..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
$cmd1 = "gcloud compute ssh $clusterName-m --zone=$zone --command='yarn application -list'"
Write-Host "Running: $cmd1" -ForegroundColor Gray
Write-Host ""
$result1 = Invoke-Expression $cmd1 2>&1
if ($result1 -match "RUNNING" -or $result1 -match "Flink") {
    Write-Host "✅ Command 1: SUCCESS - Flink job is running" -ForegroundColor Green
} else {
    Write-Host "⚠️  Command 1: Check output above" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Press Enter to continue to Command 2..." -ForegroundColor Cyan
Read-Host

# Command 2
Write-Host ""
Write-Host "Command 2: Checking cluster status..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
$cmd2 = "gcloud dataproc clusters describe $clusterName --region=$region"
Write-Host "Running: $cmd2" -ForegroundColor Gray
Write-Host ""
$result2 = Invoke-Expression $cmd2 2>&1
if ($result2 -match "RUNNING" -or $result2 -match "state: RUNNING") {
    Write-Host "✅ Command 2: SUCCESS - Cluster is running" -ForegroundColor Green
} else {
    Write-Host "⚠️  Command 2: Check output above" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "Press Enter to continue to Command 3..." -ForegroundColor Cyan
Read-Host

# Command 3
Write-Host ""
Write-Host "Command 3: Checking Kafka data..." -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host "First, checking if kafka-consumer-test pod exists..." -ForegroundColor Gray
$podCheck = kubectl get pod kafka-consumer-test -n default 2>&1 | Out-String
if ($podCheck -match "NotFound") {
    Write-Host "❌ Pod doesn't exist. Creating it..." -ForegroundColor Red
    kubectl run kafka-consumer-test --image=bitnami/kafka:latest --namespace=default --restart=Never --command -- sleep 3600
    Write-Host "Waiting for pod to be ready..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
}

$cmd3 = "kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server '$firstBroker' --topic ticket-bookings --from-beginning --max-messages 5"
Write-Host "Running: $cmd3" -ForegroundColor Gray
Write-Host ""
Write-Host "Note: This may take a moment and may show no output if there's no data yet." -ForegroundColor Yellow
Write-Host ""

$result3 = Invoke-Expression $cmd3 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Command 3: SUCCESS - Kafka consumer works" -ForegroundColor Green
    if ($result3 -match "event_id" -or $result3 -match "ticket") {
        Write-Host "   Data found in Kafka!" -ForegroundColor Green
    } else {
        Write-Host "   No data yet - make some bookings through your frontend" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  Command 3: Check output above" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  All Commands Tested!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Summary:" -ForegroundColor Yellow
Write-Host "  Command 1: Flink job status" -ForegroundColor White
Write-Host "  Command 2: Cluster status" -ForegroundColor White
Write-Host "  Command 3: Kafka data" -ForegroundColor White
Write-Host ""
Write-Host "You're ready for your demo!" -ForegroundColor Green
Write-Host ""

