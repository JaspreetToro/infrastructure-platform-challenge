# Alternative: Use existing VPC instead of creating new one
# Uncomment this file and comment out the VPC module in main.tf

# data "aws_vpc" "existing" {
#   default = true  # Use default VPC
#   # OR specify by tag:
#   # tags = {
#   #   Name = "your-existing-vpc"
#   # }
# }

# data "aws_subnets" "existing_public" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.existing.id]
#   }
#   
#   tags = {
#     Type = "Public"
#   }
# }

# data "aws_subnets" "existing_private" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.existing.id]
#   }
#   
#   tags = {
#     Type = "Private"
#   }
# }

# # If no existing subnets with proper tags, use all subnets
# data "aws_subnets" "all_subnets" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.existing.id]
#   }
# }

# locals {
#   vpc_id = data.aws_vpc.existing.id
#   public_subnet_ids = length(data.aws_subnets.existing_public.ids) > 0 ? data.aws_subnets.existing_public.ids : slice(data.aws_subnets.all_subnets.ids, 0, 2)
#   private_subnet_ids = length(data.aws_subnets.existing_private.ids) > 0 ? data.aws_subnets.existing_private.ids : slice(data.aws_subnets.all_subnets.ids, 0, 2)
# }