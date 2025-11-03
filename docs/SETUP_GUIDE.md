# Detailed Setup Guide

This guide provides step-by-step instructions for setting up the EKS cluster from scratch.

## Prerequisites Verification

### 1. Install Terraform

#### Windows
```powershell
# Using Chocolatey
choco install terraform

# Or download from https://www.terraform.io/downloads.html
```

#### macOS
```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

#### Linux
```bash
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

Verify:
```bash
terraform --version
```

### 2. Install AWS CLI

#### Windows
Download and install from: https://aws.amazon.com/cli/

#### macOS
```bash
brew install awscli
```

#### Linux
```bash
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Verify:
```bash
aws --version
```

### 3. Install kubectl

#### Windows
```powershell
# Using Chocolatey
choco install kubernetes-cli

# Or using AWS CLI
aws s3 cp s3://amazon-eks/1.28.3/2023-11-14/bin/windows/amd64/kubectl.exe .
```

#### macOS
```bash
brew install kubectl
```

#### Linux
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/
```

Verify:
```bash
kubectl version --client
```

## AWS Account Setup

### 1. Create IAM User

1. Log in to AWS Console
2. Navigate to IAM → Users
3. Click "Add users"
4. Set user name (e.g., "terraform-user")
5. Select "Access key - Programmatic access"
6. Attach policies:
   - AmazonEC2FullAccess
   - AmazonEKSClusterPolicy
   - AmazonEKSWorkerNodePolicy
   - AmazonVPCFullAccess
   - IAMFullAccess
   - AmazonEKS_CNI_Policy
7. Download credentials

### 2. Configure AWS Credentials

```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region (e.g., us-east-1)
- Default output format (json)

Verify:
```bash
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDXXXXXXXXXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-user"
}
```

## Step-by-Step Deployment

### Step 1: Clone Repository

```bash
git clone <your-repository-url>
cd <repository-name>
```

### Step 2: Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
# AWS Configuration
aws_region = "us-east-1"
environment = "dev"

# EKS Cluster Configuration
cluster_name    = "my-eks-cluster"
cluster_version = "1.28"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"

# Node Group Configuration
node_desired_size    = 2
node_min_size        = 2
node_max_size        = 5
node_instance_types  = ["t3.medium"]
node_disk_size       = 20
```

### Step 3: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 4: Validate Configuration

```bash
terraform validate
```

Expected output:
```
Success! The configuration is valid.
```

### Step 5: Plan Infrastructure

```bash
terraform plan -out=tfplan
```

Review the plan carefully. You should see:
- VPC and networking components
- EKS cluster
- Node groups
- IAM roles and policies
- Security groups

### Step 6: Apply Infrastructure

```bash
terraform apply tfplan
```

This will take approximately 15-20 minutes. You'll see progress as resources are created.

### Step 7: Save Terraform Outputs

```bash
# Save outputs for later use
terraform output -raw cluster_name > cluster_name.txt
terraform output -raw region > region.txt
terraform output -raw cluster_autoscaler_role_arn > autoscaler_role.txt
```

### Step 8: Configure kubectl

```bash
CLUSTER_NAME=$(terraform output -raw cluster_name)
AWS_REGION=$(terraform output -raw region)

aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
```

Expected output:
```
Added new context arn:aws:eks:us-east-1:123456789012:cluster/my-eks-cluster to ~/.kube/config
```

### Step 9: Verify Cluster

```bash
# Check nodes
kubectl get nodes

# Expected output:
NAME                             STATUS   ROLES    AGE   VERSION
ip-10-0-10-123.ec2.internal     Ready    <none>   5m    v1.28.3-eks-...
ip-10-0-11-124.ec2.internal     Ready    <none>   5m    v1.28.3-eks-...

# Check system pods
kubectl get pods -n kube-system
```

### Step 10: Deploy Metrics Server

```bash
cd ..
kubectl apply -f k8s-manifests/autoscaler/metrics-server.yaml
```

Wait for metrics server:
```bash
kubectl wait --for=condition=Available deployment/metrics-server -n kube-system --timeout=300s
```

Verify:
```bash
kubectl top nodes
```

### Step 11: Deploy Cluster Autoscaler

```bash
cd terraform
CLUSTER_NAME=$(terraform output -raw cluster_name)
CLUSTER_AUTOSCALER_ROLE_ARN=$(terraform output -raw cluster_autoscaler_role_arn)
cd ..

sed "s/\${CLUSTER_NAME}/$CLUSTER_NAME/g; s|\${CLUSTER_AUTOSCALER_ROLE_ARN}|$CLUSTER_AUTOSCALER_ROLE_ARN|g" \
    k8s-manifests/autoscaler/cluster-autoscaler.yaml | kubectl apply -f -
```

Verify:
```bash
kubectl get pods -n kube-system -l app=cluster-autoscaler
kubectl logs -l app=cluster-autoscaler -n kube-system
```

### Step 12: Deploy Nginx Test Application

```bash
kubectl apply -f k8s-manifests/nginx-test/
```

Wait for deployment:
```bash
kubectl wait --for=condition=Available deployment/nginx-test --timeout=300s
```

Get service URL:
```bash
kubectl get svc nginx-test
# Wait for EXTERNAL-IP to be assigned (may take 2-3 minutes)
```

Test application:
```bash
NGINX_URL=$(kubectl get svc nginx-test -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$NGINX_URL
```

### Step 13: Deploy Blue-Green Demo Application

```bash
kubectl apply -f blue-green-deployment/
```

Wait for deployment:
```bash
kubectl wait --for=condition=Available deployment/demo-app-blue --timeout=300s
```

Get service URL:
```bash
kubectl get svc demo-app-service
```

Test application:
```bash
DEMO_URL=$(kubectl get svc demo-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$DEMO_URL
# You should see the blue version
```

### Step 14: Deploy Jenkins

```bash
kubectl apply -f jenkins/namespace.yaml
kubectl apply -f jenkins/serviceaccount.yaml
kubectl apply -f jenkins/pvc.yaml
kubectl apply -f jenkins/deployment.yaml
kubectl apply -f jenkins/service.yaml
```

Wait for Jenkins (this takes 5-10 minutes):
```bash
kubectl wait --for=condition=Available deployment/jenkins -n jenkins --timeout=600s
```

Get Jenkins URL:
```bash
JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Jenkins URL: http://$JENKINS_URL:8080"
```

Get initial admin password:
```bash
kubectl exec -n jenkins $(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}') -- cat /var/jenkins_home/secrets/initialAdminPassword
```

## Post-Deployment Verification

### 1. Check All Resources

```bash
# Check all deployments
kubectl get deployments -A

# Check all services
kubectl get svc -A

# Check all pods
kubectl get pods -A
```

### 2. Verify Auto-Scaling Components

```bash
# Check HPA
kubectl get hpa

# Check Cluster Autoscaler
kubectl get pods -n kube-system -l app=cluster-autoscaler

# Check Metrics Server
kubectl get deployment metrics-server -n kube-system
```

### 3. Test Metrics Collection

```bash
# Node metrics
kubectl top nodes

# Pod metrics
kubectl top pods
```

## Common Issues and Solutions

### Issue: Nodes Not Ready

**Symptoms**: Nodes show as "NotReady"

**Solution**:
```bash
kubectl describe node <node-name>
# Check for issues with VPC CNI or other components
```

### Issue: Metrics Server Not Working

**Symptoms**: `kubectl top` commands fail

**Solution**:
```bash
# Check metrics server logs
kubectl logs -n kube-system -l k8s-app=metrics-server

# Verify API service
kubectl get apiservice v1beta1.metrics.k8s.io
```

### Issue: Load Balancer Not Created

**Symptoms**: Service shows `<pending>` for EXTERNAL-IP

**Solution**:
```bash
# Check service events
kubectl describe svc <service-name>

# Verify AWS Load Balancer Controller
kubectl get events -n kube-system

# Check security groups
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<vpc-id>
```

### Issue: Pods Pending Due to Resource Constraints

**Symptoms**: Pods stuck in "Pending" state

**Solution**:
```bash
# Check pod events
kubectl describe pod <pod-name>

# Check node resources
kubectl describe nodes

# Verify cluster autoscaler
kubectl logs -l app=cluster-autoscaler -n kube-system
```

## Next Steps

1. Review the [Auto-Scaling Documentation](AUTO_SCALING.md)
2. Learn about [Blue-Green Deployment](BLUE_GREEN_DEPLOYMENT.md)
3. Configure Jenkins pipeline
4. Test auto-scaling behavior
5. Practice blue-green deployment

## Cleanup

When you're done, clean up resources:

```bash
./scripts/cleanup.sh
```

Or manually:

```bash
# Delete Kubernetes resources
kubectl delete -f blue-green-deployment/
kubectl delete -f jenkins/
kubectl delete -f k8s-manifests/nginx-test/
kubectl delete -f k8s-manifests/autoscaler/

# Wait for load balancers to be deleted
sleep 60

# Destroy infrastructure
cd terraform
terraform destroy
```

## Support

If you encounter issues:
1. Check the troubleshooting section
2. Review AWS CloudWatch logs
3. Check Kubernetes events: `kubectl get events -A`
4. Review pod logs: `kubectl logs <pod-name>`

