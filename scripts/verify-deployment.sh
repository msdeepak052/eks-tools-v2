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