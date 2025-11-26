# 🎥 Flink Analytics Demo Guide

## ✅ What You Already Have

1. **✅ VPC Network** - `infrastructure/gcp/network.tf` (just created)
2. **✅ Dataproc Cluster** - Running with Flink installed
3. **✅ Init Script** - `init-scripts/install-dependencies.sh` (downloads Kafka connector)
4. **✅ Flink Job** - `analytics_job.py` (reads from Kafka, aggregates, writes back)
5. **✅ Submission Script** - `submit-dataproc-job.py`

## 📋 Pre-Flight Checklist

### 1. Get Your Infrastructure Values

```powershell
# From AWS Terraform
cd "infrastructure\aws"
terraform output msk_brokers  # Copy this value
terraform output s3_bucket_name

# From GCP Terraform
cd "..\gcp"
terraform output gcp_bucket_name  # For Flink jobs
terraform output dataproc_cluster_name
```

### 2. Ensure Network is Deployed

```powershell
cd "infrastructure\gcp"
terraform init
terraform plan  # Should show network resources being created
terraform apply -auto-approve
```

## 🚀 Submitting the Flink Job

### Step 1: Get AWS Kafka Brokers

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2\infrastructure\aws"
$kafkaBrokers = terraform output -raw msk_brokers
Write-Host "Kafka Brokers: $kafkaBrokers"
```

### Step 2: Get GCP Values

```powershell
cd "..\gcp"
$gcpProject = terraform output -raw gcp_project_id
$gcsBucket = terraform output -raw gcp_bucket_name
$clusterName = terraform output -raw dataproc_cluster_name
$region = terraform output -raw gcp_region

Write-Host "GCP Project: $gcpProject"
Write-Host "GCS Bucket: $gcsBucket"
Write-Host "Cluster: $clusterName"
```

### Step 3: Submit the Job

```powershell
cd "..\..\services\analytics-service"

python submit-dataproc-job.py `
  --project-id "$gcpProject" `
  --cluster-name "$clusterName" `
  --region "$region" `
  --gcs-bucket "$gcsBucket" `
  --kafka-brokers "$kafkaBrokers"
```

## 🎯 What the Job Does

1. **Reads from Kafka topic**: `ticket-bookings`
2. **Performs Windowed Aggregation**: Counts tickets per event in 1-minute tumbling windows
3. **Writes results to Kafka topic**: `analytics-results`

## 📊 Verifying It's Working

### Option 1: Check Flink Web UI

```powershell
# Get the cluster's master node external IP
gcloud compute instances list --filter="name:flink-analytics-cluster-m"

# Access Flink UI at: http://<EXTERNAL-IP>:8081
```

### Option 2: Check Kafka Topics (from EKS)

```powershell
# Port forward to a pod that can reach Kafka
kubectl run kafka-client --rm -it --image=wurstmeister/kafka:latest -- bash

# Inside the pod:
export KAFKA_BROKERS="<your-msk-brokers>"

# Check if topics exist
kafka-topics.sh --bootstrap-server $KAFKA_BROKERS --list

# Consume from results topic
kafka-console-consumer.sh --bootstrap-server $KAFKA_BROKERS --topic analytics-results --from-beginning
```

### Option 3: Generate Test Data

```powershell
# Book some tickets through your application UI
# The booking-service will publish to Kafka
# Flink will process and aggregate
# Results will appear in analytics-results topic
```

## 🎥 Demo Video Checklist

### Show These Things:

1. **✅ Terraform Apply Output**
   - Show network resources created
   - Show Dataproc cluster running

2. **✅ GCP Console**
   - Navigate to Dataproc → Clusters
   - Show your cluster is running
   - Show VPC Network configuration

3. **✅ Submit Flink Job**
   - Run the submit command
   - Show job submission success

4. **✅ Flink UI**
   - Access http://<cluster-ip>:8081
   - Show running job
   - Show task managers

5. **✅ Data Flow**
   - Book tickets via frontend
   - Show Kafka messages (booking-service logs)
   - Show Flink processing (Flink UI)
   - Show analytics results (consume from analytics-results topic)

## 🔧 Troubleshooting

### Job Fails with "Kafka Connector Not Found"

```bash
# SSH into master node and check
gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-a

ls /usr/lib/flink/lib/ | grep kafka
# Should see: flink-sql-connector-kafka-1.15.4.jar
```

### Can't Connect to Kafka

The Dataproc cluster (in GCP) needs to reach AWS MSK. Ensure:
- MSK security group allows inbound from `0.0.0.0/0` (or GCP IP ranges)
- Or use VPC peering between AWS and GCP (advanced)

### No Data in analytics-results

1. Check if bookings are being published:
   ```powershell
   kubectl logs <booking-service-pod> -n default
   ```

2. Check Flink job logs:
   ```powershell
   gcloud dataproc jobs list --cluster=flink-analytics-cluster --region=us-central1
   ```

## 📝 Architecture Diagram for Report

```
User → Frontend (EKS) 
         ↓
      Booking Service (EKS) 
         ↓
      AWS MSK Kafka (ticket-bookings topic)
         ↓
      GCP Dataproc/Flink (Windowed Aggregation)
         ↓
      AWS MSK Kafka (analytics-results topic)
```

## ✅ Assignment Requirements Met

- **✅** Managed cluster (Dataproc)
- **✅** Real-time stream processing (Flink)
- **✅** Connects to Kafka (AWS MSK)
- **✅** Windowed aggregation (1-minute tumbling windows)
- **✅** Multi-cloud (GCP Dataproc processing AWS Kafka data)
- **✅** Infrastructure as Code (Terraform for network + cluster)

