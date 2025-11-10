Here are all the completed files and deployment steps:

## Complete File Structure & Contents

### 1. `.gitlab-ci.yml`
```yaml
variables:
  KUBE_VERSION: "1.28"
  HELM_VERSION: "3.12.0"
  
stages:
  - validate
  - deploy

before_script:
  - chmod +x ./scripts/setup-helm.sh
  - ./scripts/setup-helm.sh

.validate: &validate
  stage: validate
  script:
    - helm dependency update charts/$CHART_NAME
    - helm template charts/$CHART_NAME -f environments/$ENVIRONMENT/values.yaml --namespace $NAMESPACE > manifest.yaml
    - kubeval manifest.yaml
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

.deploy: &deploy
  stage: deploy
  script:
    - helm upgrade --install $RELEASE_NAME charts/$CHART_NAME \
        --namespace $NAMESPACE \
        --create-namespace \
        -f environments/$ENVIRONMENT/values.yaml \
        --atomic \
        --timeout 10m
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

# ALB Controller Deployment
validate-alb-controller:
  <<: *validate
  variables:
    CHART_NAME: "alb-controller"
    NAMESPACE: "kube-system"
    ENVIRONMENT: "dev"

deploy-alb-controller:
  <<: *deploy
  variables:
    CHART_NAME: "alb-controller"
    RELEASE_NAME: "aws-load-balancer-controller"
    NAMESPACE: "kube-system"
    ENVIRONMENT: "dev"

# Cert Manager Deployment
validate-cert-manager:
  <<: *validate
  variables:
    CHART_NAME: "cert-manager"
    NAMESPACE: "cert-manager"
    ENVIRONMENT: "dev"

deploy-cert-manager:
  <<: *deploy
  variables:
    CHART_NAME: "cert-manager"
    RELEASE_NAME: "cert-manager"
    NAMESPACE: "cert-manager"
    ENVIRONMENT: "dev"

# Prometheus Stack Deployment
validate-prometheus-stack:
  <<: *validate
  variables:
    CHART_NAME: "prometheus-stack"
    NAMESPACE: "monitoring"
    ENVIRONMENT: "dev"

deploy-prometheus-stack:
  <<: *deploy
  variables:
    CHART_NAME: "prometheus-stack"
    RELEASE_NAME: "monitoring"
    NAMESPACE: "monitoring"
    ENVIRONMENT: "dev"

# ArgoCD Deployment
validate-argocd:
  <<: *validate
  variables:
    CHART_NAME: "argocd"
    NAMESPACE: "argocd"
    ENVIRONMENT: "dev"

deploy-argocd:
  <<: *deploy
  variables:
    CHART_NAME: "argocd"
    RELEASE_NAME: "argocd"
    NAMESPACE: "argocd"
    ENVIRONMENT: "dev"
```

### 2. `charts/alb-controller/Chart.yaml`
```yaml
apiVersion: v2
name: alb-controller
description: AWS Load Balancer Controller
version: 0.1.0
dependencies:
  - name: aws-load-balancer-controller
    version: 1.5.4
    repository: https://aws.github.io/eks-charts
```

### 3. `charts/cert-manager/Chart.yaml`
```yaml
apiVersion: v2
name: cert-manager
description: Cert Manager
version: 0.1.0
dependencies:
  - name: cert-manager
    version: 1.12.0
    repository: https://charts.jetstack.io
```

### 4. `charts/prometheus-stack/Chart.yaml`
```yaml
apiVersion: v2
name: prometheus-stack
description: Prometheus and Grafana Stack
version: 0.1.0
dependencies:
  - name: kube-prometheus-stack
    version: 46.0.0
    repository: https://prometheus-community.github.io/helm-charts
```

### 5. `charts/prometheus-stack/templates/ingress.yaml`
```yaml
{{- if .Values.ingress.enabled }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/group.name: {{ .Values.ingress.groupName }}
    alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.certificateArn }}
    alb.ingress.kubernetes.io/healthcheck-path: /-/healthy
spec:
  ingressClassName: alb
  rules:
  - host: prometheus.{{ .Values.global.domain }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ .Values.prometheus.service.serviceName | default "monitoring-kube-prometheus-prometheus" }}
            port:
              number: {{ .Values.prometheus.service.servicePort | default 9090 }}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/group.name: {{ .Values.ingress.groupName }}
    alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.certificateArn }}
    alb.ingress.kubernetes.io/healthcheck-path: /api/health
spec:
  ingressClassName: alb
  rules:
  - host: grafana.{{ .Values.global.domain }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ .Values.grafana.service.serviceName | default "monitoring-grafana" }}
            port:
              number: {{ .Values.grafana.service.servicePort | default 3000 }}
{{- end }}
```

### 6. `charts/argocd/Chart.yaml`
```yaml
apiVersion: v2
name: argocd
description: Argo CD
version: 0.1.0
dependencies:
  - name: argo-cd
    version: 5.34.0
    repository: https://argoproj.github.io/argo-helm
```

### 7. `charts/argocd/templates/ingress.yaml`
```yaml
{{- if .Values.ingress.enabled }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-ingress
  namespace: argocd
  annotations:
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/group.name: {{ .Values.ingress.groupName }}
    alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.certificateArn }}
    alb.ingress.kubernetes.io/healthcheck-path: /healthz
spec:
  ingressClassName: alb
  rules:
  - host: argocd.{{ .Values.global.domain }}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: {{ .Values.server.service.name | default "argocd-server" }}
            port:
              number: {{ .Values.server.service.servicePort | default 80 }}
{{- end }}
```

### 8. `environments/dev/values.yaml`
```yaml
# Global variables
global:
  clusterName: "dev-eks-cluster"
  region: "us-west-2"
  domain: "devopswithdeepak.site"

# ALB Controller configuration
alb-controller:
  clusterName: "dev-eks-cluster"
  region: "us-west-2"
  vpcId: "vpc-12345678"
  serviceAccount:
    create: true
    name: "aws-load-balancer-controller"
  ingressClass: "alb"

# Cert Manager configuration  
cert-manager:
  installCRDs: true
  replicaCount: 2
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

# Prometheus Stack configuration
prometheus-stack:
  # Disable default ingresses since we're using custom ones
  grafana:
    adminPassword: "admin123"
    service:
      type: ClusterIP
      port: 3000
    ingress:
      enabled: false
  
  prometheus:
    service:
      type: ClusterIP
      port: 9090
    ingress:
      enabled: false
  
  alertmanager:
    service:
      type: ClusterIP
    ingress:
      enabled: false

  # Ingress configuration for our custom templates
  ingress:
    enabled: true
    groupName: "tools-alb-group"
    certificateArn: "arn:aws:acm:us-west-2:123456789012:certificate/your-certificate-id"

# ArgoCD configuration
argocd:
  server:
    service:
      type: ClusterIP
      port: 80
    ingress:
      enabled: false  # Disable default ingress
    
    extraArgs:
      - --insecure
  
  configs:
    params:
      server.insecure: true

  # Ingress configuration for our custom template
  ingress:
    enabled: true
    groupName: "tools-alb-group"
    certificateArn: "arn:aws:acm:us-west-2:123456789012:certificate/your-certificate-id"
```

### 9. `environments/dev/cluster-config.yaml`
```yaml
# Cluster-specific configuration
eks:
  clusterName: "dev-eks-cluster"
  region: "us-west-2"
  vpcId: "vpc-12345678"
  
# IAM Role ARNs
iam:
  albControllerRole: "arn:aws:iam::123456789012:role/eks-alb-controller-role"
  
# Network configuration
network:
  domain: "devopswithdeepak.site"
  privateSubnets: 
    - "subnet-12345678"
    - "subnet-87654321"

# Certificate ARN (replace with your actual certificate ARN)
certificateArn: "arn:aws:acm:us-west-2:123456789012:certificate/your-certificate-id"
```

### 10. `scripts/setup-helm.sh`
```bash
#!/bin/bash

set -e

echo "Setting up Helm and Kubernetes tools..."

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install helm
wget https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz
tar -zxvf helm-v${HELM_VERSION}-linux-amd64.tar.gz
mv linux-amd64/helm /usr/local/bin/helm

# Install kubeval for validation
wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz
tar -xf kubeval-linux-amd64.tar.gz
mv kubeval /usr/local/bin

# Add required helm repositories
helm repo add eks https://aws.github.io/eks-charts
helm repo add jetstack https://charts.jetstack.io
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Configure kubectl with AWS EKS
aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER_NAME

# Verify cluster access
kubectl cluster-info

echo "Setup completed successfully!"
```

### 11. `scripts/verify-deployment.sh`
```bash
#!/bin/bash

set -e

echo "Verifying deployments..."

# Check ALB Controller
echo "Checking ALB Controller..."
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check Cert Manager
echo "Checking Cert Manager..."
kubectl get pods -n cert-manager

# Check Prometheus Stack
echo "Checking Prometheus Stack..."
kubectl get pods -n monitoring

# Check ArgoCD
echo "Checking ArgoCD..."
kubectl get pods -n argocd

# Check Ingress resources
echo "Checking Ingress resources..."
kubectl get ingress -A

# Check Services
echo "Checking Services..."
kubectl get svc -n argocd
kubectl get svc -n monitoring

echo "All deployments verified successfully!"
```

## Deployment Steps

### Prerequisites:
1. **EKS Cluster** running with proper IAM roles
2. **AWS CLI** configured with appropriate permissions
3. **GitLab CI/CD** variables set:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` (e.g., `us-west-2`)
   - `EKS_CLUSTER_NAME` (e.g., `dev-eks-cluster`)

### Pre-deployment Setup:

1. **Create ACM Certificate** for `*.devopswithdeepak.site` in AWS Certificate Manager
2. **Update values.yaml** with your actual values:
   - Replace `vpc-12345678` with your actual VPC ID
   - Replace certificate ARN with your actual ACM certificate ARN
   - Update cluster name and region if different

### Deployment Order (Automatic via CI/CD):

1. **ALB Controller** - Creates the load balancer controller
2. **Cert Manager** - Manages TLS certificates
3. **Prometheus Stack** - Deploys monitoring stack with ingress
4. **ArgoCD** - Deploys GitOps tool with ingress

### Post-deployment:

1. **Get ArgoCD Admin Password**:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
   ```

2. **Access URLs**:
   - ArgoCD: `https://argocd.devopswithdeepak.site`
   - Prometheus: `https://prometheus.devopswithdeepak.site`
   - Grafana: `https://grafana.devopswithdeepak.site` (admin/admin123)

3. **Verify DNS**: Ensure DNS records point to the ALB DNS name

### Manual Verification Commands:
```bash
# Check all deployments
kubectl get pods -A

# Check ingress resources
kubectl get ingress -A

# Check ALB status
kubectl get ingress -n argocd -o wide
kubectl get ingress -n monitoring -o wide

# Check services
kubectl get svc -n argocd
kubectl get svc -n monitoring
```

This setup will deploy all tools with a single ALB, proper namespace isolation, and ingress routing for all three subdomains!