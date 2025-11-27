# Flink Job Quick Start Guide

## 🚀 Quick Setup (3 Steps)

### Step 1: Run Diagnostic
First, check if everything is set up correctly:

```powershell
cd services\analytics-service
.\DIAGNOSE_FLINK.ps1
```

This will check:
- ✅ GCP configuration
- ✅ Cluster status
- ✅ Job file existence
- ✅ Network connectivity

### Step 2: Submit Flink Job
If the diagnostic passes, submit the job:

```powershell
.\SUBMIT_FLINK_JOB_FIXED.ps1
```

This script will:
1. Get configuration from Terraform
2. Upload job file to GCS
3. SSH to master node
4. Download Kafka connector (if needed)
5. Submit Flink job using `flink run`

### Step 3: Verify Job is Running

```powershell
# Get cluster info
cd ..\..\infrastructure\gcp
$clusterName = terraform output -raw dataproc_cluster_name
$region = terraform output -raw gcp_region
$project = terraform output -raw gcp_project_id

# Get zone
$zoneUri = gcloud dataproc clusters describe $clusterName --region=$region --project=$project --format="value(config.gceClusterConfig.zoneUri)"
$zone = $zoneUri.Split('/')[-1]

# Check YARN applications (Flink runs on YARN)
gcloud compute ssh "$clusterName-m" --zone=$zone --project=$project --command="yarn application -list"
```

You should see a Flink application in RUNNING state.

## 🔍 Troubleshooting

### Issue: "Cluster not found"
**Solution:** Deploy the cluster first:
```powershell
cd infrastructure\gcp
terraform apply
```

### Issue: "Job submission fails with connection error"
**Possible causes:**
1. **Kafka not accessible from GCP**
   - Check MSK security group allows inbound from `0.0.0.0/0` on port 9092
   - Or add GCP Dataproc IPs to security group

2. **Cluster not ready**
   - Wait 5-10 minutes after cluster creation
   - Check status: `gcloud dataproc clusters describe <cluster-name> --region=us-central1`

3. **SSH access issues**
   - Ensure you have `compute.instanceAdmin` role
   - Try: `gcloud compute ssh <cluster-name>-m --zone=<zone>`

### Issue: "Job runs but no output"
**Check:**
1. **Kafka topics exist:**
   ```powershell
   # Get Kafka brokers
   cd infrastructure\aws
   $brokers = terraform output -raw msk_brokers
   
   # Create topics (from a pod with Kafka tools)
   kubectl run kafka-client --rm -it --image=confluentinc/cp-kafka:latest -- bash
   # Inside pod:
   kafka-topics --bootstrap-server $brokers --create --topic ticket-bookings --partitions 3 --replication-factor 2
   kafka-topics --bootstrap-server $brokers --create --topic analytics-results --partitions 1 --replication-factor 2
   ```

2. **Data is flowing:**
   - Book tickets through frontend
   - Check booking-service logs: `kubectl logs -l app=booking-service`
   - Consume from ticket-bookings topic to verify messages

3. **Wait for window:**
   - Flink aggregates in 1-minute windows
   - Results appear after the first window closes

### Issue: "Flink UI not accessible"
**Solution:** Use SSH tunnel:
```powershell
$clusterName = "flink-analytics-cluster"
$zone = "us-central1-c"  # Get from cluster description
$project = "your-project-id"

gcloud compute ssh "$clusterName-m" --zone=$zone --project=$project --ssh-flag="-L 8081:localhost:8081"
```

Then open: http://localhost:8081

## 📊 Monitoring

### Check Job Status
```powershell
# List all jobs
gcloud dataproc jobs list --cluster=<cluster-name> --region=us-central1

# Describe specific job
gcloud dataproc jobs describe <job-id> --region=us-central1
```

### View Flink Metrics
1. Access Flink UI (see above)
2. Click on running job
3. Check "Records Sent" and "Records Received"
4. View task manager metrics

### Check Kafka Topics
```powershell
# Consume from input topic
kubectl run kafka-consumer --rm -it --image=confluentinc/cp-kafka:latest -- bash
# Inside pod:
kafka-console-consumer --bootstrap-server <broker> --topic ticket-bookings --from-beginning

# Consume from output topic (after 1 minute)
kafka-console-consumer --bootstrap-server <broker> --topic analytics-results --from-beginning
```

## 🎯 What the Job Does

1. **Reads** from Kafka topic `ticket-bookings`
2. **Processes** events in 1-minute tumbling windows
3. **Aggregates** total tickets per event per window
4. **Writes** results to Kafka topic `analytics-results`

### Input Format (ticket-bookings):
```json
{
  "event_id": "event-123",
  "user_id": "user-456",
  "ticket_count": 2,
  "timestamp": 1234567890.123
}
```

### Output Format (analytics-results):
```json
{
  "event_id": "event-123",
  "window_end": "2025-01-20 10:01:00.000",
  "total_tickets": 15
}
```

## 🔧 Manual Submission (Alternative)

If the PowerShell script doesn't work, you can submit manually:

```powershell
# 1. Get values
cd infrastructure\gcp
$project = terraform output -raw gcp_project_id
$bucket = terraform output -raw gcp_bucket_name
$cluster = terraform output -raw dataproc_cluster_name
$region = terraform output -raw gcp_region

cd ..\..\infrastructure\aws
$kafka = terraform output -raw msk_brokers

# 2. Upload job
cd ..\..\services\analytics-service
gsutil cp analytics_job.py "gs://$bucket/flink-jobs/analytics_job.py"

# 3. Get zone
$zoneUri = gcloud dataproc clusters describe $cluster --region=$region --project=$project --format="value(config.gceClusterConfig.zoneUri)"
$zone = $zoneUri.Split('/')[-1]

# 4. Submit via SSH
gcloud compute ssh "$cluster-m" --zone=$zone --project=$project --command="export KAFKA_BROKERS='$kafka'; export PYFLINK_CLIENT_EXECUTABLE=python3; export PYFLINK_EXECUTABLE=python3; [ -f /tmp/flink-sql-connector-kafka-1.15.4.jar ] || wget -O /tmp/flink-sql-connector-kafka-1.15.4.jar https://repo.maven.apache.org/maven2/org/apache/flink/flink-sql-connector-kafka/1.15.4/flink-sql-connector-kafka-1.15.4.jar; gsutil cp gs://$bucket/flink-jobs/analytics_job.py /tmp/analytics_job.py; flink run -m yarn-cluster -pyexec python3 -py /tmp/analytics_job.py -j /tmp/flink-sql-connector-kafka-1.15.4.jar -- --kafka-brokers '$kafka'"
```

## ✅ Success Indicators

You'll know it's working when:
1. ✅ Diagnostic script shows all green checkmarks
2. ✅ Job submission completes without errors
3. ✅ `yarn application -list` shows Flink app in RUNNING state
4. ✅ Flink UI shows job with active task managers
5. ✅ After booking tickets, analytics-results topic has data (after 1 minute)

## 📝 Notes

- **Flink Version:** Dataproc 2.1 comes with Flink 1.15
- **Kafka Connector:** Automatically downloaded (version 1.15.4)
- **Window Size:** 1 minute (configurable in analytics_job.py)
- **Processing Mode:** Real-time streaming (not batch)

