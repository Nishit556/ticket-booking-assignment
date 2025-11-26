# Correct Demo Commands - Copy and Paste These
# The cluster is in us-central1-f (not us-central1-c)

# Get the actual zone dynamically
$ZONE = gcloud dataproc clusters describe flink-analytics-cluster --region=us-central1 --project=YOUR_GCP_PROJECT_ID --format="value(config.gceClusterConfig.zoneUri)" | ForEach-Object { $_.Split('/')[-1] }
Write-Host "Cluster zone: $ZONE" -ForegroundColor Cyan
Write-Host ""

# ========================================
# Command 1: Show Flink job running
# ========================================
Write-Host "1. Showing Flink job running..." -ForegroundColor Yellow
gcloud compute ssh flink-analytics-cluster-m --zone=$ZONE --project=YOUR_GCP_PROJECT_ID --command="yarn application -list"
Write-Host ""

# ========================================
# Command 2: Show GCP cluster status
# ========================================
Write-Host "2. Showing GCP cluster status..." -ForegroundColor Yellow
gcloud dataproc clusters describe flink-analytics-cluster --region=us-central1 --project=YOUR_GCP_PROJECT_ID
Write-Host ""

# ========================================
# Command 3: Show real data in Kafka
# ========================================
Write-Host "3. Showing real data in Kafka..." -ForegroundColor Yellow

# Get Kafka broker from AWS
Push-Location "infrastructure\aws"
$KAFKA_BROKER = (terraform output -raw msk_brokers).Split(',')[0].Trim()
Pop-Location

# Ensure pod exists
kubectl get pod kafka-consumer-test -n default -o name 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "Creating kafka-consumer-test pod..." -ForegroundColor Gray
    kubectl run kafka-consumer-test --image=confluentinc/cp-kafka:7.5.0 --restart=Never --namespace=default --command -- sh -c "tail -f /dev/null" 2>&1 | Out-Null
    Start-Sleep -Seconds 5
}

kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server "$KAFKA_BROKER" --topic ticket-bookings --from-beginning --max-messages 5

