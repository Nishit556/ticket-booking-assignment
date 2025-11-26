# Demo Commands Status

## ✅ Commands Are Working!

All three demo commands are now functional. Here's what's set up:

### Command 1: Show Flink Job Running
```powershell
gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-f --command="yarn application -list"
```
**Status:** ✅ Working  
**Note:** Currently shows 0 applications (Flink job needs to be submitted)

### Command 2: Show GCP Cluster Status
```powershell
gcloud dataproc clusters describe flink-analytics-cluster --region=us-central1
```
**Status:** ✅ Working  
**Result:** Cluster is RUNNING

### Command 3: Show Real Data in Kafka
```powershell
kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server "b-1.ticketbookingkafka.bo30jr.c8.kafka.us-east-1.amazonaws.com:9092" --topic ticket-bookings --from-beginning --max-messages 5
```
**Status:** ✅ Working  
**Result:** Successfully consuming messages from Kafka

---

## 📝 Important Notes

### Zone Correction
- **Your command used:** `us-central1-c`
- **Actual zone:** `us-central1-f`
- The scripts automatically detect the correct zone

### Kafka Broker
- **Your command used:** `b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092`
- **Actual broker:** `b-1.ticketbookingkafka.bo30jr.c8.kafka.us-east-1.amazonaws.com:9092`
- The scripts automatically get the correct broker from Terraform

---

## 🚀 Next Step: Submit Flink Job

The Flink job is **not currently running**. To submit it:

```powershell
cd services\analytics-service
.\SUBMIT_FLINK_JOB.ps1
```

Or manually:
```powershell
cd services\analytics-service
python submit-dataproc-job.py `
  --project-id "YOUR_GCP_PROJECT_ID" `
  --cluster-name "flink-analytics-cluster" `
  --region "us-central1" `
  --gcs-bucket "YOUR_GCP_PROJECT_ID-flink-jobs" `
  --kafka-brokers "b-1.ticketbookingkafka.bo30jr.c8.kafka.us-east-1.amazonaws.com:9092,b-2.ticketbookingkafka.bo30jr.c8.kafka.us-east-1.amazonaws.com:9092"
```

After submission, wait 1-2 minutes, then Command 1 will show the Flink job running.

---

## 🎯 Quick Run Scripts

### Option 1: Full Demo Script (with checks and setup)
```powershell
.\run-demo-commands.ps1
```

### Option 2: Exact Commands (as you specified)
```powershell
.\run-exact-demo-commands.ps1
```

Both scripts automatically:
- Get the correct zone from the cluster
- Get the correct Kafka broker from AWS
- Ensure the kafka-consumer-test pod exists
- Run all three commands

---

## ✅ Verification Checklist

- [x] GCP Dataproc cluster is running
- [x] Cluster zone detected: `us-central1-f`
- [x] Kafka broker accessible
- [x] kafka-consumer-test pod exists
- [x] All three commands execute successfully
- [ ] Flink job submitted and running (needs to be done)

---

## 🔧 Troubleshooting

If Command 1 shows "No Flink jobs running":
1. Submit the job using `SUBMIT_FLINK_JOB.ps1`
2. Wait 1-2 minutes for the job to start
3. Re-run Command 1 to verify

If Command 3 fails:
1. Check if pod exists: `kubectl get pod kafka-consumer-test -n default`
2. If not, the script will create it automatically
3. Verify Kafka broker is accessible from your cluster

