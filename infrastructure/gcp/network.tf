# VPC Network Configuration for Dataproc Cluster
# Requirement: "All cloud infrastructure (networks, clusters, databases, storage, IAM policies, etc.)"

# Create VPC Network
resource "google_compute_network" "dataproc_network" {
  name                    = "dataproc-network"
  auto_create_subnetworks = false
  description             = "VPC network for Flink analytics cluster"
}

# Create Subnet
resource "google_compute_subnetwork" "dataproc_subnet" {
  name          = "dataproc-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.dataproc_network.id
  description   = "Subnet for Dataproc/Flink cluster"
  
  # Enable private Google access (allows VMs to reach Google APIs without external IPs)
  private_ip_google_access = true
}

# Firewall rule for internal communication within the subnet
resource "google_compute_firewall" "allow_internal" {
  name    = "dataproc-allow-internal"
  network = google_compute_network.dataproc_network.name
  description = "Allow internal communication between cluster nodes"

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/24"]
}

# Firewall rule to allow SSH access (for demo purposes)
resource "google_compute_firewall" "allow_ssh" {
  name    = "dataproc-allow-ssh"
  network = google_compute_network.dataproc_network.name
  description = "Allow SSH access for Flink job submission"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Allow SSH from anywhere for demo purposes
  # In production, restrict this to specific IP ranges or use IAP (35.235.240.0/20)
  source_ranges = ["0.0.0.0/0"]
}

# Firewall rule to allow external access for Flink Web UI (optional, for demo purposes)
resource "google_compute_firewall" "allow_flink_ui" {
  name    = "dataproc-allow-flink-ui"
  network = google_compute_network.dataproc_network.name
  description = "Allow access to Flink Web UI for demo purposes"

  allow {
    protocol = "tcp"
    ports    = ["8081", "8088"]  # Flink UI and YARN UI
  }

  # Allow from your IP (update this to your actual IP for security)
  # For demo purposes, allowing all (NOT recommended for production)
  source_ranges = ["0.0.0.0/0"]
  
  target_tags = ["dataproc-cluster"]
}

