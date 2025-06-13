variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}


variable "cluster_oidc_provider_arn" {
  description = "The URL on the EKS cluster OIDC Issuer"
  type        = string
  default     = ""
}

variable "aws_iam_openid_connect_provider_extract_from_arn" {
  description = "The ARN on the EKS cluster OIDC Issuer"
  type        = string
}

variable "cluster_oidc_issuer_url" {
  type        = string
  description = "The URL of the OIDC issuer from the EKS cluster"
}
