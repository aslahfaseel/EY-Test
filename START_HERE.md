# 🚀 START HERE - Your EKS Project Guide

Welcome! This is your complete AWS EKS infrastructure project adapted from GKE requirements.

## 📚 Quick Navigation

Choose your path based on your needs:

### 🎯 For Immediate Setup (Quickest)
👉 **[QUICKSTART.md](QUICKSTART.md)** - Get running in 15 minutes

### 💻 For Windows Users
👉 **[WINDOWS_SETUP.md](WINDOWS_SETUP.md)** - Windows-specific instructions

### 📖 For Complete Understanding
👉 **[README.md](README.md)** - Full documentation

### 🏗️ For Project Overview
👉 **[PROJECT_SUMMARY.md](PROJECT_SUMMARY.md)** - What's included

### 📁 For Project Structure
👉 **[STRUCTURE.md](STRUCTURE.md)** - File organization

## ✅ What You Need Before Starting

### Required Tools
- [ ] **Terraform** (>= 1.0)
- [ ] **AWS CLI** (>= 2.0)
- [ ] **kubectl** (>= 1.28)
- [ ] **Git**

### Required Setup
- [ ] AWS account configured
- [ ] AWS credentials set up (`aws configure`)
- [ ] Basic understanding of Kubernetes

### Time & Cost
- **Setup Time**: 15-20 minutes
- **Testing Time**: 30-60 minutes
- **Monthly Cost**: ~$200-250 (⚠️ **Remember to cleanup!**)

## 🎯 What This Project Does

This is a **complete, production-ready** AWS EKS infrastructure that demonstrates:

✅ **Infrastructure as Code** with Terraform
✅ **Kubernetes Cluster** (EKS) with 2-5 nodes
✅ **Auto-Scaling** (both pods and nodes)
✅ **CI/CD** with Jenkins
✅ **Blue-Green Deployment** strategy
✅ **Complete Documentation**

## 🚦 Getting Started (3 Simple Steps)

### Step 1: Configure AWS
```bash
aws configure
# Enter your AWS access key and secret key
```

### Step 2: Choose Your Setup Method

#### Option A: Automated (Recommended)
```bash
# For Linux/Mac or Git Bash on Windows
chmod +x scripts/*.sh
./scripts/setup.sh
```

#### Option B: Manual (Step-by-step)
Follow **[docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)**

#### Option C: Windows PowerShell
Follow **[WINDOWS_SETUP.md](WINDOWS_SETUP.md)**

### Step 3: Test & Verify
```bash
# Get service URLs
./scripts/get-endpoints.sh

# Test auto-scaling
./scripts/test-autoscaling.sh

# Test blue-green deployment
./scripts/test-bluegreen.sh
```

## 📚 Documentation Guide

### For Different Audiences

**If you're new to Kubernetes:**
1. Start with [README.md](README.md) - Overview
2. Read [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md) - Basics
3. Understand [docs/AUTO_SCALING.md](docs/AUTO_SCALING.md) - Concepts

**If you're experienced:**
1. Check [QUICKSTART.md](QUICKSTART.md) - Fast setup
2. Review [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Architecture
3. Dive into code directly

**If you're on Windows:**
1. Read [WINDOWS_SETUP.md](WINDOWS_SETUP.md) first
2. Then follow [QUICKSTART.md](QUICKSTART.md)

**If you're cost-conscious:**
1. Check [docs/COST_ESTIMATION.md](docs/COST_ESTIMATION.md)
2. Review trial account section
3. Set up billing alerts

**For the assignment submission:**
1. Read all documentation
2. Follow [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
3. Capture screenshots (guide in each doc)
4. Test everything
5. Push to GitHub

## 📋 Project Components

### Terraform Files (`terraform/`)
- VPC and networking setup
- EKS cluster configuration
- Node groups with auto-scaling
- IAM roles and policies
- **Start here for infrastructure**

### Kubernetes Manifests (`k8s-manifests/`)
- Nginx test application
- Horizontal Pod Autoscaler
- Cluster Autoscaler
- Metrics Server
- **Start here for applications**

### Jenkins Setup (`jenkins/`)
- Jenkins deployment
- Blue-green pipeline
- RBAC configuration
- **Start here for CI/CD**

### Blue-Green Demo (`blue-green-deployment/`)
- Sample application
- Two versions (blue/green)
- Service configuration
- **Start here for deployment strategy**

### Scripts (`scripts/`)
- Automated setup
- Testing scripts
- Cleanup scripts
- **Start here for automation**

### Documentation (`docs/`)
- Detailed guides
- Best practices
- Troubleshooting
- **Start here for learning**

## 🎓 Learning Path

### Day 1: Setup & Basics
1. Install prerequisites
2. Run automated setup
3. Explore the cluster
4. Get familiar with kubectl

### Day 2: Auto-Scaling
1. Read [docs/AUTO_SCALING.md](docs/AUTO_SCALING.md)
2. Test HPA scaling
3. Test Cluster Autoscaler
4. Capture screenshots

### Day 3: Blue-Green Deployment
1. Read [docs/BLUE_GREEN_DEPLOYMENT.md](docs/BLUE_GREEN_DEPLOYMENT.md)
2. Configure Jenkins
3. Test manual deployment
4. Test Jenkins pipeline

### Day 4: Documentation & Submission
1. Review all components
2. Take final screenshots
3. Write your report
4. Push to GitHub

## ⚠️ Important Warnings

### 1. Cost Alert
This infrastructure costs approximately:
- **Per Day**: $8-13
- **Per Month**: $200-250

**Always cleanup when done!**
```bash
./scripts/cleanup.sh
```

### 2. AWS Credentials
- Never commit AWS credentials
- Use `.gitignore` (already included)
- Review files before pushing

### 3. Resource Limits
- Default: 2-5 nodes
- Watch your AWS limits
- Monitor costs daily

### 4. Cleanup Checklist
Before destroying infrastructure:
- [ ] Delete all Kubernetes resources
- [ ] Wait for LoadBalancers to terminate
- [ ] Run `terraform destroy`
- [ ] Verify in AWS Console
- [ ] Check your AWS bill

## 🆘 Need Help?

### Common Issues

**Terraform fails:**
- Check AWS credentials: `aws sts get-caller-identity`
- Check region in terraform.tfvars
- Review [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)

**Pods not starting:**
- Wait 2-3 minutes
- Check logs: `kubectl logs <pod-name>`
- Check events: `kubectl get events`

**LoadBalancer pending:**
- Normal for first 2-3 minutes
- Check security groups
- Verify VPC configuration

**Auto-scaling not working:**
- Verify Metrics Server: `kubectl top nodes`
- Check HPA: `kubectl describe hpa`
- Review [docs/AUTO_SCALING.md](docs/AUTO_SCALING.md)

**Jenkins not accessible:**
- Wait 5-10 minutes for initialization
- Check pod status: `kubectl get pods -n jenkins`
- Check logs: `kubectl logs -n jenkins <jenkins-pod>`

### Where to Find Answers

1. **Setup Issues** → [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
2. **Auto-scaling** → [docs/AUTO_SCALING.md](docs/AUTO_SCALING.md)
3. **Deployment** → [docs/BLUE_GREEN_DEPLOYMENT.md](docs/BLUE_GREEN_DEPLOYMENT.md)
4. **Costs** → [docs/COST_ESTIMATION.md](docs/COST_ESTIMATION.md)
5. **General** → [README.md](README.md)

## 🎯 Success Checklist

You'll know everything is working when:

- [ ] EKS cluster is running
- [ ] 2 nodes are in Ready state
- [ ] All pods are Running
- [ ] Nginx app is accessible
- [ ] HPA scales pods under load
- [ ] Cluster Autoscaler adds nodes
- [ ] Jenkins is accessible
- [ ] Blue-green switch works
- [ ] Screenshots captured
- [ ] Documentation complete

## 📊 Project Stats

- **Total Files**: 36
- **Lines of Code**: ~6,000
- **Terraform Resources**: ~30
- **Kubernetes Resources**: ~20
- **Documentation**: ~3,500 lines
- **Scripts**: 5 automation scripts

## 🎉 Ready to Start?

Choose your path:

- **Fast Start**: [QUICKSTART.md](QUICKSTART.md)
- **Windows**: [WINDOWS_SETUP.md](WINDOWS_SETUP.md)
- **Detailed**: [docs/SETUP_GUIDE.md](docs/SETUP_GUIDE.md)
- **Overview**: [README.md](README.md)

## 📞 Final Notes

### For Your Assignment Submission

This project provides **everything required**:

✅ EKS Cluster (replaces GKE)
✅ 2-node setup (scalable to 5)
✅ Nginx test application
✅ Auto-scaling demonstration
✅ Jenkins deployment
✅ Blue-green deployment
✅ Complete documentation
✅ Screenshots guide
✅ Cost considerations
✅ Troubleshooting

### What Makes This Project Stand Out

1. **Complete Infrastructure**: Production-ready setup
2. **Comprehensive Docs**: Every aspect documented
3. **Automation Scripts**: Easy testing and demos
4. **Best Practices**: Industry-standard patterns
5. **Cost Awareness**: Budget and optimization tips
6. **Multiple Paths**: Different user journeys
7. **Windows Support**: Cross-platform friendly
8. **GitHub Ready**: Professional structure

### Next Steps

1. ⭐ Read this file completely
2. 📖 Choose your documentation path
3. 🚀 Run the setup
4. 🧪 Test all features
5. 📸 Capture screenshots
6. 📝 Document your findings
7. 🚀 Push to GitHub
8. ✅ Submit your assignment

---

**Good luck with your project!** 🎉

Remember: This is a **learning opportunity** - take time to understand each component, experiment, and ask questions.

**Most Important**: Always run `./scripts/cleanup.sh` when done to avoid unexpected AWS charges!

