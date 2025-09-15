# Developer Guide: How to Deploy Your Service

This guide walks you through deploying a new microservice using the infrastructure platform.

## Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl configured for your target cluster
- Helm 3.x installed
- Terraform 1.0+ installed

## Step 1: Service Planning

Before deploying, consider:

- **Service Name**: Must be lowercase, alphanumeric with hyphens only
- **Environment**: Choose dev, staging, or prod
- **Resource Requirements**: CPU, memory, and scaling needs
- **Dependencies**: Database, cache, message queue requirements

## Step 2: Infrastructure Deployment

### 2.1 Configure Terraform Variables

Create a `terraform.tfvars` file:

```hcl
service_name = "my-awesome-service"
cluster_name = "dev-cluster"
oidc_provider_arn = "arn:aws:iam::123456789:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/EXAMPLE"

# Optional: Customize resources
enable_rds = true
use_aurora = false
db_instance_class = "db.t3.micro"
enable_cache = true
cache_node_type = "cache.t3.micro"
enable_sqs = true
```

### 2.2 Deploy Infrastructure

```bash
cd terraform/environments/dev

# Initialize Terraform
terraform init

# Create workspace for your service
terraform workspace new my-awesome-service
terraform workspace select my-awesome-service

# Plan and apply
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"

# Save outputs for later use
terraform output > ../../../outputs.txt
```

### 2.3 Verify Infrastructure

```bash
# Check namespace creation
kubectl get namespace my-awesome-service

# Verify service account
kubectl get serviceaccount -n my-awesome-service

# Check AWS resources
aws rds describe-db-instances --db-instance-identifier my-awesome-service-dev
aws elbv2 describe-load-balancers --names my-awesome-service-dev-alb
```

## Step 3: Application Deployment

### 3.1 Prepare Your Application

Ensure your application:

- Exposes health check endpoints (`/health`, `/ready`)
- Reads configuration from environment variables
- Handles graceful shutdown (SIGTERM)
- Implements structured logging

Example environment variables your app should support:

```bash
# Database
DATABASE_URL=mysql://user:pass@host:3306/dbname
DB_HOST=localhost
DB_PORT=3306
DB_NAME=myapp
DB_USERNAME=admin
DB_PASSWORD=secret

# Cache
CACHE_URL=redis://localhost:6379
CACHE_HOST=localhost
CACHE_PORT=6379

# Message Queue
QUEUE_URL=https://sqs.us-west-2.amazonaws.com/123456789/my-queue

# Application
SERVICE_NAME=my-awesome-service
SERVICE_PORT=8080
ENVIRONMENT=dev
LOG_LEVEL=info
```

### 3.2 Create Custom Values File

Create `my-service-values.yaml`:

```yaml
image:
  repository: my-org/my-awesome-service
  tag: "v1.0.0"

service:
  targetPort: 8080

database:
  enabled: true
  host: "my-awesome-service-dev.cluster-xyz.us-west-2.rds.amazonaws.com"
  passwordSecret:
    name: "my-awesome-service-dev-db-password"
    key: "password"

cache:
  enabled: true
  host: "my-awesome-service-dev.abc123.cache.amazonaws.com"

messageQueue:
  enabled: true
  queueUrl: "https://sqs.us-west-2.amazonaws.com/123456789/my-awesome-service-dev-queue"

ingress:
  hosts:
    - host: "dev-api.company.com"
      paths:
        - path: /my-awesome-service
          pathType: Prefix

configMap:
  enabled: true
  data:
    LOG_LEVEL: "debug"
    FEATURE_FLAG_X: "true"

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

### 3.3 Deploy with Helm

```bash
# Install the service
helm install my-awesome-service ./helm/microservice-chart \
  --namespace my-awesome-service \
  --values helm/microservice-chart/values-dev.yaml \
  --values my-service-values.yaml

# Verify deployment
kubectl get pods -n my-awesome-service
kubectl get service -n my-awesome-service
kubectl get ingress -n my-awesome-service
```

### 3.4 Test Your Deployment

```bash
# Check pod logs
kubectl logs -n my-awesome-service deployment/my-awesome-service

# Port forward for local testing
kubectl port-forward -n my-awesome-service service/my-awesome-service 8080:80

# Test health endpoints
curl http://localhost:8080/health
curl http://localhost:8080/ready

# Test via ingress (if configured)
curl https://dev-api.company.com/my-awesome-service/health
```

## Step 4: GitOps Setup (Optional)

### 4.1 Prepare Git Repository

```bash
# Create application directory
mkdir -p gitops/applications/my-awesome-service

# Create application manifest
cat > gitops/applications/my-awesome-service/application.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-awesome-service
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/my-awesome-service
    targetRevision: HEAD
    path: helm
    helm:
      valueFiles:
      - values-dev.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-awesome-service
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
EOF
```

### 4.2 Apply ArgoCD Application

```bash
kubectl apply -f gitops/applications/my-awesome-service/application.yaml

# Check sync status
argocd app get my-awesome-service
argocd app sync my-awesome-service
```

## Step 5: Monitoring and Observability

### 5.1 Enable Monitoring

Update your values file:

```yaml
monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 30s
    path: /metrics

# Ensure your app exposes Prometheus metrics
configMap:
  data:
    METRICS_ENABLED: "true"
```

### 5.2 Access Dashboards

```bash
# Port forward to Grafana
kubectl port-forward -n monitoring service/grafana 3000:80

# Access at http://localhost:3000
# Default credentials: admin/admin
```

### 5.3 Set Up Alerts

Create `alerts.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-awesome-service-alerts
  namespace: my-awesome-service
spec:
  groups:
  - name: my-awesome-service
    rules:
    - alert: HighErrorRate
      expr: rate(http_requests_total{job="my-awesome-service",status=~"5.."}[5m]) > 0.1
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: High error rate detected
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{pod=~"my-awesome-service-.*"}[15m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: Pod is crash looping
```

## Step 6: Scaling and Performance

### 6.1 Configure Autoscaling

```yaml
autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80
```

### 6.2 Performance Testing

```bash
# Install hey for load testing
go install github.com/rakyll/hey@latest

# Run load test
hey -n 1000 -c 10 https://dev-api.company.com/my-awesome-service/health

# Monitor during test
kubectl top pods -n my-awesome-service
kubectl get hpa -n my-awesome-service
```

## Step 7: Troubleshooting

### Common Issues

1. **Pod Won't Start**:
   ```bash
   kubectl describe pod -n my-awesome-service <pod-name>
   kubectl logs -n my-awesome-service <pod-name>
   ```

2. **Database Connection Issues**:
   ```bash
   # Check secret exists
   kubectl get secret -n my-awesome-service
   
   # Verify database endpoint
   kubectl exec -n my-awesome-service <pod-name> -- nslookup <db-host>
   ```

3. **Ingress Not Working**:
   ```bash
   kubectl describe ingress -n my-awesome-service
   kubectl logs -n kube-system deployment/aws-load-balancer-controller
   ```

4. **High Memory Usage**:
   ```bash
   # Check resource limits
   kubectl describe pod -n my-awesome-service <pod-name>
   
   # Adjust in values file
   resources:
     limits:
       memory: 1Gi
   ```

### Useful Commands

```bash
# Get all resources for your service
kubectl get all -n my-awesome-service

# Check events
kubectl get events -n my-awesome-service --sort-by='.lastTimestamp'

# Debug networking
kubectl exec -n my-awesome-service <pod-name> -- netstat -tlnp
kubectl exec -n my-awesome-service <pod-name> -- curl -v localhost:8080/health

# Check resource usage
kubectl top pods -n my-awesome-service
kubectl describe node <node-name>
```

## Step 8: Cleanup

### Remove Application

```bash
# Uninstall Helm release
helm uninstall my-awesome-service -n my-awesome-service

# Delete namespace
kubectl delete namespace my-awesome-service
```

### Remove Infrastructure

```bash
cd terraform/environments/dev
terraform workspace select my-awesome-service
terraform destroy -var-file="terraform.tfvars"
terraform workspace select default
terraform workspace delete my-awesome-service
```

## Best Practices

1. **Resource Management**:
   - Always set resource requests and limits
   - Use appropriate instance types for your workload
   - Monitor and adjust based on actual usage

2. **Security**:
   - Use least privilege IAM policies
   - Enable network policies in production
   - Regularly rotate secrets

3. **Reliability**:
   - Implement proper health checks
   - Use pod disruption budgets
   - Test failure scenarios

4. **Observability**:
   - Implement structured logging
   - Expose meaningful metrics
   - Set up appropriate alerts

5. **Cost Optimization**:
   - Use spot instances for non-critical workloads
   - Implement proper autoscaling
   - Regular review of resource usage

## Getting Help

- **Platform Team**: platform@company.com
- **Documentation**: [Internal Wiki](https://wiki.company.com/platform)
- **Slack**: #platform-support
- **Office Hours**: Tuesdays 2-3 PM PST