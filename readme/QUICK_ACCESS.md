# 🚀 Quick Access Guide - Ticket Booking System

**Last Updated:** 2025-11-20

---

## 🌐 Application URLs

### Frontend Application
**URL:** `http://ab281cfd51be84e1aa3f813cfc6d4a85-918774444.us-east-1.elb.amazonaws.com`

**Features:**
- User Registration
- Event Browsing
- Ticket Booking
- Ticket Generation (Lambda)
- Service Status Panel

---

### Grafana Dashboard (Monitoring)
**URL:** `http://a0b290f92f26546da960c8a80342b05b-680390527.us-east-1.elb.amazonaws.com`

**Login:**
- Username: `admin`
- Password: `prom-operator`

**What to see:**
- Service metrics (RPS, latency, error rates)
- Kubernetes cluster health
- Pod CPU/Memory usage
- HPA scaling metrics

---

## 📊 Current Deployment Status

### Services Running
| Service | Pods | Status |
|---------|------|--------|
| Frontend | 2/2 | ✅ Running |
| Booking Service | 2/2 | ✅ Running |
| Event Catalog | 2/2 | ✅ Running |
| User Service | 2/2 | ✅ Running |

### HPAs Active
- ✅ `booking-hpa` (2-10 pods, CPU > 50%)
- ✅ `user-hpa` (2-10 pods, CPU > 50%)

### Infrastructure
- ✅ EKS Cluster: `ticket-booking-cluster`
- ✅ MSK Kafka: `ticket-booking-kafka`
- ✅ RDS PostgreSQL: Active
- ✅ DynamoDB: `ticket-booking-users`
- ✅ S3 Bucket: `ticket-booking-raw-data-1f8db074`
- ✅ Lambda: `ticket-generator-func`
- ✅ Prometheus + Grafana: Deployed

---

## 🔑 Quick Commands

### Check Pods
```powershell
kubectl get pods
```

### Check Services
```powershell
kubectl get svc
```

### Check HPAs
```powershell
kubectl get hpa
```

### View Logs
```powershell
kubectl logs -l app=frontend --tail=50
kubectl logs -l app=booking-service --tail=50
```

### Restart Service
```powershell
kubectl rollout restart deployment/frontend
```

---

## 🧪 Testing Checklist

1. ✅ Open frontend URL
2. ✅ Register a user
3. ✅ View events (should auto-load)
4. ✅ Book a ticket (check booking history panel)
5. ✅ Generate ticket (click "Demo Ticket" or upload file)
6. ✅ Check tickets list panel
7. ✅ Verify service status panel shows all healthy
8. ✅ Access Grafana and view dashboards

---

## 📝 Next Steps

- [ ] Record demo video
- [ ] Take screenshots of Grafana dashboards
- [ ] Document load testing results
- [ ] Integrate GCP analytics service

---

**All systems operational! 🎉**

