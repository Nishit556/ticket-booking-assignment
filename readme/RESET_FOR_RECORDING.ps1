# Reset HPA for Clean Recording
# This script resets everything to 2 replicas and waits for stabilization

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  HPA RESET FOR CLEAN RECORDING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check if k6 is running
Write-Host "Step 1: Checking for running k6 processes..." -ForegroundColor Yellow
$k6Process = Get-Process -Name "k6" -ErrorAction SilentlyContinue
if ($k6Process) {
    Write-Host "  WARNING: k6 is still running!" -ForegroundColor Red
    Write-Host "  Please go to Terminal 7 and press Ctrl+C to stop it!" -ForegroundColor Red
    Write-Host ""
    Read-Host "Press Enter AFTER you've stopped k6"
} else {
    Write-Host "  Good! No k6 process found." -ForegroundColor Green
}
Write-Host ""

# Step 2: Temporarily delete HPAs
Write-Host "Step 2: Temporarily removing HPAs..." -ForegroundColor Yellow
kubectl delete hpa booking-hpa user-hpa -n default --ignore-not-found=true
Write-Host "  HPAs deleted" -ForegroundColor Green
Write-Host ""

# Step 3: Force scale to 2 replicas
Write-Host "Step 3: Scaling deployments to 2 replicas..." -ForegroundColor Yellow
kubectl scale deployment booking-service --replicas=2 -n default
kubectl scale deployment user-service --replicas=2 -n default
Write-Host "  Deployments scaled to 2" -ForegroundColor Green
Write-Host ""

# Step 4: Wait for pods to stabilize
Write-Host "Step 4: Waiting 30 seconds for pods to stabilize..." -ForegroundColor Yellow
Start-Sleep -Seconds 30
Write-Host ""

# Step 5: Check current pod count
Write-Host "Step 5: Current pod status:" -ForegroundColor Yellow
kubectl get pods -n default | Select-String "booking-service|user-service"
Write-Host ""

# Step 6: Wait for ArgoCD to recreate HPAs
Write-Host "Step 6: Waiting for ArgoCD (self-heal) to restore HPAs..." -ForegroundColor Yellow
Write-Host "  > Run 'argocd app sync ticket-booking-app' in another terminal to force reconcilation if needed." -ForegroundColor DarkYellow
Start-Sleep -Seconds 30
Write-Host "  HPAs will reappear automatically because GitOps is enforcing the manifests." -ForegroundColor Green
Write-Host ""

# Step 7: Wait for HPA to initialize
Write-Host "Step 7: Waiting 15 seconds for HPA to initialize..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
Write-Host ""

# Step 8: Final status check
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FINAL STATUS CHECK" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "HPA Status:" -ForegroundColor Green
kubectl get hpa -n default
Write-Host ""

Write-Host "Pod Count:" -ForegroundColor Green
kubectl get pods -n default -l app=booking-service --no-headers | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { Write-Host "  Booking Service: $_ pods" }
kubectl get pods -n default -l app=user-service --no-headers | Measure-Object | Select-Object -ExpandProperty Count | ForEach-Object { Write-Host "  User Service: $_ pods" }
Write-Host ""

Write-Host "CPU Usage:" -ForegroundColor Green
kubectl top pods -n default -l app=booking-service --no-headers | ForEach-Object { Write-Host "  $_" }
kubectl top pods -n default -l app=user-service --no-headers | ForEach-Object { Write-Host "  $_" }
Write-Host ""

# Step 9: Check if ready for recording
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  READY FOR RECORDING?" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$bookingHPA = kubectl get hpa booking-hpa -n default -o jsonpath='{.status.currentReplicas}' 2>$null
$userHPA = kubectl get hpa user-hpa -n default -o jsonpath='{.status.currentReplicas}' 2>$null
$bookingCPU = kubectl get hpa booking-hpa -n default -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>$null
$userCPU = kubectl get hpa user-hpa -n default -o jsonpath='{.status.currentMetrics[0].resource.current.averageUtilization}' 2>$null

Write-Host "Booking Service:" -ForegroundColor Yellow
Write-Host "  Replicas: $bookingHPA (should be 2)" -ForegroundColor $(if ($bookingHPA -eq "2") { "Green" } else { "Red" })
Write-Host "  CPU: $bookingCPU% / 20% (should be <20%)" -ForegroundColor $(if ([int]$bookingCPU -lt 20) { "Green" } else { "Red" })
Write-Host ""

Write-Host "User Service:" -ForegroundColor Yellow
Write-Host "  Replicas: $userHPA (should be 2)" -ForegroundColor $(if ($userHPA -eq "2") { "Green" } else { "Red" })
Write-Host "  CPU: $userCPU% / 20% (should be <20%)" -ForegroundColor $(if ([int]$userCPU -lt 20) { "Green" } else { "Red" })
Write-Host ""

if ($bookingHPA -eq "2" -and $userHPA -eq "2" -and [int]$bookingCPU -lt 20 -and [int]$userCPU -lt 20) {
    Write-Host "SUCCESS! Ready for recording!" -ForegroundColor Green -BackgroundColor DarkGreen
    Write-Host ""
    Write-Host "You can now start recording:" -ForegroundColor Green
    Write-Host "  Terminal 1: .\load-testing\monitor-hpa.ps1" -ForegroundColor Cyan
    Write-Host "  Terminal 2: k6 run load-testing\load-test.js" -ForegroundColor Cyan
} else {
    Write-Host "NOT READY YET!" -ForegroundColor Red -BackgroundColor DarkRed
    Write-Host ""
    Write-Host "CPU is still high or replicas are not at 2." -ForegroundColor Red
    Write-Host "Wait 2-3 minutes for CPU to drop, then run this script again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Make sure Terminal 7 k6 test is STOPPED!" -ForegroundColor Red
}
Write-Host ""

