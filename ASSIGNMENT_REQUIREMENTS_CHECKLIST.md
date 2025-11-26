# Assignment Requirements Checklist

**Course:** CS/SS G527 - Cloud Computing  
**Assignment:** Multi-Cloud Microservices Architecture

---

## ✅ Complete Requirements Check

### a) Infrastructure as Code (IaC)
- ✅ **Terraform for AWS:** `infrastructure/aws/`
  - VPC, EKS, MSK, RDS, DynamoDB, S3, Lambda, ECR
- ✅ **Terraform for GCP:** `infrastructure/gcp/`
  - Dataproc, GCS, Service Account, VPC
- ✅ **All resources provisioned via Terraform**
- ✅ **No manual resource creation**

**Status:** ✅ COMPLETE

---

### b) Six Microservices with Distinct Functions

| # | Service | Location | Technology | Purpose | Status |
|---|---------|----------|------------|---------|--------|
| 1 | Frontend Service | AWS EKS | Node.js/Express | Web UI (Public URL) | ✅ |
| 2 | Booking Service | AWS EKS | Python/Flask | Ticket booking + Kafka producer | ✅ |
| 3 | Event Catalog | AWS EKS | Python/Flask | Event management + RDS | ✅ |
| 4 | User Service | AWS EKS | Node.js/Express | User profiles + DynamoDB | ✅ |
| 5 | Ticket Generator | AWS Lambda | Python | Serverless PDF generation | ✅ |
| 6 | Analytics Service | **GCP Dataproc** | Python/Flink | Stream processing | ✅ |

**Additional Requirements:**
- ✅ Analytics service on different cloud (GCP - Provider B)
- ✅ Serverless function (AWS Lambda)
- ✅ Message queue communication (AWS MSK Kafka)
- ✅ REST APIs for frontend-backend communication

**Status:** ✅ COMPLETE

---

### c) Managed Kubernetes with HPAs

- ✅ **Managed K8s:** AWS EKS (`ticket-booking-cluster`)
- ✅ **HPA #1:** Booking Service
  - Min: 2 pods, Max: 10 pods
  - Metric: CPU > 50%
  - File: `k8s-gitops/apps/booking-service.yaml`
- ✅ **HPA #2:** User Service
  - Min: 2 pods, Max: 10 pods
  - Metric: CPU > 50%
  - File: `k8s-gitops/apps/user-service.yaml`

**Verification:**
```powershell
kubectl get hpa
# Should show: booking-hpa, user-hpa
```

**Status:** ✅ COMPLETE

---

### d) GitOps Controller

- ✅ **Controller:** ArgoCD
- ✅ **Git Repository:** https://github.com/Nishit556/ticket-booking-assignment.git
- ✅ **ArgoCD Applications:**
  - `argocd-app.yaml` - Main application
  - `monitor-app.yaml` - Monitoring stack
  - `k8s-gitops/system/logging.yaml` - Logging stack
- ✅ **Direct kubectl forbidden:** All deployments via GitOps
- ✅ **Automated sync:** prune: true, selfHeal: true

**Verification:**
```powershell
kubectl get applications -n argocd
```

**Status:** ✅ COMPLETE

---

### e) Real-Time Stream Processing (Flink)

- ✅ **Platform:** GCP Dataproc (Provider B)
- ✅ **Technology:** Apache Flink
- ✅ **Source:** AWS MSK Kafka topic `ticket-bookings`
- ✅ **Processing:** Stateful time-windowed aggregation (1-minute tumbling window)
- ✅ **Aggregation:** SUM(ticket_count) per event_id per window
- ✅ **Sink:** AWS MSK Kafka topic `analytics-results`
- ✅ **Managed Kafka:** AWS MSK

**Code Files:**
- `services/analytics-service/analytics_job.py` - Flink job
- `infrastructure/gcp/dataproc.tf` - Dataproc cluster
- `services/analytics-service/submit-dataproc-job.py` - Job submission script

**Verification:**
```powershell
gcloud dataproc jobs list --project=$GCP_PROJECT_ID --region=$GCP_REGION
```

**Status:** ✅ COMPLETE

---

### f) Distinct Cloud Storage Products

| Storage Type | Service | Purpose | Files |
|--------------|---------|---------|-------|
| **Object Store** | AWS S3 | Raw data uploads (triggers Lambda) | `infrastructure/aws/storage.tf` |
| **SQL Database** | AWS RDS (PostgreSQL) | Event catalog (structured data) | `infrastructure/aws/database.tf` |
| **NoSQL Database** | AWS DynamoDB | User profiles (high-throughput) | `infrastructure/aws/database.tf` |
| **Object Store (GCP)** | Google Cloud Storage | Flink jobs and scripts | `infrastructure/gcp/storage.tf` |

**Status:** ✅ COMPLETE (4 distinct storage products)

---

### g) Comprehensive Observability Stack

#### ✅ Metrics: Prometheus + Grafana

- ✅ **Prometheus:** Deployed via kube-prometheus-stack
- ✅ **Grafana:** LoadBalancer with dashboards
- ✅ **ServiceMonitors:** All 4 microservices
- ✅ **Metrics Collected:**
  - RPS (Requests Per Second)
  - Error rates
  - Latency (p95, p99)
  - CPU/Memory usage
  - Pod counts
  - HPA metrics

**Files:**
- `k8s-gitops/system/monitoring.yaml` - Monitoring stack
- `k8s-gitops/system/servicemonitors.yaml` - Service discovery
- `k8s-gitops/system/prometheus-instance.yaml` - Prometheus config

**Access:**
```powershell
kubectl get svc -n monitoring monitoring-stack-grafana
# Username: admin
# Password: prom-operator
```

#### ✅ Logging: Centralized Logging (Loki)

- ✅ **Solution:** Grafana Loki + Promtail
- ✅ **Log Aggregation:** All microservices logs
- ✅ **Integration:** Loki as Grafana data source
- ✅ **Log Retention:** 10Gi persistent storage

**Files:**
- `k8s-gitops/system/logging.yaml` - Loki stack deployment

**Features:**
- Automatic log collection from all pods
- Filterable by service, namespace, pod
- Integrated with Grafana for unified observability
- Excludes system namespaces (kube-system, kube-public)

**Verification:**
```powershell
kubectl get pods -n monitoring | Select-String "loki"
# Should show: loki-0, promtail-xxxxx
```

**Status:** ✅ COMPLETE

---

### h) Load Testing

- ✅ **Tool:** k6 (Modern load testing tool)
- ✅ **Test Scenarios:**
  - User registration
  - Event browsing
  - Ticket booking
  - Health checks
- ✅ **Load Pattern:**
  - Ramp up: 10 → 150 virtual users
  - Duration: 15 minutes
  - Validates HPA scaling
- ✅ **Thresholds:**
  - p95 latency < 500ms
  - Error rate < 10%

**Files:**
- `load-testing/k6-load-test.js` - Test script
- `load-testing/run-load-test.ps1` - Execution script
- `load-testing/README.md` - Documentation

**Run Test:**
```powershell
cd load-testing
.\run-load-test.ps1
```

**Expected Outcome:**
- HPA scales booking-service from 2 → 8-10 pods
- System maintains <500ms p95 latency
- <10% error rate under peak load

**Status:** ✅ COMPLETE

---

## 📊 Summary

| Requirement | Status | Evidence |
|-------------|--------|----------|
| (a) IaC with Terraform | ✅ | `infrastructure/aws/`, `infrastructure/gcp/` |
| (b) 6 Microservices + Serverless | ✅ | 4 EKS services + Lambda + Dataproc |
| (c) Managed K8s + 2 HPAs | ✅ | EKS + booking-hpa + user-hpa |
| (d) GitOps (ArgoCD) | ✅ | `argocd-app.yaml`, automated sync |
| (e) Flink Stream Processing | ✅ | GCP Dataproc + Kafka + windowed aggregation |
| (f) 4 Storage Products | ✅ | S3 + RDS + DynamoDB + GCS |
| (g.1) Prometheus + Grafana | ✅ | `k8s-gitops/system/monitoring.yaml` |
| (g.2) Centralized Logging | ✅ | `k8s-gitops/system/logging.yaml` (Loki) |
| (h) Load Testing + HPA Demo | ✅ | `load-testing/` (k6 scripts) |

---

## 🎯 ALL REQUIREMENTS: ✅ SATISFIED

---

## 📋 Deliverables Checklist

### 1. Design Document
- ✅ `docs/design_document.md`
  - System overview
  - Cloud architecture
  - Microservices responsibilities
  - Interconnection mechanisms
  - Design rationale

### 2. Code Repository
- ✅ GitHub: https://github.com/Nishit556/ticket-booking-assignment.git
- ✅ All microservices code: `services/`
- ✅ All IaC scripts: `infrastructure/`
- ✅ All K8s manifests: `k8s-gitops/`
- ✅ GitOps configuration: `argocd-app.yaml`, etc.

### 3. Individual Videos
- ⏳ Each student records code walkthrough
- ⏳ Show student ID in terminal/code
- ⏳ Explain their code sections
- ⏳ Save link in `<idno>_video.txt`

### 4. Demo Video
- ⏳ End-to-end application walkthrough
- ⏳ Show all services working
- ⏳ Demonstrate HPA scaling (load test)
- ⏳ Show monitoring dashboards
- ⏳ Save link in `demo_video.txt`

---

## 🚀 Quick Verification Commands

```powershell
# Check all K8s resources
kubectl get pods
kubectl get svc
kubectl get hpa

# Check monitoring
kubectl get pods -n monitoring
kubectl get svc -n monitoring

# Check ArgoCD apps
kubectl get applications -n argocd

# Run load test
cd load-testing
.\run-load-test.ps1

# Check Dataproc job
gcloud dataproc jobs list --project=$GCP_PROJECT_ID --region=us-central1
```

---

**Last Updated:** 2025-11-23  
**Assignment Status:** ✅ ALL TECHNICAL REQUIREMENTS COMPLETE

