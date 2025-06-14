terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0" # use version compatible with your setup
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10" # adjust as needed
    }
  }
}


resource "kubernetes_service_account" "aws_lb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.lbc_iam_role_arn
    }
  }
}

# resource "helm_release" "loadbalancer_controller" {
#   name       = "aws-load-balancer-controller"
#   repository = "https://aws.github.io/eks-charts"
#   chart      = "aws-load-balancer-controller"
#   namespace  = "kube-system"

#   set {
#     name  = "image.repository"
#     value = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/amazon/aws-load-balancer-controller"
#   }

#   set {
#     name  = "serviceAccount.create"
#     value = "false"
#   }

#   set {
#     name  = "serviceAccount.name"
#     value = "aws-load-balancer-controller"
#   }

#   set {
#     name  = "vpcId"
#     value = var.vpc_id
#   }

#   set {
#     name  = "region"
#     value = var.aws_region
#   }

#   set {
#     name  = "clusterName"
#     value = var.cluster_id
#   }


# }


# resource "kubernetes_namespace" "monitoring" {
#   metadata {
#     name = "monitoring"
#   }
# }

# # resource "helm_release" "prometheus_grafana_stack" {
# #   name       = "kube-prometheus-stack"
# #   repository = "https://prometheus-community.github.io/helm-charts"
# #   chart      = "kube-prometheus-stack"
# #   version    = "58.0.0"
# #   namespace  = kubernetes_namespace.monitoring.metadata[0].name
# #   timeout    = 600

# #   cleanup_on_fail = true
# #   wait            = true
# #   wait_for_jobs   = true

# # values = [
# #   <<-EOT
# #   grafana:
# #     enabled: true
# #     adminPassword: "admin"
# #     service:
# #       type: ClusterIP
# #       port: 80
# #       targetPort: 3000
# #     ingress:
# #       enabled: true
# #       ingressClassName: alb
# #       annotations:
# #         alb.ingress.kubernetes.io/scheme: internet-facing
# #         alb.ingress.kubernetes.io/target-type: ip
# #         alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
# #         alb.ingress.kubernetes.io/group.name: "app-routing-group"
# #         alb.ingress.kubernetes.io/load-balancer-name: "app-alb"
# #         alb.ingress.kubernetes.io/subnets: subnet-0ff6ae89b012050bc,subnet-020ff1031afc40158
# #         alb.ingress.kubernetes.io/healthcheck-path: /login
# #       path: /
# #       pathType: Prefix

# #   prometheus:
# #     service:
# #       type: ClusterIP
# #     ingress:
# #       enabled: true
# #       ingressClassName: alb
# #       annotations:
# #         alb.ingress.kubernetes.io/scheme: internet-facing
# #         alb.ingress.kubernetes.io/target-type: ip
# #         alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
# #         alb.ingress.kubernetes.io/group.name: "app-routing-group"
# #         alb.ingress.kubernetes.io/load-balancer-name: "app-alb"
# #         alb.ingress.kubernetes.io/subnets: subnet-0ff6ae89b012050bc,subnet-020ff1031afc40158
# #         alb.ingress.kubernetes.io/healthcheck-path: /prometheus/graph
# #       path: /prometheus
# #       pathType: Prefix

# #   prometheusOperator:
# #     enabled: true

# #   prometheus-node-exporter:
# #     enabled: true

# #   alertmanager:
# #     enabled: true
# #   EOT
# # ]


# #   depends_on = [
# #     helm_release.loadbalancer_controller,
# #     kubernetes_namespace.monitoring
# #   ]
# # }


# resource "helm_release" "prometheus_grafana_stack" {
#   name       = "kube-prometheus-stack"
#   repository = "https://prometheus-community.github.io/helm-charts"
#   chart      = "kube-prometheus-stack"
#   namespace  = "monitoring"
#   create_namespace = true

#   values = [
#     yamlencode({
#       grafana = {
#         enabled        = true
#         adminPassword  = "admin"
#         service = {
#           type       = "ClusterIP"
#           port       = 80
#           targetPort = 3000
#         }
#         ingress = {
#           enabled           = true
#           ingressClassName  = "alb"
#           path              = "/"
#           pathType          = "Prefix"
#           annotations = {
#             "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
#             "alb.ingress.kubernetes.io/target-type"         = "ip"
#             "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}]"
#             "alb.ingress.kubernetes.io/group.name"          = "app-routing-group"
#             "alb.ingress.kubernetes.io/load-balancer-name"  = "app-alb"
#             "alb.ingress.kubernetes.io/subnets"             = "subnet-0ff6ae89b012050bc,subnet-020ff1031afc40158"
#             "alb.ingress.kubernetes.io/healthcheck-path"    = "/login"
#           }
#         }
#       }

#       prometheus = {
#         service = {
#           type = "ClusterIP"
#         }
#         ingress = {
#           enabled           = true
#           ingressClassName  = "alb"
#           path              = "/prometheus"
#           pathType          = "Prefix"
#           annotations = {
#             "alb.ingress.kubernetes.io/scheme"              = "internet-facing"
#             "alb.ingress.kubernetes.io/target-type"         = "ip"
#             "alb.ingress.kubernetes.io/listen-ports"        = "[{\"HTTP\": 80}]"
#             "alb.ingress.kubernetes.io/group.name"          = "app-routing-group"
#             "alb.ingress.kubernetes.io/load-balancer-name"  = "app-alb"
#             "alb.ingress.kubernetes.io/subnets"             = "subnet-0ff6ae89b012050bc,subnet-020ff1031afc40158"
#             "alb.ingress.kubernetes.io/healthcheck-path"    = "/prometheus/graph"
#           }
#         }
#         prometheusSpec = {
#           externalUrl = "http://${var.alb_dns_name}/prometheus"
#           routePrefix = "/prometheus"
#         }
#       }

#       prometheusOperator = {
#         enabled = true
#       }

#       prometheus-node-exporter = {
#         enabled = true
#       }

#       alertmanager = {
#         enabled = true
#       }
#     })
#   ]
# }

