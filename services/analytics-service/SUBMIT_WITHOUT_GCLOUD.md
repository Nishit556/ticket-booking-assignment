# Alternative: Submit Flink Job Without gcloud CLI

If gcloud CLI is broken, you can still submit the job using alternative methods:

## Option 1: Fix gcloud First (Recommended)

Run the fix script:
```powershell
.\FIX_GCLOUD_INSTALL.ps1
```

This will help you fix the Python path issue.

## Option 2: Use GCP Console

1. Go to: https://console.cloud.google.com/dataproc/clusters
2. Click on your cluster: `flink-analytics-cluster`
3. Click "Submit Job"
4. Select "Flink" as job type
5. Upload `analytics_job.py` from `services/analytics-service/`
6. Set arguments: `--kafka-brokers <your-kafka-brokers>`

## Option 3: Use Python Script Directly

If you can SSH to the cluster, you can submit manually:

```powershell
# First, upload the job file to GCS using gsutil (if that works)
# Or use GCP Console to upload to: gs://YOUR_GCP_PROJECT_ID-flink-jobs/flink-jobs/

# Then SSH to master node
gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-c

# On the master node, run:
export KAFKA_BROKERS='b-1.ticketbookingkafka.o4jsuy.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.o4jsuy.c8.kafka.us-east-1.amazonaws.com:9092'
export PYFLINK_CLIENT_EXECUTABLE=python3
export PYFLINK_EXECUTABLE=python3

# Download Kafka connector
wget -O /tmp/flink-sql-connector-kafka-1.15.4.jar https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.15.4/flink-sql-connector-kafka-1.15.4.jar

# Copy job file from GCS
gsutil cp gs://YOUR_GCP_PROJECT_ID-flink-jobs/flink-jobs/analytics_job.py /tmp/analytics_job.py

# Submit job
flink run -m yarn-cluster -pyexec python3 -py /tmp/analytics_job.py -j /tmp/flink-sql-connector-kafka-1.15.4.jar -- --kafka-brokers "$KAFKA_BROKERS"
```

## Option 4: Reinstall gcloud SDK

```powershell
# Uninstall
choco uninstall gcloudsdk -y

# Reinstall
choco install gcloudsdk -y

# Restart PowerShell and try again
```

## Quick Fix: Set Python Path

If you have Python installed:

```powershell
# Find Python
$python = Get-Command python | Select-Object -ExpandProperty Path

# Set environment variable for this session
$env:CLOUDSDK_PYTHON = $python

# Test
gcloud --version

# If it works, run diagnostic
.\DIAGNOSE_FLINK.ps1
```

