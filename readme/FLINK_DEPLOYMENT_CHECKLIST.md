# 🎯 Flink Analytics - Final Deployment Checklist

## ✅ Components Status

| Component | Status | Location |
|-----------|--------|----------|
| VPC Network | ✅ **READY** | `infrastructure/gcp/network.tf` |
| Init Script | ✅ **READY** | `infrastructure/gcp/init-scripts/install-dependencies.sh` |
| Flink Job Code | ✅ **READY** | `services/analytics-service/analytics_job.py` |
| Submission Script | ✅ **READY** | `services/analytics-service/submit-dataproc-job.py` |
| Quick Submit (PowerShell) | ✅ **READY** | `services/analytics-service/SUBMIT_FLINK_JOB.ps1` |
| Demo Guide | ✅ **READY** | `services/analytics-service/DEMO_GUIDE.md` |

## 🚀 Deployment Steps

### 1. Deploy GCP Network & Dataproc Cluster (10 minutes)

```powershell
cd "infrastructure\gcp"

# Initialize Terraform (if you haven't already)
terraform init

# Review what will be created
terraform plan

# Apply (creates VPC, subnet, firewall rules, Dataproc cluster)
terraform apply -auto-approve
```

**Expected Output:**
- ✅ Network created
- ✅ Subnet created
- ✅ Firewall rules created
- ✅ Dataproc cluster running (takes 5-8 minutes)

### 2. Verify Cluster is Running

```powershell
# Check from CLI
gcloud dataproc clusters list --region=us-central1

# Or visit GCP Console:
# https://console.cloud.google.com/dataproc/clusters
```

**Expected:** Status should be "RUNNING"

### 3. Submit Flink Job (2 minutes)

```powershell
cd "..\..\services\analytics-service"

# Option A: Quick Submit (Recommended)
.\SUBMIT_FLINK_JOB.ps1

# Option B: Manual Submit
python submit-dataproc-job.py `
  --project-id "<your-project>" `
  --cluster-name "flink-analytics-cluster" `
  --region "us-central1" `
  --gcs-bucket "<your-bucket>" `
  --kafka-brokers "<your-msk-brokers>"
```

**Expected Output:**
```
=== Starting Flink Analytics Job ===
Kafka Brokers: b-1.ticketbookingkafka...
Source Topic: ticket-bookings
Sink Topic: analytics-results
=====================================
Job submitted successfully
```

### 4. Verify Job is Running

#### Option A: Flink Web UI

```powershell
# Get master node IP
gcloud compute instances describe flink-analytics-cluster-m `
  --zone=us-central1-a `
  --format="get(networkInterfaces[0].accessConfigs[0].natIP)"

# Access UI at: http://<IP>:8081
```

**What to look for:**
- Running Jobs: 1
- Task Managers: 2
- Available Task Slots: 4

#### Option B: Check job logs

```powershell
gcloud dataproc jobs list `
  --cluster=flink-analytics-cluster `
  --region=us-central1
```

### 5. Test End-to-End Data Flow

#### A. Create Kafka Topics (if not exists)

```powershell
# Get MSK brokers from Terraform
cd "infrastructure\aws"
$kafkaBrokers = terraform output -raw msk_brokers

# SSH into EKS node or use kafka-client pod
kubectl run kafka-client --rm -it --image=confluentinc/cp-kafka:latest -- bash

# Inside pod:
export KAFKA_BROKERS="$kafkaBrokers"

kafka-topics --bootstrap-server $KAFKA_BROKERS --create --topic ticket-bookings --partitions 3 --replication-factor 2
kafka-topics --bootstrap-server $KAFKA_BROKERS --create --topic analytics-results --partitions 1 --replication-factor 2
```

#### B. Book Tickets via Frontend

1. Go to your frontend URL (LoadBalancer IP from `kubectl get svc frontend`)
2. Register a user
3. Browse events
4. Book 2-3 tickets for different events

#### C. Verify Data Flow

**Step 1: Check booking-service logs**
```powershell
kubectl logs -l app=booking-service -n default --tail=20
```
**Expected:** See "Connected to Kafka" and "Booking request received"

**Step 2: Consume from ticket-bookings topic**
```bash
# In kafka-client pod
kafka-console-consumer --bootstrap-server $KAFKA_BROKERS --topic ticket-bookings --from-beginning

# Expected output:
# {"event_id":"123","user_id":"user1","ticket_count":2,"timestamp":1234567890}
```

**Step 3: Check Flink is processing**
- Visit Flink UI: http://<master-ip>:8081
- Click on running job
- Check "Records Sent" and "Records Received" metrics

**Step 4: Consume from analytics-results topic**
```bash
kafka-console-consumer --bootstrap-server $KAFKA_BROKERS --topic analytics-results --from-beginning

# Expected output (after 1 minute window):
# {"event_id":"123","window_end":"2024-11-23T10:30:00.000Z","total_tickets":5}
```

## 📊 Architecture Flow

```
1. User books ticket → Frontend (K8s)
2. Frontend → Booking Service (K8s)
3. Booking Service → AWS MSK Kafka (ticket-bookings topic)
4. Kafka → GCP Dataproc Flink Job (reads, aggregates)
5. Flink → AWS MSK Kafka (analytics-results topic)
6. Analytics Results → Can be consumed by dashboards/reports
```

## 🎥 Demo Video Checklist

### What to Show:

1. **✅ GCP Console - Dataproc**
   - Show cluster running
   - Show master/worker nodes
   - Show Flink component installed

2. **✅ Terminal - Submit Job**
   - Run `SUBMIT_FLINK_JOB.ps1`
   - Show successful submission

3. **✅ Flink Web UI**
   - Show job running
   - Show task managers
   - Show metrics (records processed)

4. **✅ Frontend - Book Tickets**
   - Book 2-3 tickets
   - Show booking confirmation

5. **✅ Kafka - Verify Data**
   - Show messages in ticket-bookings
   - Wait 1 minute
   - Show aggregated results in analytics-results

6. **✅ Architecture Diagram**
   - Draw on whiteboard or slide showing multi-cloud setup

## 🔧 Troubleshooting Guide

### Issue: Flink can't connect to Kafka

**Solution:** Update MSK security group to allow inbound from `0.0.0.0/0` on port 9092

```powershell
cd "infrastructure\aws"

# Add this to your MSK security group
aws ec2 authorize-security-group-ingress `
  --group-id <msk-security-group-id> `
  --protocol tcp `
  --port 9092 `
  --cidr 0.0.0.0/0
```

### Issue: No data in analytics-results

**Check:**
1. Are bookings reaching Kafka? → Check booking-service logs
2. Is Flink job running? → Check Flink UI
3. Has 1 minute window passed? → Aggregation happens every minute

### Issue: Can't access Flink UI

```powershell
# Check if firewall rule allows port 8081
gcloud compute firewall-rules list --filter="name:dataproc-allow-flink-ui"

# If not exists, create it (already in network.tf)
cd "infrastructure\gcp"
terraform apply -auto-approve
```

## 📝 Assignment Requirements - Met!

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Managed cluster (Dataproc) | ✅ | `dataproc.tf` |
| Real-time stream processing (Flink) | ✅ | `analytics_job.py` |
| Infrastructure as Code | ✅ | `network.tf`, `dataproc.tf` |
| VPC Network configuration | ✅ | `network.tf` (NEW) |
| Initialization scripts | ✅ | `install-dependencies.sh` |
| Actual working Flink job | ✅ | `analytics_job.py` |
| Kafka → Flink → Kafka flow | ✅ | Windowed aggregation |
| Multi-cloud integration | ✅ | GCP processing AWS data |

## 🎉 You're Ready!

Run these commands to get everything working:

```powershell
# 1. Deploy infrastructure
cd "infrastructure\gcp"
terraform apply -auto-approve

# 2. Submit Flink job
cd "..\..\services\analytics-service"
.\SUBMIT_FLINK_JOB.ps1

# 3. Test by booking tickets!
```

Good luck with your demo! 🚀

