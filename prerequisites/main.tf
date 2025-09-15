terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = "infrastructure-platform-challenge"
      Environment = "prerequisites"
      ManagedBy   = "terraform"
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# VPC Module
module "vpc" {
  source = "./vpc"
  
  aws_region   = var.aws_region
  cluster_name = var.cluster_name
  vpc_cidr     = var.vpc_cidr
}

# EKS Module
module "eks" {
  source = "./eks"
  
  aws_region         = var.aws_region
  cluster_name       = var.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.vpc.vpc_id
  public_subnet_ids  = module.vpc.public_subnet_ids
  private_subnet_ids = module.vpc.private_subnet_ids
}

# EKS Addons Module
module "addons" {
  source = "./addons"
  
  aws_region             = var.aws_region
  cluster_name           = var.cluster_name
  oidc_provider_arn      = module.eks.oidc_provider_arn
  cluster_endpoint       = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = data.aws_eks_cluster.cluster.certificate_authority[0].data
  cluster_token          = data.aws_eks_cluster_auth.cluster.token
}