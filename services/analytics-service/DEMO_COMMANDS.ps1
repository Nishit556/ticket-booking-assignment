# Demo Commands - Ready to Run
# These are the exact commands for your demo

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Demo Commands" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get cluster info
Push-Location "..\..\infrastructure\gcp"
$clusterName = terraform output -raw dataproc_cluster_name
$region = terraform output -raw gcp_region
$zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --format="value(config.gceClusterConfig.zoneUri)" 2>&1 | Out-String
$zone = $zoneUri.Trim().Split('/')[-1]
Pop-Location

Push-Location "..\..\infrastructure\aws"
$kafkaBrokers = terraform output -raw msk_brokers 2>$null
Pop-Location

Write-Host "Command 1: Show Flink job running" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
$cmd1 = "gcloud compute ssh $clusterName-m --zone=$zone --command='yarn application -list'"
Write-Host $cmd1 -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to run this command..." -ForegroundColor Cyan
Read-Host
Invoke-Expression $cmd1

Write-Host ""
Write-Host ""
Write-Host "Command 2: Show GCP cluster status" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
$cmd2 = "gcloud dataproc clusters describe $clusterName --region=$region"
Write-Host $cmd2 -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to run this command..." -ForegroundColor Cyan
Read-Host
Invoke-Expression $cmd2

Write-Host ""
Write-Host ""
Write-Host "Command 3: Show real data in Kafka" -ForegroundColor Yellow
Write-Host "----------------------------------------" -ForegroundColor Gray
Write-Host "NOTE: Make sure kafka-consumer-test pod exists!" -ForegroundColor Yellow
Write-Host ""

# Extract first broker for the command
$firstBroker = ($kafkaBrokers -split ',')[0]
$cmd3 = "kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server '$firstBroker' --topic ticket-bookings --from-beginning --max-messages 5"
Write-Host $cmd3 -ForegroundColor White
Write-Host ""
Write-Host "Press Enter to run this command..." -ForegroundColor Cyan
Read-Host
Invoke-Expression $cmd3

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Demo Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green

