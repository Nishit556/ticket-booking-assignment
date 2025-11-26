# Setup Kafka Consumer Pod for Recording
# This script frees up cluster capacity and creates the kafka-consumer-test pod

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setting Up Kafka Consumer Pod" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Delete stuck/error pods
Write-Host "Step 1: Cleaning up stuck pods..." -ForegroundColor Yellow
kubectl delete pod kafka-consumer-test -n default --ignore-not-found=true | Out-Null
kubectl delete pod kafka-consumer -n default --ignore-not-found=true | Out-Null

# Delete pending user-service pods
$pendingPods = kubectl get pods -n default -o jsonpath='{.items[?(@.status.phase=="Pending")].metadata.name}' 2>$null
if ($pendingPods) {
    $pendingPods -split "`n" | ForEach-Object {
        if ($_ -and $_ -match "user-service|kafka") {
            Write-Host "  Deleting pending pod: $_" -ForegroundColor Gray
            kubectl delete pod $_ -n default --ignore-not-found=true | Out-Null
        }
    }
}

Write-Host "  Cleanup complete" -ForegroundColor Green
Write-Host ""

# Step 2: Scale down services temporarily
Write-Host "Step 2: Temporarily scaling down services..." -ForegroundColor Yellow
kubectl scale deployment user-service --replicas=2 -n default | Out-Null
kubectl scale deployment booking-service --replicas=2 -n default | Out-Null
Write-Host "  Services scaled down" -ForegroundColor Green
Write-Host ""

# Step 3: Wait for pods to terminate
Write-Host "Step 3: Waiting 30 seconds for pods to terminate..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
Write-Host ""

# Step 4: Create kafka-consumer-test pod
Write-Host "Step 4: Creating kafka-consumer-test pod..." -ForegroundColor Yellow
kubectl run kafka-consumer-test --image=confluentinc/cp-kafka:7.5.0 --restart=Never --namespace=default --command -- sh -c "tail -f /dev/null"

Write-Host "  Pod created" -ForegroundColor Green
Write-Host ""

# Step 5: Wait for pod to be ready
Write-Host "Step 5: Waiting for pod to be ready (this may take 1-2 minutes)..." -ForegroundColor Yellow
$timeout = 120
$elapsed = 0
$ready = $false

while ($elapsed -lt $timeout -and -not $ready) {
    $status = kubectl get pod kafka-consumer-test -n default -o jsonpath='{.status.phase}' 2>$null
    if ($status -eq "Running") {
        $ready = $true
        Write-Host "  Pod is Running!" -ForegroundColor Green
        break
    }
    Write-Host "  Status: $status (waiting...)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
    $elapsed += 5
}

Write-Host ""

# Step 6: Final status
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Final Status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
kubectl get pod kafka-consumer-test -n default
Write-Host ""

$finalStatus = kubectl get pod kafka-consumer-test -n default -o jsonpath='{.status.phase}' 2>$null
if ($finalStatus -eq "Running") {
    Write-Host "SUCCESS! Pod is ready." -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host ""
    Write-Host "You can now run your command:" -ForegroundColor Green
    Write-Host "kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server `"b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092`" --topic ticket-bookings --from-beginning --max-messages 5" -ForegroundColor Cyan
} else {
    Write-Host "NOT READY YET!" -ForegroundColor Red -BackgroundColor DarkRed
    Write-Host ""
    Write-Host "The pod is still in status: $finalStatus" -ForegroundColor Red
    Write-Host "The cluster may still be at capacity." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Use the script instead:" -ForegroundColor Yellow
    Write-Host ".\run-kafka-consumer.ps1" -ForegroundColor Cyan
}
Write-Host ""

