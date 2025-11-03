#!/bin/bash

set -e

echo "================================================"
echo "EKS Cluster Setup Script"
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

# Check prerequisites
print_status "Checking prerequisites..."

command -v terraform >/dev/null 2>&1 || { print_error "terraform is required but not installed. Aborting."; exit 1; }
command -v aws >/dev/null 2>&1 || { print_error "AWS CLI is required but not installed. Aborting."; exit 1; }
command -v kubectl >/dev/null 2>&1 || { print_error "kubectl is required but not installed. Aborting."; exit 1; }

print_status "All prerequisites are installed."
echo ""

# Check AWS credentials
print_status "Checking AWS credentials..."
aws sts get-caller-identity >/dev/null 2>&1
if [ $? -eq 0 ]; then
    print_status "AWS credentials are configured."
    aws sts get-caller-identity
else
    print_error "AWS credentials are not configured properly."
    exit 1
fi
echo ""

# Change to terraform directory
cd terraform

# Initialize Terraform
print_status "Initializing Terraform..."
terraform init
echo ""

# Validate Terraform configuration
print_status "Validating Terraform configuration..."
terraform validate
echo ""

# Show Terraform plan
print_status "Generating Terraform plan..."
terraform plan -out=tfplan
echo ""

# Ask for confirmation
read -p "Do you want to apply this Terraform plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    print_warning "Deployment cancelled by user."
    exit 0
fi
echo ""

# Apply Terraform
print_status "Applying Terraform configuration..."
terraform apply tfplan
echo ""

# Get cluster name
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw region)
CLUSTER_AUTOSCALER_ROLE_ARN=$(terraform output -raw cluster_autoscaler_role_arn)

print_status "Cluster created: $CLUSTER_NAME"
print_status "Region: $AWS_REGION"
echo ""

# Configure kubectl
print_status "Configuring kubectl..."
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
echo ""

# Wait for cluster to be ready
print_status "Waiting for cluster to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s
echo ""

# Return to root directory
cd ..

# Deploy Metrics Server
print_status "Deploying Metrics Server..."
kubectl apply -f k8s-manifests/autoscaler/metrics-server.yaml
echo ""

# Wait for Metrics Server
print_status "Waiting for Metrics Server to be ready..."
sleep 30
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=300s
echo ""

# Deploy Cluster Autoscaler
print_status "Deploying Cluster Autoscaler..."
sed "s/\${CLUSTER_NAME}/$CLUSTER_NAME/g; s|\${CLUSTER_AUTOSCALER_ROLE_ARN}|$CLUSTER_AUTOSCALER_ROLE_ARN|g" \
    k8s-manifests/autoscaler/cluster-autoscaler.yaml | kubectl apply -f -
echo ""

# Deploy nginx test application
print_status "Deploying nginx test application..."
kubectl apply -f k8s-manifests/nginx-test/
echo ""

# Wait for nginx deployment
print_status "Waiting for nginx deployment to be ready..."
kubectl wait --for=condition=Available deployment/nginx-test -n default --timeout=300s
echo ""

# Get nginx service endpoint
print_status "Getting nginx service endpoint..."
kubectl get service nginx-test -n default
echo ""

# Deploy Jenkins
print_status "Deploying Jenkins..."
kubectl apply -f jenkins/namespace.yaml
kubectl apply -f jenkins/serviceaccount.yaml
kubectl apply -f jenkins/pvc.yaml
kubectl apply -f jenkins/deployment.yaml
kubectl apply -f jenkins/service.yaml
echo ""

# Wait for Jenkins
print_status "Waiting for Jenkins to be ready (this may take a few minutes)..."
kubectl wait --for=condition=Available deployment/jenkins -n jenkins --timeout=600s
echo ""

# Get Jenkins service endpoint
print_status "Getting Jenkins service endpoint..."
kubectl get service jenkins -n jenkins
echo ""

# Deploy Blue-Green application
print_status "Deploying Blue-Green demo application..."
kubectl apply -f blue-green-deployment/
echo ""

# Wait for blue deployment
print_status "Waiting for blue deployment to be ready..."
kubectl wait --for=condition=Available deployment/demo-app-blue -n default --timeout=300s
echo ""

# Get demo app service endpoint
print_status "Getting demo app service endpoint..."
kubectl get service demo-app-service -n default
echo ""

print_status "================================================"
print_status "Setup Complete!"
print_status "================================================"
echo ""
print_status "Cluster Name: $CLUSTER_NAME"
print_status "Region: $AWS_REGION"
echo ""
print_status "Next Steps:"
echo ""
echo "1. Get nginx test application URL:"
echo "   kubectl get svc nginx-test -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "2. Get Jenkins URL and initial admin password:"
echo "   kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo "   kubectl exec -n jenkins \$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword"
echo ""
echo "3. Get Blue-Green demo app URL:"
echo "   kubectl get svc demo-app-service -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
echo ""
echo "4. To test auto-scaling, deploy the load generator:"
echo "   kubectl apply -f k8s-manifests/load-generator/load-test.yaml"
echo ""
echo "5. Monitor auto-scaling:"
echo "   kubectl get hpa -w"
echo "   kubectl get pods -w"
echo ""

