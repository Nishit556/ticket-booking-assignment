# GCP Setup Verification and Auto-Fix Script
# This script checks everything and provides fixes

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🔍 GCP Setup Verification Script" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PROJECT_ID = "YOUR_GCP_PROJECT_ID"
$REGION = "us-central1"
$ZONE = "us-central1-a"
$CLUSTER = "flink-analytics-cluster"

$ErrorCount = 0
$WarningCount = 0

# Function to check status
function Check-Status($name, $condition, $fix = $null) {
    Write-Host "Checking: $name" -NoNewline
    if ($condition) {
        Write-Host " ✅" -ForegroundColor Green
        return $true
    } else {
        Write-Host " ❌" -ForegroundColor Red
        $script:ErrorCount++
        if ($fix) {
            Write-Host "  Fix: $fix" -ForegroundColor Yellow
        }
        return $false
    }
}

# 1. Check gcloud is installed
Write-Host "📋 Step 1: Checking Prerequisites" -ForegroundColor Cyan
Write-Host "-----------------------------------"

$gcloudPath = Get-Command gcloud -ErrorAction SilentlyContinue
Check-Status "gcloud CLI installed" ($null -ne $gcloudPath) "Download from: https://cloud.google.com/sdk/docs/install"

$gsutilPath = Get-Command gsutil -ErrorAction SilentlyContinue
Check-Status "gsutil installed" ($null -ne $gsutilPath) "Part of Google Cloud SDK"

Write-Host ""

# 2. Check authentication
Write-Host "📋 Step 2: Checking Authentication" -ForegroundColor Cyan
Write-Host "-----------------------------------"

try {
    $currentProject = gcloud config get-value project 2>$null
    Check-Status "Authenticated to GCP" ($null -ne $currentProject) "Run: gcloud auth login"
    Check-Status "Correct project selected" ($currentProject -eq $PROJECT_ID) "Run: gcloud config set project $PROJECT_ID"
} catch {
    Check-Status "Authenticated to GCP" $false "Run: gcloud auth login"
}

Write-Host ""

# 3. Check APIs are enabled
Write-Host "📋 Step 3: Checking Required APIs" -ForegroundColor Cyan
Write-Host "-----------------------------------"

$requiredApis = @(
    "dataproc.googleapis.com",
    "storage-component.googleapis.com", 
    "compute.googleapis.com",
    "iam.googleapis.com"
)

foreach ($api in $requiredApis) {
    try {
        $enabled = gcloud services list --enabled --filter="name:$api" --format="value(name)" 2>$null
        $apiName = $api -replace ".googleapis.com", ""
        if ($enabled) {
            Check-Status "$apiName API" $true
        } else {
            Check-Status "$apiName API" $false "Run: gcloud services enable $api"
        }
    } catch {
        Check-Status "$apiName API" $false "Run: gcloud services enable $api"
    }
}

Write-Host ""

# 4. Check Terraform state
Write-Host "📋 Step 4: Checking Terraform Status" -ForegroundColor Cyan
Write-Host "-----------------------------------"

$tfStateExists = Test-Path "terraform.tfstate"
Check-Status "Terraform initialized" $tfStateExists "Run: terraform init"

if ($tfStateExists) {
    try {
        $tfOutput = terraform output -json 2>$null | ConvertFrom-Json
        if ($tfOutput) {
            Check-Status "Terraform applied" $true
            
            if ($tfOutput.gcs_bucket_name.value) {
                Write-Host "  📦 GCS Bucket: $($tfOutput.gcs_bucket_name.value)" -ForegroundColor Gray
            }
            if ($tfOutput.dataproc_cluster_name.value) {
                Write-Host "  🖥️  Cluster: $($tfOutput.dataproc_cluster_name.value)" -ForegroundColor Gray
            }
        } else {
            Check-Status "Terraform applied" $false "Run: terraform apply"
        }
    } catch {
        Check-Status "Terraform applied" $false "Run: terraform apply"
    }
}

Write-Host ""

# 5. Check Dataproc cluster
Write-Host "📋 Step 5: Checking Dataproc Cluster" -ForegroundColor Cyan
Write-Host "-----------------------------------"

try {
    $clusterStatus = gcloud dataproc clusters describe $CLUSTER --region=$REGION --project=$PROJECT_ID --format="value(status.state)" 2>$null
    
    if ($clusterStatus -eq "RUNNING") {
        Check-Status "Cluster status" $true
        
        # Check init script logs
        Write-Host "  Checking init script..." -NoNewline
        $initLog = gcloud compute ssh ${CLUSTER}-m --project=$PROJECT_ID --zone=$ZONE --command="cat /var/log/dataproc-initialization-script-0.log 2>/dev/null | tail -5" 2>$null
        
        if ($initLog -match "successfully") {
            Write-Host " ✅" -ForegroundColor Green
            Write-Host "  📄 Init script ran successfully" -ForegroundColor Gray
        } else {
            Write-Host " ⚠️" -ForegroundColor Yellow
            $script:WarningCount++
            Write-Host "  📄 Cannot verify init script status" -ForegroundColor Yellow
        }
        
    } elseif ($clusterStatus) {
        Check-Status "Cluster status" $false "Cluster is $clusterStatus, not RUNNING. Wait or recreate."
    } else {
        Check-Status "Cluster exists" $false "Run: terraform apply"
    }
} catch {
    Check-Status "Cluster exists" $false "Run: terraform apply"
}

Write-Host ""

# 6. Check GCS bucket
Write-Host "📋 Step 6: Checking GCS Bucket" -ForegroundColor Cyan
Write-Host "-----------------------------------"

$bucket = "${PROJECT_ID}-flink-jobs"
try {
    $bucketExists = gsutil ls "gs://$bucket" 2>$null
    if ($LASTEXITCODE -eq 0) {
        Check-Status "GCS bucket exists" $true
        
        # Check if job file exists
        $jobFileExists = gsutil ls "gs://$bucket/flink-jobs/analytics_job.py" 2>$null
        if ($LASTEXITCODE -eq 0) {
            Check-Status "Job file uploaded" $true
        } else {
            Check-Status "Job file uploaded" $false "Run: gsutil cp analytics_job.py gs://$bucket/flink-jobs/"
        }
    } else {
        Check-Status "GCS bucket exists" $false "Run: terraform apply"
    }
} catch {
    Check-Status "GCS bucket exists" $false "Run: terraform apply"
}

Write-Host ""

# 7. Check AWS MSK security group
Write-Host "📋 Step 7: Checking AWS MSK Access" -ForegroundColor Cyan
Write-Host "-----------------------------------"

try {
    $awsConfigured = aws sts get-caller-identity 2>$null
    if ($LASTEXITCODE -eq 0) {
        Check-Status "AWS CLI configured" $true
        
        # Try to get security group
        Push-Location "..\..\infrastructure\aws"
        $sgId = terraform output -raw msk_security_group_id 2>$null
        Pop-Location
        
        if ($sgId) {
            Write-Host "  🔒 Security Group: $sgId" -ForegroundColor Gray
            
            # Check if port 9092 is open
            $sgRules = aws ec2 describe-security-groups --group-ids $sgId --region us-east-1 --query "SecurityGroups[0].IpPermissions[?FromPort==``9092``]" 2>$null
            
            if ($sgRules -match "9092") {
                Check-Status "MSK port 9092 open" $true
            } else {
                Check-Status "MSK port 9092 open" $false "Run: aws ec2 authorize-security-group-ingress --group-id $sgId --protocol tcp --port 9092 --cidr 0.0.0.0/0 --region us-east-1"
            }
        } else {
            $script:WarningCount++
            Write-Host "  ⚠️ Cannot verify MSK security group" -ForegroundColor Yellow
        }
    } else {
        $script:WarningCount++
        Write-Host "  ⚠️ AWS CLI not configured (needed for MSK access)" -ForegroundColor Yellow
    }
} catch {
    $script:WarningCount++
    Write-Host "  ⚠️ Cannot check AWS resources" -ForegroundColor Yellow
}

Write-Host ""

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "📊 Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

if ($ErrorCount -eq 0 -and $WarningCount -eq 0) {
    Write-Host "✅ All checks passed! Ready to submit jobs." -ForegroundColor Green
} elseif ($ErrorCount -eq 0) {
    Write-Host "⚠️  $WarningCount warnings found, but core setup is OK." -ForegroundColor Yellow
} else {
    Write-Host "❌ $ErrorCount errors found. Fix them before proceeding." -ForegroundColor Red
    if ($WarningCount -gt 0) {
        Write-Host "⚠️  $WarningCount warnings found." -ForegroundColor Yellow
    }
}

Write-Host ""

# Next steps
if ($ErrorCount -eq 0) {
    Write-Host "🚀 Next Steps:" -ForegroundColor Cyan
    Write-Host "-----------------------------------"
    Write-Host "1. Submit Flink job:" -ForegroundColor White
    Write-Host "   cd ..\..\services\analytics-service" -ForegroundColor Gray
    Write-Host "   .\SUBMIT_JOB.ps1" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Check job status:" -ForegroundColor White
    Write-Host "   gcloud dataproc jobs list --cluster=$CLUSTER --region=$REGION --project=$PROJECT_ID" -ForegroundColor Gray
    Write-Host ""
    Write-Host "3. View in console:" -ForegroundColor White
    Write-Host "   https://console.cloud.google.com/dataproc/jobs?project=$PROJECT_ID" -ForegroundColor Gray
} else {
    Write-Host "🔧 Required Actions:" -ForegroundColor Yellow
    Write-Host "-----------------------------------"
    Write-Host "Review the errors above and run the suggested fixes." -ForegroundColor White
    Write-Host ""
    Write-Host "Then run this script again to verify:" -ForegroundColor White
    Write-Host "   .\VERIFY_AND_FIX.ps1" -ForegroundColor Gray
}

Write-Host ""

