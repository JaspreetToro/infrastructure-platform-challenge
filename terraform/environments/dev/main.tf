terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    # Configure your S3 backend here
    bucket = "terraform-state-jasaws-1757901002"
    key    = "microservice-platform/dev/terraform.tfstate"
    region = "us-west-2"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Environment   = "dev"
      Project       = "microservice-platform"
      ManagedBy     = "terraform"
      CostCenter    = "engineering"
    }
  }
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

# Data sources for existing EKS cluster
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

data "aws_vpc" "main" {
  tags = {
    Name = "${var.cluster_name}-vpc"
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  tags = {
    Type = "private"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  
  tags = {
    Type = "public"
  }
}

# Generate random password for database
resource "random_password" "db_password" {
  length  = 16
  special = true
}

# Store password in AWS Secrets Manager
resource "aws_secretsmanager_secret" "db_password" {
  name = "${var.service_name}-dev-db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db_password.result
}

# Deploy microservice platform
module "microservice_platform" {
  source = "../../modules/microservice-platform"

  service_name       = var.service_name
  environment        = "dev"
  vpc_id            = data.aws_vpc.main.id
  private_subnet_ids = data.aws_subnets.private.ids
  public_subnet_ids  = data.aws_subnets.public.ids
  oidc_provider_arn = var.oidc_provider_arn

  # Database configuration for dev
  enable_rds           = true
  use_aurora          = false
  db_instance_class   = "db.t3.micro"
  db_allocated_storage = 20
  db_password         = random_password.db_password.result

  # Cache configuration for dev
  enable_cache     = true
  cache_node_type  = "cache.t3.micro"
  cache_num_nodes  = 1

  # SQS configuration
  enable_sqs = true

  tags = {
    Environment = "dev"
    Service     = var.service_name
  }
}