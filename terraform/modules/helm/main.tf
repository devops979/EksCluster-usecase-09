provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_id
}

# resource "kubernetes_service_account" "aws_lb_controller" {
#   metadata {
#     name      = "aws-load-balancer-controller"
#     namespace = "kube-system"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = var.lbc_iam_role_arn
#     }
#   }
# }

resource "helm_release" "loadbalancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "vpcId"
    value = var.vpc_id
  }

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "clusterName"
    value = var.cluster_id
  }


}


resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

resource "helm_release" "prometheus_grafana_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "58.0.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  timeout    = 600

  cleanup_on_fail = true
  wait            = true
  wait_for_jobs   = true

values = [
  <<-EOT
  grafana:
    enabled: true
    adminPassword: "admin"
    service:
      type: ClusterIP
      port: 80
      targetPort: 3000
    ingress:
      enabled: true
      ingressClassName: alb
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
        alb.ingress.kubernetes.io/group.name: "app-routing-group"
        alb.ingress.kubernetes.io/load-balancer-name: "app-alb"
        alb.ingress.kubernetes.io/subnets: subnet-04b9576408b6256b2,subnet-065cdada683c653e6
        alb.ingress.kubernetes.io/healthcheck-path: /login
      path: /
      pathType: Prefix

  prometheus:
    service:
      type: ClusterIP
    ingress:
      enabled: true
      ingressClassName: alb
      annotations:
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
        alb.ingress.kubernetes.io/group.name: "app-routing-group"
        alb.ingress.kubernetes.io/load-balancer-name: "app-alb"
        alb.ingress.kubernetes.io/subnets: subnet-04b9576408b6256b2,subnet-065cdada683c653e6
        alb.ingress.kubernetes.io/healthcheck-path: /prometheus/graph
      paths:
        - path: /prometheus
          pathType: Prefix

  prometheusOperator:
    enabled: true

  prometheus-node-exporter:
    enabled: true

  alertmanager:
    enabled: true
  EOT
]


  depends_on = [
    helm_release.loadbalancer_controller,
    kubernetes_namespace.monitoring
  ]
}
