#!/bin/bash

# Script to demonstrate blue-green deployment

set -e

echo "================================================"
echo "Blue-Green Deployment Demonstration"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_step() {
    echo -e "${CYAN}==>${NC} $1"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Get service URL
DEMO_URL=$(kubectl get svc demo-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ -z "$DEMO_URL" ]; then
    echo "ERROR: Service URL not available yet"
    echo "Please wait for LoadBalancer to be provisioned"
    exit 1
fi

print_info "Demo Application URL: http://$DEMO_URL"
echo ""

# Function to check current version
check_version() {
    echo "Checking current version..."
    ACTIVE=$(kubectl get svc demo-app-service -o jsonpath='{.spec.selector.version}')
    echo "Active Version: $ACTIVE"
    
    if [ "$ACTIVE" == "blue" ]; then
        INACTIVE="green"
    else
        INACTIVE="blue"
    fi
    echo "Inactive Version: $INACTIVE"
}

# Function to test endpoint
test_endpoint() {
    echo ""
    echo "Testing endpoint (you should see $1 in the response)..."
    curl -s http://$DEMO_URL | grep -i "$1" && echo "✓ Verified" || echo "✗ Check failed"
}

# Step 1: Check initial state
print_step "Step 1: Checking initial state"
echo ""
check_version
echo ""
echo "Deployments:"
kubectl get deployments -l app=demo-app
echo ""
test_endpoint "$ACTIVE"
echo ""
read -p "Press Enter to continue..."

# Step 2: Scale up inactive deployment
print_step "Step 2: Scaling up $INACTIVE deployment"
echo ""
kubectl scale deployment demo-app-$INACTIVE --replicas=3
print_info "Waiting for $INACTIVE deployment to be ready..."
kubectl wait --for=condition=Available deployment/demo-app-$INACTIVE --timeout=300s
echo ""
echo "Both deployments are now running:"
kubectl get deployments -l app=demo-app
echo ""
read -p "Press Enter to continue..."

# Step 3: Run health checks
print_step "Step 3: Running health checks on $INACTIVE deployment"
echo ""
echo "Checking pod status..."
kubectl get pods -l app=demo-app,version=$INACTIVE
echo ""

print_info "Testing $INACTIVE pods..."
for pod in $(kubectl get pods -l app=demo-app,version=$INACTIVE -o jsonpath='{.items[*].metadata.name}'); do
    echo "Testing $pod..."
    kubectl exec $pod -- wget -q -O- http://localhost:80 > /dev/null && echo "  ✓ $pod is healthy" || echo "  ✗ $pod failed"
done
echo ""
read -p "Press Enter to continue..."

# Step 4: Switch traffic
print_step "Step 4: Switching traffic to $INACTIVE deployment"
echo ""
print_info "Current service is pointing to: $ACTIVE"
echo ""
echo "Updating service selector to: $INACTIVE"
kubectl patch service demo-app-service -p "{\"spec\":{\"selector\":{\"version\":\"$INACTIVE\"}}}"
echo ""
print_info "Traffic switched!"
sleep 2
echo ""
test_endpoint "$INACTIVE"
echo ""
echo "You can now open http://$DEMO_URL in your browser"
echo "You should see the $INACTIVE version"
echo ""
read -p "Press Enter to continue..."

# Step 5: Verification
print_step "Step 5: Verification period (30 seconds)"
echo ""
print_info "Monitoring new deployment..."
for i in {30..1}; do
    echo -ne "Time remaining: $i seconds\r"
    sleep 1
done
echo ""
echo ""

# Check if deployment is still healthy
READY=$(kubectl get deployment demo-app-$INACTIVE -o jsonpath='{.status.readyReplicas}')
echo "Ready pods: $READY"
if [ "$READY" == "3" ]; then
    print_info "Deployment is stable"
else
    echo "WARNING: Deployment may have issues"
fi
echo ""
read -p "Press Enter to continue..."

# Step 6: Scale down old deployment
print_step "Step 6: Scaling down $ACTIVE deployment"
echo ""
kubectl scale deployment demo-app-$ACTIVE --replicas=0
print_info "$ACTIVE deployment scaled down"
echo ""
echo "Final state:"
kubectl get deployments -l app=demo-app
echo ""

# Step 7: Summary
print_step "Deployment Complete!"
echo ""
echo "================================================"
echo "Blue-Green Deployment Summary"
echo "================================================"
echo ""
echo "Active Deployment: demo-app-$INACTIVE"
echo "Standby Deployment: demo-app-$ACTIVE"
echo ""
echo "Application URL: http://$DEMO_URL"
echo ""
echo "Current Service Configuration:"
kubectl get svc demo-app-service -o yaml | grep -A 3 selector
echo ""
echo "To switch back to $ACTIVE:"
echo "  kubectl scale deployment demo-app-$ACTIVE --replicas=3"
echo "  kubectl patch service demo-app-service -p '{\"spec\":{\"selector\":{\"version\":\"$ACTIVE\"}}}'"
echo "  kubectl scale deployment demo-app-$INACTIVE --replicas=0"
echo ""
print_info "Deployment completed successfully!"

