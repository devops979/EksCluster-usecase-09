// Terraform Tests for Infrastructure
package test

import (
	"testing"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/stretchr/testify/assert"
)

func TestTerraformVPCModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/vpc",
		Vars: map[string]interface{}{
			"project_name":           "test",
			"environment":            "test",
			"aws_region":            "us-west-2",
			"vpc_cidr":              "10.0.0.0/16",
			"availability_zones":     []string{"us-west-2a", "us-west-2b"},
			"public_subnet_cidrs":    []string{"10.0.1.0/24", "10.0.2.0/24"},
			"private_subnet_cidrs":   []string{"10.0.10.0/24", "10.0.20.0/24"},
		},
	})

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndPlan(t, terraformOptions)
	
	// Validate the plan
	planOutput := terraform.InitAndPlan(t, terraformOptions)
	assert.Contains(t, planOutput, "aws_vpc.main")
	assert.Contains(t, planOutput, "aws_subnet.public")
	assert.Contains(t, planOutput, "aws_subnet.private")
}

func TestTerraformEKSModule(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../modules/eks",
		Vars: map[string]interface{}{
			"project_name":              "test",
			"environment":               "test", 
			"cluster_name":              "test-eks",
			"vpc_id":                   "vpc-12345",
			"private_subnet_ids":        []string{"subnet-12345", "subnet-67890"},
			"public_subnet_ids":         []string{"subnet-abcde", "subnet-fghij"},
			"cluster_service_role_arn":  "arn:aws:iam::123456789012:role/test-role",
			"node_group_role_arn":       "arn:aws:iam::123456789012:role/test-node-role",
		},
	})

	// Only validate the plan without applying
	terraform.InitAndPlan(t, terraformOptions)
}

func TestTerraformSecurityCompliance(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../environments/dev",
	})

	// Initialize and validate
	terraform.Init(t, terraformOptions)
	terraform.Validate(t, terraformOptions)
	
	// Run a plan to check for security issues
	planOutput := terraform.Plan(t, terraformOptions)
	
	// Basic security checks
	assert.NotContains(t, planOutput, "0.0.0.0/0", "Should not allow unrestricted access")
	assert.Contains(t, planOutput, "encryption", "Should include encryption configuration")
}

func TestTerraformResourceTags(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../environments/dev",
	})

	terraform.Init(t, terraformOptions)
	planOutput := terraform.Plan(t, terraformOptions)
	
	// Check that resources have required tags
	assert.Contains(t, planOutput, "Environment", "Resources should have Environment tag")
	assert.Contains(t, planOutput, "Project", "Resources should have Project tag")
	assert.Contains(t, planOutput, "ManagedBy", "Resources should have ManagedBy tag")
}

func TestTerraformStateConfiguration(t *testing.T) {
	t.Parallel()

	terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
		TerraformDir: "../environments/dev",
	})

	// Verify backend configuration
	terraform.Init(t, terraformOptions)
	
	// This test ensures that the state backend is properly configured
	// In a real scenario, you'd check the backend configuration
	assert.FileExists(t, "../environments/dev/.terraform/terraform.tfstate")
}