#!/bin/bash

# Script to demonstrate auto-scaling

set -e

echo "================================================"
echo "Auto-Scaling Demonstration"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}==>${NC} $1"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Step 1: Check initial state
print_step "Step 1: Checking initial state..."
echo ""
echo "Current HPA status:"
kubectl get hpa nginx-test-hpa
echo ""
echo "Current pods:"
kubectl get pods -l app=nginx-test
echo ""
read -p "Press Enter to continue..."

# Step 2: Deploy load generator
print_step "Step 2: Deploying load generator..."
kubectl apply -f k8s-manifests/load-generator/load-test.yaml
print_info "Load generator deployed"
echo ""
read -p "Press Enter to continue..."

# Step 3: Watch scaling
print_step "Step 3: Watching auto-scaling (press Ctrl+C to stop)..."
echo ""
print_info "This will take 2-5 minutes to trigger scaling"
echo ""

# Create a temporary script to display metrics
cat << 'EOF' > /tmp/watch-scaling.sh
#!/bin/bash
while true; do
    clear
    echo "================================================"
    echo "Auto-Scaling Monitor"
    echo "================================================"
    echo ""
    echo "Time: $(date '+%H:%M:%S')"
    echo ""
    echo "HPA Status:"
    kubectl get hpa nginx-test-hpa 2>/dev/null || echo "HPA not found"
    echo ""
    echo "Pods:"
    kubectl get pods -l app=nginx-test --no-headers 2>/dev/null | wc -l | xargs echo "Count:"
    kubectl get pods -l app=nginx-test 2>/dev/null || echo "No pods found"
    echo ""
    echo "Pod Resource Usage:"
    kubectl top pods -l app=nginx-test 2>/dev/null || echo "Metrics not available yet"
    echo ""
    echo "Recent Events:"
    kubectl get events --sort-by='.lastTimestamp' | grep -E 'nginx-test|HorizontalPod' | tail -5
    echo ""
    echo "Press Ctrl+C to stop monitoring"
    sleep 5
done
EOF

chmod +x /tmp/watch-scaling.sh
/tmp/watch-scaling.sh

# Step 4: Stop load test (if user presses Ctrl+C)
echo ""
print_step "Step 4: Stopping load test..."
kubectl delete pod load-generator --ignore-not-found=true
print_info "Load generator stopped"
echo ""

# Step 5: Show final state
print_step "Step 5: Final state"
echo ""
echo "HPA Status:"
kubectl get hpa nginx-test-hpa
echo ""
echo "Pods:"
kubectl get pods -l app=nginx-test
echo ""
print_info "Pods will scale down after 5 minutes (stabilization window)"
echo ""

# Cleanup
rm -f /tmp/watch-scaling.sh

echo "================================================"
echo "Auto-Scaling Demonstration Complete!"
echo "================================================"
echo ""
echo "Summary:"
echo "1. Started with 2 pods (minReplicas)"
echo "2. Load test generated high CPU usage"
echo "3. HPA scaled up to handle load"
echo "4. Pods will scale down after load stops (5 min stabilization)"
echo ""
echo "To view scaling logs:"
echo "  kubectl describe hpa nginx-test-hpa"
echo ""
echo "To monitor scale-down:"
echo "  kubectl get hpa -w"
echo ""

