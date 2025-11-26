# PowerShell script to run k6 load test
# Usage: .\run-load-test.ps1

Write-Host "🧪 Starting Load Test for Ticket Booking System" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════" -ForegroundColor Green

# Check if k6 is installed
$k6Path = Get-Command k6 -ErrorAction SilentlyContinue
if (-not $k6Path) {
    Write-Host "❌ k6 is not installed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install k6:" -ForegroundColor Yellow
    Write-Host "  Windows (Chocolatey): choco install k6" -ForegroundColor Yellow
    Write-Host "  Windows (Winget): winget install k6" -ForegroundColor Yellow
    Write-Host "  Or download from: https://k6.io/docs/get-started/installation/" -ForegroundColor Yellow
    exit 1
}

# Get Frontend URL from kubectl
Write-Host "📡 Getting Frontend LoadBalancer URL..." -ForegroundColor Cyan
try {
    $FRONTEND_URL = kubectl get svc frontend-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
    if ([string]::IsNullOrWhiteSpace($FRONTEND_URL)) {
        Write-Host "⚠️  Could not retrieve LoadBalancer URL from kubectl" -ForegroundColor Yellow
        Write-Host "Using default URL from environment..." -ForegroundColor Yellow
        $FRONTEND_URL = "http://ab281cfd51be84e1aa3f813cfc6d4a85-918774444.us-east-1.elb.amazonaws.com"
    } else {
        $FRONTEND_URL = "http://$FRONTEND_URL"
    }
} catch {
    Write-Host "⚠️  kubectl not available, using default URL" -ForegroundColor Yellow
    $FRONTEND_URL = "http://ab281cfd51be84e1aa3f813cfc6d4a85-918774444.us-east-1.elb.amazonaws.com"
}

Write-Host "Frontend URL: $FRONTEND_URL" -ForegroundColor White
Write-Host ""

# Test if frontend is accessible
Write-Host "🔍 Testing frontend accessibility..." -ForegroundColor Cyan
try {
    $response = Invoke-WebRequest -Uri $FRONTEND_URL -Method GET -TimeoutSec 10 -ErrorAction Stop
    Write-Host "✅ Frontend is accessible (Status: $($response.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "❌ Frontend is not accessible!" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor Red
    Write-Host "Please verify the frontend service is running:" -ForegroundColor Yellow
    Write-Host "  kubectl get svc frontend-service" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "🚀 Starting k6 Load Test..." -ForegroundColor Green
Write-Host "This will take approximately 15 minutes" -ForegroundColor Yellow
Write-Host ""
Write-Host "📊 Test will:"  -ForegroundColor Cyan
Write-Host "  1. Ramp up from 10 to 150 virtual users" -ForegroundColor White
Write-Host "  2. Stress test all endpoints (register, events, bookings)" -ForegroundColor White
Write-Host "  3. Trigger HPA scaling (watch with: kubectl get hpa)" -ForegroundColor White
Write-Host "  4. Generate detailed performance report" -ForegroundColor White
Write-Host ""

# Run k6 test
$env:FRONTEND_URL = $FRONTEND_URL
k6 run --out json=load-test-results.json k6-load-test.js

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Load Test Completed Successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📄 Results saved to:" -ForegroundColor Cyan
    Write-Host "  - load-test-results.json" -ForegroundColor White
    Write-Host "  - load-test-summary.json" -ForegroundColor White
    Write-Host ""
    Write-Host "🔍 Check HPA scaling:" -ForegroundColor Cyan
    Write-Host "  kubectl get hpa" -ForegroundColor Yellow
    Write-Host "  kubectl get pods" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📊 View metrics in Grafana:" -ForegroundColor Cyan
    $GRAFANA_URL = kubectl get svc -n monitoring monitoring-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>$null
    if ($GRAFANA_URL) {
        Write-Host "  http://$GRAFANA_URL" -ForegroundColor White
    }
} else {
    Write-Host ""
    Write-Host "❌ Load Test Failed!" -ForegroundColor Red
    Write-Host "Check the error messages above for details." -ForegroundColor Yellow
}

