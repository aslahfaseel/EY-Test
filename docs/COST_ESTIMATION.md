# AWS Cost Estimation

This document provides a breakdown of costs associated with running this EKS infrastructure.

## Monthly Cost Breakdown

### Core Infrastructure

| Resource | Specification | Quantity | Hourly Cost | Monthly Cost |
|----------|--------------|----------|-------------|--------------|
| EKS Control Plane | - | 1 | $0.10 | $72.00 |
| EC2 Instances (Nodes) | t3.medium | 2-5 | $0.0416 | $59.90 - $149.76 |
| NAT Gateways | - | 2 | $0.045 | $64.80 |
| Elastic IPs | For NAT | 2 | $0.005 | $7.20 |
| EBS Volumes | 20 GB gp2 per node | 2-5 | $0.10/GB/mo | $4.00 - $10.00 |

**Subtotal (Core)**: $207.90 - $303.76/month

### Load Balancers

| Resource | Quantity | Hourly Cost | Monthly Cost |
|----------|----------|-------------|--------------|
| Application Load Balancer | 3 (nginx, jenkins, demo) | $0.0225 | $48.60 |
| ALB Data Processing | Variable | $0.008/GB | Varies |

**Subtotal (Load Balancers)**: ~$50-60/month

### Data Transfer

| Type | Typical Usage | Cost |
|------|---------------|------|
| Data Transfer Out | 10 GB | $0.09/GB = $0.90 |
| Data Transfer In | Free | $0.00 |
| Inter-AZ Transfer | 20 GB | $0.01/GB = $0.20 |

**Subtotal (Data Transfer)**: ~$1-10/month

### Storage

| Resource | Size | Cost |
|----------|------|------|
| Jenkins PVC (EBS) | 10 GB | $1.00/month |
| EBS Snapshots | As needed | $0.05/GB/month |

**Subtotal (Storage)**: ~$1-5/month

## Total Estimated Costs

| Configuration | Monthly Cost |
|--------------|-------------|
| **Minimum (2 nodes, light usage)** | ~$210-230 |
| **Typical (2-3 nodes, moderate)** | ~$250-280 |
| **Maximum (5 nodes, heavy usage)** | ~$350-400 |

## Cost Optimization Strategies

### 1. Use Spot Instances for Non-Production

```hcl
# In eks.tf
resource "aws_eks_node_group" "spot" {
  capacity_type = "SPOT"
  
  instance_types = ["t3.medium", "t3a.medium", "t2.medium"]
  
  # Potential savings: 50-70%
}
```

**Savings**: ~$30-75/month

### 2. Reduce Node Count

For testing/development:

```hcl
# In terraform.tfvars
node_desired_size = 1
node_min_size = 1
node_max_size = 3
```

**Savings**: ~$30-60/month

### 3. Use Single NAT Gateway

For non-production:

```hcl
# In vpc.tf - modify to use single NAT
# Both private subnets use same NAT gateway
```

**Savings**: ~$32/month

### 4. Use Smaller Instance Types

```hcl
# In terraform.tfvars
node_instance_types = ["t3.small"]  # Instead of t3.medium
```

**Savings**: ~$20-30/month

### 5. Schedule Cluster Downtime

For development clusters:

```bash
# Stop cluster outside working hours
# Example: Run only 8 hours/day, 5 days/week

# Potential savings: 75% of node costs
```

**Savings**: ~$45-112/month

### 6. Use AWS Free Tier (New Accounts)

AWS Free Tier includes:
- 750 hours/month of t2.micro or t3.micro (first 12 months)
- 5 GB of standard storage
- 15 GB of bandwidth

**Savings**: ~$10-20/month for 12 months

### 7. Delete When Not in Use

**Most Important**: Always destroy resources when not actively testing:

```bash
./scripts/cleanup.sh
```

**Savings**: 100% when not in use!

## Cost Monitoring Setup

### 1. Enable Cost Explorer

```bash
# Via AWS Console
# Navigate to: Billing → Cost Explorer
# Enable Cost Explorer
```

### 2. Set Up Billing Alerts

```bash
# Create SNS topic
aws sns create-topic --name billing-alerts

# Create budget
aws budgets create-budget \
  --account-id <account-id> \
  --budget file://budget.json
```

Example `budget.json`:

```json
{
  "BudgetName": "EKS-Monthly-Budget",
  "BudgetLimit": {
    "Amount": "300",
    "Unit": "USD"
  },
  "TimeUnit": "MONTHLY",
  "BudgetType": "COST"
}
```

### 3. Tag Resources for Tracking

All resources are tagged via Terraform:

```hcl
default_tags {
  tags = {
    Environment = "dev"
    Project     = "EKS-Demo"
    ManagedBy   = "Terraform"
  }
}
```

View costs by tag in AWS Cost Explorer.

### 4. Use AWS Cost Anomaly Detection

Enable in AWS Console:
- Billing → Cost Anomaly Detection
- Create monitor for EKS costs
- Set alert threshold (e.g., $50 anomaly)

## Daily Cost Breakdown

For running 24 hours:

| Period | Cost |
|--------|------|
| 1 Hour | ~$0.35 - 0.55 |
| 8 Hours (workday) | ~$2.80 - 4.40 |
| 24 Hours (full day) | ~$8.40 - 13.20 |

## Trial Account Considerations

### AWS Free Tier Limitations

Be aware of free tier limits:

- **t2.micro**: 750 hours/month for 12 months
- **EBS Storage**: 30 GB for 12 months
- **Data Transfer**: 15 GB out/month
- **Load Balancer**: Not included in free tier

### Recommendations for Trial Accounts

1. **Use smaller instances**: t3.micro or t3.small
2. **Single node**: Start with 1 node, scale if needed
3. **Single NAT Gateway**: Use one NAT for both AZs
4. **Delete LoadBalancers**: Use NodePort for testing
5. **Set strict budgets**: Alert at $50, hard limit at $100
6. **Destroy daily**: Create/destroy cluster daily

### Modified Configuration for Trial Accounts

Create `terraform/terraform.tfvars` for cost-conscious setup:

```hcl
aws_region = "us-east-1"
cluster_name = "demo-eks-trial"
cluster_version = "1.28"

vpc_cidr = "10.0.0.0/16"

node_desired_size = 1
node_min_size = 1
node_max_size = 2
node_instance_types = ["t3.small"]
node_disk_size = 10  # Reduced from 20 GB
```

**Estimated Cost**: ~$100-130/month

## Billing Best Practices

### 1. Daily Cost Checks

```bash
# Check current month costs
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=SERVICE
```

### 2. Weekly Resource Audit

```bash
# List running EC2 instances
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0]]'

# List load balancers
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[].[LoadBalancerName,State.Code]'

# List NAT gateways
aws ec2 describe-nat-gateways \
  --filter "Name=state,Values=available"
```

### 3. Automated Shutdown Script

Create a script to stop resources during off-hours:

```bash
#!/bin/bash
# stop-cluster.sh

# Scale node group to 0
aws eks update-nodegroup-config \
  --cluster-name demo-eks-cluster \
  --nodegroup-name demo-eks-cluster-node-group \
  --scaling-config minSize=0,maxSize=5,desiredSize=0
```

### 4. Use Terraform Cost Estimation

```bash
# Install Infracost
brew install infracost

# Get cost estimate
cd terraform
infracost breakdown --path .
```

## Cost Comparison: EKS vs Alternatives

| Service | Monthly Cost | Pros | Cons |
|---------|------------|------|------|
| **AWS EKS** | $210-300 | Production-ready, managed control plane | Higher cost |
| **ECS Fargate** | $150-200 | Serverless, no nodes to manage | Less flexibility |
| **Self-managed K8s** | $120-180 | Lower cost, full control | High operational overhead |
| **Minikube** | $0 (local) | Free, good for learning | Not production-ready |

## Hidden Costs to Watch

1. **CloudWatch Logs**: $0.50/GB ingested
2. **VPC Flow Logs**: $0.50/GB
3. **S3 (Terraform state)**: Minimal but adds up
4. **Route 53** (if used): $0.50/hosted zone
5. **KMS** (if encrypting secrets): $1/key/month

## Summary

### Minimum Viable Cost (Trial/Learning)

```
Configuration:
- 1 t3.small node
- Single NAT Gateway
- No load balancers (use NodePort)
- 8 GB EBS volumes

Estimated: ~$80-100/month
```

### Recommended for Learning/Testing

```
Configuration:
- 2 t3.medium nodes
- 2 NAT Gateways (HA)
- 3 Load Balancers
- 20 GB EBS volumes

Estimated: ~$210-250/month
```

### Production-Ready Configuration

```
Configuration:
- 3 t3.large nodes (min)
- 2 NAT Gateways
- Multiple Load Balancers
- Larger EBS volumes
- CloudWatch logs
- Backups

Estimated: $500-800/month
```

## Important Reminders

⚠️ **Always clean up resources after testing**

⚠️ **Set up billing alerts before deploying**

⚠️ **Check your bill daily during initial setup**

⚠️ **Use tags to track costs by project**

⚠️ **Consider using AWS Budgets for hard limits**

---

**Last Updated**: November 2024  
**Prices**: US East (N. Virginia) region  
**Note**: Prices may vary by region and are subject to change

