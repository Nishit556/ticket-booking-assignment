# Simple Kafka Consumer Script
# This creates a temporary job to consume Kafka messages

param(
    [string]$Topic = "ticket-bookings",
    [int]$MaxMessages = 5
)

$BROKERS = "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092"

Write-Host "Creating Kafka consumer job..." -ForegroundColor Yellow

# Delete any existing job
kubectl delete job kafka-consumer-job -n default --ignore-not-found=true
Start-Sleep -Seconds 2

# Create a job with a lightweight image
$jobYaml = @"
apiVersion: batch/v1
kind: Job
metadata:
  name: kafka-consumer-job
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: kafka-consumer
        image: confluentinc/cp-kafka:7.5.0
        command:
        - sh
        - -c
        - |
          kafka-console-consumer \
            --bootstrap-server $BROKERS \
            --topic $Topic \
            --from-beginning \
            --max-messages $MaxMessages
      restartPolicy: Never
  backoffLimit: 1
"@

$jobYaml | kubectl apply -f -

Write-Host "Waiting for job to complete..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Wait for job to finish (max 60 seconds)
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    $jobStatus = kubectl get job kafka-consumer-job -n default -o jsonpath='{.status.conditions[0].type}' 2>$null
    if ($jobStatus -eq "Complete") {
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
}

# Get logs
Write-Host "`nKafka Messages:" -ForegroundColor Green
Write-Host "=================" -ForegroundColor Green
kubectl logs -n default -l job-name=kafka-consumer-job --tail=50

Write-Host "`nCleaning up job..." -ForegroundColor Yellow
kubectl delete job kafka-consumer-job -n default

