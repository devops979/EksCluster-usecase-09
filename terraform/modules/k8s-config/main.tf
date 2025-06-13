terraform {
  required_providers {
    kubernetes = {
      source                = "hashicorp/kubernetes"
      version               = "~> 2.24"
      configuration_aliases = [kubernetes.eks]
    }
  }
}

resource "kubernetes_config_map_v1_data" "aws_auth" {
  provider = kubernetes.eks
  
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      [{
        rolearn  = var.node_role_arn
        username = "system:node:{{EC2PrivateDNSName}}"
        groups   = ["system:bootstrappers", "system:nodes"]
      }],
      var.additional_roles
    ))

    mapUsers = yamlencode(concat(
      [{
        userarn  = var.user_arn
        username = split("/", var.user_arn)[1]  # Better than "root"
        groups   = ["cluster-admin"]
      }],
      var.additional_users
    ))
  }

  force = true
}