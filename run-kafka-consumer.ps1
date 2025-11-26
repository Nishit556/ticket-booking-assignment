# Run Kafka Consumer Command - For Recording
# This creates a Job to consume Kafka messages

$BROKERS = "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092"
$TOPIC = "ticket-bookings"
$MAX_MESSAGES = 5

Write-Host "Creating Kafka consumer job..." -ForegroundColor Yellow

# Delete any existing job
kubectl delete job kafka-consumer-job -n default --ignore-not-found=true | Out-Null
Start-Sleep -Seconds 2

# Create job
kubectl create job kafka-consumer-job --image=confluentinc/cp-kafka:7.5.0 -n default -- kafka-console-consumer --bootstrap-server $BROKERS --topic $TOPIC --from-beginning --max-messages $MAX_MESSAGES

Write-Host "Waiting for job to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Wait for pod to be scheduled and running (max 120 seconds)
$timeout = 120
$elapsed = 0
$podRunning = $false
while ($elapsed -lt $timeout) {
    $podName = kubectl get pods -n default -l job-name=kafka-consumer-job -o jsonpath='{.items[0].metadata.name}' 2>$null
    if ($podName) {
        $podPhase = kubectl get pod $podName -n default -o jsonpath='{.status.phase}' 2>$null
        if ($podPhase -eq "Running") {
            $podRunning = $true
            Write-Host "Pod is running: $podName" -ForegroundColor Green
            break
        } elseif ($podPhase -eq "Pending") {
            Write-Host "Pod still pending... (waiting for cluster capacity)" -ForegroundColor Yellow
        }
    }
    Start-Sleep -Seconds 3
    $elapsed += 3
}

if (-not $podRunning) {
    Write-Host "Warning: Pod did not start within timeout. Checking status..." -ForegroundColor Red
}

# Wait for job completion (max 60 seconds after pod is running)
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    $status = kubectl get job kafka-consumer-job -n default -o jsonpath='{.status.conditions[0].type}' 2>$null
    if ($status -eq "Complete" -or $status -eq "Failed") {
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
}

# Check job and pod status
Write-Host ""
Write-Host "Job Status:" -ForegroundColor Yellow
kubectl get job kafka-consumer-job -n default
Write-Host ""

Write-Host "Pod Status:" -ForegroundColor Yellow
kubectl get pods -n default -l job-name=kafka-consumer-job
Write-Host ""

# Get pod name
$podName = kubectl get pods -n default -l job-name=kafka-consumer-job -o jsonpath='{.items[0].metadata.name}' 2>$null

if ($podName) {
    Write-Host "Pod Logs:" -ForegroundColor Yellow
    kubectl logs $podName -n default --tail=100
    Write-Host ""
    
    # Check if pod failed
    $podStatus = kubectl get pod $podName -n default -o jsonpath='{.status.containerStatuses[0].state}' 2>$null
    if ($podStatus -match "terminated|waiting") {
        Write-Host "Pod Events:" -ForegroundColor Yellow
        kubectl describe pod $podName -n default | Select-String -Pattern "Events:|Error:|Warning:" -Context 3
    }
} else {
    Write-Host "No pod found for job!" -ForegroundColor Red
}

# Show logs
Write-Host ""
Write-Host "Kafka Messages from ticket-bookings topic:" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
if ($podName) {
    kubectl logs $podName -n default --tail=100 2>&1
} else {
    Write-Host "No logs available - pod may not have started" -ForegroundColor Red
}

# Cleanup
Write-Host ""
Write-Host "Note: Job will remain for debugging. Delete manually with:" -ForegroundColor Gray
Write-Host "kubectl delete job kafka-consumer-job -n default" -ForegroundColor Gray

