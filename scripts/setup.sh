#!/bin/bash
set -euo pipefail

# Set environment variables
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
ENV="production"

echo "🔧 Initializing Terraform..."
cd terraform
terraform init
terraform apply -auto-approve

echo "🔧 Configuring kubectl context..."
gcloud container clusters get-credentials "${ENV}-gke" --region "$REGION"

echo "📦 Applying Kubernetes namespace..."
kubectl apply -f ../kubernetes/base/namespace.yaml

echo "✅ Setup complete."
