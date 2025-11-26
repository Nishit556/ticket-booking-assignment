# 🔧 Recording Fix - Fresh Start Required

## 🚨 **Problem Identified:**

The **old k6 load test from Terminal 7 is STILL RUNNING!**

**Current Status:**
- ✅ HPA thresholds set to 20%
- ❌ **Booking-service CPU: 73%/20%** (old load test still active!)
- ❌ **Already scaled to 4 replicas** before recording started
- ❌ User-service at 10%/20% (2 replicas)

---

## ✅ **Fix - 3 Steps to Clean Start**

### **Step 1: STOP the Old Load Test** ⚠️ CRITICAL!

**In Terminal 7 (where the old k6 test is running):**

```powershell
# Press Ctrl+C to kill the k6 process
```

**Expected:** k6 test stops, traffic drops immediately

---

### **Step 2: Wait for Cooldown** (2-3 minutes)

Wait for CPU to drop below 20% so HPA scales back to 2 replicas:

```powershell
# Monitor in real-time (run this in Terminal 1):
kubectl get hpa -n default --watch
```

**What to watch for:**
```
NAME          TARGETS        REPLICAS
booking-hpa   cpu: 73%/20%   4        ← Starting point
booking-hpa   cpu: 45%/20%   4        ← Still cooling down...
booking-hpa   cpu: 18%/20%   4        ← Getting close...
booking-hpa   cpu: 15%/20%   2        ← READY! ✅ (scales back to 2)
user-hpa      cpu: 8%/20%    2        ← READY! ✅
```

**How long?** Usually **2-3 minutes** after stopping k6.

**To check manually:**
```powershell
kubectl get hpa -n default
```

---

### **Step 3: Start Fresh Recording** 🎬

**Only when BOTH services show:**
- ✅ **CPU below 20%**
- ✅ **Exactly 2 replicas**

**Then start your recording:**

**Terminal 1: Monitor HPA**
```powershell
.\load-testing\monitor-hpa.ps1
```

**Terminal 2: Start NEW Load Test** (wait 10 seconds after Terminal 1)
```powershell
k6 run load-testing\load-test.js
```

---

## 📊 **Expected Recording Timeline:**

| Time | CPU | Booking Replicas | User Replicas | Event |
|------|-----|------------------|---------------|-------|
| 0:00 | 5-10% | 2 | 2 | **🎬 START RECORDING** |
| 0:30 | 15% | 2 | 2 | Load ramping up |
| 2:00 | 25% | 2 → 3 | 2 | **First scale-up!** |
| 4:00 | 40% | 3 → 5 | 2 → 3 | **Gradual scaling** |
| 7:00 | 55% | 5 → 7 | 3 → 5 | **More pods added** |
| 10:00 | 60% | 7 → 8 | 5 → 7 | **Peak load** |
| 12:00 | 40% | 8 → 6 | 7 → 5 | **Scaling down** |
| 14:00 | 20% | 6 → 4 | 5 → 3 | **Test complete** |

---

## 🎯 **Current Status Checklist:**

Before recording, verify:

```powershell
kubectl get hpa -n default
```

**Must show:**
- [ ] `booking-hpa`: `cpu: <20%/20%`, `REPLICAS: 2`
- [ ] `user-hpa`: `cpu: <20%/20%`, `REPLICAS: 2`

```powershell
kubectl get pods -n default | Select-String "booking-service|user-service"
```

**Must show:**
- [ ] Exactly **2 booking-service pods** (Running)
- [ ] Exactly **2 user-service pods** (Running)

---

## 🚨 **If HPA Scales Too Fast (>20% threshold):**

If 20% threshold still causes instant scaling, try **30%**:

```powershell
# Edit the files:
# In k8s-gitops/apps/booking-service.yaml: averageUtilization: 20 → 30
# In k8s-gitops/apps/user-service.yaml: averageUtilization: 20 → 30

# Then commit and sync via ArgoCD:
git add k8s-gitops/apps/booking-service.yaml k8s-gitops/apps/user-service.yaml
git commit -m "Relax HPA threshold to 30%"
git push origin main
argocd app sync ticket-booking-app
```

---

## 📋 **Summary:**

1. ⚠️ **STOP Terminal 7** (Ctrl+C on k6 test)
2. ⏳ **Wait 2-3 minutes** (CPU drops, replicas → 2)
3. ✅ **Verify clean state** (both at 2 replicas, <20% CPU)
4. 🎬 **Start recording** (monitor + new k6 test)

**You MUST stop the old load test first, or the pods will keep scaling before your recording starts!**

