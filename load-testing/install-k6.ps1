# Install k6 Load Testing Tool on Windows
# This script downloads and installs k6 using Chocolatey

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Installing k6 Load Testing Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Chocolatey is installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Chocolatey not found. Installing Chocolatey first..." -ForegroundColor Yellow
    
    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    
    Write-Host "✅ Chocolatey installed successfully!" -ForegroundColor Green
}

# Install k6
Write-Host ""
Write-Host "Installing k6..." -ForegroundColor Yellow
choco install k6 -y

# Refresh environment
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify installation
Write-Host ""
Write-Host "Verifying k6 installation..." -ForegroundColor Yellow
k6 version

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  ✅ k6 Installed Successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Get your frontend URL: kubectl get svc frontend -n default" -ForegroundColor White
Write-Host "2. Update the BASE_URL in load-testing/load-test.js" -ForegroundColor White
Write-Host "3. Run the load test: k6 run load-testing/load-test.js" -ForegroundColor White

