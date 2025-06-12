# Deployment Guide

## Overview

This guide covers the complete deployment process for the DevOps Challenge microservices application, from infrastructure provisioning to application deployment on Amazon EKS.

## Prerequisites

Before starting the deployment, ensure you have:

### Required Tools
- **AWS CLI** (v2.x): `aws --version`
- **Terraform** (v1.5+): `terraform --version`
- **kubectl** (v1.28+): `kubectl version --client`
- **Docker** (v20.x+): `docker --version`
- **Git**: `git --version`

### AWS Setup
```bash
# Configure AWS credentials
aws configure

# Verify access
aws sts get-caller-identity
```

### GitHub Setup
Configure the following secrets in your GitHub repository:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION`
- `AWS_ACCOUNT_ID`

## Infrastructure Deployment

### Step 1: Clone Repository
```bash
git clone <your-repository-url>
cd devops-eks-challenge
```

### Step 2: Configure Environment
```bash
# Copy example variables
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars

# Edit variables as needed
vim terraform/environments/dev/terraform.tfvars
```

### Step 3: Initialize Terraform
```bash
cd terraform/environments/dev
terraform init
```

### Step 4: Plan Infrastructure
```bash
terraform plan -out=tfplan
```

Review the plan carefully before proceeding.

### Step 5: Apply Infrastructure
```bash
terraform apply tfplan
```

This will create:
- VPC with public/private subnets
- EKS cluster with node groups
- ECR repositories
- IAM roles and security groups
- S3 bucket for state storage
- DynamoDB table for state locking

### Step 6: Configure kubectl
```bash
aws eks update-kubeconfig --region us-west-2 --name devops-challenge-dev-eks
kubectl get nodes
```

## Application Deployment

### Manual Deployment

#### Step 1: Build and Push Images
```bash
# Get ECR login token
aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-west-2.amazonaws.com

# Build appointment service
docker build -f docker/appointment-service/Dockerfile -t devops-challenge-appointment-service .
docker tag devops-challenge-appointment-service:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/devops-challenge-appointment-service:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/devops-challenge-appointment-service:latest

# Build patient service
docker build -f docker/patient-service/Dockerfile -t devops-challenge-patient-service .
docker tag devops-challenge-patient-service:latest <account-id>.dkr.ecr.us-west-2.amazonaws.com/devops-challenge-patient-service:latest
docker push <account-id>.dkr.ecr.us-west-2.amazonaws.com/devops-challenge-patient-service:latest
```

#### Step 2: Update Kubernetes Manifests
```bash
# Replace placeholders in manifests
sed -i "s|ECR_REGISTRY|<account-id>.dkr.ecr.us-west-2.amazonaws.com|g" k8s/*/deployment.yaml
sed -i "s|PROJECT_NAME|devops-challenge|g" k8s/*/deployment.yaml
sed -i "s|IMAGE_TAG|latest|g" k8s/*/deployment.yaml
```

#### Step 3: Deploy to Kubernetes
```bash
# Create namespace
kubectl apply -f k8s/namespace.yaml

# Deploy appointment service
kubectl apply -f k8s/appointment-service/

# Deploy patient service
kubectl apply -f k8s/patient-service/

# Verify deployment
kubectl get pods -n microservices
kubectl get services -n microservices
```

### Automated Deployment (CI/CD)

The GitHub Actions workflows handle automated deployment:

#### Infrastructure Pipeline
- **Trigger**: Push to `main` branch with terraform changes
- **Steps**:
  1. Terraform format and validate
  2. Security scanning with Checkov
  3. OPA policy validation
  4. Terraform plan (on PR)
  5. Terraform apply (on merge to main)

#### Application Pipeline
- **Trigger**: Push to `main` branch with application changes
- **Steps**:
  1. Detect changed services
  2. Security scanning with Trivy
  3. Build and push Docker images
  4. Deploy to EKS
  5. Run smoke tests

## Verification

### Infrastructure Verification
```bash
# Check EKS cluster
aws eks describe-cluster --name devops-challenge-dev-eks

# Verify nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Verify ECR repositories
aws ecr describe-repositories
```

### Application Verification
```bash
# Check application pods
kubectl get pods -n microservices

# Check services
kubectl get services -n microservices

# Check logs
kubectl logs -f deployment/appointment-service -n microservices
kubectl logs -f deployment/patient-service -n microservices

# Test endpoints (if load balancers are ready)
APPOINTMENT_LB=$(kubectl get service appointment-service -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
PATIENT_LB=$(kubectl get service patient-service -n microservices -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://$APPOINTMENT_LB/health
curl http://$PATIENT_LB/health
```

## Monitoring Setup

### CloudWatch Container Insights
```bash
# Enable Container Insights
aws eks update-cluster-config \
  --region us-west-2 \
  --name devops-challenge-dev-eks \
  --logging '{"enable":["api","audit","authenticator","controllerManager","scheduler"]}'
```

### Prometheus and Grafana (Optional)
```bash
# Add Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace

# Access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
```

## Scaling

### Horizontal Pod Autoscaler
HPA is configured for both services:
```bash
# Check HPA status
kubectl get hpa -n microservices

# Generate load to test scaling
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh
# Inside the pod:
while true; do wget -q -O- http://appointment-service.microservices.svc.cluster.local/health; done
```

### Cluster Autoscaler
```bash
# Install cluster autoscaler
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml

# Configure for your cluster
kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"
kubectl -n kube-system edit deployment.apps/cluster-autoscaler
```

## Troubleshooting

### Common Issues

#### 1. Pod Stuck in Pending State
```bash
# Check events
kubectl describe pod <pod-name> -n microservices

# Common causes:
# - Insufficient resources
# - Node selector/affinity issues
# - Image pull errors
```

#### 2. Service Not Accessible
```bash
# Check service endpoints
kubectl get endpoints -n microservices

# Check security groups
aws ec2 describe-security-groups --group-ids <sg-id>

# Verify load balancer
kubectl describe service <service-name> -n microservices
```

#### 3. Image Pull Errors
```bash
# Check ECR permissions
aws ecr get-login-password --region us-west-2

# Verify image exists
aws ecr list-images --repository-name devops-challenge-appointment-service

# Check node IAM permissions
kubectl describe pod <pod-name> -n microservices
```

#### 4. Terraform State Issues
```bash
# Refresh state
terraform refresh

# Import existing resources
terraform import aws_eks_cluster.main devops-challenge-dev-eks

# Force unlock (if needed)
terraform force-unlock <lock-id>
```

### Useful Commands

```bash
# Get cluster info
kubectl cluster-info

# Check resource usage
kubectl top nodes
kubectl top pods -n microservices

# View logs
kubectl logs -f deployment/appointment-service -n microservices --tail=100

# Execute into pod
kubectl exec -it <pod-name> -n microservices -- /bin/sh

# Port forward for testing
kubectl port-forward svc/appointment-service 8080:80 -n microservices

# Check resource quotas
kubectl describe resourcequota -n microservices

# View events
kubectl get events -n microservices --sort-by='.lastTimestamp'
```

## Rollback Procedures

### Application Rollback
```bash
# Check rollout history
kubectl rollout history deployment/appointment-service -n microservices

# Rollback to previous version
kubectl rollout undo deployment/appointment-service -n microservices

# Rollback to specific revision
kubectl rollout undo deployment/appointment-service --to-revision=2 -n microservices
```

### Infrastructure Rollback
```bash
# Terraform rollback
cd terraform/environments/dev
git checkout <previous-commit>
terraform plan
terraform apply
```

## Security Considerations

### Network Policies
```yaml
# Example network policy
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
```

### Pod Security Standards
```yaml
# Pod security context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  fsGroup: 1000
  seccompProfile:
    type: RuntimeDefault
```

### RBAC
```bash
# Check current permissions
kubectl auth can-i --list

# Create service account with limited permissions
kubectl create serviceaccount limited-sa -n microservices
kubectl create rolebinding limited-binding --clusterrole=view --serviceaccount=microservices:limited-sa -n microservices
```

## Performance Optimization

### Resource Requests and Limits
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "50m"
  limits:
    memory: "128Mi"
    cpu: "100m"
```

### Node Optimization
```bash
# Check node capacity
kubectl describe nodes

# Optimize node groups
# - Use appropriate instance types
# - Configure spot instances for cost savings
# - Set proper taints and tolerations
```

## Backup and Recovery

### Backup Strategy
```bash
# Backup EKS cluster configuration
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Backup persistent volumes (if any)
kubectl get pv -o yaml > pv-backup.yaml

# Backup secrets and configmaps
kubectl get secrets --all-namespaces -o yaml > secrets-backup.yaml
kubectl get configmaps --all-namespaces -o yaml > configmaps-backup.yaml
```

### Disaster Recovery
1. **Infrastructure**: Terraform state in S3 with versioning
2. **Applications**: Container images in ECR with lifecycle policies
3. **Configuration**: GitOps approach with version control
4. **Data**: Regular backups of persistent storage

## Next Steps

1. **Set up monitoring and alerting**
2. **Implement service mesh (Istio)**
3. **Add distributed tracing**
4. **Configure backup strategies**
5. **Implement chaos engineering**
6. **Set up disaster recovery procedures**
7. **Add performance testing**
8. **Implement security scanning in CI/CD**