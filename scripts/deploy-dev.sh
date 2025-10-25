#!/bin/bash
# Deploy Gridata to development environment

set -e

ENV="dev"
AWS_REGION="${AWS_REGION:-us-east-1}"

echo "🏔️  Deploying Gridata to $ENV environment..."

# Check prerequisites
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform is required but not installed. Aborting." >&2; exit 1; }
command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed. Aborting." >&2; exit 1; }
command -v helm >/dev/null 2>&1 || { echo "❌ Helm is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"

# Navigate to environment directory
cd terraform/envs/$ENV

# Initialize Terraform
echo "🔧 Initializing Terraform..."
terraform init

# Validate configuration
echo "✔️  Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "📋 Planning infrastructure changes..."
terraform plan -out=tfplan

# Prompt for confirmation
read -p "Do you want to apply these changes? (yes/no) " -n 3 -r
echo
if [[ ! $REPLY =~ ^yes$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Apply infrastructure
echo "🚀 Applying infrastructure changes..."
terraform apply tfplan

# Get cluster credentials
echo "🔐 Configuring kubectl..."
CLUSTER_NAME=$(terraform output -raw cluster_name)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Wait for cluster to be ready
echo "⏳ Waiting for cluster to be ready..."
kubectl wait --for=condition=ready nodes --all --timeout=300s

# Verify deployments
echo "✅ Verifying deployments..."
kubectl get pods -A

# Get service URLs
echo ""
echo "🎉 Deployment complete!"
echo ""
echo "📍 Service URLs:"
terraform output -json | jq -r 'to_entries[] | "\(.key): \(.value.value)"'

echo ""
echo "🔧 Access cluster:"
echo "  kubectl get pods -n airflow"
echo "  kubectl get pods -n spark-operator"
echo "  kubectl get pods -n minio"
echo ""
