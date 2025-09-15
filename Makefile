.PHONY: help init plan apply destroy test lint clean

# Default target
help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

# Variables
SERVICE_NAME ?= example-service
ENVIRONMENT ?= dev
TERRAFORM_DIR = terraform/environments/$(ENVIRONMENT)
HELM_CHART = helm/microservice-chart

# Terraform targets
init: ## Initialize Terraform
	cd $(TERRAFORM_DIR) && terraform init

plan: ## Plan Terraform changes
	cd $(TERRAFORM_DIR) && terraform plan -var="service_name=$(SERVICE_NAME)"

apply: ## Apply Terraform changes
	cd $(TERRAFORM_DIR) && terraform apply -var="service_name=$(SERVICE_NAME)" -auto-approve

destroy: ## Destroy Terraform resources
	cd $(TERRAFORM_DIR) && terraform destroy -var="service_name=$(SERVICE_NAME)" -auto-approve

# Helm targets
helm-lint: ## Lint Helm chart
	helm lint $(HELM_CHART)

helm-template: ## Generate Helm templates
	helm template $(SERVICE_NAME) $(HELM_CHART) \
		--values $(HELM_CHART)/values-$(ENVIRONMENT).yaml \
		--set image.tag=latest

helm-install: ## Install Helm chart
	helm upgrade --install $(SERVICE_NAME) $(HELM_CHART) \
		--namespace $(SERVICE_NAME) \
		--create-namespace \
		--values $(HELM_CHART)/values-$(ENVIRONMENT).yaml

helm-uninstall: ## Uninstall Helm chart
	helm uninstall $(SERVICE_NAME) --namespace $(SERVICE_NAME)

# Testing targets
test: ## Run all tests
	cd tests && go test -v -timeout 30m

test-terraform: ## Run Terraform tests only
	cd tests && go test -v -run TestMicroservicePlatform -timeout 30m

# Linting and validation
lint: ## Run all linting
	@echo "Running pre-commit hooks..."
	pre-commit run --all-files

validate-terraform: ## Validate Terraform code
	cd $(TERRAFORM_DIR) && terraform validate
	cd terraform/modules/microservice-platform && terraform validate

validate-helm: ## Validate Helm chart
	helm lint $(HELM_CHART)
	helm template test $(HELM_CHART) --values $(HELM_CHART)/values-dev.yaml > /dev/null

validate: validate-terraform validate-helm ## Validate all code

# Documentation
docs: ## Generate documentation
	terraform-docs markdown table --output-file README.md terraform/modules/microservice-platform
	helm-docs --chart-search-root=helm

# Utility targets
clean: ## Clean temporary files
	find . -name "*.tfstate*" -delete
	find . -name ".terraform" -type d -exec rm -rf {} +
	find . -name "*.log" -delete

setup: ## Setup development environment
	@echo "Installing pre-commit..."
	pip install pre-commit
	pre-commit install
	@echo "Installing required tools..."
	@echo "Please ensure you have: terraform, helm, kubectl, go"

# Cost estimation
cost-estimate: ## Estimate infrastructure costs
	@echo "Estimating costs for $(ENVIRONMENT) environment..."
	cd $(TERRAFORM_DIR) && terraform plan -var="service_name=$(SERVICE_NAME)" -out=plan.out
	@echo "Use tools like Infracost for detailed cost analysis"

# Security scanning
security-scan: ## Run security scans
	@echo "Running Terraform security scan..."
	cd terraform/modules/microservice-platform && tfsec .
	@echo "Running Helm security scan..."
	helm template $(SERVICE_NAME) $(HELM_CHART) | kubesec scan -

# Multi-environment deployment
deploy-all: ## Deploy to all environments
	$(MAKE) apply ENVIRONMENT=dev
	$(MAKE) apply ENVIRONMENT=staging
	$(MAKE) apply ENVIRONMENT=prod

# Monitoring setup
setup-monitoring: ## Setup monitoring stack
	kubectl apply -f https://raw.githubusercontent.com/prometheus-operator/prometheus-operator/main/bundle.yaml
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm install monitoring prometheus-community/kube-prometheus-stack

# Example usage
example: ## Deploy example service
	$(MAKE) apply SERVICE_NAME=example-service ENVIRONMENT=dev
	$(MAKE) helm-install SERVICE_NAME=example-service ENVIRONMENT=dev