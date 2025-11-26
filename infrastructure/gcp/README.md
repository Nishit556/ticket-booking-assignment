# GCP Infrastructure for Analytics Service

This directory contains Terraform configuration for deploying the Flink analytics service on GCP Dataproc.

## Prerequisites

1. **GCP Account Setup:**
   ```bash
   # Install gcloud CLI if not already installed
   # https://cloud.google.com/sdk/docs/install

   # Authenticate
   gcloud auth login
   gcloud auth application-default login

   # Set your project
   gcloud config set project YOUR_PROJECT_ID
   ```

2. **Enable Required APIs:**
   ```bash
   gcloud services enable dataproc.googleapis.com
   gcloud services enable storage-component.googleapis.com
   gcloud services enable compute.googleapis.com
   ```

3. **Get AWS MSK Broker Endpoints:**
   ```bash
   # From AWS
   aws kafka get-bootstrap-brokers --cluster-arn <your-msk-cluster-arn>
   ```

## Setup

1. **Copy the example variables file:**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your values:**
   - `gcp_project_id`: Your GCP project ID
   - `aws_msk_brokers`: Comma-separated list of MSK broker endpoints from AWS

3. **Initialize Terraform:**
   ```bash
   terraform init
   ```

4. **Review the plan:**
   ```bash
   terraform plan
   ```

5. **Apply the configuration:**
   ```bash
   terraform apply
   ```

## Important Notes

### MSK Access from GCP

Since MSK is in AWS and Dataproc is in GCP, you need to ensure MSK is accessible:

1. **Option 1: Public Endpoint (Not Recommended for Production)**
   - MSK security group must allow traffic from GCP Dataproc IPs
   - This is complex as Dataproc IPs are dynamic

2. **Option 2: VPN Connection (Recommended)**
   - Set up a VPN between AWS VPC and GCP VPC
   - Configure routing appropriately

3. **Option 3: For Assignment/Demo**
   - Temporarily allow MSK security group to accept traffic from `0.0.0.0/0` on port 9092
   - **WARNING: Only for testing/demo purposes!**

### Updating MSK Security Group

To allow Dataproc to access MSK, update the AWS security group:

```bash
# Get the MSK security group ID
aws ec2 describe-security-groups --filters "Name=group-name,Values=ticket-booking-kafka-sg"

# Add ingress rule (for demo only - use specific IPs in production)
aws ec2 authorize-security-group-ingress \
  --group-id <sg-id> \
  --protocol tcp \
  --port 9092 \
  --cidr 0.0.0.0/0
```

## Outputs

After applying, you'll get:
- `dataproc_cluster_name`: Name of the cluster
- `gcs_bucket_name`: Bucket for storing job files
- `service_account_email`: Service account email

## Next Steps

1. Upload the initialization script to GCS
2. Upload the Flink job to GCS
3. Submit the job to Dataproc

See `../../services/analytics-service/README.md` for job submission instructions.

## Cleanup

To destroy all resources:
```bash
terraform destroy
```

