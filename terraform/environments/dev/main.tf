# Development Environment Configuration
terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.99.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
      configuration_aliases = [kubernetes.eks]  # Critical addition for provider alias
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10"
    }
  }

  backend "s3" {
    bucket       = "demo-usecases-bucket-new"
    key          = "usecase-09/workspace/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Owner       = "devops-team"
      CostCenter  = "engineering"
    }
  }
}

# Default kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.eks_cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Aliased kubernetes provider for EKS
provider "kubernetes" {
  alias                  = "eks"
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.eks.token
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.eks_cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.eks.token
      exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.eks_cluster_name,
      "--region",
      var.aws_region
    ]
  }
  }
}


# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}



# Local variables
locals {
  cluster_name = "${var.project_name}-${var.environment}-eksnew"
  common_tags = {
    Environment = var.environment
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region

  vpc_cidr             = var.vpc_cidr
  availability_zones   = data.aws_availability_zones.available.names
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs

  enable_nat_gateway   = true
  enable_vpn_gateway   = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = local.common_tags
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = var.environment

  repositories = [
    "appointment-service",
    "patient-service"
  ]

  tags = local.common_tags
}

# IAM Module
module "iam_core" {
  source = "../../modules/iam_core"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.cluster_name
  tags         = local.common_tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  project_name = var.project_name
  environment  = var.environment
  cluster_name = local.cluster_name

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  public_subnet_ids  = module.vpc.public_subnet_ids

  cluster_version  = var.cluster_version
  create_log_group = true
  # IAM roles
  cluster_service_role_arn = module.iam_core.eks_cluster_role_arn
  node_group_role_arn      = module.iam_core.eks_node_group_role_arn

  # Node group configuration
  node_groups = var.node_groups

  # Security
  enable_irsa                  = true
  enable_cluster_creator_admin = true

  tags = local.common_tags

  depends_on = [
    module.vpc,
    module.iam_core
  ]
}

data "aws_iam_openid_connect_provider" "eks" {
  url = module.eks.cluster_oidc_issuer_url
  depends_on = [ module.eks ]
}

module "iam_irsa" {
  source = "../../modules/iam_irsa"

  project_name                          = var.project_name
  environment                           = var.environment
  cluster_oidc_provider_arn             = data.aws_iam_openid_connect_provider.eks.arn
  cluster_oidc_issuer_url               = module.eks.cluster_oidc_issuer_url
  aws_iam_openid_connect_provider_extract_from_arn = replace(data.aws_iam_openid_connect_provider.eks.arn, "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/", "")
  depends_on = [
    module.eks
  ]
}


data "aws_eks_cluster" "eks" {
  name       = module.eks.eks_cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.eks_cluster_name
  depends_on = [module.eks]
}

module "k8s_config" {
  source = "../../modules/k8s-config"

  kube_host     = data.aws_eks_cluster.eks.endpoint
  kube_ca       = data.aws_eks_cluster.eks.certificate_authority[0].data
  kube_token    = data.aws_eks_cluster_auth.eks.token

  node_role_arn = module.iam_core.eks_node_group_role_arn
  user_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/root"
  additional_roles = []
  additional_users = []

  providers = {
    kubernetes.eks = kubernetes.eks
  }
  depends_on = [
    module.eks,
    module.iam_core
  ]
}

# data "aws_lb" "app_alb" {
#   name = "app-alb"
# }


# module "helm" {
#   source                             = "../../modules/helm"
#   cluster_id                         = module.eks.cluster_id
#   cluster_endpoint                   = module.eks.cluster_endpoint
#   alb_dns_name = data.aws_lb.app_alb.dns_name
#   cluster_certificate_authority_data = module.eks.cluster_certificate_authority_data
#   lbc_iam_depends_on                 = module.iam_irsa.aws_load_balancer_controller_role_name
#   lbc_iam_role_arn                   = module.iam_irsa.aws_load_balancer_controller_role_arn
#   vpc_id                             = module.vpc.vpc_id
#   aws_region                         = var.aws_region
#   providers = {
#     kubernetes = kubernetes.eks   # use aliased provider
#     helm=helm                     # if defined externally
#   }
#   depends_on = [
#     module.eks,
#     module.iam_irsa,
#     data.aws_lb.app_alb
#   ]
# }


