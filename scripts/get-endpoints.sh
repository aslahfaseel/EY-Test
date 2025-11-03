#!/bin/bash

# Script to get all service endpoints

set -e

echo "================================================"
echo "Service Endpoints"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to get LoadBalancer URL
get_lb_url() {
    local service=$1
    local namespace=$2
    
    echo -n "Waiting for LoadBalancer..."
    for i in {1..60}; do
        URL=$(kubectl get svc $service -n $namespace -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ ! -z "$URL" ]; then
            echo " Ready!"
            echo "$URL"
            return 0
        fi
        echo -n "."
        sleep 2
    done
    echo " Timed out"
    echo "Pending..."
    return 1
}

echo -e "${BLUE}Nginx Test Application:${NC}"
echo "Service: nginx-test"
NGINX_URL=$(get_lb_url "nginx-test" "default")
if [ "$NGINX_URL" != "Pending..." ]; then
    echo -e "${GREEN}URL: http://$NGINX_URL${NC}"
    echo "Test: curl http://$NGINX_URL"
else
    echo "Status: $NGINX_URL"
fi
echo ""

echo -e "${BLUE}Blue-Green Demo Application:${NC}"
echo "Service: demo-app-service"
DEMO_URL=$(get_lb_url "demo-app-service" "default")
if [ "$DEMO_URL" != "Pending..." ]; then
    echo -e "${GREEN}URL: http://$DEMO_URL${NC}"
    echo "Test: curl http://$DEMO_URL"
    
    # Check which version is active
    ACTIVE_VERSION=$(kubectl get svc demo-app-service -o jsonpath='{.spec.selector.version}')
    echo "Active Version: $ACTIVE_VERSION"
else
    echo "Status: $DEMO_URL"
fi
echo ""

echo -e "${BLUE}Jenkins:${NC}"
echo "Service: jenkins"
JENKINS_URL=$(get_lb_url "jenkins" "jenkins")
if [ "$JENKINS_URL" != "Pending..." ]; then
    echo -e "${GREEN}URL: http://$JENKINS_URL:8080${NC}"
    echo ""
    echo "Initial Admin Password:"
    JENKINS_POD=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ ! -z "$JENKINS_POD" ]; then
        kubectl exec -n jenkins $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword 2>/dev/null || echo "Jenkins pod not ready yet"
    else
        echo "Jenkins pod not found"
    fi
else
    echo "Status: $JENKINS_URL"
fi
echo ""

echo "================================================"
echo "Cluster Information"
echo "================================================"
echo ""

cd terraform 2>/dev/null && {
    CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || echo "N/A")
    REGION=$(terraform output -raw region 2>/dev/null || echo "N/A")
    
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Region: $REGION"
    cd ..
} || {
    echo "Terraform outputs not available"
}

echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "================================================"
echo "Quick Commands"
echo "================================================"
echo ""
echo "# Watch HPA:"
echo "kubectl get hpa -w"
echo ""
echo "# Watch Pods:"
echo "kubectl get pods -w"
echo ""
echo "# Generate Load:"
echo "kubectl apply -f k8s-manifests/load-generator/load-test.yaml"
echo ""
echo "# Blue-Green Switch to Green:"
echo "kubectl scale deployment demo-app-green --replicas=3"
echo "kubectl patch service demo-app-service -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'"
echo "kubectl scale deployment demo-app-blue --replicas=0"
echo ""

