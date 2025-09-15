variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-west-2"
}

variable "service_name" {
  description = "Name of the microservice"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "vpc_name" {
  description = "VPC name to lookup"
  type        = string
  default     = "main-vpc"
}

variable "oidc_provider_arn" {
  description = "EKS OIDC provider ARN"
  type        = string
}