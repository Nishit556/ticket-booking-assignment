# 🎬 HPA Scaling Demo - Recording Setup

## ✅ Changes Made

**HPA Thresholds Updated:**
- `booking-hpa`: **5% → 20% CPU** ✅
- `user-hpa`: **5% → 20% CPU** ✅

**Why?**
- Scaling is now **gradual** (not instant)
- Perfect for demonstrating HPA behavior in your video
- Shows: 2 pods → 4 pods → 6 pods → 8 pods (gradual increase)

---

## 🎯 Before Recording - Setup Steps

### **Step 1: Stop the Current Load Test**

**In Terminal 7 (where k6 is running):**
```powershell
# Press Ctrl+C to stop the k6 load test
```

### **Step 2: Wait for Pods to Scale Down**

Wait **5 minutes** for HPA to automatically scale back to 2 pods:

```powershell
# Check every minute
kubectl get hpa -n default
```

**Expected after 5 minutes:**
```
NAME          TARGETS        REPLICAS
booking-hpa   cpu: 2%/20%    2        ← Back to minimum
user-hpa      cpu: 2%/20%    2        ← Back to minimum
```

### **Step 3: Verify Clean State**

```powershell
kubectl get pods -n default -l app=user-service
```

**Expected:** Only **2 user-service pods** running

---

## 🎥 Recording Steps (After Setup)

### **Terminal 1: HPA Monitor** (Start this first)

```powershell
.\load-testing\monitor-hpa.ps1
```

**What you'll see:**
```
HPA Status:
NAME          TARGETS        REPLICAS
booking-hpa   cpu: 2%/20%    2
user-hpa      cpu: 2%/20%    2
```

### **Terminal 2: Start Load Test** (Wait 10 seconds after Terminal 1)

```powershell
k6 run load-testing\load-test.js
```

---

## 📊 What to Expect During Recording

### **Timeline (14-minute test):**

| Time | CPU Usage | Replicas | Status |
|------|-----------|----------|--------|
| 0-2 min | 5-15% | 2 | Starting up |
| 2-5 min | 20-35% | 2 → 4 | **🎬 Scaling begins!** |
| 5-8 min | 35-50% | 4 → 6 | **🎬 Gradual scaling** |
| 8-10 min | 50-60% | 6 → 8 | **🎬 More scaling** |
| 10-12 min | 40-50% | 8 | Sustained load |
| 12-14 min | 20-30% | 8 → 6 | **🎬 Scaling down** |

---

## 🎯 Key Points to Mention in Video

1. **"Initial State"**: 2 pods per service (minimum replicas)
2. **"Load Test Starts"**: k6 generating 50-200 concurrent users
3. **"CPU Exceeds 20%"**: HPA detects high usage
4. **"Automatic Scaling"**: Kubernetes adds pods (2 → 4 → 6 → 8)
5. **"Load Decreases"**: HPA scales down (8 → 6 → 4 → 2)

---

## 📋 Assignment Requirement (h) - What You're Demonstrating

> **"Use a load testing tool (e.g., k6, JMeter, Gatling) to validate your system's resilience and scalability. Load Test: Generate sustained traffic to demonstrate the HPA scaling out your services."**

✅ **Tool Used:** k6 (modern, scriptable load testing tool)  
✅ **Traffic Generated:** 0-200 concurrent users over 14 minutes  
✅ **HPA Behavior:** Automatic scaling from 2 → 10 pods based on CPU (20% threshold)  
✅ **Resilience:** System handles load without crashing  
✅ **Scalability:** Pods scale up/down automatically with load

---

## 🚨 Important Notes

1. **Wait 5 minutes** after stopping the old test before starting the new recording
2. **Start monitoring first**, then start load test (so you capture the scaling)
3. **Don't interrupt** the 14-minute test once started
4. **Recording duration:** ~15 minutes total (14 min test + 1 min explanation)

---

## 🎬 Current Status

- ✅ HPA thresholds set to **20%**
- ⏳ **WAITING**: Current load test still running (pods at 6-10 replicas)
- 🔄 **NEXT**: Stop Terminal 7, wait 5 minutes, then record fresh demo

---

## 📞 Quick Reference Commands

```powershell
# Check HPA status
kubectl get hpa -n default

# Check pod count
kubectl get pods -n default -l app=user-service

# Check CPU usage
kubectl top pods -n default -l app=user-service
```

