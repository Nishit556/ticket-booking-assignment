module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = var.cluster_name
  cluster_version = "1.30" 

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets # Nodes go in private subnets for security

  cluster_endpoint_public_access = true

  # Create a Node Group (The actual servers)
  eks_managed_node_groups = {
    main = {
      min_size     = 2
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"] # Cost-effective but capable enough for 5 services
      capacity_type  = "ON_DEMAND"
    }
  }

  # Allow current user to administer the cluster
  enable_irsa = true
}