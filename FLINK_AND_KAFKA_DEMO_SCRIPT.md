# Flink Job & Kafka Demo Script
## Video Recording Transcript for Part 3 - Analytics Service

---

## 🎬 **INTRODUCTION**

**What to say:**
"Hello, I'm [Your Name], ID [Your ID]. In this part of the demonstration, I'll show you the analytics service running on GCP Dataproc and how it processes real-time data from Kafka. This demonstrates requirement (e) for stateful, time-windowed aggregation and requirement (b) for cross-cloud analytics."

---

## 📋 **SETUP & CONTEXT**

**What to say:**
"Before we begin, let me explain what we're going to demonstrate:
1. First, I'll show that our Flink job is actively running on the GCP Dataproc cluster
2. Then, I'll display the cluster status to show the infrastructure is healthy
3. Finally, I'll show real booking events flowing through Kafka, which the Flink job processes

This demonstrates the complete data pipeline: AWS MSK (Kafka) → GCP Dataproc (Flink) → Analytics Results."

---

## 🔍 **COMMAND 1: SHOWING FLINK JOB RUNNING**

**Command to run:**
```bash
gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-c --command="yarn application -list"
```

**What to say before running:**
"First, I'll connect to the master node of our Dataproc cluster and check if the Flink job is running. Dataproc uses YARN as the resource manager, so we can use YARN commands to see all running applications."

**What to say while command is executing:**
"I'm SSH-ing into the master node of our Dataproc cluster. This cluster is running in GCP's us-central1-c zone. Once connected, I'll query YARN to list all running applications, which should include our Flink streaming job."

**What to say when results appear:**
"Perfect! You can see the Flink job is running. The output shows:
- Application ID: [point to the ID]
- Application Name: [point to the name, likely something like 'Flink Streaming Job']
- Application Type: YARN
- State: RUNNING (or ACCEPTED if it just started)
- Final Status: UNDEFINED (this is normal for long-running streaming jobs)

This confirms that our analytics service is actively processing booking events from Kafka in real-time. The job is running continuously, performing time-windowed aggregations as new events arrive."

**What to point out:**
- "Notice the job state is RUNNING - this means it's actively consuming from Kafka"
- "The application type shows it's a YARN application, which is how Dataproc manages Flink"
- "This job has been running since [mention if you can see start time], processing events continuously"

---

## 📊 **COMMAND 2: SHOWING GCP CLUSTER STATUS**

**Command to run:**
```bash
gcloud dataproc clusters describe flink-analytics-cluster --region=us-central1
```

**What to say before running:**
"Now let me show you the status of our Dataproc cluster. This command will display detailed information about the cluster configuration, including the number of nodes, machine types, and current state."

**What to say while command is executing:**
"I'm querying the Dataproc API to get the full cluster description. This will show us the infrastructure details that support our Flink job."

**What to say when results appear:**
"Excellent! The cluster status shows:
- **Cluster Name**: flink-analytics-cluster
- **Status**: RUNNING (the cluster is healthy and operational)
- **Region**: us-central1
- **Master Node**: [point to machine type, e.g., n1-standard-2]
- **Worker Nodes**: [point to count and machine type]
- **Software Config**: Shows Flink is installed as an optional component
- **Network**: [point to VPC configuration]

This demonstrates that we have a fully managed Flink cluster on GCP. The cluster is provisioned using Terraform, as shown in Part 1, and it's configured to run our analytics job.

**Key points to highlight:**
- "The cluster is in RUNNING state, meaning all nodes are healthy"
- "We have [X] worker nodes processing the stream in parallel"
- "The cluster is in GCP's us-central1 region, while our Kafka is in AWS us-east-1 - this demonstrates cross-cloud architecture"
- "Flink is listed as an optional component, which means it was pre-installed during cluster creation"

---

## 📨 **COMMAND 3: SHOWING REAL DATA IN KAFKA**

**Command to run:**
```bash
kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092" --topic ticket-bookings --from-beginning --max-messages 5
```

**What to say before running:**
"Finally, let me show you the actual booking events flowing through Kafka. This is the data that our Flink job is consuming and processing. I'll use a test pod in our Kubernetes cluster to consume messages from the Kafka topic."

**What to say while command is executing:**
"I'm executing a Kafka console consumer inside a test pod. This will:
- Connect to our AWS MSK cluster using the bootstrap server address
- Read from the 'ticket-bookings' topic
- Start from the beginning to show historical messages
- Limit to 5 messages so we can see the data format

This demonstrates that real booking events are being published to Kafka by our booking service."

**What to say when results appear:**
"Perfect! You can see actual booking events in JSON format. Each message contains:
- **event_id**: The ID of the event being booked
- **user_id**: The user making the booking
- **ticket_count**: Number of tickets requested
- **timestamp**: When the booking was made

These are the exact messages that:
1. The booking service publishes when users make bookings
2. The Flink job consumes and processes
3. Get aggregated into time-windowed results

**What to point out:**
- "Each JSON object represents a real booking event"
- "The timestamp shows when the booking occurred"
- "These messages are being consumed by our Flink job running on GCP"
- "The Flink job groups these by event_id and calculates totals per 1-minute window"

---

## 🔄 **EXPLAINING THE DATA FLOW**

**What to say:**
"Let me explain the complete data flow we've just demonstrated:

1. **Source**: Users make bookings through our frontend service
2. **Booking Service**: Publishes events to Kafka topic 'ticket-bookings' on AWS MSK
3. **Kafka**: Stores and streams these events (we just saw the actual messages)
4. **Flink Job**: Running on GCP Dataproc, consumes from Kafka
5. **Processing**: Flink performs time-windowed aggregation (1-minute tumbling windows)
6. **Output**: Aggregated results are published to 'analytics-results' topic

This architecture demonstrates:
- **Cross-cloud integration**: AWS MSK → GCP Dataproc
- **Real-time processing**: Events are processed as they arrive
- **Stateful aggregation**: Flink maintains state for window calculations
- **Scalability**: Both Kafka and Flink can scale to handle increased load"

---

## 🎯 **KEY TECHNICAL POINTS TO MENTION**

**If asked about the setup:**

**1. Cross-Cloud Connectivity:**
"The Flink job on GCP connects to AWS MSK over the public internet. In production, you'd use VPN or Direct Connect, but for this assignment, we've configured security groups to allow the connection. The Kafka bootstrap server address we saw is the public endpoint of our MSK cluster."

**2. Flink Job Configuration:**
"Our Flink job uses the Table API with SQL-like syntax. It creates a source table that reads from Kafka, performs a GROUP BY with TUMBLE window function, and writes results to a sink table that publishes back to Kafka."

**3. Real-Time Processing:**
"The job processes events in real-time, not in batches. As soon as a booking event arrives in Kafka, Flink processes it and includes it in the current time window. When a 1-minute window closes, the aggregated result is immediately published."

**4. Fault Tolerance:**
"Flink provides exactly-once processing semantics. If a node fails, Flink can recover from checkpoints and continue processing without losing or duplicating events."

---

## 📈 **DEMONSTRATING THE COMPLETE PIPELINE**

**What to say:**
"To summarize what we've shown:

1. ✅ **Flink Job Running**: Confirmed the analytics service is active on GCP
2. ✅ **Cluster Healthy**: Dataproc cluster is operational with proper configuration
3. ✅ **Real Data**: Actual booking events are flowing through Kafka

This satisfies assignment requirements:
- **(b)**: Analytics service runs on a different cloud provider (GCP)
- **(e)**: Stateful, time-windowed aggregation using Flink
- **Cross-cloud**: AWS MSK and GCP Dataproc working together
- **Real-time**: Continuous stream processing, not batch

The system is production-ready and demonstrates enterprise-grade stream processing architecture."

---

## 🎬 **CLOSING**

**What to say:**
"This concludes the demonstration of the analytics service. We've successfully shown:
- The Flink job is running and processing events
- The GCP infrastructure is healthy and properly configured
- Real booking data is flowing through the system

The analytics service performs time-windowed aggregations on booking events, calculating total tickets sold per event in 1-minute intervals. This provides real-time insights into booking patterns and satisfies requirement (e) for stateful stream processing.

Thank you for watching. This demonstrates the cross-cloud analytics architecture required by the assignment."

---

## 📝 **QUICK REFERENCE: COMMANDS TO RUN**

1. **Check Flink Job:**
   ```bash
   gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-c --command="yarn application -list"
   ```

2. **Check Cluster Status:**
   ```bash
   gcloud dataproc clusters describe flink-analytics-cluster --region=us-central1
   ```

3. **Show Kafka Messages:**
   ```bash
   kubectl exec kafka-consumer-test -n default -- kafka-console-consumer --bootstrap-server "b-1.ticketbookingkafka.qjnue5.c8.kafka.us-east-1.amazonaws.com:9092" --topic ticket-bookings --from-beginning --max-messages 5
   ```

---

## 💡 **TIPS FOR RECORDING**

1. **Show the terminal clearly** - Make sure the command output is visible
2. **Point to specific values** - When results appear, point to key fields
3. **Explain what you're seeing** - Don't just read output, explain what it means
4. **Show the ID** - Display your student ID at the beginning
5. **Wait for output** - Don't rush, let commands complete before moving on
6. **Connect the dots** - Explain how these three commands show the complete pipeline
7. **Be natural** - Adapt this script to your speaking style

---

## 🔧 **TROUBLESHOOTING TALKING POINTS**

**If Flink job is not running:**
"Let me check if we need to submit the job. The job should be submitted using our Python script that connects to Dataproc and starts the Flink application."

**If cluster is not found:**
"The cluster might be in a different region or might need to be created. Let me verify the cluster exists using: `gcloud dataproc clusters list`"

**If Kafka consumer fails:**
"The test pod might not exist. We can create it using: `kubectl run kafka-consumer-test --image=bitnami/kafka --rm -it --restart=Never -- kafka-console-consumer --bootstrap-server [address] --topic ticket-bookings`"

---

**End of Script**

