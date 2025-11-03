# Quick Start Guide

Get your EKS cluster up and running in 15 minutes!

## Prerequisites

Ensure you have:
- ✅ Terraform installed
- ✅ AWS CLI configured
- ✅ kubectl installed
- ✅ AWS account with appropriate permissions

## Quick Setup

### 1. Clone and Configure

```bash
# Clone the repository
git clone <repository-url>
cd <repository-name>

# Configure Terraform variables
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars if needed
cd ..
```

### 2. Deploy Everything

```bash
# Make script executable
chmod +x scripts/setup.sh

# Run automated setup (takes ~15-20 minutes)
./scripts/setup.sh
```

### 3. Get Your URLs

```bash
# Nginx Test App
kubectl get svc nginx-test -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Jenkins
kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Blue-Green Demo App
kubectl get svc demo-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 4. Test Auto-Scaling

```bash
# Start load test
kubectl apply -f k8s-manifests/load-generator/load-test.yaml

# Watch scaling
kubectl get hpa -w
```

### 5. Test Blue-Green Deployment

```bash
# Manual switch from Blue to Green
kubectl scale deployment demo-app-green --replicas=3
kubectl wait --for=condition=Available deployment/demo-app-green --timeout=300s
kubectl patch service demo-app-service -p '{"spec":{"selector":{"version":"green"}}}'
kubectl scale deployment demo-app-blue --replicas=0
```

## Cleanup

```bash
# Remove all resources
./scripts/cleanup.sh
```

## What's Included

✅ **EKS Cluster**: Production-ready Kubernetes cluster  
✅ **Auto-Scaling**: HPA and Cluster Autoscaler configured  
✅ **Jenkins**: CI/CD pipeline ready  
✅ **Demo Apps**: Nginx and Blue-Green applications  
✅ **Monitoring**: Metrics Server installed  

## Next Steps

1. Read the [detailed documentation](README.md)
2. Try the [auto-scaling demo](docs/AUTO_SCALING.md)
3. Configure [Jenkins pipeline](docs/BLUE_GREEN_DEPLOYMENT.md)
4. Capture screenshots for your submission

## Troubleshooting

If something goes wrong:

```bash
# Check cluster status
kubectl get nodes
kubectl get pods -A

# View logs
kubectl logs -l app=<app-name>

# Check Terraform state
cd terraform
terraform show
```

## Support

- Check the [main README](README.md)
- Review [setup guide](docs/SETUP_GUIDE.md)
- See [troubleshooting section](README.md#troubleshooting)

---

**Estimated Time**: 15-20 minutes  
**Estimated Cost**: ~$200-250/month (destroy when done!)

