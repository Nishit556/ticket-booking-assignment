# Demo Checklist - Before Your Presentation

## ✅ Pre-Demo Setup (Do This Today!)

### 1. Submit Flink Job
```powershell
cd services\analytics-service
.\PREPARE_DEMO.ps1
```

This will:
- ✅ Run diagnostic
- ✅ Submit Flink job
- ✅ Verify job is running
- ✅ Show you the exact demo commands

### 2. Verify Kafka Consumer Pod Exists
```powershell
# Check if pod exists
kubectl get pod kafka-consumer-test -n default

# If it doesn't exist, create it:
kubectl run kafka-consumer-test --image=bitnami/kafka --rm -it --restart=Never -- sleep 3600
```

**Important:** Keep this pod running! Don't exit the terminal where it's running, or create it as a deployment instead.

### 3. Generate Test Data (Optional but Recommended)
Make some bookings through your frontend to ensure there's data in Kafka:
1. Open your frontend URL
2. Register a user
3. Browse events
4. Book 2-3 tickets

This ensures the Kafka topic has data for the demo.

## 🎬 Demo Commands (For Tomorrow)

### Command 1: Show Flink Job Running
```powershell
gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-c --command="yarn application -list"
```

**What to say:**
"This shows our Flink analytics job running on the Dataproc cluster. You can see it's in RUNNING state, processing events from Kafka in real-time."

**Expected output:**
- Application ID
- Application Name (Flink)
- State: RUNNING
- Final Status: UNDEFINED (normal for streaming jobs)

### Command 2: Show GCP Cluster Status
```powershell
gcloud dataproc clusters describe flink-analytics-cluster --region=us-central1
```

**What to say:**
"This shows our Dataproc cluster configuration. It's running in GCP's us-central1 region with 1 master node and 2 worker nodes. The cluster is healthy and operational."

**Key points to highlight:**
- Status: RUNNING
- Master node configuration
- Worker nodes count
- Region: us-central1 (while Kafka is in AWS us-east-1 - cross-cloud!)

### Command 3: Show Real Data in Kafka
```powershell
kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server "b-1.ticketbookingkafka.o4jsuy.c8.kafka.us-east-1.amazonaws.com:9092" --topic ticket-bookings --from-beginning --max-messages 5
```

**IMPORTANT:** Use the broker from your Terraform output, not the one in the demo script if they're different!

**What to say:**
"Here we see actual booking events flowing through Kafka. These are real events published by our booking service when users make reservations. Our Flink job consumes these events and performs time-windowed aggregations."

**Expected output:**
- JSON messages with event_id, user_id, ticket_count, timestamp

## ⚠️ Important Notes

### Kafka Broker Address
**Check your actual broker address:**
```powershell
cd infrastructure\aws
terraform output -raw msk_brokers
```

The demo script shows: `b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092`
But your Terraform shows: `b-1.ticketbookingkafka.o4jsuy.c8.kafka.us-east-1.amazonaws.com:9092`

**Use the one from YOUR Terraform output!**

### If Something Goes Wrong

**Flink job not running:**
```powershell
# Re-submit the job
cd services\analytics-service
.\SUBMIT_FLINK_JOB_FIXED.ps1
```

**Kafka consumer pod missing:**
```powershell
kubectl run kafka-consumer-test --image=bitnami/kafka --rm -it --restart=Never -- sleep 3600
```

**No data in Kafka:**
- Make some bookings through the frontend
- Check booking-service logs: `kubectl logs -l app=booking-service`

## 🎯 Quick Test Before Demo

Run this to test all three commands:
```powershell
cd services\analytics-service
.\DEMO_COMMANDS.ps1
```

This will run each command interactively so you can verify they work.

## 📝 Final Checklist

- [ ] Flink job submitted and running
- [ ] Kafka consumer pod exists
- [ ] Test data generated (bookings made)
- [ ] All three demo commands tested
- [ ] Correct Kafka broker address noted
- [ ] Cluster zone verified (us-central1-c)
- [ ] gcloud authenticated and working

## 🚀 You're Ready!

Good luck with your demo! Everything should work smoothly if you've completed the pre-demo setup.

