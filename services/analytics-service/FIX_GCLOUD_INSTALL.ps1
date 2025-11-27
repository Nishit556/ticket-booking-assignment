# Fix gcloud SDK Python Issue
# This script helps fix the missing Python issue in gcloud SDK

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GCloud SDK Python Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Python is available on system
Write-Host "Step 1: Checking for system Python..." -ForegroundColor Yellow
$pythonPath = Get-Command python -ErrorAction SilentlyContinue
if ($pythonPath) {
    Write-Host "✅ System Python found: $($pythonPath.Path)" -ForegroundColor Green
    $pythonVersion = python --version 2>&1
    Write-Host "   Version: $pythonVersion" -ForegroundColor Gray
} else {
    Write-Host "❌ System Python not found" -ForegroundColor Red
    Write-Host "   Installing Python may help fix the issue" -ForegroundColor Yellow
}

Write-Host ""

# Check gcloud installation path
Write-Host "Step 2: Checking gcloud installation..." -ForegroundColor Yellow
$gcloudPath = Get-Command gcloud -ErrorAction SilentlyContinue
if ($gcloudPath) {
    Write-Host "✅ gcloud found: $($gcloudPath.Path)" -ForegroundColor Green
    
    # Check if bundled Python exists
    $bundledPython = "C:\ProgramData\chocolatey\lib\google-cloud-sdk\tools\google-cloud-sdk\platform\bundledpython\python.exe"
    if (Test-Path $bundledPython) {
        Write-Host "✅ Bundled Python exists" -ForegroundColor Green
    } else {
        Write-Host "❌ Bundled Python missing: $bundledPython" -ForegroundColor Red
        Write-Host "   This is the root cause of the issue" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ gcloud not found in PATH" -ForegroundColor Red
}

Write-Host ""

# Solutions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Solutions" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Option 1: Reinstall gcloud SDK (Recommended)" -ForegroundColor Yellow
Write-Host "  1. Uninstall current gcloud:" -ForegroundColor White
Write-Host "     choco uninstall gcloudsdk -y" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Install fresh:" -ForegroundColor White
Write-Host "     choco install gcloudsdk -y" -ForegroundColor Gray
Write-Host ""

Write-Host "Option 2: Install Python and point gcloud to it" -ForegroundColor Yellow
Write-Host "  1. Install Python:" -ForegroundColor White
Write-Host "     choco install python -y" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Set gcloud to use system Python:" -ForegroundColor White
Write-Host "     gcloud config set disable_prompts True" -ForegroundColor Gray
Write-Host ""

Write-Host "Option 3: Use GCP Console (Temporary Workaround)" -ForegroundColor Yellow
Write-Host "  You can check cluster status and submit jobs via:" -ForegroundColor White
Write-Host "  https://console.cloud.google.com/dataproc/clusters" -ForegroundColor Gray
Write-Host ""

Write-Host "Option 4: Manual Python Path Fix" -ForegroundColor Yellow
if ($pythonPath) {
    Write-Host "  Try setting CLOUDSDK_PYTHON environment variable:" -ForegroundColor White
    Write-Host "  `$env:CLOUDSDK_PYTHON = '$($pythonPath.Path)'" -ForegroundColor Gray
    Write-Host "  Then try gcloud commands again" -ForegroundColor Gray
} else {
    Write-Host "  First install Python, then set CLOUDSDK_PYTHON" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Quick Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($pythonPath) {
    Write-Host "Setting CLOUDSDK_PYTHON and testing..." -ForegroundColor Yellow
    $env:CLOUDSDK_PYTHON = $pythonPath.Path
    $testResult = gcloud --version 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ SUCCESS! gcloud works with system Python" -ForegroundColor Green
        Write-Host ""
        Write-Host "To make this permanent, add to your PowerShell profile:" -ForegroundColor Yellow
        Write-Host "  `$env:CLOUDSDK_PYTHON = '$($pythonPath.Path)'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Or set it in this session and try the diagnostic again:" -ForegroundColor Yellow
        Write-Host "  `$env:CLOUDSDK_PYTHON = '$($pythonPath.Path)'" -ForegroundColor Gray
        Write-Host "  .\DIAGNOSE_FLINK.ps1" -ForegroundColor Gray
    } else {
        Write-Host "❌ Still having issues. Try reinstalling gcloud SDK." -ForegroundColor Red
    }
} else {
    Write-Host "⚠️  No system Python found. Install Python first:" -ForegroundColor Yellow
    Write-Host "  choco install python -y" -ForegroundColor Gray
}

Write-Host ""

