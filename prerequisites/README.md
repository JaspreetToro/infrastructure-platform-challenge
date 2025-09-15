# Prerequisites Setup

This directory contains Terraform configurations to set up all the prerequisites needed for the infrastructure platform challenge.

## What Gets Created

### VPC Infrastructure
- VPC with DNS support
- 2 Public subnets (for ALB)
- 2 Private subnets (for EKS nodes)
- Internet Gateway
- NAT Gateways (2 for HA)
- Route tables and associations

### EKS Cluster
- EKS cluster with managed node group
- IAM roles and policies
- OIDC identity provider
- Security groups
- CloudWatch logging enabled

### Essential Addons
- AWS Load Balancer Controller
- EBS CSI Driver
- Proper IAM roles with IRSA

## Quick Setup

### 1. Configure Variables
```bash
cd prerequisites
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferences
```

### 2. Deploy Prerequisites
```bash
terraform init
terraform plan
terraform apply
```

### 3. Configure kubectl
```bash
aws eks update-kubeconfig --region us-west-2 --name dev-cluster
kubectl get nodes
```

### 4. Verify Setup
```bash
# Check nodes are ready
kubectl get nodes

# Check addons are running
kubectl get pods -n kube-system

# Test load balancer controller
kubectl get deployment -n kube-system aws-load-balancer-controller
```

## Outputs

After deployment, you'll get:
- VPC ID and subnet IDs
- EKS cluster details
- OIDC provider ARN (needed for microservice platform)
- kubectl configuration command

## Cost Estimate

**Monthly cost**: ~$150-200
- EKS cluster: $73/month
- NAT Gateways: $45/month (2 x $22.5)
- EC2 instances: $30-60/month (t3.medium nodes)
- Data transfer: $10-20/month

## Cleanup

```bash
terraform destroy
```

**Note**: Ensure no other resources are using the VPC before destroying.

## Next Steps

After prerequisites are deployed:

1. Note the `oidc_provider_arn` output
2. Use it in the main platform deployment:
   ```bash
   cd ../terraform/environments/dev
   terraform apply -var="oidc_provider_arn=<output_value>"
   ```

## Troubleshooting

### Common Issues

1. **Region mismatch**: Ensure AWS CLI and Terraform use same region
2. **Insufficient permissions**: Need EKS, VPC, IAM permissions
3. **Resource limits**: Check AWS service quotas for your region

### Useful Commands

```bash
# Check EKS cluster status
aws eks describe-cluster --name dev-cluster

# List available addons
aws eks describe-addon-versions --kubernetes-version 1.28

# Check OIDC provider
aws iam list-open-id-connect-providers
```