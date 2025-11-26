# Monitor HPA Scaling in Real-Time
# This script watches the HPA and pod count while load test is running

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HPA Scaling Monitor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Monitoring HPA and pod scaling..." -ForegroundColor Yellow
Write-Host "Press Ctrl+C to stop monitoring" -ForegroundColor Yellow
Write-Host ""

# Create a log file
$logFile = "load-testing/hpa-scaling-log.txt"
"HPA Scaling Log - $(Get-Date)" | Out-File -FilePath $logFile -Encoding UTF8

# Monitor loop
while ($true) {
    Clear-Host
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  HPA Scaling Monitor - $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Get HPA status
    Write-Host "HPA Status:" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Gray
    kubectl get hpa -n default
    
    Write-Host ""
    Write-Host "Pod Counts:" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Gray
    
    # Count pods for each service
    $bookingPods = (kubectl get pods -n default -l app=booking-service --no-headers 2>$null | Measure-Object).Count
    $userPods = (kubectl get pods -n default -l app=user-service --no-headers 2>$null | Measure-Object).Count
    $eventPods = (kubectl get pods -n default -l app=event-catalog --no-headers 2>$null | Measure-Object).Count
    $frontendPods = (kubectl get pods -n default -l app=frontend --no-headers 2>$null | Measure-Object).Count
    
    Write-Host "  Booking Service:  $bookingPods pods" -ForegroundColor White
    Write-Host "  User Service:     $userPods pods" -ForegroundColor White
    Write-Host "  Event Catalog:    $eventPods pods" -ForegroundColor White
    Write-Host "  Frontend:         $frontendPods pods" -ForegroundColor White
    
    Write-Host ""
    Write-Host "Resource Usage (Top 3 CPU-consuming pods):" -ForegroundColor Green
    Write-Host "==========================================" -ForegroundColor Gray
    $topOutput = kubectl top pods -n default --sort-by=cpu 2>$null
    if ($topOutput) {
        $topOutput | Select-Object -First 4
    } else {
        Write-Host "  Metrics not available (metrics-server may be initializing)" -ForegroundColor Yellow
    }
    
    # Log to file
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    "$timestamp | Booking: $bookingPods | User: $userPods | Event: $eventPods | Frontend: $frontendPods" | Out-File -FilePath $logFile -Append -Encoding UTF8
    
    Write-Host ""
    Write-Host "Refreshing in 5 seconds... (Ctrl+C to stop)" -ForegroundColor Gray
    Start-Sleep -Seconds 5
}
