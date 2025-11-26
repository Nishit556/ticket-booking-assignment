# 🚀 Load Testing Guide - HPA Scaling Demonstration

## 📋 Overview

This guide demonstrates **Requirement (h)** from the assignment:
> "Use a load testing tool (e.g., k6, JMeter, Gatling) to validate your system's resilience and scalability. Load Test: Generate sustained traffic to demonstrate the HPA scaling out your services."

---

## 🎯 What We'll Demonstrate

1. **Sustained Traffic Generation** using k6
2. **HPA (Horizontal Pod Autoscaler) Scaling** in real-time
3. **System Resilience** under load
4. **Automatic Scale-Up** when CPU exceeds 50%
5. **Automatic Scale-Down** when traffic decreases

---

## 📦 Prerequisites

- ✅ Kubernetes cluster running (EKS)
- ✅ Services deployed with HPA configured
- ✅ Frontend LoadBalancer service with external IP
- ✅ Windows PowerShell

---

## 🚀 Step-by-Step Instructions

### **Step 1: Install k6 Load Testing Tool**

**Where:** Run in your normal **PowerShell terminal**

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
.\load-testing\install-k6.ps1
```

**What this does:**
- Installs Chocolatey (Windows package manager) if not present
- Installs k6 load testing tool
- Verifies installation

**Expected output:**
```
✅ k6 Installed Successfully!
k6 v0.47.0 (or similar version)
```

---

### **Step 2: Get Your Frontend URL**

**Where:** Run in **PowerShell**

```powershell
kubectl get svc frontend -n default
```

**Expected output:**
```
NAME       TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)        AGE
frontend   LoadBalancer   10.100.12.34    a1b2c3d4e5f6g7h8.us-east-1.elb.amazonaws.com   80:30123/TCP   1h
```

**Copy the EXTERNAL-IP** (e.g., `a1b2c3d4e5f6g7h8.us-east-1.elb.amazonaws.com`)

---

### **Step 3: Configure Load Test Script**

**Where:** Edit the file in your IDE

1. Open: `load-testing/load-test.js`
2. Find line 10: `const BASE_URL = 'http://YOUR_FRONTEND_IP';`
3. Replace with your frontend URL:
   ```javascript
   const BASE_URL = 'http://a1b2c3d4e5f6g7h8.us-east-1.elb.amazonaws.com';
   ```
4. Save the file

---

### **Step 4: Check Initial State**

**Where:** Run in **PowerShell**

```powershell
# Check HPA configuration
kubectl get hpa -n default

# Check current pod count
kubectl get pods -n default | Select-String "booking-service|user-service|event-catalog|frontend"
```

**Expected output:**
```
NAME          REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS   AGE
booking-hpa   Deployment/booking-service   15%/50%   2         10        2          1h
user-hpa      Deployment/user-service      10%/50%   2         10        2          1h
```

**Key points:**
- `TARGETS`: Current CPU% / Target CPU% (50%)
- `MINPODS`: 2 (minimum replicas)
- `MAXPODS`: 10 (maximum replicas)
- `REPLICAS`: Current number of pods (should be 2 initially)

---

### **Step 5: Start HPA Monitor (Terminal 1)**

**Where:** Open a **NEW PowerShell terminal**

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
.\load-testing\monitor-hpa.ps1
```

**What this does:**
- Shows real-time HPA status
- Displays current pod counts
- Shows CPU usage of top pods
- Logs scaling events to `hpa-scaling-log.txt`
- Refreshes every 5 seconds

**Keep this terminal open and visible!**

---

### **Step 6: Run Load Test (Terminal 2)**

**Where:** In your **ORIGINAL PowerShell terminal**

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
k6 run load-testing/load-test.js
```

**What happens:**
1. **0-2 minutes:** Ramps up to 50 virtual users
2. **2-7 minutes:** Increases to 100 users (🔥 **HPA should trigger here!**)
3. **7-9 minutes:** Spikes to 200 users
4. **9-12 minutes:** Scales back to 100 users
5. **12-14 minutes:** Ramps down to 0 users

**Expected output (during test):**
```
     ✓ events status is 200
     ✓ events response time < 2s
     ✓ booking status is 200
     
     http_reqs......................: 1234   41.23/s
     http_req_duration..............: avg=450ms min=100ms med=400ms max=2000ms p(95)=1500ms
     vus............................: 100/100 min=0 max=200
```

---

### **Step 7: Watch HPA Scaling in Real-Time**

**Where:** Look at **Terminal 1** (HPA Monitor)

**What you'll see:**

**Initial State (low traffic):**
```
📊 HPA Status:
NAME          REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   Deployment/booking-service   15%/50%   2         10        2
user-hpa      Deployment/user-service      12%/50%   2         10        2

📦 Pod Counts:
  Booking Service:  2 pods
  User Service:     2 pods
```

**After 5 minutes (high traffic - SCALING UP):**
```
📊 HPA Status:
NAME          REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   Deployment/booking-service   68%/50%   2         10        5  ✅ SCALED UP!
user-hpa      Deployment/user-service      72%/50%   2         10        6  ✅ SCALED UP!

📦 Pod Counts:
  Booking Service:  5 pods  ⬆️
  User Service:     6 pods  ⬆️
```

**After 12 minutes (traffic decreases - SCALING DOWN):**
```
📊 HPA Status:
NAME          REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   Deployment/booking-service   25%/50%   2         10        3  ⬇️ SCALING DOWN
user-hpa      Deployment/user-service      20%/50%   2         10        2  ⬇️ SCALED DOWN

📦 Pod Counts:
  Booking Service:  3 pods  ⬇️
  User Service:     2 pods  ⬇️
```

---

### **Step 8: Analyze Results**

**Where:** After test completes (in **Terminal 2**)

k6 will display a summary:

```
========================================
  Load Test Summary
========================================
Total Requests: 15,432
Failed Requests: 2.3%
Avg Response Time: 478ms
P95 Response Time: 1,524ms
========================================

✅ http_req_duration........: avg=478ms min=105ms med=412ms max=2.1s p(95)=1524ms
✅ http_reqs................: 15432  (51.44/s)
✅ vus......................: 0/200  min=0 max=200
```

**Review the HPA log:**

```powershell
Get-Content load-testing/hpa-scaling-log.txt
```

---

## 📊 What to Show in Your Demo

### **1. Before Load Test**
- Show initial pod count (2 pods per service)
- Show low CPU usage (< 50%)

### **2. During Load Test**
- **Split screen with both terminals visible:**
  - Terminal 1: HPA monitor showing scaling
  - Terminal 2: k6 running load test
- **Point out when HPA triggers:**
  - CPU exceeds 50%
  - REPLICAS count increases
  - New pods appear in pod count

### **3. After Load Test**
- Show pods scaling back down
- Show successful request rate (> 90%)
- Show average response times remained acceptable

---

## 🎥 Demo Script (What to Say)

> "Now I'll demonstrate system resilience and scalability using k6 load testing."

> "Initially, we have 2 pods per service, as defined by our HPA minimum replicas."

> "I'm starting a load test that ramps up to 200 concurrent users over 14 minutes."

> "As you can see in the monitor, when CPU usage exceeds 50%, the HPA automatically scales up the pods."

> "The booking-service scaled from 2 to 5 pods, and user-service scaled from 2 to 6 pods."

> "Despite the increased load, our response times remain acceptable (< 2 seconds for 95% of requests)."

> "As traffic decreases, the HPA automatically scales pods back down to save resources."

> "The system handled 15,000+ requests with a 97.7% success rate, demonstrating resilience."

---

## ✅ Success Criteria

| Criterion | Target | How to Verify |
|-----------|--------|---------------|
| **HPA Scaling Up** | Pods increase when CPU > 50% | Watch Terminal 1 (HPA monitor) |
| **HPA Scaling Down** | Pods decrease when traffic drops | Watch Terminal 1 after 12 minutes |
| **Request Success Rate** | > 90% | Check k6 summary (`http_req_failed`) |
| **Response Time** | P95 < 2000ms | Check k6 summary (`http_req_duration`) |
| **System Resilience** | No crashes/errors | Pods remain in `Running` state |

---

## 🐛 Troubleshooting

### **Issue: k6 not found**
**Solution:**
```powershell
# Close and reopen PowerShell, then:
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
k6 version
```

### **Issue: Connection refused / 404 errors**
**Solution:**
- Verify frontend URL is correct
- Test manually: `curl http://YOUR_FRONTEND_IP/api/events`
- Check services are running: `kubectl get pods -n default`

### **Issue: HPA not scaling**
**Solution:**
- Check metrics-server is running: `kubectl get deployment metrics-server -n kube-system`
- Verify HPA exists: `kubectl get hpa -n default`
- Increase load duration or intensity in `load-test.js`

### **Issue: All requests failing**
**Solution:**
- Check backend services logs:
  ```powershell
  kubectl logs -l app=booking-service -n default --tail=50
  kubectl logs -l app=user-service -n default --tail=50
  ```

---

## 📁 Generated Files

After running the test, you'll have:

1. **`load-testing/hpa-scaling-log.txt`** - Timestamped log of pod scaling events
2. **`load-test-summary.json`** - Detailed k6 test results (JSON format)

**Save these for your assignment submission!**

---

## 🎓 Assignment Requirement Checklist

- ✅ **Load testing tool used:** k6
- ✅ **Sustained traffic generated:** 14-minute test with 50-200 concurrent users
- ✅ **HPA scaling demonstrated:** Pods scale up when CPU > 50%, scale down when traffic decreases
- ✅ **Resilience validated:** System handles 15K+ requests with > 90% success rate
- ✅ **Scalability validated:** Services automatically scale from 2 to 6+ pods under load

---

## 📸 Screenshots to Take for Demo

1. **Initial state:** `kubectl get hpa` showing 2 replicas
2. **During load test:** Both terminals side-by-side showing scaling
3. **Scaled up state:** HPA showing 5-6 replicas with high CPU
4. **k6 summary:** Final load test results
5. **Scaled down state:** HPA back to 2 replicas after test

---

## 🚀 Quick Reference Commands

```powershell
# Install k6
.\load-testing\install-k6.ps1

# Get frontend URL
kubectl get svc frontend -n default

# Check HPA status
kubectl get hpa -n default

# Monitor HPA (Terminal 1)
.\load-testing\monitor-hpa.ps1

# Run load test (Terminal 2)
k6 run load-testing/load-test.js

# View scaling log
Get-Content load-testing/hpa-scaling-log.txt
```

---

## 🎉 You're Ready!

Follow the steps above, and you'll have a complete demonstration of load testing, HPA scaling, and system resilience for your assignment!

**Good luck with your demo! 🚀**

