output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane"
  value       = module.eks.cluster_security_group_id
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

# --- Add these to the bottom of outputs.tf ---

output "s3_bucket_name" {
  description = "Name of the S3 bucket for raw data"
  # Matches 'resource "aws_s3_bucket" "raw_data"' in storage.tf
  value       = aws_s3_bucket.raw_data.id
}

output "rds_endpoint" {
  description = "RDS instance hostname"
  # Matches 'resource "aws_db_instance" "default"' in database.tf
  value       = aws_db_instance.default.address
}

output "msk_brokers" {
  description = "Kafka Broker endpoints"
  # Matches 'resource "aws_msk_cluster" "kafka"' in kafka.tf
  value       = aws_msk_cluster.kafka.bootstrap_brokers
}