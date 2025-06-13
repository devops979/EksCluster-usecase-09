variable "node_role_arn" {
  description = "IAM role ARN for EKS worker nodes"
  type        = string
}

variable "user_arn" {
  description = "IAM user ARN to be added to system:masters group"
  type        = string
}
