# 🎥 HPA Scaling Demo - Terminal Commands for Recording

## 📋 Copy-Paste These Commands for Your Video

### **Step 1: Show Current HPA Status (AFTER Scaling)**

```powershell
kubectl get hpa -n default
```

**Expected Output (RECORD THIS!):**
```
NAME          REFERENCE                    TARGETS       MINPODS   MAXPODS   REPLICAS   AGE
booking-hpa   Deployment/booking-service   cpu: 2%/5%    2         10        2          5h53m
user-hpa      Deployment/user-service      cpu: 14%/5%   2         10        10         5h52m
                                            ^^^^^ OVER THRESHOLD!      ^^^ SCALED TO MAX!
```

---

### **Step 2: Show All Running Pods**

```powershell
kubectl get pods -n default
```

**Expected Output:**
```
NAME                               READY   STATUS    RESTARTS   AGE
booking-service-xxx                1/1     Running   0          10m
booking-service-yyy                1/1     Running   0          10m
user-service-xxx                   1/1     Running   0          5m   ← 10 PODS!
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
user-service-xxx                   1/1     Running   0          5m
```

---

### **Step 3: Show ONLY User Service Pods (Cleaner for Demo)**

```powershell
kubectl get pods -n default -l app=user-service
```

**Expected Output:**
```
NAME                            READY   STATUS    RESTARTS   AGE
user-service-859f65b55b-24v4n   1/1     Running   0          5m
user-service-859f65b55b-27gnt   1/1     Running   0          5m
user-service-859f65b55b-9kwrw   1/1     Running   0          5m
user-service-859f65b55b-cnzbh   1/1     Running   0          5m
user-service-859f65b55b-f8rpd   1/1     Running   0          5m
user-service-859f65b55b-m482v   1/1     Running   0          5m
user-service-859f65b55b-m5npt   1/1     Running   0          5m
user-service-859f65b55b-sqk6t   1/1     Running   0          5m
user-service-859f65b55b-xn5hg   1/1     Running   0          5m
user-service-859f65b55b-zv5w9   1/1     Running   0          5m

👉 10 REPLICAS (scaled from 2!)
```

---

### **Step 4: Count Pods (Proof of Scaling)**

```powershell
kubectl get pods -n default -l app=user-service --no-headers | Measure-Object | Select-Object -ExpandProperty Count
```

**Expected Output:**
```
10
```

---

### **Step 5: Show Resource Usage**

```powershell
kubectl top pods -n default --sort-by=cpu | Select-Object -First 12
```

**Expected Output:**
```
NAME                               CPU(cores)   MEMORY(bytes)
user-service-xxx                   8m           35Mi
user-service-xxx                   7m           34Mi
user-service-xxx                   6m           33Mi
user-service-xxx                   6m           35Mi
user-service-xxx                   5m           34Mi
user-service-xxx                   5m           32Mi
user-service-xxx                   4m           33Mi
user-service-xxx                   4m           35Mi
user-service-xxx                   3m           34Mi
user-service-xxx                   3m           32Mi

👉 Multiple user-service pods consuming CPU!
```

---

### **Step 6: Show HPA Events (Scaling History)**

```powershell
kubectl describe hpa user-hpa -n default | Select-String -Pattern "Scaled|Normal" -Context 0,1
```

**Expected Output:**
```
Events:
  Normal  SuccessfulRescale  5m   horizontal-pod-autoscaler  New size: 4; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  4m   horizontal-pod-autoscaler  New size: 7; reason: cpu resource utilization (percentage of request) above target
  Normal  SuccessfulRescale  3m   horizontal-pod-autoscaler  New size: 10; reason: cpu resource utilization (percentage of request) above target

👉 Shows HPA scaling from 2 → 4 → 7 → 10!
```

---

## 🎬 **Narration Script for Your Video**

### **What to Say While Recording:**

1. **Show HPA Status:**
   > "First, let me show the Horizontal Pod Autoscaler status. As you can see, the user-service HPA is showing 14% CPU usage against a 5% threshold. Because the CPU is above the threshold, the HPA has automatically scaled the service to 10 replicas, which is the maximum we configured."

2. **Show Pods:**
   > "Now, let me show the actual pods. Here you can see 10 user-service pods running, all in a healthy state. The HPA automatically created these 8 additional pods when it detected high CPU usage from the load test."

3. **Show Resource Usage:**
   > "Looking at the resource usage, we can see multiple user-service pods consuming CPU resources. The load is now distributed across all 10 replicas instead of just 2, which demonstrates how Kubernetes automatically scales to handle increased traffic."

4. **Show HPA Events:**
   > "Finally, the HPA events show the scaling history. You can see it scaled from 2 to 4 pods, then to 7, and finally to the maximum of 10. This demonstrates the system's resilience and ability to automatically respond to load."

---

## 📊 **One-Liner Summary Command (Best for Demo)**

```powershell
Write-Host "=== HPA SCALING DEMO ===" -ForegroundColor Cyan; `
Write-Host ""; `
Write-Host "HPA Status:" -ForegroundColor Green; `
kubectl get hpa -n default; `
Write-Host ""; `
Write-Host "User Service Pods (Scaled to 10!):" -ForegroundColor Green; `
kubectl get pods -n default -l app=user-service; `
Write-Host ""; `
Write-Host "Pod Count:" -ForegroundColor Green; `
$count = (kubectl get pods -n default -l app=user-service --no-headers | Measure-Object).Count; `
Write-Host "  Total user-service replicas: $count" -ForegroundColor Yellow
```

**This single command shows everything in one go!**

---

## ✅ **What This Proves for Your Assignment**

- ✅ **HPA is configured** (Requirement h)
- ✅ **Load test generated traffic** (k6 running)
- ✅ **System scaled automatically** (2 → 10 replicas)
- ✅ **Demonstrates resilience** (handles load by scaling)
- ✅ **Demonstrates scalability** (automatic horizontal scaling)

---

## 🎯 **Quick Recording Steps**

1. Open a clean PowerShell terminal
2. Run the "One-Liner Summary Command" above
3. Pause and explain each section
4. Run individual commands for more detail
5. Show HPA events for scaling history

**Total recording time: 2-3 minutes max!**

