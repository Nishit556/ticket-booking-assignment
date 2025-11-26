# Script to Run All Three Demo Commands
# 1. Show Flink job running
# 2. Show GCP cluster status
# 3. Show real data in Kafka

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Running Demo Commands" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get GCP configuration from Terraform
Write-Host "Step 1: Getting GCP configuration..." -ForegroundColor Yellow
Push-Location "infrastructure\gcp"
try {
    $GCP_PROJECT_ID = terraform output -raw gcp_project_id
    $CLUSTER_NAME = terraform output -raw dataproc_cluster_name
    $REGION = terraform output -raw gcp_region
    
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($GCP_PROJECT_ID)) {
        Write-Host "❌ ERROR: Could not get GCP configuration from Terraform" -ForegroundColor Red
        Write-Host "Make sure you've run 'terraform apply' in infrastructure/gcp" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Project: $GCP_PROJECT_ID" -ForegroundColor Green
    Write-Host "✅ Cluster: $CLUSTER_NAME" -ForegroundColor Green
    Write-Host "✅ Region: $REGION" -ForegroundColor Green
} finally {
    Pop-Location
}

Write-Host ""

# Get cluster zone dynamically
Write-Host "Step 2: Getting cluster zone..." -ForegroundColor Yellow
$ZONE_OUTPUT = gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION --project=$GCP_PROJECT_ID --format="value(config.gceClusterConfig.zoneUri)" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ ERROR: Could not get cluster zone. Is the cluster running?" -ForegroundColor Red
    Write-Host $ZONE_OUTPUT -ForegroundColor Red
    exit 1
}

$ZONE = $ZONE_OUTPUT.Split('/')[-1]
Write-Host "✅ Zone: $ZONE" -ForegroundColor Green
Write-Host ""

# ========================================
# Command 1: Show Flink job running
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Command 1: Show Flink Job Running" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Running: gcloud compute ssh ${CLUSTER_NAME}-m --zone=$ZONE --command='yarn application -list'" -ForegroundColor Gray
Write-Host ""

$MASTER_NODE = "${CLUSTER_NAME}-m"
$FLINK_CHECK = gcloud compute ssh $MASTER_NODE --zone=$ZONE --project=$GCP_PROJECT_ID --command="yarn application -list" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host $FLINK_CHECK -ForegroundColor White
    Write-Host ""
    
    # Check if any applications are actually running (not just the header)
    # The output shows "Total number of applications: X" - if X > 0, we have jobs
    if ($FLINK_CHECK -match "Total number of applications.*?:\s*(\d+)") {
        $appCount = [int]$matches[1]
        if ($appCount -gt 0) {
            Write-Host "✅ Flink job(s) found running! ($appCount application(s))" -ForegroundColor Green
        } else {
            Write-Host "⚠️  No Flink jobs currently running (0 applications found)." -ForegroundColor Yellow
            Write-Host ""
            Write-Host "To submit the Flink job, run:" -ForegroundColor Cyan
            Write-Host "  cd services\analytics-service" -ForegroundColor Gray
            Write-Host "  .\SUBMIT_FLINK_JOB.ps1" -ForegroundColor Gray
            Write-Host ""
            Write-Host "Or wait a moment if you just submitted it..." -ForegroundColor Gray
        }
    } elseif ($FLINK_CHECK -match "application_\d+") {
        # Fallback: if we see application IDs, jobs are running
        Write-Host "✅ Flink job(s) found running!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No Flink jobs currently running." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To submit the Flink job, run:" -ForegroundColor Cyan
        Write-Host "  cd services\analytics-service" -ForegroundColor Gray
        Write-Host "  .\SUBMIT_FLINK_JOB.ps1" -ForegroundColor Gray
    }
} else {
    Write-Host "❌ ERROR: Could not connect to master node" -ForegroundColor Red
    Write-Host $FLINK_CHECK -ForegroundColor Red
}

Write-Host ""
Write-Host ""

# ========================================
# Command 2: Show GCP cluster status
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Command 2: Show GCP Cluster Status" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Running: gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION" -ForegroundColor Gray
Write-Host ""

$CLUSTER_STATUS = gcloud dataproc clusters describe $CLUSTER_NAME --region=$REGION --project=$GCP_PROJECT_ID 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host $CLUSTER_STATUS -ForegroundColor White
    Write-Host ""
    Write-Host "✅ Cluster status retrieved successfully!" -ForegroundColor Green
} else {
    Write-Host "❌ ERROR: Could not get cluster status" -ForegroundColor Red
    Write-Host $CLUSTER_STATUS -ForegroundColor Red
}

Write-Host ""
Write-Host ""

# ========================================
# Command 3: Show real data in Kafka
# ========================================
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Command 3: Show Real Data in Kafka" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Get Kafka brokers from AWS
Write-Host "Getting Kafka brokers from AWS..." -ForegroundColor Yellow
Push-Location "infrastructure\aws"
try {
    $KAFKA_BROKERS_FULL = terraform output -raw msk_brokers 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($KAFKA_BROKERS_FULL)) {
        # Try alternative method - use the broker from the user's command
        $KAFKA_BROKER = "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092"
        Write-Host "⚠️  Using default broker: $KAFKA_BROKER" -ForegroundColor Yellow
    } else {
        # Use first broker from comma-separated list
        $KAFKA_BROKER = ($KAFKA_BROKERS_FULL -split ',')[0].Trim()
        Write-Host "✅ Using broker: $KAFKA_BROKER" -ForegroundColor Green
    }
} catch {
    # Fallback to default
    $KAFKA_BROKER = "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092"
    Write-Host "⚠️  Using default broker: $KAFKA_BROKER" -ForegroundColor Yellow
} finally {
    Pop-Location
}

Write-Host ""

# Check if kafka-consumer-test pod exists
Write-Host "Checking for kafka-consumer-test pod..." -ForegroundColor Yellow
$POD_EXISTS = kubectl get pod kafka-consumer-test -n default -o name 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  kafka-consumer-test pod not found. Creating it..." -ForegroundColor Yellow
    kubectl run kafka-consumer-test --image=confluentinc/cp-kafka:7.5.0 --restart=Never --namespace=default --command -- sh -c "tail -f /dev/null" 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Pod created. Waiting for it to be ready..." -ForegroundColor Green
        $timeout = 60
        $elapsed = 0
        $podReady = $false
        
        while ($elapsed -lt $timeout) {
            $podStatus = kubectl get pod kafka-consumer-test -n default -o jsonpath='{.status.phase}' 2>&1
            if ($podStatus -eq "Running") {
                $podReady = $true
                break
            }
            Start-Sleep -Seconds 2
            $elapsed += 2
        }
        
        if (-not $podReady) {
            Write-Host "⚠️  Pod may not be ready yet, but continuing..." -ForegroundColor Yellow
        }
    } else {
        Write-Host "❌ ERROR: Could not create pod" -ForegroundColor Red
    }
} else {
    Write-Host "✅ kafka-consumer-test pod exists" -ForegroundColor Green
}

Write-Host ""
Write-Host "Running: kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server `"$KAFKA_BROKER`" --topic ticket-bookings --from-beginning --max-messages 5" -ForegroundColor Gray
Write-Host ""

$KAFKA_OUTPUT = kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server "$KAFKA_BROKER" --topic ticket-bookings --from-beginning --max-messages 5 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host $KAFKA_OUTPUT -ForegroundColor White
    Write-Host ""
    if ($KAFKA_OUTPUT -match "Processed a total of") {
        Write-Host "✅ Kafka messages retrieved successfully!" -ForegroundColor Green
    } else {
        Write-Host "⚠️  No messages found in topic (topic may be empty or broker unreachable)" -ForegroundColor Yellow
    }
} else {
    Write-Host "❌ ERROR: Could not consume from Kafka" -ForegroundColor Red
    Write-Host $KAFKA_OUTPUT -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Check if pod is running: kubectl get pod kafka-consumer-test -n default" -ForegroundColor White
    Write-Host "2. Check pod logs: kubectl logs kafka-consumer-test -n default" -ForegroundColor White
    Write-Host "3. Verify Kafka broker is accessible from cluster" -ForegroundColor White
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Demo Commands Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

