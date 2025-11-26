# Upload initialization script to GCS
# Note: The init script must exist at this path relative to the terraform files
resource "google_storage_bucket_object" "init_script" {
  name   = "init-scripts/install-dependencies.sh"
  bucket = google_storage_bucket.flink_jobs.name
  source = "${path.module}/init-scripts/install-dependencies.sh"
  content_type = "text/x-shellscript"
  
  depends_on = [google_storage_bucket.flink_jobs]
}

# Dataproc Cluster for Flink
resource "google_dataproc_cluster" "flink_cluster" {
  name   = var.dataproc_cluster_name
  region = var.gcp_region

  cluster_config {
    # Master node configuration
    master_config {
      num_instances = 1
      machine_type  = var.dataproc_machine_type
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 30
      }
    }

    # Worker nodes configuration
    worker_config {
      num_instances = var.dataproc_num_workers
      machine_type  = var.dataproc_machine_type
      disk_config {
        boot_disk_type    = "pd-standard"
        boot_disk_size_gb = 30
      }
    }

    # Software configuration - Install Flink
    software_config {
      image_version = "2.1-debian11"
      optional_components = ["Flink"]
    }

    # Service account and network configuration
    gce_cluster_config {
      service_account = google_service_account.dataproc_sa.email
      service_account_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
      # Attach to our VPC subnet (network is implied from subnet)
      subnetwork = google_compute_subnetwork.dataproc_subnet.self_link
      # Add tag for firewall rules
      tags = ["dataproc-cluster"]
    }

    # Initialization actions - Install Python dependencies
    initialization_action {
      script      = "gs://${google_storage_bucket.flink_jobs.name}/${google_storage_bucket_object.init_script.name}"
      timeout_sec = 600
    }
  }

  depends_on = [
    google_storage_bucket_object.init_script,
    google_project_iam_member.dataproc_worker,
    google_project_iam_member.storage_admin,
    google_project_iam_member.storage_object_admin,
    google_project_iam_member.compute_admin,
    # Ensure network and firewall rules are created first
    google_compute_network.dataproc_network,
    google_compute_subnetwork.dataproc_subnet,
    google_compute_firewall.allow_internal,
    google_compute_firewall.allow_ssh,
    google_compute_firewall.allow_flink_ui
  ]
}

