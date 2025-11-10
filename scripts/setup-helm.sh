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