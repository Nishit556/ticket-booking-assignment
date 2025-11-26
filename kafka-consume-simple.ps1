# Simple Kafka Consumer - Matches your exact command
# This creates a Job and shows the output immediately

param(
    [string]$Topic = "ticket-bookings",
    [int]$MaxMessages = 5
)

$BROKERS = "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092"

Write-Host "Consuming from Kafka topic: $Topic" -ForegroundColor Yellow
Write-Host "Max messages: $MaxMessages" -ForegroundColor Yellow
Write-Host ""

# Delete any existing job
kubectl delete job kafka-consumer-job -n default --ignore-not-found=true | Out-Null
Start-Sleep -Seconds 2

# Create job
kubectl create job kafka-consumer-job --image=confluentinc/cp-kafka:7.5.0 -n default -- kafka-console-consumer --bootstrap-server $BROKERS --topic $Topic --from-beginning --max-messages $MaxMessages

Write-Host "Waiting for job to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Wait for completion (max 30 seconds)
$timeout = 30
$elapsed = 0
while ($elapsed -lt $timeout) {
    $status = kubectl get job kafka-consumer-job -n default -o jsonpath='{.status.conditions[0].type}' 2>$null
    if ($status -eq "Complete") {
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
}

# Show logs
Write-Host ""
Write-Host "Kafka Messages:" -ForegroundColor Green
Write-Host "===============" -ForegroundColor Green
kubectl logs -n default -l job-name=kafka-consumer-job --tail=50

# Cleanup
Write-Host ""
kubectl delete job kafka-consumer-job -n default --ignore-not-found=true | Out-Null

