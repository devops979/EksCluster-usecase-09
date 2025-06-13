variable "node_role_arn" {
  description = "ARN of the IAM role for EKS worker nodes"
  type        = string
  default= null
}

variable "user_arn" {
  description = "ARN of the IAM user for cluster admin access"
  type        = string
  # Example value: "arn:aws:iam::123456789012:user/admin"
}

variable "additional_roles" {
  description = "Additional IAM roles to add to aws-auth"
  type        = list(any)
  default     = []
  # Example:
  # default = [
  #   {
  #     rolearn  = "arn:aws:iam::123456789012:role/custom-role"
  #     username = "custom-user"
  #     groups   = ["system:viewers"]
  #   }
  # ]
}

variable "additional_users" {
  description = "Additional IAM users to add to aws-auth"
  type        = list(any)
  default     = []
}

variable "kube_host" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "kube_ca" {
  description = "EKS cluster CA certificate (base64 encoded)"
  type        = string
}

variable "kube_token" {
  description = "Authentication token for EKS cluster"
  type        = string
}
