# Load Testing & HPA Monitoring Demo Script
## Video Recording Transcript for Part 4

---

## 🎬 **INTRODUCTION**

**What to say:**
"Hello, I'm [Your Name], ID [Your ID]. In this part of the demonstration, I'll show you how we validate the Horizontal Pod Autoscaler (HPA) functionality through load testing. This satisfies requirement (h) of the assignment, which requires load testing to demonstrate HPA scaling."

---

## 📋 **SETUP & CONTEXT**

**What to say:**
"Before we begin, let me explain what we're going to demonstrate:
1. First, I'll start a monitoring script that watches HPA and pod counts in real-time
2. Then, I'll run a load test using k6, which will gradually increase traffic
3. We'll observe how the HPA automatically scales pods based on CPU utilization
4. Finally, we'll review the results to show that the system maintained performance under load"

---

## 🔍 **PART 1: STARTING HPA MONITORING**

**Command to run:**
```powershell
.\load-testing\monitor-hpa.ps1
```

**What to say while running:**
"First, I'm starting the HPA monitoring script. This script will continuously watch our Kubernetes cluster and display:
- The current HPA status, showing target CPU utilization and current replica counts
- The actual pod counts for each service
- Resource usage metrics for the top CPU-consuming pods

This gives us real-time visibility into how the system responds to load. Notice that initially, we have 2 pods for the booking service and 2 pods for the user service, which matches our HPA minimum replica configuration."

**What to point out:**
- "You can see the HPA shows a target CPU utilization of 20%"
- "Current replicas are at the minimum: 2 pods for booking-service and 2 pods for user-service"
- "The script refreshes every 5 seconds, so we'll see updates in real-time"

---

## 🚀 **PART 2: RUNNING THE LOAD TEST**

**Open a NEW terminal window (keep monitoring running)**

**Command to run:**
```powershell
k6 run load-testing\load-test.js
```

**What to say before running:**
"Now I'll run the k6 load test. k6 is a modern load testing tool that simulates multiple users accessing our application. The test script is configured with several stages:
- Stage 1: Ramp up to 10 virtual users over 1 minute
- Stage 2: Increase to 50 users over 3 minutes
- Stage 3: Scale to 100 users over 5 minutes - this should trigger HPA scaling
- Stage 4: Peak load of 150 users for 3 minutes - maximum stress test
- Stage 5: Ramp down to 50 users over 2 minutes
- Stage 6: Cool down to 0 users over 1 minute

The test will hit multiple endpoints:
- Homepage access
- User registration
- Event listing
- Ticket booking
- User bookings retrieval
- Health checks

We have thresholds configured: 95% of requests must complete in under 500 milliseconds, and the error rate must stay below 10%."

**What to say while test is running:**
"As the test progresses, you can see:
- The number of virtual users increasing
- Request rate (requests per second) climbing
- Response time metrics being tracked
- Any errors being reported

Watch the monitoring window - you should start seeing the pod counts increase as CPU utilization rises above our 20% threshold."

**What to point out during test:**
- "Notice how the request rate is increasing as we add more virtual users"
- "The p95 latency is staying under our 500ms threshold, which is good"
- "If you look at the monitoring window, you can see pods starting to scale up"

---

## 📊 **PART 3: OBSERVING HPA SCALING**

**Switch back to monitoring window**

**What to say:**
"Let's check the monitoring window. You can see that:
- The HPA has detected increased CPU utilization
- The booking-service pod count has increased from 2 to [X] pods
- The user-service pod count has also scaled up
- The HPA status shows current CPU utilization above the 20% target

This demonstrates that our HPA configuration is working correctly. When the average CPU utilization across all pods exceeds 20%, Kubernetes automatically provisions new pods to handle the increased load."

**What to point out:**
- "Look at the HPA status - it shows 'Current Replicas: [X]' which is higher than the minimum of 2"
- "The CPU utilization metric shows we're above the 20% threshold"
- "Pod counts are dynamically adjusting - this is auto-scaling in action"

---

## 📈 **PART 4: ANALYZING RESULTS**

**After test completes**

**What to say:**
"The load test has completed. Let me show you the results:

From the k6 output, we can see:
- Total requests processed: [number]
- Average request rate: [X] requests per second
- Response time metrics:
  - Average: [X]ms
  - 95th percentile: [X]ms (under our 500ms threshold)
  - 99th percentile: [X]ms
- Error rate: [X]% (under our 10% threshold)

The test also generated a summary file: `load-test-summary.json` with detailed metrics."

**What to say about HPA:**
"Looking at the final HPA status:
- The system successfully scaled up to handle peak load
- As traffic decreased, the HPA will scale down pods to save resources
- The minimum replica count ensures we always have 2 pods for high availability

This validates that our HPA configuration satisfies requirement (c) - at least two critical services have Horizontal Pod Autoscalers configured."

---

## 🎯 **PART 5: KEY TAKEAWAYS**

**What to say:**
"Let me summarize what we've demonstrated:

1. **HPA Configuration**: Our booking-service and user-service have HPAs configured with:
   - Minimum replicas: 2 (for high availability)
   - Maximum replicas: 10 (to handle peak load)
   - Target CPU utilization: 20% (aggressive scaling for quick response)

2. **Load Testing**: The k6 test validated:
   - System can handle 150 concurrent users
   - Response times stay under 500ms
   - Error rates remain below 10%
   - HPA successfully scales to meet demand

3. **Observability**: We have full visibility into:
   - Pod scaling events
   - CPU utilization metrics
   - Request rates and latencies
   - Error rates

This demonstrates a production-ready, auto-scaling microservices architecture that can handle variable workloads efficiently."

---

## 🔧 **TECHNICAL DETAILS TO MENTION**

**If asked about configuration:**

**HPA Configuration:**
"The HPA is configured in our Kubernetes manifests using the `autoscaling/v2` API. It monitors CPU utilization and automatically adjusts replica counts. The 20% threshold means we scale up early to handle traffic spikes proactively."

**Load Test Script:**
"The k6 script uses a realistic user journey: users register, browse events, make bookings, and check their bookings. This simulates real-world usage patterns, not just simple health checks."

**Monitoring Script:**
"The monitoring script uses `kubectl` commands to query the cluster state. It polls every 5 seconds to show real-time scaling behavior. The script also logs all scaling events to a file for later analysis."

---

## 🎬 **CLOSING**

**What to say:**
"This concludes the load testing and HPA demonstration. We've successfully shown that:
- The system can handle variable workloads
- HPA automatically scales resources based on demand
- Performance metrics meet our defined thresholds
- The architecture is resilient and production-ready

Thank you for watching. This satisfies assignment requirement (h) for load testing and validates requirement (c) for HPA on critical services."

---

## 📝 **QUICK REFERENCE: COMMANDS TO RUN**

1. **Start Monitoring (Terminal 1):**
   ```powershell
   .\load-testing\monitor-hpa.ps1
   ```

2. **Run Load Test (Terminal 2):**
   ```powershell
   k6 run load-testing\load-test.js
   ```

3. **Check Results:**
   ```powershell
   kubectl get hpa
   kubectl get pods
   cat load-test-summary.json
   ```

---

## 💡 **TIPS FOR RECORDING**

1. **Show both terminals side-by-side** so viewers can see monitoring and load test simultaneously
2. **Point to specific numbers** when discussing metrics
3. **Wait for scaling events** - don't rush, let the HPA actually scale before moving on
4. **Explain what you're seeing** in real-time, don't just read the script
5. **Show the ID** clearly at the beginning of the video
6. **Keep it natural** - this is a guide, adapt it to your speaking style

---

**End of Script**

