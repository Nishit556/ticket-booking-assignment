# Exact Demo Commands as Requested
# These commands use the actual values from your infrastructure

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Running Exact Demo Commands" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get actual values from infrastructure
Write-Host "Getting infrastructure values..." -ForegroundColor Yellow

# Get GCP values
Push-Location "infrastructure\gcp"
$GCP_PROJECT = terraform output -raw gcp_project_id
$CLUSTER_NAME = terraform output -raw dataproc_cluster_name
$REGION = terraform output -raw gcp_region
Pop-Location

# Get zone dynamically (actual zone may differ from us-central1-c)
$ZONE_URI = gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION --project=$GCP_PROJECT --format="value(config.gceClusterConfig.zoneUri)" 2>&1
$ZONE = $ZONE_URI.Split('/')[-1]

# Get Kafka broker (first one from the list)
Push-Location "infrastructure\aws"
$KAFKA_BROKERS = terraform output -raw msk_brokers 2>&1
Pop-Location
$KAFKA_BROKER = ($KAFKA_BROKERS -split ',')[0].Trim()

Write-Host "✅ Project: $GCP_PROJECT" -ForegroundColor Green
Write-Host "✅ Cluster: $CLUSTER_NAME" -ForegroundColor Green
Write-Host "✅ Region: $REGION" -ForegroundColor Green
Write-Host "✅ Zone: $ZONE" -ForegroundColor Green
Write-Host "✅ Kafka Broker: $KAFKA_BROKER" -ForegroundColor Green
Write-Host ""

# ========================================
# Command 1: Show Flink job running
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "1. Show Flink job running" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Command: gcloud compute ssh ${CLUSTER_NAME}-m --zone=$ZONE --command='yarn application -list'" -ForegroundColor Gray
Write-Host ""

gcloud compute ssh "${CLUSTER_NAME}-m" --zone=$ZONE --project=$GCP_PROJECT --command="yarn application -list"

Write-Host ""

# ========================================
# Command 2: Show GCP cluster status
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "2. Show GCP cluster status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Command: gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION" -ForegroundColor Gray
Write-Host ""

gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION --project=$GCP_PROJECT

Write-Host ""

# ========================================
# Command 3: Show real data in Kafka
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "3. Show real data in Kafka" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ensure kafka-consumer-test pod exists
Write-Host "Ensuring kafka-consumer-test pod exists..." -ForegroundColor Yellow
$podCheck = kubectl get pod kafka-consumer-test -n default -o name 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating kafka-consumer-test pod..." -ForegroundColor Yellow
    kubectl run kafka-consumer-test --image=confluentinc/cp-kafka:7.5.0 --restart=Never --namespace=default --command -- sh -c "tail -f /dev/null" 2>&1 | Out-Null
    Start-Sleep -Seconds 5
}

Write-Host ""
Write-Host "Command: kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server `"$KAFKA_BROKER`" --topic ticket-bookings --from-beginning --max-messages 5" -ForegroundColor Gray
Write-Host ""

kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server "$KAFKA_BROKER" --topic ticket-bookings --from-beginning --max-messages 5

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Commands Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

