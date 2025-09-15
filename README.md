# Infrastructure Platform Design Challenge

A reusable infrastructure module and deployment system for standardized microservices across multiple manufacturing sites, supporting both cloud (EKS) and edge (K3s) environments.

## 🏗️ Architecture Overview

This platform provides a standardized approach to deploying microservices with:

- **Terraform Module**: Provisions AWS infrastructure (EKS namespace, RDS/Aurora, ElastiCache, SQS, ALB)
- **Helm Chart**: Manages Kubernetes deployments with sophisticated templating
- **GitOps**: ArgoCD ApplicationSet for multi-cluster deployment
- **Testing**: Terratest validation for infrastructure code

## 📁 Project Structure

```
infrastructure-platform-challenge/
├── prerequisites/                       # EKS cluster & VPC setup
├── terraform/
│   ├── modules/microservice-platform/    # Reusable Terraform module
│   └── environments/                     # Environment-specific configs
├── helm/microservice-chart/              # Helm chart for K8s deployment
├── gitops/argocd/                       # ArgoCD configurations
├── tests/                               # Terratest validation
└── docs/                               # Documentation
```

## 🚀 Quick Start

### 0. Create S3 Bucket for Terraform State

```bash
# Create unique S3 bucket for Terraform state
BUCKET_NAME="terraform-state-$(whoami)-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME
echo "Created bucket: $BUCKET_NAME"

# Enable versioning for state file protection
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled
```

### 1. Setup Prerequisites (First Time Only)

```bash
cd prerequisites
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your preferences
terraform init
terraform apply
# Note the oidc_provider_arn output
```

### 2. Configure Terraform Backend

```bash
cd terraform/environments/dev
# Update the S3 backend configuration with your bucket name
sed -i '' "s/your-terraform-state-bucket/$BUCKET_NAME/g" main.tf
# Verify the update
grep "bucket =" main.tf
```

### 3. Deploy Infrastructure (Terraform)

```bash
cd terraform/environments/dev
terraform init
terraform plan -var="service_name=my-service" \
               -var="cluster_name=dev-cluster" \
               -var="oidc_provider_arn=<from_prerequisites_output>"
terraform apply
```

### 4. Deploy Application (Helm)

```bash
# Configure kubectl for EKS cluster
aws eks update-kubeconfig --region us-west-2 --name dev-cluster

# Get database endpoint from Terraform
cd terraform/environments/dev
DB_HOST=$(terraform output -raw database_endpoint)

# Navigate to Helm chart directory
cd ../../../helm/microservice-chart

# Create database password secret and deploy application
kubectl create namespace my-service --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic my-service-dev-db-password \
  --from-literal=password=demo-password-123 \
  -n my-service

# Deploy application with demo nginx image (using unprivileged nginx for security)
helm install my-service . \
  --namespace my-service \
  --create-namespace \
  --values values-dev.yaml \
  --set image.repository=nginxinc/nginx-unprivileged \
  --set image.tag=alpine \
  --set database.host="$DB_HOST" \
  --set database.passwordSecret.name=my-service-dev-db-password \
  --set serviceAccount.name=my-service-sa \
  --set serviceAccount.create=false \
  --set healthCheck.path="/" \
  --set readinessProbe.path="/" \
  --set service.port=80 \
  --set service.targetPort=8080
```

### 4.1. Verify Deployment

```bash
# Check all resources in the namespace
kubectl get all -n my-service

# Check pod details and environment variables
kubectl describe pod -n my-service -l app.kubernetes.io/name=microservice-chart

# View application logs
kubectl logs -n my-service deployment/my-service-microservice-chart

# Check service account and IRSA configuration
kubectl get serviceaccount -n my-service
kubectl describe serviceaccount my-service-sa -n my-service

# Verify ingress and load balancer (if ALB controller is installed)
kubectl get ingress -n my-service
kubectl describe ingress -n my-service

# Test application via service (works without ingress)
kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -- \
  curl -I my-service-microservice-chart.my-service.svc.cluster.local

# Alternative: Direct pod access for testing
kubectl exec -n my-service deployment/my-service-microservice-chart -- curl -I http://localhost:8080
```

### 4.2. Troubleshooting Common Issues

```bash
# If pods are not starting, check events
kubectl get events -n my-service --sort-by='.lastTimestamp'

# If deployment fails due to service account not found
kubectl get serviceaccount -n my-service
# Use the correct service account name from Terraform output

# If pods fail with "CreateContainerConfigError" due to runAsUser policy
# Use unprivileged images: nginxinc/nginx-unprivileged instead of nginx

# If health checks fail with 404 errors
# Update probe paths to match your application endpoints:
# --set healthCheck.path="/" --set readinessProbe.path="/"

# If deployment fails, check replicaset
kubectl describe replicaset -n my-service

# If pods are pending, check node resources
kubectl describe nodes
kubectl top nodes

# Test service connectivity from within cluster
kubectl run test-pod --image=curlimages/curl --rm -i --restart=Never -- \
  curl -I my-service-microservice-chart.my-service.svc.cluster.local
```

### 5. GitOps Deployment (ArgoCD)

```bash
# Install ArgoCD (prerequisite for GitOps)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Navigate to GitOps directory and deploy ApplicationSet
cd ../../gitops/argocd
kubectl apply -f applicationset.yaml

# Note: ApplicationSet is ready for multi-cluster deployment
# In production, you would register additional clusters with proper labels
echo "ApplicationSet deployed - ready for multi-cluster GitOps"

# Verify GitOps deployment
kubectl get applicationset -n argocd
kubectl get applications -n argocd
kubectl describe applicationset microservice-platform -n argocd
```

## 🔧 Key Features

### Terraform Module Features

- **Multi-Environment Support**: Dev, staging, prod configurations
- **Database Options**: RDS MySQL or Aurora with automatic failover
- **Caching**: ElastiCache Redis with encryption
- **Message Queue**: SQS with dead letter queue
- **Load Balancing**: ALB with path-based routing
- **Security**: IRSA, security groups, IAM policies
- **Validation**: Input validation and Terratest coverage

### Helm Chart Features

- **Environment-Aware**: Different resource limits per environment
- **Multi-Cluster Ready**: Supports both EKS and K3s
- **Comprehensive Templating**: Named templates and includes
- **Auto-Scaling**: HPA with CPU/memory metrics
- **Health Checks**: Liveness and readiness probes
- **Security**: Pod security contexts and network policies
- **Monitoring**: ServiceMonitor for Prometheus

### GitOps Features

- **Multi-Cluster Deployment**: ApplicationSet with cluster generators
- **Gradual Rollouts**: Canary and blue-green strategies
- **Automated Sync**: Self-healing with retry logic
- **Environment Promotion**: Different branches per environment

## 🏛️ Architecture Decisions (ADRs)

### ADR-001: Terraform Module Design

**Decision**: Create a single, comprehensive Terraform module rather than multiple smaller modules.

**Rationale**:
- Reduces complexity for teams consuming the platform
- Ensures consistent resource configuration
- Simplifies dependency management
- Enables atomic deployments

**Trade-offs**:
- Less flexibility for edge cases
- Larger blast radius for changes
- More complex module maintenance

### ADR-002: Helm Over CUE

**Decision**: Use Helm for Kubernetes configuration management.

**Rationale**:
- Mature ecosystem with extensive community support
- Built-in templating and packaging capabilities
- Native Kubernetes integration
- Team familiarity and existing tooling

**Trade-offs**:
- Less type safety compared to CUE
- Template complexity can grow unwieldy
- Limited validation capabilities

### ADR-003: ArgoCD ApplicationSet Pattern

**Decision**: Use ApplicationSet for multi-cluster deployment.

**Rationale**:
- Declarative multi-cluster management
- Automatic cluster discovery and sync
- Consistent deployment patterns across environments
- Built-in rollback capabilities

## 📋 Usage Guide

### Deploying a New Service

1. **Infrastructure Setup**:
   ```bash
   cd terraform/environments/dev
   terraform workspace new my-new-service
   terraform apply -var="service_name=my-new-service"
   ```

2. **Application Deployment**:
   ```bash
   helm install my-new-service ./helm/microservice-chart \
     --namespace my-new-service \
     --create-namespace \
     --values values-dev.yaml \
     --set image.repository=my-org/my-new-service \
     --set database.host=$(terraform output -raw database_endpoint)
   ```

3. **GitOps Configuration**:
   - Add cluster labels for environment targeting
   - Commit Helm values to Git repository
   - ArgoCD will automatically sync the application

### Environment-Specific Configurations

| Environment | Replicas | Resources | Database | Monitoring |
|-------------|----------|-----------|----------|------------|
| Dev         | 1        | 250m/256Mi| t3.micro | Disabled   |
| Staging     | 2        | 375m/384Mi| t3.small | Basic      |
| Production  | 3+       | 500m/512Mi| r6g.large| Full       |

### Multi-Cluster GitOps Setup

To enable the ApplicationSet to create Applications, register additional clusters:

```bash
# Example: Register a staging cluster
# 1. Get staging cluster credentials
aws eks update-kubeconfig --region us-west-2 --name staging-cluster

# 2. Add cluster to ArgoCD
argocd cluster add arn:aws:eks:us-west-2:123456789:cluster/staging-cluster \
  --name staging-cluster \
  --label environment=staging

# 3. Verify cluster registration
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# 4. Check Applications are created
kubectl get applications -n argocd
```

**Alternative: Manual cluster registration**
```bash
# Create cluster secret manually
kubectl create secret generic cluster-staging \
  --from-literal=name=staging-cluster \
  --from-literal=server=https://staging-cluster-endpoint \
  --from-file=config=/path/to/staging/kubeconfig \
  -n argocd

# Label the cluster
kubectl label secret cluster-staging \
  environment=staging \
  argocd.argoproj.io/secret-type=cluster \
  -n argocd
```

### Scaling Strategy

The platform handles scaling through multiple dimensions:

1. **Horizontal Pod Autoscaling**: CPU/memory-based scaling
2. **Cluster Autoscaling**: Node-level scaling for resource demands
3. **Database Scaling**: Aurora read replicas for read-heavy workloads
4. **Cache Scaling**: ElastiCache cluster mode for high throughput

## 🧪 Testing

### Infrastructure Testing

```bash
cd tests
go test -v -timeout 30m
```

### Helm Chart Testing

```bash
helm lint ./helm/microservice-chart
helm template test ./helm/microservice-chart --values values-dev.yaml
```

## 💰 Cost Estimation

### Development Environment (per service)
- EKS: $0.10/hour (shared cluster cost allocation)
- RDS t3.micro: $0.017/hour
- ElastiCache t3.micro: $0.017/hour
- ALB: $0.0225/hour
- **Total**: ~$50/month per service

### Production Environment (per service)
- EKS: $0.30/hour (shared cluster cost allocation)
- Aurora r6g.large (2 instances): $0.48/hour
- ElastiCache r6g.large: $0.201/hour
- ALB: $0.0225/hour
- **Total**: ~$550/month per service

## 🔮 Future Enhancements

1. **Multi-Region Support**:
   - Cross-region database replication
   - Global load balancing with Route 53
   - Regional failover automation

2. **Enhanced Security**:
   - Network policies for pod-to-pod communication
   - OPA Gatekeeper policies for compliance
   - Secrets management with External Secrets Operator

3. **Observability**:
   - Distributed tracing with Jaeger
   - Centralized logging with Fluentd/ELK
   - Custom Grafana dashboards

4. **Advanced Deployment Strategies**:
   - Feature flags integration
   - A/B testing capabilities
   - Automated rollback on SLI violations

5. **Cost Optimization**:
   - Spot instance integration
   - Resource right-sizing recommendations
   - Automated scaling based on business metrics

6. **Developer Experience**:
   - CLI tool for service bootstrapping
   - Local development environment (Tilt/Skaffold)
   - Self-service portal for deployments

## 🛠️ Pre-commit Hooks

```bash
# Install pre-commit
pip install pre-commit

# Setup hooks
pre-commit install

# Manual run
pre-commit run --all-files
```

## 📚 Additional Resources

- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
- [ArgoCD ApplicationSet Documentation](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes with appropriate tests
4. Submit a pull request with detailed description

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
