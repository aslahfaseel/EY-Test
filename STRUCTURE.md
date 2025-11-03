# Project Structure

```
EKS-Terraform-Project/
│
├── README.md                           # Main documentation
├── QUICKSTART.md                       # Quick start guide
├── PROJECT_SUMMARY.md                  # Complete project overview
├── STRUCTURE.md                        # This file
├── LICENSE                             # MIT License
├── .gitignore                          # Git ignore rules
│
├── terraform/                          # Infrastructure as Code
│   ├── provider.tf                     # AWS, Kubernetes, Helm providers
│   ├── variables.tf                    # Input variables
│   ├── vpc.tf                          # VPC, subnets, NAT gateways
│   ├── iam.tf                          # IAM roles and policies
│   ├── eks.tf                          # EKS cluster and node groups
│   ├── outputs.tf                      # Output values
│   └── terraform.tfvars.example        # Example configuration
│
├── k8s-manifests/                      # Kubernetes resources
│   │
│   ├── nginx-test/                     # Test application
│   │   ├── deployment.yaml             # Nginx deployment
│   │   ├── service.yaml                # LoadBalancer service
│   │   └── hpa.yaml                    # Horizontal Pod Autoscaler
│   │
│   ├── autoscaler/                     # Auto-scaling components
│   │   ├── metrics-server.yaml         # Metrics Server
│   │   └── cluster-autoscaler.yaml     # Cluster Autoscaler
│   │
│   └── load-generator/                 # Testing tools
│       └── load-test.yaml              # Load generation pod
│
├── jenkins/                            # Jenkins CI/CD
│   ├── namespace.yaml                  # Jenkins namespace
│   ├── serviceaccount.yaml             # ServiceAccount with RBAC
│   ├── pvc.yaml                        # Persistent volume claim
│   ├── deployment.yaml                 # Jenkins deployment
│   ├── service.yaml                    # LoadBalancer service
│   └── Jenkinsfile-bluegreen           # Blue-green pipeline
│
├── blue-green-deployment/              # Demo application
│   ├── app-deployment.yaml             # Blue and Green deployments
│   └── service.yaml                    # Service with version selector
│
├── scripts/                            # Automation scripts
│   ├── setup.sh                        # Automated full setup
│   ├── cleanup.sh                      # Complete cleanup
│   ├── get-endpoints.sh                # Get service URLs
│   ├── test-autoscaling.sh             # Auto-scaling demo
│   └── test-bluegreen.sh               # Blue-green demo
│
└── docs/                               # Detailed documentation
    ├── SETUP_GUIDE.md                  # Step-by-step setup
    ├── AUTO_SCALING.md                 # Auto-scaling guide
    ├── BLUE_GREEN_DEPLOYMENT.md        # Deployment strategy
    └── COST_ESTIMATION.md              # Cost analysis

```

## File Count Summary

- **Terraform Files**: 7
- **Kubernetes Manifests**: 9
- **Jenkins Files**: 6
- **Scripts**: 5
- **Documentation**: 9
- **Total Files**: 36 files

## Lines of Code

Approximate breakdown:

- **Terraform**: ~800 lines
- **Kubernetes YAML**: ~900 lines
- **Jenkins Pipeline**: ~200 lines
- **Shell Scripts**: ~500 lines
- **Documentation**: ~3,500 lines
- **Total**: ~6,000 lines

## Key Components

### Infrastructure Layer (Terraform)
```
AWS Cloud
├── VPC (10.0.0.0/16)
│   ├── Public Subnets (2 AZs)
│   │   ├── Internet Gateway
│   │   └── NAT Gateways (2)
│   └── Private Subnets (2 AZs)
│       └── EKS Worker Nodes
├── EKS Control Plane
├── Node Group (2-5 nodes)
└── IAM Roles & Policies
```

### Application Layer (Kubernetes)
```
Kubernetes Cluster
├── kube-system namespace
│   ├── Metrics Server
│   ├── Cluster Autoscaler
│   ├── CoreDNS
│   ├── VPC CNI
│   └── kube-proxy
│
├── jenkins namespace
│   └── Jenkins (CI/CD)
│       ├── Deployment
│       ├── Service (LoadBalancer)
│       └── PVC (10 GB)
│
└── default namespace
    ├── nginx-test
    │   ├── Deployment (2-10 replicas)
    │   ├── Service (LoadBalancer)
    │   └── HPA
    │
    ├── demo-app-blue
    │   └── Deployment (0-3 replicas)
    │
    ├── demo-app-green
    │   └── Deployment (0-3 replicas)
    │
    └── demo-app-service
        └── Service (LoadBalancer)
```

## Resource Relationships

```
┌─────────────────────────────────────────────────────┐
│                   Terraform                          │
│  Creates and manages all AWS infrastructure         │
└────────────────┬────────────────────────────────────┘
                 │
                 ├─> VPC & Networking
                 ├─> EKS Cluster
                 ├─> Node Groups
                 ├─> IAM Roles
                 └─> Security Groups
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│              Kubernetes Resources                    │
│  Deployed on the EKS cluster                        │
└────────────────┬────────────────────────────────────┘
                 │
                 ├─> Metrics Server (enables HPA)
                 ├─> Cluster Autoscaler (scales nodes)
                 ├─> nginx-test (with HPA)
                 ├─> Jenkins (CI/CD)
                 └─> Blue-Green App
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│           Jenkins Pipeline                           │
│  Automates blue-green deployments                   │
└─────────────────────────────────────────────────────┘
```

## Deployment Flow

```
1. Developer/Operator
   │
   ├─> Configures terraform.tfvars
   │
   └─> Runs setup.sh
       │
       ├─> Terraform Init & Apply
       │   │
       │   └─> Creates AWS Infrastructure
       │       ├─> VPC
       │       ├─> EKS Cluster
       │       └─> Node Groups
       │
       ├─> Configure kubectl
       │
       ├─> Deploy Metrics Server
       │
       ├─> Deploy Cluster Autoscaler
       │
       ├─> Deploy Applications
       │   ├─> nginx-test
       │   ├─> Blue-Green demo
       │   └─> Jenkins
       │
       └─> Display Endpoints
```

## Auto-Scaling Flow

```
HPA Flow:
Load → High CPU → HPA detects → Scales pods up
                                      │
                                      ├─> More pods needed
                                      │   than node capacity
                                      │
                                      └─> Triggers Cluster Autoscaler
                                          │
                                          └─> Adds new nodes

Cluster Autoscaler Flow:
Pending Pods → CA detects → Scales node group → New nodes added
                                                       │
                                                       └─> Pods scheduled
```

## Blue-Green Deployment Flow

```
1. Current State:
   Service → Blue Deployment (active)
             Green Deployment (standby, 0 replicas)

2. Deploy Green:
   Scale up Green → Wait for ready → Health checks

3. Switch Traffic:
   Service → Green Deployment (active)
             Blue Deployment (standby, still running)

4. Verify:
   Monitor Green for issues (30 seconds)

5. Cleanup:
   Service → Green Deployment (active)
             Blue Deployment (scaled to 0)

6. Rollback (if needed):
   Service → Blue Deployment (active)
             Green Deployment (scaled to 0)
```

## Testing Flow

```
Auto-Scaling Test:
1. Deploy load generator
   │
2. Watch HPA metrics
   │
3. Observe pod scaling (2 → 10)
   │
4. Observe node scaling (2 → 5)
   │
5. Stop load generator
   │
6. Watch scale-down (5 minutes)

Blue-Green Test:
1. Access blue version
   │
2. Scale up green
   │
3. Switch service to green
   │
4. Verify green is serving
   │
5. Scale down blue
   │
6. (Optional) Switch back
```

## Documentation Structure

```
User Journey:

Start Here → README.md (Overview)
   │
   ├─> Quick Path → QUICKSTART.md
   │
   └─> Detailed Path
       │
       ├─> Setup → docs/SETUP_GUIDE.md
       │
       ├─> Learn Auto-Scaling → docs/AUTO_SCALING.md
       │
       ├─> Learn Blue-Green → docs/BLUE_GREEN_DEPLOYMENT.md
       │
       └─> Cost Planning → docs/COST_ESTIMATION.md
```

## Integration Points

### Terraform → Kubernetes
- Outputs cluster endpoint
- Outputs cluster CA certificate
- Configures kubectl context
- Provides cluster autoscaler role ARN

### Kubernetes → AWS
- Service creates AWS LoadBalancers
- EBS volumes for persistent storage
- IAM roles via IRSA
- Cluster Autoscaler modifies ASG

### Jenkins → Kubernetes
- Uses kubectl commands
- Accesses cluster via service account
- Deploys and manages resources
- Monitors deployment health

## Security Architecture

```
Network Security:
├── VPC Isolation
├── Private Subnets for nodes
├── Security Groups
│   ├── Cluster SG (control plane)
│   └── Node SG (workers)
└── Network ACLs

Access Control:
├── IAM Roles
│   ├── Cluster Role
│   ├── Node Role
│   └── Autoscaler Role
├── Kubernetes RBAC
│   ├── Cluster Roles
│   └── Service Accounts
└── OIDC Provider for IRSA

Data Security:
├── EKS encryption at rest
├── EBS volume encryption
└── TLS for all communications
```

## Monitoring Points

```
Infrastructure:
├── AWS CloudWatch (EKS cluster logs)
├── EC2 metrics (node health)
└── VPC Flow Logs (network)

Kubernetes:
├── Metrics Server (resource usage)
├── Cluster Autoscaler logs
├── HPA metrics
└── Pod logs

Application:
├── LoadBalancer health checks
├── Application logs
└── Service endpoints
```

## Cost Structure

```
Fixed Costs:
├── EKS Control Plane: $72/month
└── NAT Gateways: $65/month

Variable Costs:
├── EC2 Instances: $60-150/month
├── LoadBalancers: $50-60/month
├── EBS Volumes: $5-15/month
└── Data Transfer: $5-20/month

Total: ~$210-400/month
```

---

This structure provides a **complete, production-ready EKS deployment** with all necessary components for the assignment requirements adapted from GKE to AWS.

