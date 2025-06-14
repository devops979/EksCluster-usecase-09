## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.12.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.99.1 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 2.10 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 2.24.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.99.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ecr"></a> [ecr](#module\_ecr) | ../../modules/ecr | n/a |
| <a name="module_eks"></a> [eks](#module\_eks) | ../../modules/eks | n/a |
| <a name="module_iam_core"></a> [iam\_core](#module\_iam\_core) | ../../modules/iam_core | n/a |
| <a name="module_iam_irsa"></a> [iam\_irsa](#module\_iam\_irsa) | ../../modules/iam_irsa | n/a |
| <a name="module_k8s_config"></a> [k8s\_config](#module\_k8s\_config) | ../../modules/k8s-config | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | ../../modules/vpc | n/a |

## Resources

| Name | Type |
|------|------|
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_eks_cluster.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster) | data source |
| [aws_eks_cluster_auth.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/eks_cluster_auth) | data source |
| [aws_iam_openid_connect_provider.eks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_openid_connect_provider) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aws_region"></a> [aws\_region](#input\_aws\_region) | AWS region | `string` | `"us-east-1"` | no |
| <a name="input_cluster_version"></a> [cluster\_version](#input\_cluster\_version) | Kubernetes version for EKS cluster | `string` | `"1.28"` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name | `string` | `"dev"` | no |
| <a name="input_node_groups"></a> [node\_groups](#input\_node\_groups) | EKS node group configurations | <pre>map(object({<br>    instance_types = list(string)<br>    capacity_type  = string<br>    disk_size      = number<br>    ami_type       = string<br>    scaling_config = object({<br>      desired_size = number<br>      max_size     = number<br>      min_size     = number<br>    })<br>    update_config = object({<br>      max_unavailable_percentage = number<br>    })<br>    labels = map(string)<br>    taints = list(object({<br>      key    = string<br>      value  = string<br>      effect = string<br>    }))<br>  }))</pre> | <pre>{<br>  "general": {<br>    "ami_type": "AL2_x86_64",<br>    "capacity_type": "ON_DEMAND",<br>    "disk_size": 20,<br>    "instance_types": [<br>      "t3.medium"<br>    ],<br>    "labels": {<br>      "Environment": "dev",<br>      "NodeGroup": "general"<br>    },<br>    "scaling_config": {<br>      "desired_size": 2,<br>      "max_size": 4,<br>      "min_size": 1<br>    },<br>    "taints": [],<br>    "update_config": {<br>      "max_unavailable_percentage": 25<br>    }<br>  },<br>  "spot": {<br>    "ami_type": "AL2_x86_64",<br>    "capacity_type": "SPOT",<br>    "disk_size": 20,<br>    "instance_types": [<br>      "t3.medium",<br>      "t3.large"<br>    ],<br>    "labels": {<br>      "Environment": "dev",<br>      "NodeGroup": "spot"<br>    },<br>    "scaling_config": {<br>      "desired_size": 1,<br>      "max_size": 3,<br>      "min_size": 0<br>    },<br>    "taints": [<br>      {<br>        "effect": "NO_SCHEDULE",<br>        "key": "spot-instance",<br>        "value": "true"<br>      }<br>    ],<br>    "update_config": {<br>      "max_unavailable_percentage": 50<br>    }<br>  }<br>}</pre> | no |
| <a name="input_private_subnet_cidrs"></a> [private\_subnet\_cidrs](#input\_private\_subnet\_cidrs) | CIDR blocks for private subnets | `list(string)` | <pre>[<br>  "10.0.10.0/24",<br>  "10.0.20.0/24"<br>]</pre> | no |
| <a name="input_project_name"></a> [project\_name](#input\_project\_name) | Name of the project | `string` | `"devops-challenge"` | no |
| <a name="input_public_subnet_cidrs"></a> [public\_subnet\_cidrs](#input\_public\_subnet\_cidrs) | CIDR blocks for public subnets | `list(string)` | <pre>[<br>  "10.0.1.0/24",<br>  "10.0.2.0/24"<br>]</pre> | no |
| <a name="input_vpc_cidr"></a> [vpc\_cidr](#input\_vpc\_cidr) | CIDR block for VPC | `string` | `"10.0.0.0/16"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cluster_arn"></a> [cluster\_arn](#output\_cluster\_arn) | EKS cluster ARN |
| <a name="output_cluster_certificate_authority_data"></a> [cluster\_certificate\_authority\_data](#output\_cluster\_certificate\_authority\_data) | Base64 encoded certificate data required to communicate with the cluster |
| <a name="output_cluster_endpoint"></a> [cluster\_endpoint](#output\_cluster\_endpoint) | Endpoint for EKS control plane |
| <a name="output_cluster_iam_role_arn"></a> [cluster\_iam\_role\_arn](#output\_cluster\_iam\_role\_arn) | IAM role ARN associated with EKS cluster |
| <a name="output_cluster_iam_role_name"></a> [cluster\_iam\_role\_name](#output\_cluster\_iam\_role\_name) | IAM role name associated with EKS cluster |
| <a name="output_cluster_id"></a> [cluster\_id](#output\_cluster\_id) | EKS cluster ID |
| <a name="output_cluster_primary_security_group_id"></a> [cluster\_primary\_security\_group\_id](#output\_cluster\_primary\_security\_group\_id) | Cluster security group that was created by Amazon EKS for the cluster |
| <a name="output_cluster_security_group_id"></a> [cluster\_security\_group\_id](#output\_cluster\_security\_group\_id) | Security group ids attached to the cluster control plane |
| <a name="output_configure_kubectl"></a> [configure\_kubectl](#output\_configure\_kubectl) | Configure kubectl: make sure you're logged in with the correct AWS profile and run the following command to update your kubeconfig |
| <a name="output_ecr_repository_arns"></a> [ecr\_repository\_arns](#output\_ecr\_repository\_arns) | ECR repository ARNs |
| <a name="output_ecr_repository_urls"></a> [ecr\_repository\_urls](#output\_ecr\_repository\_urls) | ECR repository URLs |
| <a name="output_environment"></a> [environment](#output\_environment) | Environment name |
| <a name="output_node_groups"></a> [node\_groups](#output\_node\_groups) | EKS node groups |
| <a name="output_private_subnet_ids"></a> [private\_subnet\_ids](#output\_private\_subnet\_ids) | IDs of the private subnets |
| <a name="output_public_subnet_ids"></a> [public\_subnet\_ids](#output\_public\_subnet\_ids) | IDs of the public subnets |
| <a name="output_region"></a> [region](#output\_region) | AWS region |
| <a name="output_vpc_cidr_block"></a> [vpc\_cidr\_block](#output\_vpc\_cidr\_block) | CIDR block of the VPC |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of the VPC |
