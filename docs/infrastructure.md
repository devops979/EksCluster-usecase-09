# Infrastructure Documentation

## Overview

This document describes the AWS infrastructure setup for the DevOps Challenge project, deployed using Terraform with a modular approach.

## Architecture

The infrastructure consists of the following main components:

### Network Layer
- **VPC**: Custom VPC with public and private subnets across multiple AZs
- **Subnets**: Public subnets for load balancers, private subnets for EKS nodes  
- **NAT Gateways**: For outbound internet access from private subnets
- **Route Tables**: Separate routing for public and private subnets

### Container Platform
- **EKS Cluster**: Managed Kubernetes service with encryption and logging
- **Node Groups**: Auto-scaling groups of EC2 instances for workloads
- **ECR Repositories**: Private container registries for application images

### Security
- **IAM Roles**: Least-privilege access for EKS cluster and node groups
- **Security Groups**: Network-level access control
- **KMS**: Encryption keys for EKS secrets
- **VPC Flow Logs**: Network traffic monitoring

### State Management
- **S3 Backend**: Remote state storage with versioning and encryption
- **DynamoDB**: State locking to prevent concurrent modifications

## Module Structure

The Terraform code is organized into reusable modules:

```
terraform/
├── modules/
│   ├── vpc/          # Virtual Private Cloud setup
│   ├── eks/          # EKS cluster and node groups
│   ├── iam/          # Identity and Access Management
│   └── ecr/          # Elastic Container Registry
└── environments/
    ├── dev/          # Development environment
    ├── staging/      # Staging environment  
    └── prod/         # Production environment
```

## VPC Module

Creates a secure network foundation:

- **CIDR Block**: 10.0.0.0/16 (65,536 IP addresses)
- **Availability Zones**: Spans multiple AZs for high availability
- **Public Subnets**: 10.0.1.0/24, 10.0.2.0/24 (512 IPs each)
- **Private Subnets**: 10.0.10.0/24, 10.0.20.0/24 (512 IPs each)
- **NAT Gateways**: One per AZ for redundancy
- **VPC Endpoints**: For private AWS service access (optional)

### Key Features
- DNS hostnames and resolution enabled
- VPC Flow Logs for security monitoring
- Network ACLs for additional security layer
- Internet Gateway for public internet access

## EKS Module

Deploys a production-ready Kubernetes cluster:

### Cluster Configuration
- **Version**: Kubernetes 1.28 (configurable)
- **Endpoint Access**: Both public and private enabled
- **Logging**: All log types enabled (API, audit, authenticator, controller manager, scheduler)
- **Encryption**: KMS encryption for secrets at rest
- **Add-ons**: CoreDNS, kube-proxy, VPC CNI, EBS CSI driver

### Node Groups
- **General Purpose**: On-demand instances for stable workloads
- **Spot Instances**: Cost-optimized for fault-tolerant workloads
- **Auto Scaling**: Automatic scaling based on demand
- **Instance Types**: t3.medium, t3.large (configurable)
- **AMI**: Amazon Linux 2 optimized for EKS

### Security Features
- **Private Node Communication**: Nodes in private subnets
- **Security Groups**: Restricted access between components
- **IAM Roles**: Service-linked roles with minimal permissions
- **Pod Security**: Security contexts and non-root containers

## IAM Module

Implements security best practices:

### Cluster Service Role
- Permissions for EKS cluster management
- VPC resource controller access
- CloudWatch logging permissions

### Node Group Role
- EC2 and EKS worker node permissions
- ECR image pull access
- EBS CSI driver permissions
- CloudWatch agent permissions

### Service Account Roles (IRSA)
- AWS Load Balancer Controller
- Cluster Autoscaler
- External DNS (if used)

## ECR Module

Container image management:

### Repository Features
- **Image Scanning**: Vulnerability scanning enabled
- **Lifecycle Policies**: Automatic cleanup of old images
- **Encryption**: AES256 encryption at rest
- **Access Control**: IAM-based repository policies

### Repositories Created
- `devops-challenge-appointment-service`
- `devops-challenge-patient-service`

## Security Considerations

### Network Security
- Private subnets for all compute resources
- Security groups with minimal required access
- NACLs as additional defense layer
- VPC Flow Logs for monitoring

### Data Protection
- Encryption at rest for all storage
- Encryption in transit for all communications
- KMS key rotation enabled
- S3 bucket versioning and encryption

### Access Control
- IAM roles with least privilege principle
- Service accounts for workload identity
- MFA required for administrative access
- Regular access reviews

### Monitoring and Logging
- CloudWatch for metrics and logs
- VPC Flow Logs for network monitoring
- EKS control plane logging
- Container insights (optional)

## Cost Optimization

### Resource Sizing
- Right-sized instance types for workloads
- Spot instances for non-critical workloads
- Auto-scaling to match demand

### Storage Optimization
- EBS GP3 volumes for better price/performance
- ECR lifecycle policies to reduce storage costs
- CloudWatch log retention policies

### Monitoring
- Cost allocation tags on all resources
- AWS Cost Explorer integration
- Budget alerts for cost control

## Disaster Recovery

### Backup Strategy
- S3 versioning for state files
- ECR image replication (if needed)
- EKS cluster configuration as code

### High Availability
- Multi-AZ deployment
- Auto-scaling groups
- Load balancer health checks
- Database backups (if applicable)

## Compliance

### Security Standards
- CIS Kubernetes Benchmark compliance
- AWS Security Best Practices
- NIST Cybersecurity Framework alignment

### Governance
- Resource tagging strategy
- Change management through GitOps
- Audit logging enabled
- Policy as code with OPA

## Troubleshooting

### Common Issues

1. **EKS Node Group Launch Failures**
   - Check subnet capacity
   - Verify IAM permissions
   - Review security group rules

2. **Pod Scheduling Issues**
   - Check node selectors and taints
   - Verify resource requests/limits
   - Review cluster autoscaler logs

3. **Network Connectivity**
   - Verify security group rules
   - Check route table configurations
   - Review VPC endpoints

### Useful Commands

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name devops-challenge-dev-eks

# Check cluster status
kubectl get nodes
kubectl get pods --all-namespaces

# View cluster info
kubectl cluster-info
kubectl get componentstatuses
```

## Maintenance

### Regular Tasks
- Update EKS cluster version quarterly
- Review and rotate IAM access keys
- Update node group AMIs monthly
- Review security group rules
- Monitor cost and usage

### Automation
- Automated security patching
- Backup verification
- Performance monitoring
- Capacity planning

## Next Steps

1. **Monitoring Setup**: Deploy Prometheus and Grafana
2. **Service Mesh**: Consider Istio for advanced traffic management
3. **GitOps**: Implement ArgoCD for application deployment
4. **Security**: Add Falco for runtime security monitoring
5. **Observability**: Implement distributed tracing with Jaeger