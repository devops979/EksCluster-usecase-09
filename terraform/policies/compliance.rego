# OPA Compliance Policies for Terraform

package terraform

import rego.v1

# Ensure all resources have cost center tags for billing
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type in resource_types_requiring_cost_center
    not resource.values.tags.CostCenter
    msg := sprintf("Resource %s should have 'CostCenter' tag for cost allocation", [resource.address])
}

resource_types_requiring_cost_center := [
    "aws_instance",
    "aws_eks_cluster", 
    "aws_eks_node_group",
    "aws_s3_bucket",
    "aws_rds_instance",
    "aws_elasticache_cluster"
]

# Ensure EKS clusters have appropriate log retention
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_cloudwatch_log_group"
    contains(resource.address, "eks")
    resource.values.retention_in_days > 30
    msg := sprintf("CloudWatch log group %s has retention period > 30 days, consider cost implications", [resource.address])
}

# Recommend using spot instances for non-production workloads
recommend contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_eks_node_group"
    resource.values.capacity_type == "ON_DEMAND"
    contains(resource.address, "dev") or contains(resource.address, "staging")
    msg := sprintf("Consider using SPOT instances for non-production node group %s to reduce costs", [resource.address])
}

# Ensure proper backup configuration
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not has_versioning_enabled(resource)
    msg := sprintf("S3 bucket %s should have versioning enabled for data protection", [resource.address])
}

has_versioning_enabled(resource) if {
    # This would need to be checked against aws_s3_bucket_versioning resource
    # Simplified for this example
    true
}

# Network security recommendations
recommend contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_eks_cluster"
    resource.values.vpc_config[0].endpoint_public_access == true
    msg := sprintf("EKS cluster %s has public endpoint access enabled. Consider restricting public access cidrs", [resource.address])
}

# Resource naming conventions
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    not follows_naming_convention(resource.address, resource.values.name)
    msg := sprintf("Resource %s may not follow naming conventions", [resource.address])
}

follows_naming_convention(address, name) if {
    # Check if name includes environment and project
    contains(name, "dev") or contains(name, "staging") or contains(name, "prod")
    contains(name, "devops-challenge")
}

# Security group best practices
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_security_group_rule"
    resource.values.type == "ingress"
    resource.values.from_port != resource.values.to_port
    resource.values.cidr_blocks[_] == "0.0.0.0/0"
    msg := sprintf("Security group rule %s allows broad port range from internet", [resource.address])
}

# Monitoring and observability
recommend contains msg if {
    has_eks_cluster
    not has_container_insights
    msg := "Consider enabling Container Insights for EKS cluster monitoring"
}

has_eks_cluster if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_eks_cluster"
}

has_container_insights if {
    # This would check for Container Insights configuration
    # Simplified for this example
    false
}

# Data classification and handling
warn contains msg if {
    resource := input.planned_values.root_module.resources[_]
    resource.type == "aws_s3_bucket"
    not resource.values.tags.DataClassification
    msg := sprintf("S3 bucket %s should have 'DataClassification' tag", [resource.address])
}