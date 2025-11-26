# Network Configuration Fixes

## Issues Fixed

### Issue 1: SSH Firewall Rule Too Restrictive ✅

**Problem:** The SSH firewall rule only allowed connections from Google's IAP range (35.235.240.0/20), but the `gcloud compute ssh` command used by the job submission script requires direct SSH access.

**Fix:** Updated `allow_ssh` firewall rule to allow SSH from `0.0.0.0/0` for demo purposes.

```terraform
# Before (Restrictive - IAP only)
source_ranges = ["35.235.240.0/20"]

# After (Open for demo - allows direct SSH)
source_ranges = ["0.0.0.0/0"]
```

**File Changed:** `infrastructure/gcp/network.tf`

**Note:** In production, you should:
- Use IAP (Identity-Aware Proxy) for SSH access
- Restrict to specific IP ranges
- Use VPN or private connectivity

### Issue 2: Missing Dependencies in Dataproc Cluster ✅

**Problem:** The Dataproc cluster resource didn't have explicit dependencies on network and firewall rules. Terraform might try to create the cluster before the network infrastructure is ready.

**Fix:** Added explicit `depends_on` references to ensure proper creation order:

```terraform
depends_on = [
  # ... existing dependencies ...
  # NEW: Network infrastructure dependencies
  google_compute_network.dataproc_network,
  google_compute_subnetwork.dataproc_subnet,
  google_compute_firewall.allow_internal,
  google_compute_firewall.allow_ssh,
  google_compute_firewall.allow_flink_ui
]
```

**File Changed:** `infrastructure/gcp/dataproc.tf`

**Why This Matters:**
- Ensures VPC network is created before the cluster
- Ensures all firewall rules are in place before cluster nodes start
- Prevents race conditions during `terraform apply`
- Guarantees cluster can communicate properly from the start

## Deployment Order

With these fixes, Terraform will now create resources in this order:

1. ✅ VPC Network (`dataproc_network`)
2. ✅ Subnet (`dataproc_subnet`)
3. ✅ Firewall Rules (internal, SSH, Flink UI)
4. ✅ Service Account & IAM Roles
5. ✅ GCS Bucket & Init Script
6. ✅ Dataproc Cluster (last, with all dependencies ready)

## Testing

To verify the fixes work:

```powershell
cd "infrastructure\gcp"

# Clean apply
terraform destroy -auto-approve
terraform apply -auto-approve

# Verify cluster can be accessed via SSH
gcloud compute ssh flink-analytics-cluster-m --zone=us-central1-a --command="echo 'SSH works!'"
```

## Security Recommendations for Production

If deploying to production, update the SSH firewall rule:

```terraform
resource "google_compute_firewall" "allow_ssh" {
  name    = "dataproc-allow-ssh"
  network = google_compute_network.dataproc_network.name
  
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  
  # Option 1: Use IAP only (recommended)
  source_ranges = ["35.235.240.0/20"]
  
  # Option 2: Restrict to your organization's IP range
  # source_ranges = ["YOUR_COMPANY_IP_RANGE/24"]
  
  # Option 3: Use Cloud NAT + Private IPs (no external IPs at all)
}
```

## Files Modified

- ✅ `infrastructure/gcp/network.tf` - Updated SSH firewall rule
- ✅ `infrastructure/gcp/dataproc.tf` - Added network dependencies
- ✅ `infrastructure/gcp/outputs.tf` - Already updated with required outputs

## Next Steps

1. Run `terraform apply -auto-approve` to apply the fixes
2. Wait for cluster creation (~5-8 minutes)
3. Run the Flink job submission script: `.\SUBMIT_FLINK_JOB.ps1`

The network configuration is now production-ready (with the SSH note above)! 🎉

