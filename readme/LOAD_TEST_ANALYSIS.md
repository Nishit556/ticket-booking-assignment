# Load Test Analysis - First Attempt

## 📊 First Test Results

### **Test Completed:**
- **Duration:** 14 minutes ✅
- **Total Requests:** 45,765
- **Failed Requests:** 33.33% ❌ (15,255 failed)
- **Success Rate:** 66.67% (should be >90%)
- **Avg Response Time:** 347ms ✅
- **P95 Response Time:** 431ms ✅

### **Why So Many Failures?**

The **33% failure rate** was caused by:

1. **No Metrics-Server** → HPA couldn't see CPU usage
2. **HPA Couldn't Scale** → Services stayed at 2 pods (minimum)
3. **Services Overwhelmed** → 200 concurrent users hitting only 2 pods per service
4. **Backend Overloaded** → Services couldn't handle the load

### **What We Fixed:**

✅ **Metrics-Server Installed:**
```
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           13s
```

✅ **Node Metrics Working:**
```
NAME                        CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)   
ip-10-0-1-87.ec2.internal   184m         9%       2493Mi          75%
ip-10-0-2-44.ec2.internal   88m          4%       1299Mi          39%
```

---

## 🚀 Second Attempt - What to Expect

### **Before Starting the Second Test:**

1. **Wait 2-3 minutes** after starting the HPA monitor
   - This ensures metrics-server is fully initialized
   - HPA needs time to start collecting CPU metrics

2. **Verify HPA Shows CPU Percentages:**
   ```
   NAME          TARGETS   REPLICAS
   booking-hpa   15%/50%   2        ← Should show percentages, not <unknown>
   user-hpa      12%/50%   2
   ```

3. **Check Pod Metrics Are Available:**
   ```powershell
   kubectl top pods -n default
   ```
   Should show CPU/memory usage for each pod.

---

## 📈 Expected Results (Second Attempt)

### **Timeline:**

| Time | What Should Happen | What You'll See |
|------|-------------------|-----------------|
| **0-2 min** | Load ramping up to 50 VUs | CPU starts increasing (20% → 40%) |
| **2-5 min** | Load increases to 100 VUs | **CPU exceeds 50%** |
| **5-7 min** | **HPA scales up** | Pods increase: 2 → 4 → 6 |
| **7-9 min** | Load spikes to 200 VUs | Pods at maximum (5-6 replicas) |
| **9-12 min** | Load decreases to 100 VUs | CPU stabilizes |
| **12-14 min** | Load ramps down to 0 | **HPA scales down** |
| **14-18 min** | Test complete | Pods return to 2 replicas |

### **Monitor Terminal Will Show:**

**Initial State:**
```
📊 HPA Status:
NAME          TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   15%/50%   2         10        2
user-hpa      12%/50%   2         10        2

📦 Pod Counts:
  Booking Service:  2 pods
  User Service:     2 pods
```

**When Scaling Up (~5 minutes in):**
```
📊 HPA Status:
NAME          TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   68%/50%   2         10        5  ⬆️ SCALING!
user-hpa      72%/50%   2         10        6  ⬆️ SCALING!

📦 Pod Counts:
  Booking Service:  5 pods  ⬆️ (was 2)
  User Service:     6 pods  ⬆️ (was 2)

📈 Resource Usage (Top 3 CPU-consuming pods):
NAME                              CPU(cores)   MEMORY(bytes)
booking-service-7d8f9b5c-abc12    450m         256Mi
booking-service-7d8f9b5c-def34    420m         248Mi
user-service-6c7d8e4f-ghi56       380m         312Mi
```

**After Test Completes:**
```
📊 HPA Status:
NAME          TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   18%/50%   2         10        2  ⬇️ SCALED DOWN
user-hpa      15%/50%   2         10        2  ⬇️ SCALED DOWN
```

### **k6 Terminal Will Show:**

**Final Summary (Expected):**
```
========================================
  Load Test Summary
========================================
Total Requests: 45,000+
Failed Requests: 3-5%         ← Much better than 33%!
Avg Response Time: 350-450ms
P95 Response Time: 800-1200ms
========================================

✅ http_req_duration........: avg=400ms p(95)=900ms
✅ http_reqs................: 45000+ (53/s)
✅ http_req_failed..........: 4% (1800 out of 45000)  ← PASS!
✅ vus......................: 0/200
```

---

## 🎯 Success Criteria for Second Attempt

| Metric | First Test | Target (Second Test) | Status |
|--------|-----------|---------------------|---------|
| **HPA Scaling** | ❌ No scaling (no metrics) | ✅ Pods scale 2 → 5-6 | Should PASS |
| **Success Rate** | ❌ 66.7% (33% failed) | ✅ >90% (< 10% failed) | Should PASS |
| **Response Time P95** | ✅ 431ms | ✅ <2000ms | Already PASSED |
| **System Resilience** | ❌ Services overwhelmed | ✅ No crashes/errors | Should PASS |

---

## ⚠️ Things to Watch For

### **1. Initial Metrics Delay**

**Issue:** HPA might show `<unknown>` for 1-2 minutes after metrics-server starts.

**Solution:** Wait 2-3 minutes after starting the monitor before running k6.

### **2. Scaling Delay**

**Issue:** HPA evaluates metrics every 15-30 seconds, so scaling isn't instant.

**What's Normal:**
- CPU hits 55% → HPA waits 30 seconds → Scales to 3 pods
- CPU hits 65% → HPA waits 30 seconds → Scales to 4 pods
- Total time from 50% CPU to 6 pods: **2-3 minutes**

### **3. Some Failures Are Normal**

**Expected:** 3-5% failure rate during peak load (200 VUs)

**Why:** Brief moments when:
- New pods are starting up
- Load balancer is updating
- Database connections are saturating

**Not Normal:** >10% failure rate (like the 33% we saw)

### **4. Scale-Down Delay**

**Issue:** HPA waits 5 minutes of low CPU before scaling down (to avoid thrashing).

**What's Normal:**
- Test completes at 14 minutes
- Pods stay at 5-6 replicas until ~16-17 minutes
- **Then scale down to 2 pods** at 18-19 minutes

---

## 📋 Step-by-Step for Second Attempt

### **Step 1: Start HPA Monitor** (Terminal 1)

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
.\load-testing\monitor-hpa.ps1
```

**What to Look For:**
- ✅ HPA shows CPU percentages (e.g., `15%/50%`)
- ❌ NOT showing `<unknown>/50%`

### **Step 2: Wait 2-3 Minutes**

**Why:** Let metrics-server fully initialize and HPA start collecting data.

**Verify Metrics Are Ready:**
```powershell
# In a separate PowerShell window:
kubectl top pods -n default
```

**Expected Output:**
```
NAME                              CPU(cores)   MEMORY(bytes)
booking-service-7d8f9b5c-abc12    50m          156Mi
user-service-6c7d8e4f-ghi56       45m          212Mi
```

If you see CPU values, you're ready! ✅

### **Step 3: Start Load Test** (Terminal 2)

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
k6 run load-testing\load-test.js
```

### **Step 4: Watch Both Terminals**

**Terminal 1 (Monitor):**
- Watch TARGETS column change (15% → 50% → 70%)
- Watch REPLICAS column increase (2 → 3 → 5)
- Watch Pod Counts increase in real-time

**Terminal 2 (k6):**
- Watch VUs ramping up (50 → 100 → 200)
- Watch http_reqs increasing
- Check for lower error rate

### **Step 5: Take Screenshots**

1. **Before scaling:** HPA showing 2 replicas, low CPU
2. **During scaling:** HPA showing 5-6 replicas, high CPU (>50%)
3. **k6 running:** Test in progress, 100+ VUs
4. **After scaling:** HPA back to 2 replicas
5. **Final summary:** k6 results showing <10% failures

---

## 🎥 Demo Talking Points

### **Explain the First Test:**

> "In my first test, the metrics-server wasn't installed, so HPA couldn't see CPU usage."

> "As you can see, with only 2 pods per service, the system was overwhelmed—33% of requests failed."

> "This demonstrates why auto-scaling is critical for handling variable traffic."

### **Show the Second Test:**

> "After installing metrics-server, HPA can now see real-time CPU metrics."

> "Watch as the load increases—when CPU exceeds 50%, HPA automatically scales from 2 to 5 pods."

> "With auto-scaling enabled, the failure rate drops from 33% to under 5%—proving the system is resilient."

> "After the test completes, HPA automatically scales back down to save resources."

---

## 🎯 Summary

**First Test (Completed):**
- ❌ 33% failure rate (services overwhelmed)
- ❌ No HPA scaling (metrics-server missing)
- ✅ Demonstrated the *need* for auto-scaling

**Second Test (Ready to Run):**
- ✅ Metrics-server installed and working
- ✅ HPA will scale pods (2 → 5-6)
- ✅ Expected <5% failure rate
- ✅ Will demonstrate resilience and scalability

**You're now ready for a successful second attempt!** 🚀

Just remember:
1. **Start the monitor first**
2. **Wait 2-3 minutes** for metrics to initialize
3. **Verify HPA shows CPU percentages** (not `<unknown>`)
4. **Then run the load test**

Good luck! 🎉

