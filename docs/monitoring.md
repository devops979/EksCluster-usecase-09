# Monitoring and Observability Guide

## Overview

This guide covers the comprehensive monitoring and observability setup for the DevOps Challenge microservices application running on Amazon EKS.

## Monitoring Stack

### Core Components
- **AWS CloudWatch**: Native AWS monitoring and logging
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Jaeger**: Distributed tracing (optional)
- **FluentBit**: Log aggregation and forwarding

### Architecture
```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│ Application │───▶│ Prometheus  │───▶│   Grafana   │
│    Pods     │    │   Server    │    │ Dashboards │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │
       ▼                   ▼
┌─────────────┐    ┌─────────────┐
│ FluentBit   │───▶│ CloudWatch  │
│   Logs      │    │    Logs     │
└─────────────┘    └─────────────┘
```

## CloudWatch Setup

### Container Insights
Container Insights provides cluster-level metrics and logs.

#### Enable Container Insights
```bash
# Enable Container Insights for EKS cluster
aws eks update-cluster-config \
  --region us-west-2 \
  --name devops-challenge-dev-eks \
  --logging '{"enable":["api","audit","authenticator","controllerManager","scheduler"]}'

# Deploy CloudWatch agent
curl https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/quickstart/cwagent-fluentd-quickstart.yaml | sed "s/{{cluster_name}}/devops-challenge-dev-eks/;s/{{region_name}}/us-west-2/" | kubectl apply -f -
```

#### Verify Installation
```bash
# Check CloudWatch agent pods
kubectl get pods -n amazon-cloudwatch

# Check logs
kubectl logs -f daemonset/cloudwatch-agent -n amazon-cloudwatch
```

### Custom Metrics
```bash
# Create custom metric filter
aws logs put-metric-filter \
  --log-group-name "/aws/containerinsights/devops-challenge-dev-eks/application" \
  --filter-name "ErrorCount" \
  --filter-pattern "ERROR" \
  --metric-transformations \
    metricName=ApplicationErrors,metricNamespace=DevOpsChallenge,metricValue=1
```

### CloudWatch Alarms
```bash
# Create alarm for high error rate
aws cloudwatch put-metric-alarm \
  --alarm-name "HighErrorRate" \
  --alarm-description "High error rate in applications" \
  --metric-name ApplicationErrors \
  --namespace DevOpsChallenge \
  --statistic Sum \
  --period 300 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2
```

## Prometheus Setup

### Installation via Helm
```bash
# Add Prometheus Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

### Custom Configuration
```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    retention: 30d
    resources:
      requests:
        memory: 2Gi
        cpu: 1000m
      limits:
        memory: 4Gi
        cpu: 2000m
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          resources:
            requests:
              storage: 50Gi

grafana:
  adminPassword: "admin123"
  persistence:
    enabled: true
    size: 10Gi
  
alertmanager:
  alertmanagerSpec:
    resources:
      requests:
        memory: 256Mi
        cpu: 100m
      limits:
        memory: 512Mi
        cpu: 200m
```

### Application Metrics
Add Prometheus metrics to your applications:

```python
# Python Flask example
from prometheus_client import Counter, Histogram, generate_latest
import time

REQUEST_COUNT = Counter('app_requests_total', 'Total requests', ['method', 'endpoint'])
REQUEST_LATENCY = Histogram('app_request_duration_seconds', 'Request latency')

@app.route('/metrics')
def metrics():
    return generate_latest()

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    REQUEST_COUNT.labels(method=request.method, endpoint=request.endpoint).inc()
    REQUEST_LATENCY.observe(time.time() - request.start_time)
    return response
```

### ServiceMonitor Configuration
```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: microservices-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: appointment-service
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: patient-service-monitor
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: patient-service
  endpoints:
  - port: http
    path: /metrics
    interval: 30s
```

## Grafana Dashboards

### Access Grafana
```bash
# Port forward to access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring

# Get admin password
kubectl get secret prometheus-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 --decode
```

### Import Dashboards
1. **Kubernetes Cluster Monitoring**: Dashboard ID 7249
2. **Node Exporter Full**: Dashboard ID 1860
3. **Kubernetes Pod Monitoring**: Dashboard ID 6417

### Custom Dashboard for Microservices
```json
{
  "dashboard": {
    "title": "Microservices Overview",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(app_requests_total[5m])",
            "legendFormat": "{{service}} - {{method}}"
          }
        ]
      },
      {
        "title": "Response Time",
        "type": "graph", 
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(app_request_duration_seconds_bucket[5m]))",
            "legendFormat": "95th percentile"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "singlestat",
        "targets": [
          {
            "expr": "rate(app_requests_total{status=~\"5..\"}[5m]) / rate(app_requests_total[5m]) * 100",
            "legendFormat": "Error Rate %"
          }
        ]
      }
    ]
  }
}
```

## Logging

### FluentBit Configuration
```yaml
# fluentbit-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: fluent-bit-config
  namespace: amazon-cloudwatch
data:
  fluent-bit.conf: |
    [SERVICE]
        Flush         1
        Log_Level     info
        Daemon        off
        Parsers_File  parsers.conf
        HTTP_Server   On
        HTTP_Listen   0.0.0.0
        HTTP_Port     2020

    [INPUT]
        Name              tail
        Tag               application.*
        Path              /var/log/containers/*microservices*.log
        Parser            docker
        DB                /var/log/flb_kube.db
        Mem_Buf_Limit     50MB
        Skip_Long_Lines   On
        Refresh_Interval  10

    [FILTER]
        Name                kubernetes
        Match               application.*
        Kube_URL            https://kubernetes.default.svc:443
        Kube_CA_File        /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        Kube_Token_File     /var/run/secrets/kubernetes.io/serviceaccount/token
        Merge_Log           On
        K8S-Logging.Parser  On
        K8S-Logging.Exclude Off

    [OUTPUT]
        Name                cloudwatch_logs
        Match               application.*
        region              us-west-2
        log_group_name      /aws/containerinsights/devops-challenge-dev-eks/application
        log_stream_prefix   ${hostname}-
        auto_create_group   true
```

### Structured Logging
```python
# Python structured logging example
import json
import logging
from datetime import datetime

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': record.levelname,
            'message': record.getMessage(),
            'service': 'appointment-service',
            'version': '1.0.0'
        }
        if hasattr(record, 'user_id'):
            log_entry['user_id'] = record.user_id
        if hasattr(record, 'request_id'):
            log_entry['request_id'] = record.request_id
        return json.dumps(log_entry)

# Configure logger
logger = logging.getLogger(__name__)
handler = logging.StreamHandler()
handler.setFormatter(JSONFormatter())
logger.addHandler(handler)
logger.setLevel(logging.INFO)
```

## Alerting

### Prometheus Alerting Rules
```yaml
# alerts.yaml
groups:
- name: microservices.rules
  rules:
  - alert: HighErrorRate
    expr: rate(app_requests_total{status=~"5.."}[5m]) / rate(app_requests_total[5m]) > 0.1
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value | humanizePercentage }} for {{ $labels.service }}"

  - alert: HighLatency
    expr: histogram_quantile(0.95, rate(app_request_duration_seconds_bucket[5m])) > 1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High latency detected"
      description: "95th percentile latency is {{ $value }}s for {{ $labels.service }}"

  - alert: PodCrashLooping
    expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Pod is crash looping"
      description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is crash looping"

  - alert: NodeNotReady
    expr: kube_node_status_condition{condition="Ready",status="true"} == 0
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Node is not ready"
      description: "Node {{ $labels.node }} is not ready"
```

### Alertmanager Configuration
```yaml
# alertmanager.yaml
global:
  smtp_smarthost: 'localhost:587'
  smtp_from: 'alerts@devops-challenge.com'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'

receivers:
- name: 'web.hook'
  slack_configs:
  - api_url: 'YOUR_SLACK_WEBHOOK_URL'
    channel: '#alerts'
    title: 'DevOps Challenge Alert'
    text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'

- name: 'email'
  email_configs:
  - to: 'devops-team@company.com'
    subject: 'DevOps Challenge Alert'
    body: |
      {{ range .Alerts }}
      Alert: {{ .Annotations.summary }}
      Description: {{ .Annotations.description }}
      {{ end }}
```

## Distributed Tracing (Optional)

### Jaeger Installation
```bash
# Install Jaeger operator
kubectl create namespace observability
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.41.0/jaeger-operator.yaml -n observability

# Deploy Jaeger instance
kubectl apply -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  strategy: production
  storage:
    type: elasticsearch
    elasticsearch:
      nodeCount: 3
      resources:
        requests:
          memory: 2Gi
          cpu: 1000m
        limits:
          memory: 4Gi
          cpu: 2000m
EOF
```

### Application Tracing
```python
# Python OpenTelemetry example
from opentelemetry import trace
from opentelemetry.exporter.jaeger.thrift import JaegerExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor

# Configure tracing
trace.set_tracer_provider(TracerProvider())
tracer = trace.get_tracer(__name__)

jaeger_exporter = JaegerExporter(
    agent_host_name="jaeger-agent.observability.svc.cluster.local",
    agent_port=6831,
)

span_processor = BatchSpanProcessor(jaeger_exporter)
trace.get_tracer_provider().add_span_processor(span_processor)

# Use in application
@app.route('/api/appointments')
def get_appointments():
    with tracer.start_as_current_span("get_appointments") as span:
        span.set_attribute("user.id", request.headers.get("user-id"))
        # Your application logic here
        return jsonify(appointments)
```

## Performance Monitoring

### Key Metrics to Monitor

#### Infrastructure Metrics
- **CPU Utilization**: Node and pod level
- **Memory Usage**: Available memory, memory pressure
- **Disk I/O**: Read/write operations, disk space
- **Network**: Bandwidth utilization, packet loss

#### Application Metrics
- **Request Rate**: Requests per second
- **Response Time**: Average, 95th, 99th percentiles
- **Error Rate**: 4xx and 5xx responses
- **Throughput**: Successful requests per second

#### Business Metrics
- **User Sessions**: Active users, session duration
- **Feature Usage**: API endpoint usage
- **Conversion Rates**: Success rates for business operations

### SLI/SLO Definition
```yaml
# Service Level Indicators and Objectives
slis:
  availability:
    description: "Percentage of successful requests"
    query: "rate(app_requests_total{status!~'5..'}[5m]) / rate(app_requests_total[5m])"
    
  latency:
    description: "95th percentile response time"
    query: "histogram_quantile(0.95, rate(app_request_duration_seconds_bucket[5m]))"

slos:
  availability: 99.9%  # 99.9% of requests should be successful
  latency: 500ms       # 95% of requests should complete within 500ms
```

## Troubleshooting

### Common Monitoring Issues

#### 1. Prometheus Not Scraping Targets
```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Check Prometheus targets
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Visit http://localhost:9090/targets

# Check service labels
kubectl get svc -n microservices --show-labels
```

#### 2. Grafana Dashboard Not Loading Data
```bash
# Check Prometheus data source
# Verify query syntax in Grafana
# Check time range settings

# Test Prometheus query directly
curl -G 'http://prometheus:9090/api/v1/query' \
  --data-urlencode 'query=up{job="appointment-service"}'
```

#### 3. Missing Logs in CloudWatch
```bash
# Check FluentBit pods
kubectl get pods -n amazon-cloudwatch

# Check FluentBit logs
kubectl logs daemonset/fluent-bit -n amazon-cloudwatch

# Verify IAM permissions for CloudWatch
aws iam get-role-policy --role-name NodeInstanceRole --policy-name CloudWatchAgentServerPolicy
```

### Useful Commands
```bash
# Check resource usage
kubectl top nodes
kubectl top pods -n microservices

# View metrics endpoint
kubectl port-forward svc/appointment-service 8080:80 -n microservices
curl http://localhost:8080/metrics

# Check Prometheus configuration
kubectl get prometheus -n monitoring -o yaml

# View alerting rules
kubectl get prometheusrule -n monitoring

# Check alert status
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# Visit http://localhost:9090/alerts
```

## Best Practices

### Monitoring Strategy
1. **Start with the Four Golden Signals**: Latency, traffic, errors, saturation
2. **Implement SLIs/SLOs**: Define what good service looks like
3. **Use Structured Logging**: Make logs searchable and actionable
4. **Monitor Business Metrics**: Not just technical metrics
5. **Set Up Proper Alerting**: Alert on symptoms, not causes

### Performance Optimization
1. **Right-size Resources**: Monitor actual usage vs. requests/limits
2. **Optimize Queries**: Use efficient Prometheus queries
3. **Retention Policies**: Balance storage costs with data needs
4. **Sampling**: Use sampling for high-volume tracing

### Security Considerations
1. **Secure Metrics Endpoints**: Use authentication for sensitive metrics
2. **Network Policies**: Restrict access to monitoring components
3. **Data Retention**: Follow compliance requirements for log retention
4. **Access Control**: Implement RBAC for monitoring tools

## Next Steps

1. **Implement Custom Dashboards**: Create service-specific dashboards
2. **Set Up Alerting**: Configure alerts for critical metrics
3. **Add Distributed Tracing**: Implement end-to-end request tracing
4. **Performance Testing**: Use monitoring during load testing
5. **Capacity Planning**: Use historical data for resource planning
6. **Incident Response**: Integrate monitoring with incident management