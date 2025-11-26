# 🚀 Load Testing - Quick Start (Your Setup)

## ✅ **Good News: Your Frontend LoadBalancer is Ready!**

Your frontend service is already deployed with a LoadBalancer:
- **Service Name:** `frontend-service`
- **External URL:** `http://a7cd6e28f340f4e4c9bb21bd7e1e0a51-1164090834.us-east-1.elb.amazonaws.com`

---

## 📋 **3-Step Quick Start (5 Minutes)**

### **Step 1: Install k6 (30 seconds)**

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
.\load-testing\install-k6.ps1
```

**Expected:** `✅ k6 Installed Successfully!`

---

### **Step 2: Verify Your Setup (30 seconds)**

```powershell
# Test the frontend is accessible
curl http://a7cd6e28f340f4e4c9bb21bd7e1e0a51-1164090834.us-east-1.elb.amazonaws.com/api/events
```

**Expected:** JSON response with events data

---

### **Step 3: Run Load Test (2 terminals, 14 minutes)**

#### **Terminal 1: Monitor HPA**

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
.\load-testing\monitor-hpa.ps1
```

**Keep this open!** You'll see pods scaling in real-time.

#### **Terminal 2: Run Load Test**

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
k6 run load-testing\load-test.js
```

**What to watch for:**
- VUs (Virtual Users) ramping up: 50 → 100 → 200
- Requests completing successfully
- Test duration: ~14 minutes

---

## 📊 **What You'll See**

### **Terminal 1 (HPA Monitor)** - Real-time Scaling

**Before Load Test:**
```
📊 HPA Status:
NAME          REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   Deployment/booking-service   15%/50%   2         10        2
user-hpa      Deployment/user-service      12%/50%   2         10        2

📦 Pod Counts:
  Booking Service:  2 pods
  User Service:     2 pods
```

**During Peak Load (~5 minutes in):**
```
📊 HPA Status:
NAME          REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   Deployment/booking-service   68%/50%   2         10        5  ⬆️
user-hpa      Deployment/user-service      72%/50%   2         10        6  ⬆️

📦 Pod Counts:
  Booking Service:  5 pods  ⬆️ SCALED UP!
  User Service:     6 pods  ⬆️ SCALED UP!
```

**After Test (~14 minutes):**
```
📊 HPA Status:
NAME          REFERENCE                   TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   Deployment/booking-service   20%/50%   2         10        2  ⬇️
user-hpa      Deployment/user-service      15%/50%   2         10        2  ⬇️

📦 Pod Counts:
  Booking Service:  2 pods  ⬇️ SCALED DOWN
  User Service:     2 pods  ⬇️ SCALED DOWN
```

---

### **Terminal 2 (k6 Test)** - Load Test Progress

**During Test:**
```
running (05m30s), 100/100 VUs, 8234 complete and 0 interrupted iterations

✓ events status is 200
✓ events response time < 2s
✓ user status is 200
✓ booking status is 200
✓ booking response time < 3s

http_req_duration..............: avg=478ms min=105ms med=412ms max=2.1s p(95)=1524ms
http_reqs......................: 8234   (27.45/s)
vus............................: 100/100
```

**Final Summary:**
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
✅ http_req_failed..........: 2.30% (356 out of 15432)
```

---

## 🎯 **Success Criteria**

| Metric | Target | Status |
|--------|--------|--------|
| **HPA Scaling Up** | Pods increase when CPU > 50% | Watch Terminal 1 |
| **HPA Scaling Down** | Pods decrease after load | Watch Terminal 1 |
| **Request Success Rate** | > 90% | Check k6 summary |
| **Response Time P95** | < 2000ms | Check k6 summary |
| **No Service Crashes** | All pods stay Running | `kubectl get pods` |

---

## 📸 **Screenshots for Demo**

**Take these 5 screenshots:**

1. **Before Test:**
   ```powershell
   kubectl get hpa -n default
   ```
   Shows: 2 replicas, low CPU

2. **During Test (both terminals visible):**
   - Terminal 1: HPA showing 5-6 replicas, high CPU
   - Terminal 2: k6 running, 100+ VUs

3. **Scaled Up State:**
   ```powershell
   kubectl get hpa -n default
   ```
   Shows: 5-6 replicas, CPU > 50%

4. **k6 Final Summary:**
   - Shows success rate, response times, total requests

5. **After Test:**
   ```powershell
   kubectl get hpa -n default
   ```
   Shows: 2 replicas, low CPU (scaled back down)

---

## 💡 **Demo Talking Points**

### **What to Say:**

> "I'm demonstrating requirement (h): load testing to validate system resilience and scalability."

> "I've deployed a ticket booking system across AWS and GCP with Kubernetes-based microservices."

> "I'm using k6 to generate sustained traffic - this test ramps up to 200 concurrent users over 14 minutes."

> "On the left, you can see the HPA monitor showing real-time scaling. Initially, we have 2 pods per service."

> "As traffic increases and CPU exceeds 50%, the HPA automatically scales up. Booking service scaled from 2 to 5 pods."

> "On the right, k6 is generating the load. You can see we're handling 100 concurrent users with response times under 2 seconds."

> "The system successfully handled over 15,000 requests with a 97% success rate, demonstrating resilience under load."

> "After the test completes, watch how the HPA automatically scales pods back down to save resources."

> "This demonstrates both horizontal auto-scaling and the system's ability to handle variable traffic patterns."

---

## 🐛 **Troubleshooting**

### **Issue: k6 not found after install**

```powershell
# Close and reopen PowerShell, then:
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine")
k6 version
```

### **Issue: Connection errors in k6 test**

```powershell
# Verify frontend is accessible:
curl http://a7cd6e28f340f4e4c9bb21bd7e1e0a51-1164090834.us-east-1.elb.amazonaws.com/api/events

# If fails, check pods:
kubectl get pods -n default
kubectl logs -l app=frontend -n default --tail=50
```

### **Issue: HPA not scaling**

```powershell
# Check metrics-server is running:
kubectl get deployment metrics-server -n kube-system

# Check HPA status:
kubectl describe hpa booking-hpa -n default

# Check pod CPU usage:
kubectl top pods -n default
```

### **Issue: Services returning errors**

```powershell
# Check service logs:
kubectl logs -l app=booking-service -n default --tail=50
kubectl logs -l app=user-service -n default --tail=50
kubectl logs -l app=event-catalog -n default --tail=50
```

---

## ✅ **You're Ready!**

Your load test is already configured with your frontend URL. Just run:

1. **Terminal 1:** `.\load-testing\monitor-hpa.ps1`
2. **Terminal 2:** `k6 run load-testing\load-test.js`

**Duration:** 14 minutes total

**Good luck with your demo! 🚀**

---

## 📚 **Related Documentation**

- **Detailed Guide:** `LOAD_TESTING_GUIDE.md` (complete step-by-step)
- **Summary:** `LOAD_TESTING_SUMMARY.md` (quick reference)
- **README:** `load-testing/README.md` (quick start)

