# Security Guide

## Overview

This document outlines the comprehensive security measures implemented in the DevOps Challenge project, covering infrastructure security, application security, and operational security practices.

## Security Architecture

### Defense in Depth Strategy
```
┌─────────────────────────────────────────────────────────┐
│                    Internet Gateway                      │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                  Public Subnets                        │
│              (Load Balancers Only)                      │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                 Private Subnets                        │
│              (EKS Worker Nodes)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │
│  │ Pod Security│  │   Network   │  │   Service   │    │
│  │   Context   │  │   Policies  │  │   Mesh      │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Infrastructure Security

### Network Security

#### VPC Configuration
- **Private Subnets**: All compute resources in private subnets
- **NAT Gateways**: Controlled outbound internet access
- **Security Groups**: Stateful firewall rules
- **NACLs**: Additional network-level protection
- **VPC Flow Logs**: Network traffic monitoring

#### Security Groups
```hcl
# EKS Cluster Security Group
resource "aws_security_group" "cluster" {
  name_prefix = "${var.cluster_name}-cluster-sg"
  vpc_id      = var.vpc_id

  # HTTPS access from anywhere (API server)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Node Group Security Group
resource "aws_security_group" "node_group" {
  name_prefix = "${var.cluster_name}-node-sg"
  vpc_id      = var.vpc_id

  # Node to node communication
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "-1"
    self      = true
  }

  # Cluster to node communication
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.cluster.id]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}
```

#### Network Policies
```yaml
# Deny all ingress traffic by default
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: microservices
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Allow specific communication between services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-appointment-to-patient
  namespace: microservices
spec:
  podSelector:
    matchLabels:
      app: patient-service
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: appointment-service
    ports:
    - protocol: TCP
      port: 5000
```

### Identity and Access Management

#### IAM Roles and Policies
```hcl
# EKS Cluster Service Role
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# Attach minimal required policies
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}
```

#### RBAC Configuration
```yaml
# Service Account for applications
apiVersion: v1
kind: ServiceAccount
metadata:
  name: appointment-service
  namespace: microservices
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT:role/appointment-service-role
automountServiceAccountToken: false

---
# Role with minimal permissions
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: microservices
  name: appointment-service-role
rules:
- apiGroups: [""]
  resources: ["configmaps", "secrets"]
  verbs: ["get", "list"]

---
# Bind role to service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: appointment-service-binding
  namespace: microservices
subjects:
- kind: ServiceAccount
  name: appointment-service
  namespace: microservices
roleRef:
  kind: Role
  name: appointment-service-role
  apiGroup: rbac.authorization.k8s.io
```

### Encryption

#### Data at Rest
- **EKS Secrets**: KMS encryption for etcd
- **EBS Volumes**: Encrypted storage for persistent data
- **S3 Buckets**: Server-side encryption for Terraform state
- **ECR**: Encrypted container images

#### Data in Transit
- **TLS 1.2+**: All communications encrypted
- **Service Mesh**: mTLS between services (optional)
- **VPC Endpoints**: Private communication with AWS services

```hcl
# KMS Key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption Key"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# EKS Cluster with encryption
resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = var.cluster_service_role_arn

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  # Other configuration...
}
```

## Container Security

### Image Security

#### Base Image Hardening
```dockerfile
# Use minimal base images
FROM python:3.11-slim

# Update packages and remove package manager
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get purge -y --auto-remove gcc

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Set working directory and ownership
WORKDIR /app
RUN chown -R appuser:appuser /app

# Copy application files
COPY --chown=appuser:appuser app/ .

# Switch to non-root user
USER appuser

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

EXPOSE 5000
CMD ["python", "app.py"]
```

#### Image Scanning
```yaml
# GitHub Actions security scanning
- name: Run Trivy vulnerability scanner
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: '${{ env.ECR_REGISTRY }}/${{ env.PROJECT_NAME }}-${{ matrix.service }}:${{ github.sha }}'
    format: 'sarif'
    output: 'trivy-results.sarif'

- name: Upload Trivy scan results to GitHub Security tab
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: 'trivy-results.sarif'
```

### Pod Security

#### Security Contexts
```yaml
# Pod Security Context
apiVersion: apps/v1
kind: Deployment
metadata:
  name: appointment-service
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: appointment-service
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
          capabilities:
            drop:
            - ALL
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
```

#### Pod Security Standards
```yaml
# Pod Security Policy (deprecated, use Pod Security Standards)
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Runtime Security

#### Falco Installation (Optional)
```bash
# Install Falco for runtime security monitoring
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update

helm install falco falcosecurity/falco \
  --namespace falco-system \
  --create-namespace \
  --set falco.grpc.enabled=true \
  --set falco.grpcOutput.enabled=true
```

#### Custom Falco Rules
```yaml
# Custom security rules
- rule: Unexpected Network Connection
  desc: Detect unexpected network connections from containers
  condition: >
    spawned_process and container and
    (proc.name=nc or proc.name=ncat or proc.name=netcat) and
    not proc.pname in (shell_binaries)
  output: >
    Unexpected network connection (user=%user.name command=%proc.cmdline
    container=%container.name image=%container.image.repository)
  priority: WARNING

- rule: Sensitive File Access
  desc: Detect access to sensitive files
  condition: >
    open_read and container and
    (fd.name startswith /etc/passwd or
     fd.name startswith /etc/shadow or
     fd.name startswith /etc/ssh/)
  output: >
    Sensitive file accessed (user=%user.name command=%proc.cmdline
    file=%fd.name container=%container.name)
  priority: WARNING
```

## Application Security

### Secure Coding Practices

#### Input Validation
```python
from flask import Flask, request, jsonify
from marshmallow import Schema, fields, ValidationError
import re

app = Flask(__name__)

class AppointmentSchema(Schema):
    patient_id = fields.Integer(required=True, validate=lambda x: x > 0)
    doctor_id = fields.Integer(required=True, validate=lambda x: x > 0)
    date = fields.DateTime(required=True)
    notes = fields.String(validate=lambda x: len(x) <= 500)

@app.route('/appointments', methods=['POST'])
def create_appointment():
    schema = AppointmentSchema()
    try:
        data = schema.load(request.json)
    except ValidationError as err:
        return jsonify({'errors': err.messages}), 400
    
    # Process validated data
    return jsonify({'status': 'created'}), 201
```

#### Authentication and Authorization
```python
import jwt
from functools import wraps
from flask import request, jsonify, current_app

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'message': 'Token is missing'}), 401
        
        try:
            # Remove 'Bearer ' prefix
            token = token.split(' ')[1]
            data = jwt.decode(token, current_app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user_id = data['user_id']
        except jwt.ExpiredSignatureError:
            return jsonify({'message': 'Token has expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'message': 'Token is invalid'}), 401
        
        return f(current_user_id, *args, **kwargs)
    
    return decorated

@app.route('/appointments', methods=['GET'])
@token_required
def get_appointments(current_user_id):
    # Only return appointments for the authenticated user
    appointments = get_user_appointments(current_user_id)
    return jsonify(appointments)
```

#### Secrets Management
```yaml
# External Secrets Operator
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: microservices
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        secretRef:
          accessKeyID:
            name: aws-credentials
            key: access-key-id
          secretAccessKey:
            name: aws-credentials
            key: secret-access-key

---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secrets
  namespace: microservices
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: app-secrets
    creationPolicy: Owner
  data:
  - secretKey: database-password
    remoteRef:
      key: prod/database
      property: password
```

### API Security

#### Rate Limiting
```python
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address

limiter = Limiter(
    app,
    key_func=get_remote_address,
    default_limits=["200 per day", "50 per hour"]
)

@app.route('/api/appointments')
@limiter.limit("10 per minute")
def get_appointments():
    return jsonify(appointments)
```

#### CORS Configuration
```python
from flask_cors import CORS

# Configure CORS securely
CORS(app, 
     origins=['https://yourdomain.com'],
     methods=['GET', 'POST', 'PUT', 'DELETE'],
     allow_headers=['Content-Type', 'Authorization'])
```

## Security Scanning and Compliance

### Infrastructure Scanning

#### Checkov Integration
```yaml
# GitHub Actions Checkov scan
- name: Run Checkov
  run: |
    pip install checkov
    checkov -d terraform/ --framework terraform \
      --output cli --output sarif --output-file-path console,checkov-results.sarif \
      --check CKV_AWS_58,CKV_AWS_79,CKV_AWS_23 \
      --soft-fail

- name: Upload Checkov results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: checkov-results.sarif
```

#### Custom Security Policies
```rego
# OPA Gatekeeper policy
package kubernetes.admission

deny[msg] {
    input.request.kind.kind == "Pod"
    input.request.object.spec.securityContext.runAsRoot == true
    msg := "Pods must not run as root"
}

deny[msg] {
    input.request.kind.kind == "Pod"
    container := input.request.object.spec.containers[_]
    not container.securityContext.readOnlyRootFilesystem
    msg := "Containers must have read-only root filesystem"
}
```

### Vulnerability Management

#### Automated Scanning Pipeline
```yaml
# Vulnerability scanning workflow
name: Security Scan
on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  push:
    branches: [main]

jobs:
  security-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Run Trivy filesystem scan
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'fs'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-fs-results.sarif'
    
    - name: Run Trivy config scan
      uses: aquasecurity/trivy-action@master
      with:
        scan-type: 'config'
        scan-ref: '.'
        format: 'sarif'
        output: 'trivy-config-results.sarif'
    
    - name: Upload results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-fs-results.sarif'
```

## Incident Response

### Security Monitoring

#### CloudWatch Security Alarms
```bash
# Create security-related alarms
aws cloudwatch put-metric-alarm \
  --alarm-name "UnauthorizedAPIAccess" \
  --alarm-description "Detect unauthorized API access attempts" \
  --metric-name UnauthorizedAPICalls \
  --namespace AWS/EKS \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

#### Security Event Logging
```python
import logging
import json
from datetime import datetime

security_logger = logging.getLogger('security')

def log_security_event(event_type, user_id, details):
    security_event = {
        'timestamp': datetime.utcnow().isoformat(),
        'event_type': event_type,
        'user_id': user_id,
        'details': details,
        'severity': 'HIGH' if event_type in ['unauthorized_access', 'privilege_escalation'] else 'MEDIUM'
    }
    security_logger.warning(json.dumps(security_event))

# Usage
@app.route('/admin/users')
@token_required
def admin_users(current_user_id):
    if not is_admin(current_user_id):
        log_security_event('unauthorized_access', current_user_id, {
            'endpoint': '/admin/users',
            'ip_address': request.remote_addr
        })
        return jsonify({'error': 'Unauthorized'}), 403
    
    return jsonify(get_all_users())
```

### Incident Response Playbook

#### Security Incident Response Steps
1. **Detection**: Automated alerts and monitoring
2. **Assessment**: Determine scope and impact
3. **Containment**: Isolate affected systems
4. **Eradication**: Remove threats and vulnerabilities
5. **Recovery**: Restore normal operations
6. **Lessons Learned**: Post-incident review

#### Automated Response Actions
```yaml
# Kubernetes Network Policy for incident response
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: emergency-isolation
  namespace: microservices
spec:
  podSelector:
    matchLabels:
      app: compromised-service
  policyTypes:
  - Ingress
  - Egress
  # No ingress or egress rules = deny all traffic
```

## Compliance and Governance

### Security Standards Compliance

#### CIS Kubernetes Benchmark
- Regular compliance scanning with kube-bench
- Automated remediation where possible
- Documentation of exceptions and compensating controls

#### SOC 2 Type II Considerations
- Access logging and monitoring
- Data encryption requirements
- Change management processes
- Incident response procedures

### Audit Logging
```yaml
# EKS Audit Logging Configuration
apiVersion: v1
kind: ConfigMap
metadata:
  name: audit-policy
  namespace: kube-system
data:
  audit-policy.yaml: |
    apiVersion: audit.k8s.io/v1
    kind: Policy
    rules:
    - level: Metadata
      namespaces: ["microservices"]
      verbs: ["create", "update", "patch", "delete"]
      resources:
      - group: ""
        resources: ["secrets", "configmaps"]
    - level: RequestResponse
      namespaces: ["microservices"]
      verbs: ["create", "update", "patch", "delete"]
      resources:
      - group: "apps"
        resources: ["deployments", "replicasets"]
```

## Security Best Practices

### Development Security
1. **Secure by Default**: Security controls enabled by default
2. **Least Privilege**: Minimal required permissions
3. **Defense in Depth**: Multiple layers of security
4. **Regular Updates**: Keep dependencies and base images updated
5. **Security Testing**: Automated security testing in CI/CD

### Operational Security
1. **Regular Audits**: Periodic security assessments
2. **Patch Management**: Timely application of security patches
3. **Access Reviews**: Regular review of user access and permissions
4. **Backup and Recovery**: Secure backup and tested recovery procedures
5. **Incident Response**: Prepared incident response procedures

### Monitoring and Alerting
1. **Security Metrics**: Track security-related metrics
2. **Anomaly Detection**: Detect unusual patterns and behaviors
3. **Real-time Alerts**: Immediate notification of security events
4. **Log Analysis**: Regular analysis of security logs
5. **Threat Intelligence**: Stay informed about emerging threats

## Security Checklist

### Pre-Deployment
- [ ] Security scanning completed
- [ ] Vulnerability assessment passed
- [ ] Access controls configured
- [ ] Encryption enabled
- [ ] Monitoring configured

### Post-Deployment
- [ ] Security monitoring active
- [ ] Incident response procedures tested
- [ ] Access logs reviewed
- [ ] Compliance requirements met
- [ ] Security documentation updated

### Ongoing
- [ ] Regular security assessments
- [ ] Patch management process
- [ ] Security training for team
- [ ] Incident response drills
- [ ] Compliance audits

This comprehensive security guide ensures that the DevOps Challenge project maintains a strong security posture throughout its lifecycle, from development to production operations.