# Create Kafka Consumer Pod for Demo

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Creating Kafka Consumer Pod" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if pod already exists
Write-Host "Checking if kafka-consumer-test pod exists..." -ForegroundColor Yellow
$podCheck = kubectl get pod kafka-consumer-test -n default 2>&1 | Out-String
$podExists = ($LASTEXITCODE -eq 0) -and ($podCheck -match "kafka-consumer-test" -and $podCheck -notmatch "NotFound")

if ($podExists) {
    Write-Host "✅ Pod already exists!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Pod status:" -ForegroundColor Cyan
    kubectl get pod kafka-consumer-test -n default
    Write-Host ""
    Write-Host "You can now use it for the demo command!" -ForegroundColor Green
} else {
    Write-Host "Pod not found. Creating it..." -ForegroundColor Yellow
    Write-Host ""
    
    # Create the pod
    Write-Host "Creating kafka-consumer-test pod..." -ForegroundColor Cyan
    Write-Host "Using confluentinc/cp-kafka image (more reliable)" -ForegroundColor Gray
    kubectl run kafka-consumer-test `
        --image=confluentinc/cp-kafka:latest `
        --namespace=default `
        --restart=Never `
        --command -- sleep 3600
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Pod created successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Waiting for pod to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        
        # Check pod status
        kubectl get pod kafka-consumer-test -n default
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  Pod Ready for Demo!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "You can now use this command in your demo:" -ForegroundColor Cyan
        Write-Host ""
        Push-Location "..\..\infrastructure\aws"
        $kafkaBrokers = terraform output -raw msk_brokers 2>$null
        Pop-Location
        $firstBroker = ($kafkaBrokers -split ',')[0]
        Write-Host "  kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server '$firstBroker' --topic ticket-bookings --from-beginning --max-messages 5" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "❌ Failed to create pod" -ForegroundColor Red
        Write-Host "Error details:" -ForegroundColor Yellow
        Write-Host $existingPod -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Note: This pod will stay running until you delete it." -ForegroundColor Gray
Write-Host "To delete after demo: kubectl delete pod kafka-consumer-test -n default" -ForegroundColor Gray
Write-Host ""

