# Install Metrics Server for HPA to work
# This enables HPA to see CPU/memory usage

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing Metrics Server" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Installing metrics-server..." -ForegroundColor Yellow
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

Write-Host ""
Write-Host "Waiting for metrics-server to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

Write-Host ""
Write-Host "Checking metrics-server status..." -ForegroundColor Yellow
kubectl get deployment metrics-server -n kube-system

Write-Host ""
Write-Host "Waiting for metrics to be available (this may take 30-60 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

Write-Host ""
Write-Host "Testing metrics collection..." -ForegroundColor Yellow
kubectl top nodes

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ Metrics Server Installed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "HPA should now be able to see CPU metrics." -ForegroundColor Cyan
Write-Host "Check with: kubectl get hpa -n default" -ForegroundColor White
Write-Host ""
Write-Host "Note: It may take 1-2 minutes for metrics to appear in HPA." -ForegroundColor Gray

