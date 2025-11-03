#!/bin/bash

set -e

echo "================================================"
echo "EKS Cluster Cleanup Script"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Warning
print_warning "This will destroy all resources created by Terraform!"
read -p "Are you sure you want to continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_warning "Cleanup cancelled by user."
    exit 0
fi
echo ""

# Delete Kubernetes resources first (to release load balancers)
print_status "Deleting Kubernetes resources..."

kubectl delete -f blue-green-deployment/ --ignore-not-found=true
kubectl delete -f jenkins/ --ignore-not-found=true
kubectl delete -f k8s-manifests/nginx-test/ --ignore-not-found=true
kubectl delete -f k8s-manifests/load-generator/ --ignore-not-found=true
kubectl delete -f k8s-manifests/autoscaler/cluster-autoscaler.yaml --ignore-not-found=true
kubectl delete -f k8s-manifests/autoscaler/metrics-server.yaml --ignore-not-found=true

echo ""
print_status "Waiting for load balancers to be deleted (60 seconds)..."
sleep 60
echo ""

# Change to terraform directory
cd terraform

# Destroy Terraform resources
print_status "Destroying Terraform infrastructure..."
terraform destroy -auto-approve

cd ..

print_status "Cleanup complete!"

