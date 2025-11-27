# Loki Frontend Access Guide

## Overview

**Loki doesn't have a built-in web UI.** The standard way to access Loki logs is through **Grafana**, which serves as the frontend for Loki.

## Access Methods

### Method 1: Loki Logs Dashboard (Recommended for Demo)

1. **Import the Dashboard:**
   - Access Grafana: `http://<grafana-loadbalancer-url>`
   - Login: `admin` / `prom-operator`
   - Go to **Dashboards** → **Import**
   - Upload `loki-logs-dashboard.json`
   - Click **Import**

2. **View the Dashboard:**
   - Navigate to **Dashboards** → **Loki Logs Dashboard**
   - You'll see:
     - All application logs in real-time
     - Service-specific log panels (Booking, User, Event Catalog, Frontend)
     - Error logs filtered automatically
     - Log volume metrics
     - Error count statistics

### Method 2: Grafana Explore View (Interactive Log Querying)

1. **Access Grafana:**
   ```
   http://<grafana-loadbalancer-url>
   ```

2. **Open Explore:**
   - Click **Explore** (compass icon) in the left sidebar
   - Select **Loki** as the data source from the dropdown

3. **Query Logs using LogQL:**
   ```logql
   # All application logs
   {namespace="default"}
   
   # Specific service
   {namespace="default", app="booking-service"}
   
   # Error logs only
   {namespace="default"} |= "error" or "Error" or "ERROR"
   
   # Logs containing specific text
   {namespace="default"} |= "booking"
   
   # Logs from specific pod
   {namespace="default", pod="booking-service-xxxxx"}
   ```

### Method 3: Direct API Access (For Verification)

You can verify Loki is running by accessing its API directly:

```powershell
# Port-forward to Loki service
kubectl port-forward -n monitoring svc/loki-stack 3100:3100

# In another terminal, query Loki API
curl http://localhost:3100/ready
curl http://localhost:3100/loki/api/v1/labels
curl http://localhost:3100/loki/api/v1/label/namespace/values
```

## Dashboard Features

The **Loki Logs Dashboard** includes:

1. **All Application Logs Panel** - Shows all logs from the `default` namespace
2. **Service-Specific Panels:**
   - Booking Service Logs
   - User Service Logs
   - Event Catalog Logs
   - Frontend Logs
3. **Error Logs Panel** - Automatically filters and displays error/exception logs
4. **Log Volume Chart** - Shows logs per minute by service
5. **Error Count Stat** - Real-time error count from last 5 minutes
6. **Interactive Filters** - Namespace and service selectors

## Verification Checklist

To demonstrate Loki is working:

- [ ] Loki is deployed: `kubectl get pods -n monitoring | grep loki`
- [ ] Promtail is running: `kubectl get pods -n monitoring | grep promtail`
- [ ] Loki datasource configured in Grafana: Check **Configuration → Data Sources → Loki**
- [ ] Logs are being collected: View logs in Grafana Explore or Dashboard
- [ ] Dashboard shows real-time logs from services

## Common LogQL Queries for Demo

```logql
# Show all logs from booking service
{namespace="default", app="booking-service"}

# Show errors from all services
{namespace="default"} |= "error" or "Error" or "ERROR"

# Show logs with specific keyword
{namespace="default"} |= "Kafka" or "kafka"

# Count logs per service
sum(count_over_time({namespace="default"}[1m])) by (app)

# Show logs from last 5 minutes with rate
rate({namespace="default"}[1m])
```

## Troubleshooting

**No logs showing?**
1. Check Promtail is running: `kubectl get pods -n monitoring -l app=promtail`
2. Check Promtail logs: `kubectl logs -n monitoring -l app=promtail`
3. Verify Loki is accessible: `kubectl get svc -n monitoring | grep loki`
4. Check Loki datasource in Grafana: Configuration → Data Sources → Loki (should show "Data source is working")

**Dashboard shows "No data"?**
1. Ensure services are generating logs
2. Check time range (default is last 15 minutes)
3. Verify label selectors match your pod labels: `kubectl get pods -n default --show-labels`

## For Your Instructor

**To show Loki frontend:**
1. Open Grafana: `http://<grafana-loadbalancer-url>`
2. Navigate to **Dashboards → Loki Logs Dashboard**
3. Or use **Explore → Select Loki** for interactive log querying

**Key Points to Demonstrate:**
- ✅ Centralized logging from all microservices
- ✅ Real-time log streaming
- ✅ Service-specific log filtering
- ✅ Error log aggregation
- ✅ Log volume metrics
- ✅ Interactive LogQL querying

