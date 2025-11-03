# Windows Setup Guide

This guide is specifically for Windows users to set up and use this EKS project.

## Prerequisites Installation on Windows

### 1. Install Terraform

**Option A: Using Chocolatey (Recommended)**
```powershell
# Install Chocolatey if not already installed
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Install Terraform
choco install terraform -y
```

**Option B: Manual Installation**
1. Download from https://www.terraform.io/downloads.html
2. Extract to `C:\terraform`
3. Add to PATH:
   - Search for "Environment Variables" in Windows
   - Edit "Path" variable
   - Add `C:\terraform`
4. Verify: `terraform --version`

### 2. Install AWS CLI

**Option A: Using Chocolatey**
```powershell
choco install awscli -y
```

**Option B: MSI Installer**
1. Download from https://aws.amazon.com/cli/
2. Run the MSI installer
3. Verify: `aws --version`

### 3. Install kubectl

**Option A: Using Chocolatey**
```powershell
choco install kubernetes-cli -y
```

**Option B: Manual Installation**
```powershell
# Download kubectl
curl.exe -LO "https://dl.k8s.io/release/v1.28.0/bin/windows/amd64/kubectl.exe"

# Move to a directory in PATH
Move-Item kubectl.exe C:\Windows\System32\kubectl.exe

# Verify
kubectl version --client
```

### 4. Install Git

**Using Chocolatey**
```powershell
choco install git -y
```

**Manual**: Download from https://git-scm.com/download/win

## Configure AWS Credentials

```powershell
# Configure AWS CLI
aws configure

# Enter when prompted:
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region name: us-east-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

## Windows-Specific Setup Instructions

### Step 1: Clone or Navigate to Project

```powershell
# If cloning from GitHub
git clone <your-repo-url>
cd <repo-name>

# Or if already have the files
cd "C:\Users\U1190427.QAMR-ACCOUNTS\OneDrive - IQVIA\IQVIA Works\AWS"
```

### Step 2: Configure Terraform

```powershell
# Navigate to terraform directory
cd terraform

# Copy example variables
Copy-Item terraform.tfvars.example terraform.tfvars

# Edit with notepad
notepad terraform.tfvars

# Go back to root
cd ..
```

### Step 3: Run Setup (PowerShell Version)

Since bash scripts won't work directly on Windows, here's the PowerShell equivalent:

**Create `setup.ps1` in scripts folder:**

```powershell
# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Green

# Check Terraform
if (!(Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Terraform not found" -ForegroundColor Red
    exit 1
}

# Check AWS CLI
if (!(Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: AWS CLI not found" -ForegroundColor Red
    exit 1
}

# Check kubectl
if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: kubectl not found" -ForegroundColor Red
    exit 1
}

Write-Host "All prerequisites installed!" -ForegroundColor Green

# Check AWS credentials
Write-Host "`nChecking AWS credentials..." -ForegroundColor Green
try {
    aws sts get-caller-identity | Out-Null
    Write-Host "AWS credentials configured" -ForegroundColor Green
} catch {
    Write-Host "ERROR: AWS credentials not configured" -ForegroundColor Red
    exit 1
}

# Change to terraform directory
Set-Location terraform

# Initialize Terraform
Write-Host "`nInitializing Terraform..." -ForegroundColor Green
terraform init

# Validate
Write-Host "`nValidating Terraform configuration..." -ForegroundColor Green
terraform validate

# Plan
Write-Host "`nGenerating Terraform plan..." -ForegroundColor Green
terraform plan -out=tfplan

# Confirm
$confirm = Read-Host "`nDo you want to apply this plan? (yes/no)"
if ($confirm -ne "yes") {
    Write-Host "Deployment cancelled" -ForegroundColor Yellow
    exit 0
}

# Apply
Write-Host "`nApplying Terraform configuration..." -ForegroundColor Green
terraform apply tfplan

# Get outputs
$clusterName = terraform output -raw cluster_name
$region = terraform output -raw region
$autoscalerRole = terraform output -raw cluster_autoscaler_role_arn

Write-Host "`nCluster created: $clusterName" -ForegroundColor Green
Write-Host "Region: $region" -ForegroundColor Green

# Configure kubectl
Write-Host "`nConfiguring kubectl..." -ForegroundColor Green
aws eks update-kubeconfig --region $region --name $clusterName

# Wait for nodes
Write-Host "`nWaiting for nodes..." -ForegroundColor Green
Start-Sleep -Seconds 30
kubectl get nodes

# Return to root
Set-Location ..

# Deploy Metrics Server
Write-Host "`nDeploying Metrics Server..." -ForegroundColor Green
kubectl apply -f k8s-manifests/autoscaler/metrics-server.yaml
Start-Sleep -Seconds 30

# Deploy Cluster Autoscaler
Write-Host "`nDeploying Cluster Autoscaler..." -ForegroundColor Green
$autoscalerYaml = Get-Content k8s-manifests/autoscaler/cluster-autoscaler.yaml -Raw
$autoscalerYaml = $autoscalerYaml -replace '\$\{CLUSTER_NAME\}', $clusterName
$autoscalerYaml = $autoscalerYaml -replace '\$\{CLUSTER_AUTOSCALER_ROLE_ARN\}', $autoscalerRole
$autoscalerYaml | kubectl apply -f -

# Deploy nginx test
Write-Host "`nDeploying nginx test application..." -ForegroundColor Green
kubectl apply -f k8s-manifests/nginx-test/

# Deploy Jenkins
Write-Host "`nDeploying Jenkins..." -ForegroundColor Green
kubectl apply -f jenkins/

# Deploy Blue-Green
Write-Host "`nDeploying Blue-Green demo..." -ForegroundColor Green
kubectl apply -f blue-green-deployment/

Write-Host "`n================================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Wait 5-10 minutes for all services to be ready"
Write-Host "2. Get service URLs:"
Write-Host "   kubectl get svc --all-namespaces"
Write-Host "3. Test auto-scaling:"
Write-Host "   kubectl apply -f k8s-manifests/load-generator/load-test.yaml"
Write-Host "   kubectl get hpa -w"
```

**Run the setup:**

```powershell
# Execute the PowerShell setup script
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
.\scripts\setup.ps1
```

### Step 4: Get Service URLs

```powershell
# Nginx test app
kubectl get svc nginx-test -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Blue-Green demo
kubectl get svc demo-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Jenkins
kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Get Jenkins password
$jenkinsPod = kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}'
kubectl exec -n jenkins $jenkinsPod -- cat /var/jenkins_home/secrets/initialAdminPassword
```

### Step 5: Test Auto-Scaling (PowerShell)

```powershell
# Deploy load generator
kubectl apply -f k8s-manifests/load-generator/load-test.yaml

# Watch HPA (open separate PowerShell window)
kubectl get hpa -w

# Watch pods (open another window)
kubectl get pods -w

# After testing, stop load generator
kubectl delete pod load-generator
```

### Step 6: Test Blue-Green Deployment (PowerShell)

```powershell
# Get current version
kubectl get svc demo-app-service -o yaml | Select-String -Pattern "version"

# Scale up green
kubectl scale deployment demo-app-green --replicas=3

# Wait for ready
kubectl wait --for=condition=Available deployment/demo-app-green --timeout=300s

# Switch traffic to green
kubectl patch service demo-app-service -p '{\"spec\":{\"selector\":{\"version\":\"green\"}}}'

# Get URL and test
$demoUrl = kubectl get svc demo-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
Start-Process "http://$demoUrl"

# Scale down blue
kubectl scale deployment demo-app-blue --replicas=0
```

### Step 7: Cleanup (PowerShell)

```powershell
# Delete Kubernetes resources
kubectl delete -f blue-green-deployment/ --ignore-not-found=true
kubectl delete -f jenkins/ --ignore-not-found=true
kubectl delete -f k8s-manifests/nginx-test/ --ignore-not-found=true
kubectl delete -f k8s-manifests/load-generator/ --ignore-not-found=true
kubectl delete -f k8s-manifests/autoscaler/cluster-autoscaler.yaml --ignore-not-found=true
kubectl delete -f k8s-manifests/autoscaler/metrics-server.yaml --ignore-not-found=true

# Wait for LoadBalancers to be deleted
Write-Host "Waiting for LoadBalancers to be deleted..."
Start-Sleep -Seconds 60

# Destroy Terraform
Set-Location terraform
terraform destroy -auto-approve
Set-Location ..
```

## Alternative: Using Git Bash

If you have Git installed, you can use Git Bash to run the Linux scripts:

```bash
# Open Git Bash
# Navigate to project
cd "/c/Users/U1190427.QAMR-ACCOUNTS/OneDrive - IQVIA/IQVIA Works/AWS"

# Make scripts executable
chmod +x scripts/*.sh

# Run setup
./scripts/setup.sh

# Run tests
./scripts/test-autoscaling.sh
./scripts/test-bluegreen.sh

# Cleanup
./scripts/cleanup.sh
```

## Alternative: Using WSL (Windows Subsystem for Linux)

If you have WSL installed:

```bash
# Open WSL
wsl

# Navigate to project (adjust path)
cd /mnt/c/Users/U1190427.QAMR-ACCOUNTS/OneDrive\ -\ IQVIA/IQVIA\ Works/AWS

# Follow Linux instructions
chmod +x scripts/*.sh
./scripts/setup.sh
```

## Troubleshooting Windows-Specific Issues

### Issue: PowerShell Execution Policy

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process
```

### Issue: kubectl Not Found

```powershell
# Add to PATH
$env:Path += ";C:\Program Files\kubectl"

# Or permanently via System Properties > Environment Variables
```

### Issue: AWS CLI Not Configured

```powershell
# Check config file
notepad $env:USERPROFILE\.aws\credentials
notepad $env:USERPROFILE\.aws\config
```

### Issue: Terraform Backend

```powershell
# If terraform init fails
Set-Location terraform
Remove-Item -Recurse -Force .terraform
terraform init
```

### Issue: Line Endings

If you edit files on Windows, convert line endings:

```powershell
# Install dos2unix via Chocolatey
choco install dos2unix

# Convert files
dos2unix scripts/*.sh
```

## Viewing Logs in PowerShell

```powershell
# Pod logs
kubectl logs <pod-name>

# Follow logs
kubectl logs -f <pod-name>

# All pods with label
kubectl logs -l app=nginx-test --all-containers=true

# Previous logs
kubectl logs <pod-name> --previous
```

## Useful PowerShell Aliases

Add to your PowerShell profile (`notepad $PROFILE`):

```powershell
# Kubectl aliases
Set-Alias -Name k -Value kubectl

# Functions
function kgp { kubectl get pods $args }
function kgs { kubectl get svc $args }
function kgn { kubectl get nodes $args }
function kd { kubectl describe $args }
function kl { kubectl logs $args }
function ke { kubectl exec -it $args }
```

## Performance Tips for Windows

1. **Use native PowerShell** instead of Git Bash for better performance
2. **Exclude project directory** from Windows Defender scanning
3. **Use WSL2** for better Linux compatibility
4. **Close unnecessary applications** during Terraform apply

## Summary

For Windows users, you have three options:

1. **PowerShell** (Recommended for Windows)
   - Native Windows experience
   - Better performance
   - Requires PowerShell scripts

2. **Git Bash** (Easiest)
   - Use existing bash scripts
   - Linux-like environment
   - Slightly slower

3. **WSL** (Best Linux compatibility)
   - Full Linux experience
   - Best compatibility
   - Requires WSL setup

Choose the option that works best for you!

---

**Note**: All bash scripts (`.sh`) work in Git Bash or WSL. PowerShell scripts (`.ps1`) work in native Windows PowerShell or PowerShell Core.

