# Analytics Service - Flink Job on GCP Dataproc

**Status:** ✅ Fixed and Working

This service performs real-time stream processing using Apache Flink on GCP Dataproc. It consumes booking events from AWS MSK Kafka, performs time-windowed aggregations, and publishes results back to Kafka.

## ⚡ Quick Start (For Windows)

```powershell
# Make sure you're in the analytics-service directory
cd services/analytics-service

# Submit the job
.\submit-flink-job.ps1 `
  -ProjectId "YOUR_GCP_PROJECT_ID" `
  -ClusterName "flink-analytics-cluster" `
  -Region "us-central1" `
  -GcsBucket "YOUR_GCP_PROJECT_ID-flink-jobs" `
  -KafkaBrokers "b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092"
```

## Architecture

- **Source**: AWS MSK Kafka topic `ticket-bookings`
- **Processing**: Flink tumbling window (1-minute) aggregation
- **Sink**: AWS MSK Kafka topic `analytics-results`
- **Platform**: GCP Dataproc cluster with Flink 1.15

## What Was Fixed

### ✅ Version Compatibility
- **Old:** Tried to install Flink 1.17 on Dataproc 2.1 (which has Flink 1.15)
- **Fixed:** Now uses Dataproc's pre-installed Flink 1.15
- **Fixed:** Init script only installs Kafka connector JAR

### ✅ Job Submission
- **Old:** Complex SSH-based submission
- **Fixed:** Simple `gcloud dataproc jobs submit` command
- **Fixed:** Added PowerShell script for Windows users

### ✅ Arguments Handling
- **Old:** Expected environment variables (didn't work)
- **Fixed:** Now accepts command-line arguments `--kafka-brokers`

## Prerequisites

1. **GCP Setup:**
   ```bash
   # Authenticate
   gcloud auth login
   gcloud auth application-default login
   
   # Set project
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Deploy GCP Infrastructure:**
   ```bash
   cd ../../infrastructure/gcp
   terraform init
   terraform apply
   ```

3. **Get Required Values:**
   ```bash
   # From Terraform outputs
   terraform output dataproc_cluster_name
   terraform output gcs_bucket_name
   
   # From AWS
   aws kafka get-bootstrap-brokers --cluster-arn <your-msk-arn>
   ```

## Deployment Steps

### Step 1: Upload Initialization Script

```bash
# From infrastructure/gcp directory
GCS_BUCKET=$(terraform output -raw gcs_bucket_name)
gsutil cp init-scripts/install-dependencies.sh gs://${GCS_BUCKET}/init-scripts/
```

### Step 2: Update MSK Security Group

Allow Dataproc to access MSK (for demo purposes):

```bash
# Get MSK security group ID
SG_ID=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=ticket-booking-kafka-sg" \
  --query "SecurityGroups[0].GroupId" \
  --output text)

# Add ingress rule (WARNING: Only for demo - use specific IPs in production)
aws ec2 authorize-security-group-ingress \
  --group-id ${SG_ID} \
  --protocol tcp \
  --port 9092 \
  --cidr 0.0.0.0/0
```

### Step 3: Submit Flink Job

**Option A: Using Python Script (Windows-friendly)**

```powershell
cd services/analytics-service

python submit-dataproc-job.py `
  --project-id "your-gcp-project-id" `
  --cluster-name "flink-analytics-cluster" `
  --region "us-central1" `
  --gcs-bucket "your-bucket-name" `
  --kafka-brokers "b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092"
```

**Option B: Using Bash Script (Linux/Mac)**

```bash
cd services/analytics-service
chmod +x submit-dataproc-job.sh

./submit-dataproc-job.sh \
  "your-gcp-project-id" \
  "flink-analytics-cluster" \
  "us-central1" \
  "your-bucket-name" \
  "b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092"
```

**Option C: Manual Submission**

```bash
# Upload job file
gsutil cp analytics_job.py gs://YOUR_BUCKET/flink-jobs/

# Submit job
gcloud dataproc jobs submit flink \
  --project=YOUR_PROJECT_ID \
  --region=us-central1 \
  --cluster=flink-analytics-cluster \
  --py-files=gs://YOUR_BUCKET/flink-jobs/analytics_job.py \
  --properties=flink.jobmanager.memory.process.size=1024m,flink.taskmanager.memory.process.size=1024m \
  -- \
  --python gs://YOUR_BUCKET/flink-jobs/analytics_job.py
```

## Monitoring

### Check Job Status

```bash
gcloud dataproc jobs list \
  --project=YOUR_PROJECT_ID \
  --region=us-central1 \
  --cluster=flink-analytics-cluster
```

### View Job Logs

```bash
# Get job ID from list above
gcloud dataproc jobs describe JOB_ID \
  --project=YOUR_PROJECT_ID \
  --region=us-central1
```

### Access Flink Web UI

```bash
# SSH tunnel to master node
gcloud compute ssh flink-analytics-cluster-m \
  --project=YOUR_PROJECT_ID \
  --zone=us-central1-a \
  --ssh-flag="-L 8081:localhost:8081"

# Then open http://localhost:8081 in browser
```

### Check Kafka Topics

```bash
# From AWS
aws kafka list-nodes --cluster-arn <your-msk-arn>

# Test consumer (from a pod with Kafka tools)
kafka-console-consumer \
  --bootstrap-server b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com:9092 \
  --topic analytics-results \
  --from-beginning
```

## Job Details

### Input Topic: `ticket-bookings`
Expected JSON format:
```json
{
  "event_id": "event-123",
  "user_id": "user-456",
  "ticket_count": 2,
  "timestamp": 1234567890.123
}
```

### Output Topic: `analytics-results`
Output JSON format:
```json
{
  "event_id": "event-123",
  "window_end": "2025-11-20 10:01:00.000",
  "total_tickets": 15
}
```

### Processing Logic

- **Window Type**: Tumbling window (non-overlapping)
- **Window Size**: 1 minute
- **Aggregation**: Sum of `ticket_count` per `event_id` per window
- **Time Attribute**: Processing time (`PROCTIME()`)

## Troubleshooting

### Job Fails to Start

1. **Check cluster status:**
   ```bash
   gcloud dataproc clusters describe flink-analytics-cluster \
     --project=YOUR_PROJECT_ID \
     --region=us-central1
   ```

2. **Check initialization script:**
   ```bash
   gcloud dataproc clusters describe flink-analytics-cluster \
     --project=YOUR_PROJECT_ID \
     --region=us-central1 \
     --format="value(config.initializationActions[0].executableFile)"
   ```

### Cannot Connect to Kafka

1. **Verify MSK security group allows traffic:**
   ```bash
   aws ec2 describe-security-groups \
     --group-ids <sg-id> \
     --query "SecurityGroups[0].IpPermissions"
   ```

2. **Test connectivity from Dataproc:**
   ```bash
   gcloud compute ssh flink-analytics-cluster-m \
     --project=YOUR_PROJECT_ID \
     --zone=us-central1-a \
     --command="telnet b-1.ticketbookingkafka.8jdhzt.c8.kafka.us-east-1.amazonaws.com 9092"
   ```

3. **Check Kafka topic exists:**
   ```bash
   # From a pod with Kafka tools
   kafka-topics --bootstrap-server <broker> --list
   ```

### Job Runs But No Output

1. **Verify input topic has data:**
   ```bash
   kafka-console-consumer \
     --bootstrap-server <broker> \
     --topic ticket-bookings \
     --from-beginning \
     --max-messages 10
   ```

2. **Check Flink logs for errors:**
   ```bash
   gcloud dataproc jobs describe JOB_ID \
     --project=YOUR_PROJECT_ID \
     --region=us-central1 \
     --format="value(driverOutputResourceUri)"
   ```

## Cleanup

To stop the job:
```bash
# List running jobs
gcloud dataproc jobs list \
  --project=YOUR_PROJECT_ID \
  --region=us-central1 \
  --cluster=flink-analytics-cluster \
  --filter="status.state=ACTIVE"

# Cancel job (if needed)
gcloud dataproc jobs cancel JOB_ID \
  --project=YOUR_PROJECT_ID \
  --region=us-central1
```

To delete the cluster:
```bash
cd ../../infrastructure/gcp
terraform destroy
```

## Next Steps

1. Create a consumer service to read from `analytics-results` topic
2. Display analytics results in the frontend
3. Set up monitoring and alerting for the Flink job

