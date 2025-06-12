# Example Terraform variables for development environment
# Copy this file to terraform.tfvars and update the values

# Project Configuration
project_name = "devops-challenge"
environment  = "dev"
aws_region   = "us-east-1"

# Network Configuration
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.10.0/24", "10.0.20.0/24"]

# EKS Configuration
cluster_version = "1.32"

# Node Groups Configuration
node_groups = {
  general = {
    instance_types = ["t3.medium"]
    capacity_type  = "ON_DEMAND"
    disk_size      = 20
    ami_type       = "AL2_x86_64"
    scaling_config = {
      desired_size = 2
      max_size     = 2
      min_size     = 1
    }
    update_config = {
      max_unavailable_percentage = 25
    }
    labels = {
      Environment = "dev"
      NodeGroup   = "general"
    }
    taints = []
  }
}
