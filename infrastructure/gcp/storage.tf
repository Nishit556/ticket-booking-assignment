# GCS Bucket for storing Flink job artifacts
resource "google_storage_bucket" "flink_jobs" {
  name          = "${var.gcp_project_id}-flink-jobs"
  location      = var.gcp_region
  force_destroy = true

  uniform_bucket_level_access = true

  versioning {
    enabled = false
  }
}

# Service Account for Dataproc
resource "google_service_account" "dataproc_sa" {
  account_id   = "dataproc-flink-sa"
  display_name = "Dataproc Flink Service Account"
}

# Grant necessary permissions to the service account
resource "google_project_iam_member" "dataproc_worker" {
  project = var.gcp_project_id
  role    = "roles/dataproc.worker"
  member  = "serviceAccount:${google_service_account.dataproc_sa.email}"
  
  depends_on = [google_service_account.dataproc_sa]
}

resource "google_project_iam_member" "storage_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.dataproc_sa.email}"
  
  depends_on = [google_service_account.dataproc_sa]
}

resource "google_project_iam_member" "storage_object_admin" {
  project = var.gcp_project_id
  role    = "roles/storage.objectAdmin"
  member  = "serviceAccount:${google_service_account.dataproc_sa.email}"
  
  depends_on = [google_service_account.dataproc_sa]
}

# Add compute admin role for dataproc operations
resource "google_project_iam_member" "compute_admin" {
  project = var.gcp_project_id
  role    = "roles/compute.admin"
  member  = "serviceAccount:${google_service_account.dataproc_sa.email}"
  
  depends_on = [google_service_account.dataproc_sa]
}

