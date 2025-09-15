.PHONY: help init plan apply destroy verify clean

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## Initialize Terraform
	terraform init

plan: ## Plan Terraform changes
	terraform plan

apply: ## Apply Terraform changes
	terraform apply -auto-approve

destroy: ## Destroy all resources
	terraform destroy -auto-approve

verify: ## Verify EKS cluster is ready
	@echo "Configuring kubectl..."
	aws eks update-kubeconfig --region $$(terraform output -raw aws_region || echo "us-west-2") --name $$(terraform output -raw cluster_name || echo "dev-cluster")
	@echo "Checking cluster nodes..."
	kubectl get nodes
	@echo "Checking system pods..."
	kubectl get pods -n kube-system
	@echo "Checking load balancer controller..."
	kubectl get deployment -n kube-system aws-load-balancer-controller

outputs: ## Show Terraform outputs
	terraform output

clean: ## Clean Terraform files
	rm -rf .terraform
	rm -f .terraform.lock.hcl
	rm -f terraform.tfstate*

quick-setup: init apply verify ## Complete setup in one command