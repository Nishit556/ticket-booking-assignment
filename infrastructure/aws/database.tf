# 1. DynamoDB (NoSQL) for User Service
resource "aws_dynamodb_table" "users" {
  name           = "ticket-booking-users"
  billing_mode   = "PAY_PER_REQUEST" # Save money (Serverless model)
  hash_key       = "userId"

  attribute {
    name = "userId"
    type = "S"
  }
}

# 2. RDS Security Group (Allow access only from EKS)
resource "aws_security_group" "rds_sg" {
  name        = "ticket-booking-rds-sg"
  description = "Allow EKS to talk to RDS"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id] # Only EKS nodes can connect
  }
}

# 3. RDS Postgres (SQL) for Event Catalog
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  db_name              = "ticketdb"
  engine               = "postgres"
  engine_version       = "16.3"
  instance_class       = "db.t3.micro" # Cheapest option
  username             = "dbadmin"
  password = var.db_password  # Use variable from terraform.tfvars
  parameter_group_name = "default.postgres16"
  skip_final_snapshot  = true # Faster destruction for assignments
  publicly_accessible  = false
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  db_subnet_group_name   = module.vpc.database_subnet_group
}