# GCP Project and Region
output "gcp_project_id" {
  description = "GCP Project ID"
  value       = var.gcp_project_id
}

output "gcp_region" {
  description = "GCP Region"
  value       = var.gcp_region
}

# Dataproc Cluster
output "dataproc_cluster_name" {
  description = "Name of the Dataproc cluster"
  value       = google_dataproc_cluster.flink_cluster.name
}

output "dataproc_cluster_region" {
  description = "Region of the Dataproc cluster"
  value       = google_dataproc_cluster.flink_cluster.region
}

# GCS Bucket (with both naming conventions for compatibility)
output "gcp_bucket_name" {
  description = "Name of the GCS bucket for Flink jobs"
  value       = google_storage_bucket.flink_jobs.name
}

output "gcs_bucket_name" {
  description = "Name of the GCS bucket for Flink jobs (alias)"
  value       = google_storage_bucket.flink_jobs.name
}

# Service Account
output "service_account_email" {
  description = "Email of the Dataproc service account"
  value       = google_service_account.dataproc_sa.email
}


