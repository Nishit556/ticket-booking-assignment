variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "aws_msk_brokers" {
  description = "AWS MSK Kafka broker endpoints (comma-separated)"
  type        = string
}

variable "dataproc_cluster_name" {
  description = "Name for the Dataproc cluster"
  type        = string
  default     = "flink-analytics-cluster"
}

variable "dataproc_machine_type" {
  description = "Machine type for Dataproc nodes"
  type        = string
  default     = "n1-standard-2"
}

variable "dataproc_num_workers" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

