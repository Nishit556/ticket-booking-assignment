# Grafana Dashboards

This directory contains custom Grafana dashboard JSON files for monitoring the ticket booking application.

## Dashboards

### 1. Service Metrics Dashboard (`service-metrics-dashboard.json`)
- **RPS (Requests Per Second)** by service
- **Error Rate** percentage by service
- **Latency** metrics (p50, p95, p99) by service
- **Total Requests** and **Current Error Rate** stat panels

### 2. Kubernetes Cluster Health Dashboard (`kubernetes-cluster-health-dashboard.json`)
- **Pod Count** by service and status
- **CPU Usage** by service/pod
- **Memory Usage** by service/pod
- **HPA Status** (current vs desired replicas)
- **Node Metrics** (CPU, Memory)
- **Service Status Summary** table

### 3. Loki Logs Dashboard (`loki-logs-dashboard.json`) - **Loki Frontend**
- **All Application Logs** - Centralized log viewer
- **Service-Specific Logs** - Booking, User, Event Catalog, Frontend
- **Error Logs** - Filtered error/exception logs from all services
- **Log Volume Metrics** - Logs per minute by service
- **Error Count** - Real-time error count stat panel
- **Interactive Filters** - Namespace and service selectors

### 4. Prometheus Monitoring Dashboard (`prometheus-monitoring-dashboard.json`)
- **Scrape Interval Duration** - Time taken for each scrape
- **Scrape Errors** - Targets with scrape failures
- **Storage Usage** - Prometheus TSDB storage metrics
- **Discovered Targets** - Number of targets by job
- **Ingestion Rate** - Samples appended and compactions
- **Prometheus Pod Logs** - Logs from Prometheus pods (via Loki)
- **Prometheus Pod Resources** - CPU and Memory usage
- **Recording Rules** - Active Prometheus recording rules

## How to Import

### Method 1: Via Grafana UI
1. Access Grafana: `http://<grafana-loadbalancer-url>`
2. Login with credentials: `admin` / `prom-operator`
3. Go to **Dashboards** → **Import**
4. Click **Upload JSON file**
5. Select one of the dashboard JSON files
6. Click **Import**

### Method 2: Via kubectl (ConfigMap)
```powershell
# Create ConfigMap for Service Metrics Dashboard
kubectl create configmap grafana-service-metrics-dashboard \
  --from-file=service-metrics-dashboard.json \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -

# Create ConfigMap for Kubernetes Cluster Health Dashboard
kubectl create configmap grafana-cluster-health-dashboard \
  --from-file=kubernetes-cluster-health-dashboard.json \
  -n monitoring \
  --dry-run=client -o yaml | kubectl apply -f -
```

Then configure Grafana to load dashboards from ConfigMaps (requires Grafana configuration update).

### Method 3: Via ArgoCD (Recommended)
Add these dashboards to your GitOps repository and configure Grafana to auto-import them.

## Metrics Used

### Flask Services (booking-service, event-catalog)
- `flask_http_request_total` - Total HTTP requests
- `flask_http_request_duration_seconds` - Request duration histogram
- `flask_http_request_exceptions_total` - Exception counter

### Node.js Services (user-service, frontend)
- `http_request_duration_seconds` - Request duration histogram
- `http_request_duration_seconds_count` - Request count
- Default process metrics from `prom-client`

### Kubernetes Metrics (from kube-prometheus-stack)
- `kube_pod_info` - Pod information
- `kube_pod_status_phase` - Pod status
- `container_cpu_usage_seconds_total` - CPU usage
- `container_memory_working_set_bytes` - Memory usage
- `kube_horizontalpodautoscaler_status_*` - HPA metrics

## Notes

- All queries filter by `namespace="default"` where services are deployed (Prometheus dashboard: `namespace="monitoring"`)
- Metrics are aggregated by `service` or `app` labels
- Time range defaults to last 1 hour (Loki dashboard: 15 minutes)
- Refresh interval: 30 seconds (Loki dashboard: 10 seconds for real-time logs)
- Dashboards use Prometheus data source with UID: `prometheus`
- Loki dashboard uses Loki data source with UID: `loki`
- Prometheus dashboard shows self-monitoring metrics (metrics about Prometheus itself)

## Loki Frontend Access

**Loki doesn't have a built-in web UI.** The standard way to access Loki logs is through **Grafana's Explore view** or the **Loki Logs Dashboard** provided here.

### Method 1: Loki Logs Dashboard (Recommended)
1. Import `loki-logs-dashboard.json` into Grafana
2. Access the dashboard: **Dashboards → Loki Logs Dashboard**
3. View logs from all services in one place

### Method 2: Grafana Explore View
1. Access Grafana: `http://<grafana-loadbalancer-url>`
2. Click **Explore** (compass icon) in the left sidebar
3. Select **Loki** as the data source
4. Enter LogQL queries:
   - `{namespace="default"}` - All logs
   - `{namespace="default", app="booking-service"}` - Booking service logs
   - `{namespace="default"} |= "error"` - Error logs only

## Troubleshooting

If dashboards show "No data":
1. Verify Prometheus is scraping metrics: `kubectl get servicemonitors -n default`
2. Check if services expose `/metrics`: `curl http://<service-url>/metrics`
3. Verify Prometheus can query metrics: Access Prometheus UI and test queries
4. Check dashboard queries match actual metric names in your cluster

