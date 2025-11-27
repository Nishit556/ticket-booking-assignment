# Quick script to fix gcloud authentication and check cluster

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  GCloud Authentication Check & Fix" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check current authentication
Write-Host "Step 1: Checking gcloud authentication..." -ForegroundColor Yellow
$authList = gcloud auth list --format="value(account)" 2>&1 | Out-String
$authList = $authList.Trim()

if ($authList) {
    Write-Host "✅ Authenticated as: $authList" -ForegroundColor Green
} else {
    Write-Host "❌ No active authentication found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run: gcloud auth login" -ForegroundColor Yellow
    Write-Host "Then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Step 2: Get project from Terraform
Write-Host "Step 2: Getting GCP project from Terraform..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\gcp"
try {
    $gcpProject = terraform output -raw gcp_project_id 2>$null
    if ($gcpProject) {
        Write-Host "✅ Project from Terraform: $gcpProject" -ForegroundColor Green
    } else {
        Write-Host "❌ Could not get project from Terraform" -ForegroundColor Red
        Pop-Location
        exit 1
    }
} finally {
    Pop-Location
}

Write-Host ""

# Step 3: Check current gcloud project
Write-Host "Step 3: Checking current gcloud project..." -ForegroundColor Yellow
$currentProject = gcloud config get-value project 2>&1 | Out-String
$currentProject = $currentProject.Trim()

if ($currentProject -eq $gcpProject) {
    Write-Host "✅ Current project matches: $currentProject" -ForegroundColor Green
} else {
    Write-Host "⚠️  Current project: $currentProject" -ForegroundColor Yellow
    Write-Host "   Expected: $gcpProject" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Setting project to $gcpProject..." -ForegroundColor Cyan
    gcloud config set project $gcpProject
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Project set successfully" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to set project" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""

# Step 4: Test cluster access
Write-Host "Step 4: Testing cluster access..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\gcp"
try {
    $clusterName = terraform output -raw dataproc_cluster_name 2>$null
    $region = terraform output -raw gcp_region 2>$null
    
    if ($clusterName -and $region) {
        Write-Host "   Checking cluster: $clusterName in region: $region" -ForegroundColor Gray
        
        $clusterStatus = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(status.state)" 2>&1 | Out-String
        $clusterStatus = $clusterStatus.Trim()
        
        if ($LASTEXITCODE -eq 0 -and $clusterStatus) {
            Write-Host "✅ Cluster found! Status: $clusterStatus" -ForegroundColor Green
            
            if ($clusterStatus -eq "RUNNING") {
                Write-Host "   Cluster is ready for job submission!" -ForegroundColor Green
            } else {
                Write-Host "   Cluster is $clusterStatus - wait for it to be RUNNING" -ForegroundColor Yellow
            }
        } else {
            Write-Host "❌ Cluster not found or not accessible" -ForegroundColor Red
            Write-Host ""
            Write-Host "Possible issues:" -ForegroundColor Yellow
            Write-Host "1. Cluster doesn't exist - Run: cd infrastructure\gcp && terraform apply" -ForegroundColor White
            Write-Host "2. Wrong project/region - Check Terraform outputs" -ForegroundColor White
            Write-Host "3. Permissions issue - Check IAM roles" -ForegroundColor White
        }
    } else {
        Write-Host "❌ Could not get cluster name from Terraform" -ForegroundColor Red
    }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Check Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "If cluster is RUNNING, you can now submit the job:" -ForegroundColor Yellow
Write-Host "  .\SUBMIT_FLINK_JOB_FIXED.ps1" -ForegroundColor White
Write-Host ""

