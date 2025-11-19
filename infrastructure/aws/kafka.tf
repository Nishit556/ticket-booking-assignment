# Security Group for Kafka
resource "aws_security_group" "kafka_sg" {
  name        = "ticket-booking-kafka-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 9092
    to_port         = 9098
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id] # Allow EKS to talk to Kafka
  }
}

# MSK Cluster
resource "aws_msk_cluster" "kafka" {
  cluster_name           = "ticket-booking-kafka"
  kafka_version          = "3.5.1"
  number_of_broker_nodes = 2

  broker_node_group_info {
    instance_type = "kafka.t3.small" # Smallest available
    client_subnets = module.vpc.private_subnets
    security_groups = [aws_security_group.kafka_sg.id]
  }

  encryption_info {
    encryption_in_transit {
      client_broker = "PLAINTEXT" # Simpler for assignments (Avoids complex TLS setup)
    }
  }

  configuration_info {
    arn      = aws_msk_configuration.kafka_config.arn
    revision = aws_msk_configuration.kafka_config.latest_revision
  }
}

resource "aws_msk_configuration" "kafka_config" {
  kafka_versions = ["3.5.1"]
  name           = "ticket-booking-config"

  server_properties = <<PROPERTIES
auto.create.topics.enable=true
delete.topic.enable=true
PROPERTIES
}