# Blue-Green Deployment Guide

This document explains the blue-green deployment strategy implementation and how to execute deployments using Jenkins.

## What is Blue-Green Deployment?

Blue-Green deployment is a release strategy that:

- **Minimizes Downtime**: New version runs alongside old version
- **Instant Rollback**: Can quickly switch back if issues occur
- **Testing in Production**: Test new version before switching traffic
- **Zero-Downtime Deployments**: No service interruption during deployment

### How It Works

```
                    ┌──────────────┐
                    │   Service    │
                    │  (Selector)  │
                    └──────┬───────┘
                           │
                ┌──────────┴──────────┐
                │                     │
         ┌──────▼──────┐       ┌─────▼──────┐
         │    BLUE     │       │   GREEN    │
         │ Deployment  │       │ Deployment │
         │ (Active)    │       │ (Standby)  │
         │  3 replicas │       │  0 replicas│
         └─────────────┘       └────────────┘

    After Deployment:

                    ┌──────────────┐
                    │   Service    │
                    │  (Selector)  │
                    └──────┬───────┘
                           │
                ┌──────────┴──────────┐
                │                     │
         ┌──────▼──────┐       ┌─────▼──────┐
         │    BLUE     │       │   GREEN    │
         │ Deployment  │       │ Deployment │
         │ (Standby)   │       │ (Active)   │
         │  0 replicas │       │  3 replicas│
         └─────────────┘       └────────────┘
```

## Architecture

### Components

1. **Blue Deployment**: First version (e.g., v1.0)
2. **Green Deployment**: Second version (e.g., v2.0)
3. **Service**: Routes traffic using label selectors
4. **Jenkins Pipeline**: Automates the deployment process

### Service Configuration

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app-service
spec:
  type: LoadBalancer
  selector:
    app: demo-app
    version: blue  # This selector determines which deployment receives traffic
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
```

The service routes traffic based on the `version` label:
- `version: blue` → Routes to blue deployment
- `version: green` → Routes to green deployment

## Manual Blue-Green Deployment

### Step 1: Check Current State

```bash
# Check deployments
kubectl get deployments -l app=demo-app

# Check current service routing
kubectl get svc demo-app-service -o yaml | grep -A 3 selector

# Get current application URL
DEMO_URL=$(kubectl get svc demo-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Application URL: http://$DEMO_URL"
```

### Step 2: Verify Current Version

```bash
# Test current version
curl http://$DEMO_URL

# Or open in browser
echo "Open: http://$DEMO_URL"
```

You should see the blue version with blue background.

### Step 3: Scale Up Green Deployment

```bash
# Scale green deployment to 3 replicas
kubectl scale deployment demo-app-green --replicas=3

# Watch pods coming up
kubectl get pods -l app=demo-app,version=green -w
```

### Step 4: Wait for Green Deployment Ready

```bash
# Wait for all pods to be ready
kubectl wait --for=condition=Available deployment/demo-app-green --timeout=300s

# Verify all pods are running
kubectl get pods -l app=demo-app,version=green
```

### Step 5: Test Green Deployment

Before switching traffic, test the green deployment directly:

```bash
# Get a green pod name
GREEN_POD=$(kubectl get pods -l app=demo-app,version=green -o jsonpath='{.items[0].metadata.name}')

# Port-forward to test
kubectl port-forward $GREEN_POD 8080:80

# In another terminal, test
curl http://localhost:8080
```

### Step 6: Switch Traffic to Green

```bash
# Update service selector to green
kubectl patch service demo-app-service -p '{"spec":{"selector":{"version":"green"}}}'

# Verify the change
kubectl get svc demo-app-service -o yaml | grep -A 3 selector
```

### Step 7: Verify Traffic Switch

```bash
# Test application (should now show green version)
curl http://$DEMO_URL

# Or open in browser
echo "Open: http://$DEMO_URL"
```

You should now see the green version with green background.

### Step 8: Monitor for Issues

Wait and monitor for a few minutes to ensure stability:

```bash
# Watch pods
kubectl get pods -l app=demo-app -w

# Check pod logs
kubectl logs -l app=demo-app,version=green --tail=50
```

### Step 9: Scale Down Blue Deployment

Once confident in the green deployment:

```bash
# Scale down blue deployment
kubectl scale deployment demo-app-blue --replicas=0

# Verify
kubectl get deployments -l app=demo-app
```

### Step 10: Rollback (If Needed)

If issues are found, quickly rollback:

```bash
# Switch service back to blue
kubectl patch service demo-app-service -p '{"spec":{"selector":{"version":"blue"}}}'

# Scale blue back up if needed
kubectl scale deployment demo-app-blue --replicas=3

# Scale green down
kubectl scale deployment demo-app-green --replicas=0
```

## Jenkins-Based Deployment

### Jenkins Setup

#### Step 1: Access Jenkins

```bash
# Get Jenkins URL
JENKINS_URL=$(kubectl get svc jenkins -n jenkins -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Jenkins URL: http://$JENKINS_URL:8080"

# Get initial admin password
JENKINS_POD=$(kubectl get pods -n jenkins -l app=jenkins -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n jenkins $JENKINS_POD -- cat /var/jenkins_home/secrets/initialAdminPassword
```

#### Step 2: Initial Jenkins Configuration

1. Open Jenkins URL in browser
2. Enter initial admin password
3. Click "Install suggested plugins"
4. Create admin user:
   - Username: admin
   - Password: (choose a strong password)
   - Full name: Admin
   - Email: admin@example.com

#### Step 3: Install Required Plugins

1. Go to "Manage Jenkins" → "Manage Plugins"
2. Go to "Available" tab
3. Install:
   - Kubernetes Plugin
   - Pipeline Plugin
   - Git Plugin
   - Blue Ocean (optional, for better UI)
4. Restart Jenkins after installation

#### Step 4: Configure Kubernetes Plugin

1. Go to "Manage Jenkins" → "Configure System"
2. Scroll to "Cloud" section
3. Click "Add a new cloud" → "Kubernetes"
4. Configure:
   - Name: kubernetes
   - Kubernetes URL: https://kubernetes.default
   - Kubernetes Namespace: default
   - Jenkins URL: http://jenkins.jenkins.svc.cluster.local:8080
5. Test connection
6. Save

### Create Blue-Green Pipeline

#### Step 1: Create New Pipeline Job

1. Click "New Item"
2. Enter name: "Blue-Green-Deployment"
3. Select "Pipeline"
4. Click "OK"

#### Step 2: Configure Pipeline

1. Scroll to "Pipeline" section
2. Definition: "Pipeline script"
3. Copy and paste the Jenkinsfile content:

```groovy
pipeline {
    agent any
    
    parameters {
        choice(name: 'DEPLOYMENT_TYPE', choices: ['blue-to-green', 'green-to-blue'], description: 'Select deployment direction')
        string(name: 'REPLICAS', defaultValue: '3', description: 'Number of replicas for new deployment')
    }
    
    environment {
        NAMESPACE = 'default'
        APP_NAME = 'demo-app'
    }
    
    stages {
        stage('Validate Current State') {
            steps {
                script {
                    echo "Validating current deployment state..."
                    sh """
                        kubectl get deployment demo-app-blue -n ${NAMESPACE}
                        kubectl get deployment demo-app-green -n ${NAMESPACE}
                        kubectl get service demo-app-service -n ${NAMESPACE}
                    """
                }
            }
        }
        
        stage('Determine Active and Target') {
            steps {
                script {
                    if (params.DEPLOYMENT_TYPE == 'blue-to-green') {
                        env.ACTIVE_DEPLOYMENT = 'demo-app-blue'
                        env.TARGET_DEPLOYMENT = 'demo-app-green'
                        env.ACTIVE_VERSION = 'blue'
                        env.TARGET_VERSION = 'green'
                    } else {
                        env.ACTIVE_DEPLOYMENT = 'demo-app-green'
                        env.TARGET_DEPLOYMENT = 'demo-app-blue'
                        env.ACTIVE_VERSION = 'green'
                        env.TARGET_VERSION = 'blue'
                    }
                    echo "Active Deployment: ${env.ACTIVE_DEPLOYMENT}"
                    echo "Target Deployment: ${env.TARGET_DEPLOYMENT}"
                }
            }
        }
        
        stage('Scale Up Target Deployment') {
            steps {
                script {
                    echo "Scaling up ${env.TARGET_DEPLOYMENT} to ${params.REPLICAS} replicas..."
                    sh """
                        kubectl scale deployment ${env.TARGET_DEPLOYMENT} --replicas=${params.REPLICAS} -n ${NAMESPACE}
                    """
                }
            }
        }
        
        stage('Wait for Target Deployment Ready') {
            steps {
                script {
                    echo "Waiting for ${env.TARGET_DEPLOYMENT} to be ready..."
                    sh """
                        kubectl rollout status deployment/${env.TARGET_DEPLOYMENT} -n ${NAMESPACE} --timeout=5m
                    """
                }
            }
        }
        
        stage('Run Health Checks') {
            steps {
                script {
                    echo "Running health checks on ${env.TARGET_DEPLOYMENT}..."
                    sh """
                        READY_PODS=\$(kubectl get deployment ${env.TARGET_DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
                        echo "Ready Pods: \$READY_PODS"
                        
                        if [ "\$READY_PODS" != "${params.REPLICAS}" ]; then
                            echo "ERROR: Not all pods are ready!"
                            exit 1
                        fi
                        
                        kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME},version=${env.TARGET_VERSION} -o name | while read pod; do
                            echo "Testing \$pod..."
                            kubectl exec \$pod -n ${NAMESPACE} -- wget -O- -q http://localhost:80 > /dev/null
                            if [ \$? -eq 0 ]; then
                                echo "\$pod is healthy"
                            else
                                echo "ERROR: \$pod health check failed!"
                                exit 1
                            fi
                        done
                    """
                }
            }
        }
        
        stage('Switch Traffic to Target') {
            steps {
                script {
                    echo "Switching service traffic to ${env.TARGET_VERSION}..."
                    sh """
                        kubectl patch service demo-app-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"${env.TARGET_VERSION}"}}}'
                    """
                    echo "Traffic switched to ${env.TARGET_VERSION}!"
                }
            }
        }
        
        stage('Verification Period') {
            steps {
                script {
                    echo "Monitoring new deployment for 30 seconds..."
                    sleep(time: 30, unit: 'SECONDS')
                    
                    sh """
                        READY_PODS=\$(kubectl get deployment ${env.TARGET_DEPLOYMENT} -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}')
                        if [ "\$READY_PODS" != "${params.REPLICAS}" ]; then
                            echo "ERROR: Deployment became unhealthy during verification!"
                            exit 1
                        fi
                    """
                }
            }
        }
        
        stage('Scale Down Old Deployment') {
            steps {
                script {
                    echo "Scaling down ${env.ACTIVE_DEPLOYMENT}..."
                    sh """
                        kubectl scale deployment ${env.ACTIVE_DEPLOYMENT} --replicas=0 -n ${NAMESPACE}
                    """
                }
            }
        }
        
        stage('Deployment Complete') {
            steps {
                script {
                    echo "==================================="
                    echo "Blue-Green Deployment Complete!"
                    echo "Active Version: ${env.TARGET_VERSION}"
                    echo "==================================="
                    
                    sh """
                        echo "Current Service Configuration:"
                        kubectl get service demo-app-service -n ${NAMESPACE} -o yaml | grep -A 5 selector
                        
                        echo ""
                        echo "Deployment Status:"
                        kubectl get deployments -n ${NAMESPACE} -l app=${APP_NAME}
                    """
                }
            }
        }
    }
    
    post {
        failure {
            script {
                echo "Deployment failed! Rolling back..."
                sh """
                    kubectl patch service demo-app-service -n ${NAMESPACE} -p '{"spec":{"selector":{"version":"${env.ACTIVE_VERSION}"}}}'
                    kubectl scale deployment ${env.TARGET_DEPLOYMENT} --replicas=0 -n ${NAMESPACE}
                    echo "Rollback completed. Service pointing back to ${env.ACTIVE_VERSION}"
                """
            }
        }
        success {
            echo "Blue-Green deployment completed successfully!"
        }
    }
}
```

4. Save the pipeline

### Execute Blue-Green Deployment

#### Step 1: Build with Parameters

1. Go to the "Blue-Green-Deployment" job
2. Click "Build with Parameters"
3. Select parameters:
   - DEPLOYMENT_TYPE: `blue-to-green`
   - REPLICAS: `3`
4. Click "Build"

#### Step 2: Monitor Pipeline Execution

Watch the pipeline stages execute:

1. **Validate Current State**: Checks existing deployments
2. **Determine Active and Target**: Sets variables
3. **Scale Up Target Deployment**: Scales green deployment
4. **Wait for Target Deployment Ready**: Waits for pods
5. **Run Health Checks**: Validates pod health
6. **Switch Traffic to Target**: Updates service selector
7. **Verification Period**: Monitors for 30 seconds
8. **Scale Down Old Deployment**: Scales down blue
9. **Deployment Complete**: Success message

#### Step 3: Verify Deployment

```bash
# Check application
DEMO_URL=$(kubectl get svc demo-app-service -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$DEMO_URL

# Check deployments
kubectl get deployments -l app=demo-app

# Check service
kubectl get svc demo-app-service -o yaml | grep -A 3 selector
```

#### Step 4: Deploy Back to Blue

Execute the pipeline again with:
- DEPLOYMENT_TYPE: `green-to-blue`
- REPLICAS: `3`

## Capturing Screenshots and Logs

### Before Deployment

```bash
# Screenshot 1: Initial state
kubectl get deployments -l app=demo-app
kubectl get svc demo-app-service -o yaml | grep -A 3 selector
kubectl get pods -l app=demo-app
```

### During Deployment

```bash
# Screenshot 2: Green pods coming up
kubectl get pods -l app=demo-app -w

# Screenshot 3: Jenkins pipeline execution
# (Take screenshot of Jenkins UI)
```

### After Deployment

```bash
# Screenshot 4: Final state
kubectl get deployments -l app=demo-app
kubectl get svc demo-app-service -o yaml | grep -A 3 selector

# Screenshot 5: Application showing green version
# (Take screenshot of browser showing green version)
```

### Pipeline Logs

```bash
# Save Jenkins console output
# From Jenkins UI: Build → Console Output → Copy all text
```

## Best Practices

### 1. Health Checks

Always implement health checks:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:
  httpGet:
    path: /ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 2. Database Migrations

Handle database migrations carefully:
- Run migrations before deployment
- Ensure backward compatibility
- Use separate migration jobs

### 3. Session Management

For stateful applications:
- Use sticky sessions during transition
- Consider session replication
- Plan for session migration

### 4. Monitoring

Monitor during deployment:
- Error rates
- Response times
- Resource usage
- Business metrics

### 5. Rollback Plan

Always have a rollback plan:
- Document rollback steps
- Test rollback procedure
- Set time limits for verification

## Troubleshooting

### Deployment Stuck in Pending

```bash
kubectl describe pod <pod-name>
kubectl get events --sort-by='.lastTimestamp'
```

### Health Checks Failing

```bash
kubectl logs <pod-name>
kubectl exec <pod-name> -- wget -O- http://localhost:80
```

### Service Not Switching Traffic

```bash
kubectl get svc demo-app-service -o yaml
kubectl get endpoints demo-app-service
```

### Jenkins Pipeline Failing

```bash
# Check Jenkins pod logs
kubectl logs -l app=jenkins -n jenkins

# Check Jenkins service account permissions
kubectl auth can-i --list --as=system:serviceaccount:jenkins:jenkins
```

## Advanced Topics

### Canary Deployment Variant

Gradually shift traffic using multiple services:

1. Create two services (blue and green)
2. Use Ingress with weighted routing
3. Gradually shift weights: 90/10 → 75/25 → 50/50 → 0/100

### Automated Testing

Add automated testing stage:

```groovy
stage('Run Integration Tests') {
    steps {
        script {
            sh """
                # Run test suite against green deployment
                curl -f http://demo-app-green/health
                # More tests...
            """
        }
    }
}
```

### Notifications

Add Slack/email notifications:

```groovy
post {
    success {
        slackSend(
            color: 'good',
            message: "Deployment successful: ${env.TARGET_VERSION}"
        )
    }
    failure {
        slackSend(
            color: 'danger',
            message: "Deployment failed, rolled back to: ${env.ACTIVE_VERSION}"
        )
    }
}
```

## Summary

- Blue-Green deployment provides zero-downtime deployments
- Manual process gives full control
- Jenkins automation ensures consistency
- Always test thoroughly before switching traffic
- Have rollback procedures ready
- Monitor closely during and after deployment
- Document every deployment for audit trail

