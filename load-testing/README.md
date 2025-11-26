# Load Testing - Quick Start

## 🚀 Quick Setup (5 Minutes)

### 1. Install k6
```powershell
.\load-testing\install-k6.ps1
```

### 2. Get Frontend URL
```powershell
kubectl get svc frontend -n default
```
Copy the EXTERNAL-IP.

### 3. Update Load Test Script
Edit `load-testing/load-test.js`:
```javascript
const BASE_URL = 'http://YOUR_FRONTEND_EXTERNAL_IP';
```

### 4. Run Test (2 Terminals)

**Terminal 1 - Monitor HPA:**
```powershell
.\load-testing\monitor-hpa.ps1
```

**Terminal 2 - Run Load Test:**
```powershell
k6 run load-testing/load-test.js
```

---

## 📊 What You'll See

### Before Test
```
NAME          TARGETS   REPLICAS
booking-hpa   15%/50%   2
user-hpa      12%/50%   2
```

### During Test (After ~5 minutes)
```
NAME          TARGETS   REPLICAS
booking-hpa   68%/50%   5  ⬆️ SCALED UP!
user-hpa      72%/50%   6  ⬆️ SCALED UP!
```

### After Test
```
NAME          TARGETS   REPLICAS
booking-hpa   20%/50%   2  ⬇️ SCALED DOWN
user-hpa      15%/50%   2  ⬇️ SCALED DOWN
```

---

## 📁 Files

- `install-k6.ps1` - Installs k6 on Windows
- `load-test.js` - Main load test script (14 minutes, 0-200 users)
- `load-test-direct.js` - Alternative test (9 minutes, simpler)
- `monitor-hpa.ps1` - Real-time HPA monitoring script

---

## 📖 Full Documentation

See `LOAD_TESTING_GUIDE.md` for complete step-by-step instructions.

---

## ✅ Success Checklist

- [ ] k6 installed and working (`k6 version`)
- [ ] Frontend URL configured in `load-test.js`
- [ ] HPA monitor running in Terminal 1
- [ ] Load test running in Terminal 2
- [ ] Pods scaling up (2 → 5+ replicas)
- [ ] Pods scaling down (after traffic decreases)
- [ ] Test completes with > 90% success rate

---

## 🐛 Troubleshooting

**Q: k6 not found?**  
A: Close and reopen PowerShell, then run `k6 version`

**Q: Connection errors in test?**  
A: Verify frontend URL: `curl http://YOUR_FRONTEND_IP/api/events`

**Q: HPA not scaling?**  
A: Check metrics-server: `kubectl get deployment metrics-server -n kube-system`

---

## 🎯 Demo Talking Points

1. "I'm using k6 to generate sustained traffic"
2. "Initially we have 2 pods per service (minimum replicas)"
3. "As CPU exceeds 50%, HPA automatically scales pods"
4. "Services scaled from 2 to 6 pods under load"
5. "System handles 15K+ requests with 97% success rate"
6. "After traffic decreases, pods automatically scale back down"
7. "This demonstrates both resilience and scalability"

**Good luck! 🚀**
