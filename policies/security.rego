# OPA Security Policies for Terraform

package terraform

import rego.v1

# Deny resources without proper tags
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type in ["aws_instance", "aws_eks_cluster", "aws_s3_bucket"]
    not resource.values.tags.Environment
    msg := sprintf("Resource %s missing required 'Environment' tag", [resource.address])
}

deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type in ["aws_instance", "aws_eks_cluster", "aws_s3_bucket"]
    not resource.values.tags.Project
    msg := sprintf("Resource %s missing required 'Project' tag", [resource.address])
}

# Deny S3 buckets without encryption
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not has_encryption(resource)
    msg := sprintf("S3 bucket %s must have encryption enabled", [resource.address])
}

has_encryption(resource) if {
    resource.values.server_side_encryption_configuration
}

# Deny EKS clusters without private endpoint access
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_eks_cluster"
    resource.values.vpc_config[0].endpoint_private_access == false
    msg := sprintf("EKS cluster %s must have private endpoint access enabled", [resource.address])
}

# Deny security groups with overly permissive ingress rules
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group"
    rule := resource.values.ingress[_]
    rule.cidr_blocks[_] == "0.0.0.0/0"
    rule.from_port == 0
    rule.to_port == 65535
    msg := sprintf("Security group %s has overly permissive ingress rule", [resource.address])
}

# Require specific instance types for EKS node groups
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_eks_node_group"
    instance_type := resource.values.instance_types[_]
    not allowed_instance_type(instance_type)
    msg := sprintf("EKS node group %s uses disallowed instance type %s", [resource.address, instance_type])
}

allowed_instance_type(instance_type) if {
    instance_type in ["t3.medium", "t3.large", "m5.large", "m5.xlarge"]
}

# Deny resources in non-approved regions
deny contains msg if {
    provider := input.configuration.provider_config.aws
    provider.region not in ["us-west-2", "us-east-1", "eu-west-1"]
    msg := sprintf("Resources must be deployed in approved regions only")
}

# Require KMS encryption for EKS clusters
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_eks_cluster"
    not resource.values.encryption_config
    msg := sprintf("EKS cluster %s must have KMS encryption configured", [resource.address])
}

# Deny ECR repositories without image scanning
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ecr_repository"
    resource.values.image_scanning_configuration[0].scan_on_push != true
    msg := sprintf("ECR repository %s must have image scanning enabled", [resource.address])
}

# Require proper lifecycle policies for ECR
deny contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ecr_repository"
    not has_lifecycle_policy(resource.address)
    msg := sprintf("ECR repository %s must have a lifecycle policy", [resource.address])
}

has_lifecycle_policy(repo_address) if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_ecr_lifecycle_policy"
    contains(resource.values.repository, repo_address)
}