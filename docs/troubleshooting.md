# Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting procedures for common issues encountered in the DevOps Challenge project, covering infrastructure, application, and operational problems.

## Infrastructure Issues

### Terraform Problems

#### State Lock Issues
```bash
# Problem: Terraform state is locked
Error: Error acquiring the state lock

# Solution 1: Wait for lock to expire (usually 15 minutes)
# Solution 2: Force unlock (use with caution)
terraform force-unlock <lock-id>

# Solution 3: Check DynamoDB for stuck locks
aws dynamodb scan --table-name devops-challenge-terraform-locks

# Solution 4: Delete stuck lock manually
aws dynamodb delete-item \
  --table-name devops-challenge-terraform-locks \
  --key '{"LockID":{"S":"<lock-id>"}}'
```

#### State Drift Issues
```bash
# Problem: Terraform state doesn't match actual infrastructure
# Solution: Refresh state and plan
terraform refresh
terraform plan

# Import missing resources
terraform import aws_eks_cluster.main devops-challenge-dev-eks

# Remove resources from state if they no longer exist
terraform state rm aws_instance.example
```

#### Provider Version Conflicts
```bash
# Problem: Provider version conflicts
Error: Failed to query available provider packages

# Solution: Clear provider cache and reinitialize
rm -rf .terraform
terraform init -upgrade
```

### AWS EKS Issues

#### Cluster Creation Failures
```bash
# Problem: EKS cluster creation fails
# Check CloudFormation events
aws cloudformation describe-stack-events \
  --stack-name eksctl-devops-challenge-dev-eks-cluster

# Common causes and solutions:
# 1. Insufficient IAM permissions
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/eks-service-role \
  --action-names eks:CreateCluster \
  --resource-arns "*"

# 2. Subnet configuration issues
aws ec2 describe-subnets --subnet-ids subnet-12345 subnet-67890

# 3. Security group conflicts
aws ec2 describe-security-groups --group-ids sg-12345
```

#### Node Group Launch Failures
```bash
# Problem: EKS node group instances fail to launch
# Check Auto Scaling Group events
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name eks-node-group-asg

# Common causes:
# 1. Insufficient subnet capacity
aws ec2 describe-subnets --subnet-ids subnet-12345 \
  --query 'Subnets[*].[SubnetId,AvailableIpAddressCount]'

# 2. Instance type not available in AZ
aws ec2 describe-instance-type-offerings \
  --location-type availability-zone \
  --filters Name=instance-type,Values=t3.medium

# 3. AMI issues
aws eks describe-addon-versions --addon-name vpc-cni \
  --kubernetes-version 1.28
```

#### Cluster Access Issues
```bash
# Problem: Cannot access EKS cluster
error: You must be logged in to the server (Unauthorized)

# Solution 1: Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name devops-challenge-dev-eks

# Solution 2: Check AWS credentials
aws sts get-caller-identity

# Solution 3: Verify cluster endpoint access
aws eks describe-cluster --name devops-challenge-dev-eks \
  --query 'cluster.endpoint'

# Solution 4: Check security groups
kubectl get nodes -o wide
```

### VPC and Networking Issues

#### DNS Resolution Problems
```bash
# Problem: Pods cannot resolve DNS names
# Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# Test DNS resolution from pod
kubectl run test-pod --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Check CoreDNS configuration
kubectl get configmap coredns -n kube-system -o yaml
```

#### Load Balancer Issues
```bash
# Problem: Load balancer not provisioning
# Check service events
kubectl describe service appointment-service -n microservices

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify IAM permissions
aws iam get-role-policy --role-name AWSLoadBalancerControllerIAMRole \
  --policy-name AWSLoadBalancerControllerIAMPolicy
```

#### Network Policy Issues
```bash
# Problem: Network policies blocking legitimate traffic
# List network policies
kubectl get networkpolicies -n microservices

# Check policy details
kubectl describe networkpolicy default-deny-ingress -n microservices

# Test connectivity between pods
kubectl exec -it pod1 -n microservices -- nc -zv pod2-service 5000

# Temporarily disable network policies for testing
kubectl delete networkpolicy --all -n microservices
```

## Application Issues

### Container and Pod Problems

#### Pod Stuck in Pending State
```bash
# Problem: Pods remain in Pending state
kubectl get pods -n microservices

# Check pod events
kubectl describe pod appointment-service-xxx -n microservices

# Common causes and solutions:
# 1. Insufficient resources
kubectl top nodes
kubectl describe nodes

# 2. Image pull errors
kubectl describe pod appointment-service-xxx -n microservices | grep -A 10 Events

# 3. Node selector/affinity issues
kubectl get nodes --show-labels
kubectl describe pod appointment-service-xxx -n microservices | grep -A 5 "Node-Selectors"

# 4. Persistent volume issues
kubectl get pv,pvc -n microservices
```

#### CrashLoopBackOff Issues
```bash
# Problem: Pods in CrashLoopBackOff state
kubectl get pods -n microservices

# Check pod logs
kubectl logs appointment-service-xxx -n microservices --previous

# Check container exit codes
kubectl describe pod appointment-service-xxx -n microservices

# Common solutions:
# 1. Fix application startup issues
# 2. Adjust resource limits
# 3. Fix health check configurations
# 4. Check environment variables and secrets
```

#### Image Pull Errors
```bash
# Problem: Cannot pull container images
# Check image name and tag
kubectl describe pod appointment-service-xxx -n microservices

# Verify ECR repository exists
aws ecr describe-repositories --repository-names devops-challenge-appointment-service

# Check ECR permissions
aws ecr get-login-password --region us-west-2

# Verify image exists in ECR
aws ecr list-images --repository-name devops-challenge-appointment-service

# Check node IAM role permissions
aws iam list-attached-role-policies --role-name eks-node-group-role
```

### Application Performance Issues

#### High Memory Usage
```bash
# Problem: Application consuming too much memory
# Check resource usage
kubectl top pods -n microservices

# Check memory limits
kubectl describe pod appointment-service-xxx -n microservices | grep -A 5 Limits

# Analyze memory usage patterns
kubectl exec -it appointment-service-xxx -n microservices -- cat /proc/meminfo

# Check for memory leaks in application logs
kubectl logs appointment-service-xxx -n microservices | grep -i "memory\|oom"
```

#### High CPU Usage
```bash
# Problem: High CPU utilization
# Check CPU usage
kubectl top pods -n microservices --sort-by=cpu

# Check CPU limits and requests
kubectl describe pod appointment-service-xxx -n microservices | grep -A 10 "Requests\|Limits"

# Profile application performance
kubectl exec -it appointment-service-xxx -n microservices -- top

# Check for CPU-intensive processes
kubectl exec -it appointment-service-xxx -n microservices -- ps aux --sort=-%cpu
```

#### Slow Response Times
```bash
# Problem: Application responding slowly
# Check application logs
kubectl logs appointment-service-xxx -n microservices --tail=100

# Test endpoint response time
kubectl exec -it test-pod -n microservices -- time curl http://appointment-service:5000/health

# Check database connections (if applicable)
kubectl exec -it appointment-service-xxx -n microservices -- netstat -an | grep :5432

# Monitor application metrics
kubectl port-forward svc/appointment-service 8080:80 -n microservices
curl http://localhost:8080/metrics
```

## Monitoring and Logging Issues

### Prometheus Problems

#### Prometheus Not Scraping Targets
```bash
# Problem: Prometheus not collecting metrics
# Check Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Visit http://localhost:9090/targets

# Check ServiceMonitor configuration
kubectl get servicemonitor -n monitoring

# Verify service labels match ServiceMonitor selector
kubectl get svc appointment-service -n microservices --show-labels

# Check Prometheus configuration
kubectl get prometheus -n monitoring -o yaml | grep serviceMonitorSelector
```

#### Missing Metrics
```bash
# Problem: Expected metrics not appearing in Prometheus
# Check if metrics endpoint is accessible
kubectl exec -it appointment-service-xxx -n microservices -- curl localhost:5000/metrics

# Verify ServiceMonitor is targeting correct port
kubectl describe servicemonitor appointment-service-monitor -n monitoring

# Check Prometheus logs
kubectl logs prometheus-kube-prometheus-prometheus-0 -n monitoring
```

### Grafana Issues

#### Dashboard Not Loading Data
```bash
# Problem: Grafana dashboard shows no data
# Check Prometheus data source configuration
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Test Prometheus queries directly
curl -G 'http://prometheus-kube-prometheus-prometheus:9090/api/v1/query' \
  --data-urlencode 'query=up{job="appointment-service"}'

# Check time range in dashboard
# Verify query syntax in dashboard panels
```

#### Grafana Login Issues
```bash
# Problem: Cannot login to Grafana
# Get admin password
kubectl get secret prometheus-grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 --decode

# Reset admin password
kubectl patch secret prometheus-grafana -n monitoring \
  -p '{"data":{"admin-password":"'$(echo -n "newpassword" | base64)'"}}'

# Restart Grafana pod
kubectl delete pod -l app.kubernetes.io/name=grafana -n monitoring
```

### CloudWatch Issues

#### Missing Logs
```bash
# Problem: Application logs not appearing in CloudWatch
# Check FluentBit pods
kubectl get pods -n amazon-cloudwatch

# Check FluentBit logs
kubectl logs daemonset/fluent-bit -n amazon-cloudwatch

# Verify log group exists
aws logs describe-log-groups --log-group-name-prefix "/aws/containerinsights"

# Check IAM permissions for CloudWatch
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::ACCOUNT:role/NodeInstanceRole \
  --action-names logs:CreateLogStream,logs:PutLogEvents \
  --resource-arns "*"
```

## CI/CD Pipeline Issues

### GitHub Actions Problems

#### Workflow Not Triggering
```bash
# Problem: GitHub Actions workflow not running
# Check workflow file syntax
yamllint .github/workflows/terraform.yml

# Verify trigger conditions
# Check if paths filter is too restrictive
# Ensure branch protection rules aren't blocking

# Check workflow runs in GitHub UI
# Look for syntax errors in workflow file
```

#### Authentication Failures
```bash
# Problem: AWS authentication failing in GitHub Actions
# Verify GitHub secrets are set correctly
# Check AWS credentials format
# Ensure IAM user has required permissions

# Test AWS CLI access locally with same credentials
aws sts get-caller-identity

# Check CloudTrail for authentication attempts
aws logs filter-log-events \
  --log-group-name CloudTrail/APIGateway \
  --filter-pattern "ERROR"
```

#### Docker Build Failures
```bash
# Problem: Docker build failing in CI/CD
# Check Dockerfile syntax
docker build -f docker/appointment-service/Dockerfile .

# Verify base image availability
docker pull python:3.11-slim

# Check for missing files
ls -la app/

# Review build logs for specific errors
```

### Terraform in CI/CD Issues

#### Plan/Apply Failures
```bash
# Problem: Terraform plan/apply failing in CI/CD
# Check Terraform version compatibility
terraform version

# Verify backend configuration
cat terraform/environments/dev/main.tf | grep backend

# Check state file permissions
aws s3 ls s3://devops-challenge-terraform-state-dev/

# Review Terraform logs for specific errors
export TF_LOG=DEBUG
terraform plan
```

## Security Issues

### RBAC Problems

#### Permission Denied Errors
```bash
# Problem: kubectl commands failing with permission errors
# Check current context and user
kubectl config current-context
kubectl config view

# Check user permissions
kubectl auth can-i get pods --namespace microservices

# List available permissions
kubectl auth can-i --list --namespace microservices

# Check role bindings
kubectl get rolebindings -n microservices
kubectl describe rolebinding appointment-service-binding -n microservices
```

#### Service Account Issues
```bash
# Problem: Pod cannot access Kubernetes API
# Check service account configuration
kubectl get serviceaccount appointment-service -n microservices

# Verify role binding
kubectl get rolebinding -n microservices | grep appointment-service

# Check pod service account
kubectl describe pod appointment-service-xxx -n microservices | grep "Service Account"

# Test API access from pod
kubectl exec -it appointment-service-xxx -n microservices -- \
  curl -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
  https://kubernetes.default.svc/api/v1/namespaces/microservices/pods
```

### Network Security Issues

#### Security Group Blocking Traffic
```bash
# Problem: Network traffic being blocked
# Check security group rules
aws ec2 describe-security-groups --group-ids sg-12345

# Test connectivity
kubectl exec -it test-pod -n microservices -- telnet appointment-service 5000

# Check VPC flow logs
aws logs filter-log-events \
  --log-group-name VPCFlowLogs \
  --filter-pattern "REJECT"

# Verify route tables
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-12345"
```

## Performance Issues

### Cluster Performance

#### Node Resource Exhaustion
```bash
# Problem: Nodes running out of resources
# Check node resource usage
kubectl top nodes

# Check resource requests vs limits
kubectl describe nodes | grep -A 5 "Allocated resources"

# List pods by resource usage
kubectl top pods --all-namespaces --sort-by=memory

# Check for resource quotas
kubectl describe resourcequota -n microservices
```

#### Slow Pod Startup
```bash
# Problem: Pods taking long time to start
# Check image pull time
kubectl describe pod appointment-service-xxx -n microservices | grep -A 10 Events

# Check resource requests
kubectl describe pod appointment-service-xxx -n microservices | grep -A 5 Requests

# Monitor pod startup phases
kubectl get pods -n microservices -w

# Check node capacity
kubectl describe nodes | grep -A 10 "Capacity\|Allocatable"
```

## Useful Debugging Commands

### General Kubernetes Debugging
```bash
# Get cluster information
kubectl cluster-info
kubectl get componentstatuses

# Check all resources in namespace
kubectl get all -n microservices

# Get events sorted by time
kubectl get events -n microservices --sort-by='.lastTimestamp'

# Describe all pods in namespace
kubectl describe pods -n microservices

# Check resource usage
kubectl top nodes
kubectl top pods -n microservices

# Get pod logs with timestamps
kubectl logs appointment-service-xxx -n microservices --timestamps=true

# Follow logs from multiple pods
kubectl logs -f -l app=appointment-service -n microservices

# Execute commands in pod
kubectl exec -it appointment-service-xxx -n microservices -- /bin/sh

# Port forward for testing
kubectl port-forward svc/appointment-service 8080:80 -n microservices

# Copy files to/from pod
kubectl cp appointment-service-xxx:/app/config.json ./config.json -n microservices
```

### AWS Debugging
```bash
# Check AWS CLI configuration
aws configure list
aws sts get-caller-identity

# List EKS clusters
aws eks list-clusters --region us-west-2

# Describe EKS cluster
aws eks describe-cluster --name devops-challenge-dev-eks --region us-west-2

# Check ECR repositories
aws ecr describe-repositories --region us-west-2

# List EC2 instances
aws ec2 describe-instances --filters "Name=tag:kubernetes.io/cluster/devops-challenge-dev-eks,Values=owned"

# Check CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix "/aws/eks"

# Monitor CloudFormation stacks
aws cloudformation list-stacks --stack-status-filter CREATE_IN_PROGRESS UPDATE_IN_PROGRESS
```

### Network Debugging
```bash
# Test DNS resolution
kubectl run test-dns --image=busybox --rm -it --restart=Never -- nslookup kubernetes.default

# Test service connectivity
kubectl run test-connectivity --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://appointment-service.microservices.svc.cluster.local:5000/health

# Check network policies
kubectl get networkpolicies -n microservices
kubectl describe networkpolicy default-deny-ingress -n microservices

# Test external connectivity
kubectl run test-external --image=busybox --rm -it --restart=Never -- \
  wget -qO- http://httpbin.org/ip
```

## Emergency Procedures

### Cluster Recovery
```bash
# If cluster is unresponsive
# 1. Check cluster status
aws eks describe-cluster --name devops-challenge-dev-eks

# 2. Check node groups
aws eks describe-nodegroup --cluster-name devops-challenge-dev-eks --nodegroup-name general

# 3. Scale node group if needed
aws eks update-nodegroup-config \
  --cluster-name devops-challenge-dev-eks \
  --nodegroup-name general \
  --scaling-config minSize=1,maxSize=5,desiredSize=3

# 4. Restart critical pods
kubectl delete pods -l app=appointment-service -n microservices
```

### Application Recovery
```bash
# If application is down
# 1. Check deployment status
kubectl get deployments -n microservices

# 2. Scale deployment
kubectl scale deployment appointment-service --replicas=3 -n microservices

# 3. Rollback if needed
kubectl rollout undo deployment/appointment-service -n microservices

# 4. Check service endpoints
kubectl get endpoints -n microservices
```

### Data Recovery
```bash
# If persistent data is lost
# 1. Check persistent volumes
kubectl get pv,pvc -n microservices

# 2. Restore from backup (if available)
# 3. Check volume snapshots
aws ec2 describe-snapshots --owner-ids self --filters "Name=tag:kubernetes.io/cluster/devops-challenge-dev-eks,Values=owned"
```

This troubleshooting guide covers the most common issues you might encounter. For issues not covered here, check the application logs, Kubernetes events, and AWS CloudTrail for additional context.