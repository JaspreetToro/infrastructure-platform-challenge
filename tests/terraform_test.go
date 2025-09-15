package test

import (
	"testing"

	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestMicroservicePlatformModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/microservice-platform",
		Vars: map[string]interface{}{
			"service_name":       "test-service",
			"environment":        "dev",
			"vpc_id":            "vpc-12345678",
			"private_subnet_ids": []string{"subnet-12345678", "subnet-87654321"},
			"public_subnet_ids":  []string{"subnet-abcdefgh", "subnet-hgfedcba"},
			"oidc_provider_arn":  "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E",
			"db_password":        "test-password-123",
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndPlan(t, terraformOptions)

	// Validate that the plan contains expected resources
	planOutput := terraform.Plan(t, terraformOptions)
	
	// Check that namespace is created
	assert.Contains(t, planOutput, "kubernetes_namespace.microservice")
	
	// Check that service account is created
	assert.Contains(t, planOutput, "kubernetes_service_account.microservice")
	
	// Check that ALB is created
	assert.Contains(t, planOutput, "aws_lb.microservice")
	
	// Check that RDS is created when enabled
	assert.Contains(t, planOutput, "aws_db_instance.microservice")
}

func TestMicroservicePlatformWithAurora(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../terraform/modules/microservice-platform",
		Vars: map[string]interface{}{
			"service_name":       "test-aurora-service",
			"environment":        "prod",
			"vpc_id":            "vpc-12345678",
			"private_subnet_ids": []string{"subnet-12345678", "subnet-87654321"},
			"public_subnet_ids":  []string{"subnet-abcdefgh", "subnet-hgfedcba"},
			"oidc_provider_arn":  "arn:aws:iam::123456789012:oidc-provider/oidc.eks.us-west-2.amazonaws.com/id/EXAMPLED539D4633E53DE1B716D3041E",
			"db_password":        "test-password-123",
			"use_aurora":         true,
		},
		NoColor: true,
	})

	defer terraform.Destroy(t, terraformOptions)

	planOutput := terraform.Plan(t, terraformOptions)
	
	// Check that Aurora cluster is created instead of RDS
	assert.Contains(t, planOutput, "aws_rds_cluster.microservice")
	assert.Contains(t, planOutput, "aws_rds_cluster_instance.microservice")
}

func TestMicroservicePlatformValidation(t *testing.T) {
	t.Parallel()

	// Test invalid service name
	terraformOptions := &terraform.Options{
		TerraformDir: "../terraform/modules/microservice-platform",
		Vars: map[string]interface{}{
			"service_name": "Invalid_Service_Name",
			"environment":  "dev",
		},
		NoColor: true,
	}

	_, err := terraform.InitAndPlanE(t, terraformOptions)
	assert.Error(t, err, "Should fail with invalid service name")

	// Test invalid environment
	terraformOptions.Vars["service_name"] = "valid-service"
	terraformOptions.Vars["environment"] = "invalid-env"

	_, err = terraform.InitAndPlanE(t, terraformOptions)
	assert.Error(t, err, "Should fail with invalid environment")
}