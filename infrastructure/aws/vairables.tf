variable "region" {
  description = "AWS Region to deploy into"
  type        = string
  default     = "us-east-1" # Change if you prefer another region
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "ticket-booking-cluster"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}
variable "db_password" {
  description = "RDS database password (set in terraform.tfvars)"
  type        = string
  sensitive   = true
}

