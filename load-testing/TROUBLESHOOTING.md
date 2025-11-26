# 🔧 Load Testing Troubleshooting

## 🎯 Current Situation

### ✅ **What's Working:**
- ✅ k6 load test is running successfully (9+ minutes, 198/200 VUs, 8,729 iterations)
- ✅ Frontend LoadBalancer is accessible
- ✅ Services are responding to requests
- ✅ HPA is deployed (but can't scale due to missing metrics)

### ⚠️ **What's Not Working:**
- ❌ **Metrics Server is NOT installed** → HPA shows `cpu: <unknown>/50%`
- ❌ **HPA cannot scale** without CPU metrics
- ❌ **Monitor script had a PowerShell syntax error** (now fixed)

---

## 🚀 **Quick Fix (3 Steps)**

### **Step 1: Close Current Monitor (Terminal 6)**

In the terminal running `monitor-hpa.ps1`:
```powershell
# Press Ctrl+C to stop
```

### **Step 2: Install Metrics Server**

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"
.\load-testing\install-metrics-server.ps1
```

**This will:**
- Install metrics-server to your EKS cluster
- Wait 30-60 seconds for metrics to be available
- Verify metrics are working

### **Step 3: Restart Monitor & Wait for Scaling**

```powershell
.\load-testing\monitor-hpa.ps1
```

**Within 1-2 minutes, you should see:**
```
NAME          TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   15%/50%   2         10        2          ← CPU now visible!
```

**When load test increases CPU > 50%, HPA will scale:**
```
NAME          TARGETS   MINPODS   MAXPODS   REPLICAS
booking-hpa   68%/50%   2         10        5          ← SCALING UP!
```

---

## 📊 **Expected Timeline**

| Time | What Happens |
|------|--------------|
| **Now** | k6 test running (9 min in), HPA can't see CPU |
| **+1 min** | Install metrics-server |
| **+2 min** | Metrics available, HPA shows real CPU % |
| **+3-4 min** | Load increases, CPU > 50%, HPA scales pods |
| **+5-10 min** | Pods scale from 2 → 5-6 replicas |
| **+14 min** | k6 test completes |
| **+16-18 min** | CPU decreases, HPA scales pods back down |

---

## 🔍 **Why This Happened**

### **Missing Metrics Server**

EKS clusters **don't come with metrics-server pre-installed**. You need to install it manually.

Without metrics-server:
- HPA can't see CPU/memory usage
- HPA shows `cpu: <unknown>/50%`
- HPA cannot make scaling decisions
- Pods stay at minimum replicas (2)

### **PowerShell Syntax Error**

The original monitor script had:
```powershell
kubectl top pods -n default --sort-by=cpu 2>$null | Select-Object -First 4
```

PowerShell tried to interpret `Top` as a cmdlet, causing:
```
Top : The term 'Top' is not recognized...
```

**Fixed version** saves output first:
```powershell
$topOutput = kubectl top pods -n default --sort-by=cpu 2>$null
if ($topOutput) {
    $topOutput | Select-Object -First 4
}
```

---

## ✅ **Verification Commands**

### **Check Metrics Server**
```powershell
kubectl get deployment metrics-server -n kube-system
```
**Expected:** `READY 1/1`

### **Check Node Metrics**
```powershell
kubectl top nodes
```
**Expected:** Shows CPU/memory usage for nodes

### **Check Pod Metrics**
```powershell
kubectl top pods -n default
```
**Expected:** Shows CPU/memory usage for pods

### **Check HPA Status**
```powershell
kubectl get hpa -n default
```
**Expected:** Shows CPU percentages (not `<unknown>`)

### **Watch HPA in Real-Time**
```powershell
kubectl get hpa -n default --watch
```
**Expected:** See TARGETS and REPLICAS changing

---

## 🎥 **For Your Demo**

### **What to Show:**

1. **Before Metrics Server:**
   ```
   TARGETS: cpu: <unknown>/50%  ← No metrics
   REPLICAS: 2                   ← Stuck at minimum
   ```

2. **After Installing Metrics Server:**
   ```
   TARGETS: 15%/50%              ← Metrics working!
   REPLICAS: 2                   ← Ready to scale
   ```

3. **During High Load:**
   ```
   TARGETS: 68%/50%              ← Exceeds threshold
   REPLICAS: 5                   ← Scaled up!
   ```

4. **After Load Decreases:**
   ```
   TARGETS: 20%/50%              ← Below threshold
   REPLICAS: 2                   ← Scaled back down
   ```

### **What to Say:**

> "Initially, HPA couldn't scale because metrics-server wasn't installed. This is common in EKS clusters."

> "After installing metrics-server, HPA can now see real-time CPU usage."

> "As you can see, when CPU exceeds 50%, HPA automatically scales from 2 to 5 pods."

> "When the load decreases, HPA scales back down to 2 pods to save resources."

---

## 📁 **Updated Files**

- ✅ `load-testing/monitor-hpa.ps1` - Fixed PowerShell syntax error
- ✅ `load-testing/install-metrics-server.ps1` - NEW: Install metrics-server
- ✅ `load-testing/TROUBLESHOOTING.md` - This file

---

## 🆘 **If Still Not Working**

### **Metrics Server Not Starting**
```powershell
# Check logs
kubectl logs -n kube-system deployment/metrics-server

# Restart metrics-server
kubectl rollout restart deployment/metrics-server -n kube-system
```

### **HPA Still Shows `<unknown>`**
```powershell
# Wait 2 minutes, then check again
Start-Sleep -Seconds 120
kubectl get hpa -n default
```

### **Pods Not Scaling**
```powershell
# Check HPA events
kubectl describe hpa booking-hpa -n default

# Check pod CPU usage
kubectl top pods -n default
```

---

## 🎯 **Next Steps**

1. **Stop current monitor** (Ctrl+C in Terminal 6)
2. **Install metrics-server** (`.\load-testing\install-metrics-server.ps1`)
3. **Restart monitor** (`.\load-testing\monitor-hpa.ps1`)
4. **Watch the magic happen!** 🎉

Your k6 test is already running, so once metrics-server is installed, HPA will start scaling immediately!

**Good luck! 🚀**

