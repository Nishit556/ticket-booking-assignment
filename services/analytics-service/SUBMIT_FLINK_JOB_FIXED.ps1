# Fixed Flink Job Submission Script
# This script uses the correct method to submit Flink jobs to Dataproc
# Uses SSH to master node and flink run command (not pyspark!)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flink Job Submission (Fixed Method)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Get GCP Configuration
Write-Host "Step 1: Getting GCP Configuration..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\gcp"
try {
    $gcpProject = terraform output -raw gcp_project_id
    if ($LASTEXITCODE -ne 0) { throw "Failed to get GCP project" }
    
    $gcsBucket = terraform output -raw gcp_bucket_name
    if ($LASTEXITCODE -ne 0) { throw "Failed to get GCS bucket" }
    
    $clusterName = terraform output -raw dataproc_cluster_name
    if ($LASTEXITCODE -ne 0) { throw "Failed to get cluster name" }
    
    $region = terraform output -raw gcp_region
    if ($LASTEXITCODE -ne 0) { throw "Failed to get region" }
    
    Write-Host "✅ GCP Project: $gcpProject" -ForegroundColor Green
    Write-Host "✅ GCS Bucket: $gcsBucket" -ForegroundColor Green
    Write-Host "✅ Cluster Name: $clusterName" -ForegroundColor Green
    Write-Host "✅ Region: $region" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to get GCP configuration" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host "   Make sure you've run 'terraform apply' in infrastructure/gcp" -ForegroundColor Yellow
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

# Step 2: Get Kafka Brokers
Write-Host ""
Write-Host "Step 2: Getting Kafka Brokers..." -ForegroundColor Yellow
Push-Location "..\..\infrastructure\aws"
try {
    $kafkaBrokers = terraform output -raw msk_brokers
    if ($LASTEXITCODE -ne 0) { throw "Failed to get Kafka brokers" }
    Write-Host "✅ Kafka Brokers: $kafkaBrokers" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Failed to get Kafka brokers" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host "   Make sure AWS MSK is deployed and Terraform outputs are available" -ForegroundColor Yellow
    Pop-Location
    exit 1
} finally {
    Pop-Location
}

# Step 3: Verify job file exists
Write-Host ""
Write-Host "Step 3: Verifying job file..." -ForegroundColor Yellow
# Check in current directory (script should be run from analytics-service directory)
$currentDir = Get-Location
$jobFile = Join-Path $currentDir "analytics_job.py"
if (-not (Test-Path $jobFile)) {
    Write-Host "❌ ERROR: analytics_job.py not found!" -ForegroundColor Red
    Write-Host "   Current directory: $currentDir" -ForegroundColor Yellow
    Write-Host "   Expected location: $jobFile" -ForegroundColor Yellow
    Write-Host "   Make sure you're running this from the services/analytics-service directory" -ForegroundColor Yellow
    exit 1
}
Write-Host "✅ Job file found: $jobFile" -ForegroundColor Green

# Step 4: Check cluster status
Write-Host ""
Write-Host "Step 4: Checking cluster status..." -ForegroundColor Yellow
try {
    $clusterStatus = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(status.state)" 2>&1 | Out-String
    $clusterStatus = $clusterStatus.Trim()
    
    if ($LASTEXITCODE -ne 0 -or -not $clusterStatus) {
        Write-Host "❌ ERROR: Cluster '$clusterName' not found or not accessible!" -ForegroundColor Red
        Write-Host "   Run: cd infrastructure\gcp && terraform apply" -ForegroundColor Yellow
        Write-Host "   Or check gcloud authentication: gcloud auth login" -ForegroundColor Yellow
        exit 1
    }
    
    if ($clusterStatus -ne "RUNNING") {
        Write-Host "⚠️  WARNING: Cluster status is '$clusterStatus', not RUNNING" -ForegroundColor Yellow
        Write-Host "   Waiting 30 seconds for cluster to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 30
        
        $clusterStatus = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(status.state)" 2>&1 | Out-String
        $clusterStatus = $clusterStatus.Trim()
        
        if ($clusterStatus -ne "RUNNING") {
            Write-Host "❌ ERROR: Cluster is still not RUNNING. Current status: $clusterStatus" -ForegroundColor Red
            Write-Host "   Please wait for the cluster to be ready and try again" -ForegroundColor Yellow
            exit 1
        }
    }
    Write-Host "✅ Cluster is RUNNING" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Could not check cluster status" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host "   Try: gcloud auth login && gcloud config set project $gcpProject" -ForegroundColor Yellow
    exit 1
}

# Step 5: Get cluster zone
Write-Host ""
Write-Host "Step 5: Getting cluster zone..." -ForegroundColor Yellow
try {
    $zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --project=$gcpProject --format="value(config.gceClusterConfig.zoneUri)" 2>&1 | Out-String
    $zoneUri = $zoneUri.Trim()
    
    if ($LASTEXITCODE -ne 0 -or -not $zoneUri) {
        Write-Host "❌ ERROR: Could not get cluster zone" -ForegroundColor Red
        Write-Host "   Make sure the cluster is fully initialized" -ForegroundColor Yellow
        exit 1
    }
    $zone = $zoneUri.Split('/')[-1]
    $masterNode = "$clusterName-m"
    Write-Host "✅ Zone: $zone" -ForegroundColor Green
    Write-Host "✅ Master Node: $masterNode" -ForegroundColor Green
} catch {
    Write-Host "❌ ERROR: Could not determine cluster zone" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    exit 1
}

# Step 6: Upload job file to GCS (if not already there)
Write-Host ""
Write-Host "Step 6: Checking/Uploading job file to GCS..." -ForegroundColor Yellow
$gcsJobPath = "gs://$gcsBucket/flink-jobs/analytics_job.py"

# Check if file already exists
Write-Host "   Checking if file already exists in GCS..." -ForegroundColor Gray
$fileExists = $false
try {
    $checkResult = gcloud storage ls $gcsJobPath 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        $fileExists = $true
    } else {
        # Try with gsutil as fallback
        $checkResult = gsutil ls $gcsJobPath 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $fileExists = $true
        }
    }
} catch {
    # File doesn't exist, will upload
}

if ($fileExists) {
    Write-Host "✅ Job file already exists in GCS, skipping upload" -ForegroundColor Green
} else {
    Write-Host "   File not found, uploading $jobFile to $gcsJobPath..." -ForegroundColor Gray
    
    try {
        # Use gcloud storage cp instead of gsutil (works with newer Python versions)
        # If that fails, try gsutil as fallback
        $uploadSuccess = $false
        
        # Try gcloud storage first (newer, more compatible)
        Write-Host "   Trying gcloud storage cp..." -ForegroundColor Gray
        gcloud storage cp $jobFile $gcsJobPath 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $uploadSuccess = $true
            Write-Host "✅ Job file uploaded successfully using gcloud storage" -ForegroundColor Green
        } else {
            # Fallback to gsutil
            Write-Host "   gcloud storage failed, trying gsutil..." -ForegroundColor Gray
            gsutil cp $jobFile $gcsJobPath 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $uploadSuccess = $true
                Write-Host "✅ Job file uploaded successfully using gsutil" -ForegroundColor Green
            }
        }
        
        if (-not $uploadSuccess) {
            Write-Host "⚠️  Upload failed, but file may already exist. Continuing..." -ForegroundColor Yellow
            Write-Host "   If job submission fails, upload manually via GCP Console:" -ForegroundColor Gray
            Write-Host "   https://console.cloud.google.com/storage/browser/$gcsBucket" -ForegroundColor Gray
        }
    } catch {
        Write-Host "⚠️  Upload error: $_" -ForegroundColor Yellow
        Write-Host "   Continuing anyway - file may already exist in GCS" -ForegroundColor Gray
    }
}

# Step 7: Submit Flink job using SSH and flink run
Write-Host ""
Write-Host "Step 7: Submitting Flink job..." -ForegroundColor Yellow
Write-Host "   This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

try {
    # Kafka connector JAR URL (matches Flink 1.15 on Dataproc 2.1)
    $kafkaJarUrl = "https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.15.4/flink-sql-connector-kafka-1.15.4.jar"
    $kafkaJarName = "flink-sql-connector-kafka-1.15.4.jar"
    $remoteJarPath = "/tmp/$kafkaJarName"
    $remoteJobPath = "/tmp/analytics_job.py"
    
    # Build the remote command
    # This downloads the Kafka connector if needed, copies the job file, and runs Flink
    # Note: We pass kafka-brokers as a command-line argument to the Python script
    $remoteCommand = "export KAFKA_BROKERS='$kafkaBrokers'; export PYFLINK_CLIENT_EXECUTABLE=python3; export PYFLINK_EXECUTABLE=python3; [ -f $remoteJarPath ] || wget -O $remoteJarPath $kafkaJarUrl; gsutil cp $gcsJobPath $remoteJobPath; flink run -m yarn-cluster -pyexec python3 -py $remoteJobPath -j $remoteJarPath -- --kafka-brokers '$kafkaBrokers'"
    
    Write-Host "   Connecting to master node and submitting job..." -ForegroundColor Gray
    Write-Host "   Command: flink run -m yarn-cluster ..." -ForegroundColor Gray
    Write-Host ""
    
    # Execute SSH command
    gcloud compute ssh $masterNode `
        --project=$gcpProject `
        --zone=$zone `
        --command=$remoteCommand
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  ✅ Job Submitted Successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Check job status:" -ForegroundColor White
        Write-Host "   gcloud compute ssh $masterNode --zone=$zone --project=$gcpProject --command='yarn application -list'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Access Flink UI (requires SSH tunnel):" -ForegroundColor White
        Write-Host "   gcloud compute ssh $masterNode --zone=$zone --project=$gcpProject --ssh-flag='-L 8081:localhost:8081'" -ForegroundColor Gray
        Write-Host "   Then open: http://localhost:8081" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. Test by booking tickets through your frontend!" -ForegroundColor White
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  ❌ Job Submission Failed" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "1. Check cluster logs in GCP Console" -ForegroundColor White
        Write-Host "2. Verify Kafka brokers are accessible from GCP" -ForegroundColor White
        Write-Host "3. Check if init script installed dependencies correctly" -ForegroundColor White
        Write-Host "4. Try running the diagnostic script: .\DIAGNOSE_FLINK.ps1" -ForegroundColor White
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "❌ ERROR: Job submission failed" -ForegroundColor Red
    Write-Host "   Error: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure gcloud CLI is installed and authenticated" -ForegroundColor White
    Write-Host "2. Check if cluster is accessible via SSH" -ForegroundColor White
    Write-Host "3. Verify network connectivity between GCP and AWS" -ForegroundColor White
    exit 1
}

