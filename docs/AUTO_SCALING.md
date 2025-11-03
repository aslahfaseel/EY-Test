# Auto-Scaling Guide

This document explains the auto-scaling mechanisms implemented in this project and how to demonstrate them.

## Overview

Two types of auto-scaling are implemented:

1. **Horizontal Pod Autoscaler (HPA)**: Scales pods based on resource utilization
2. **Cluster Autoscaler**: Scales nodes based on pod resource requirements

## Horizontal Pod Autoscaler (HPA)

### How It Works

HPA automatically scales the number of pods based on observed metrics:
- CPU utilization
- Memory utilization
- Custom metrics (optional)

### Configuration

The nginx-test application uses the following HPA configuration:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: nginx-test-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nginx-test
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70
```

**Key Parameters**:
- `minReplicas: 2` - Minimum pods (never scales below this)
- `maxReplicas: 10` - Maximum pods (never scales above this)
- `cpu: 50%` - Scale when average CPU exceeds 50%
- `memory: 70%` - Scale when average memory exceeds 70%

### Testing HPA

#### Step 1: Check Initial State

```bash
kubectl get hpa
kubectl get pods -l app=nginx-test
```

You should see 2 pods (minimum replicas).

#### Step 2: Deploy Load Generator

```bash
kubectl apply -f k8s-manifests/load-generator/load-test.yaml
```

This creates a pod that continuously sends requests to the nginx service.

#### Step 3: Watch Scaling in Real-Time

Open multiple terminal windows:

**Terminal 1**: Watch HPA
```bash
kubectl get hpa -w
```

**Terminal 2**: Watch Pods
```bash
kubectl get pods -l app=nginx-test -w
```

**Terminal 3**: Check Resource Usage
```bash
watch -n 5 'kubectl top pods -l app=nginx-test'
```

**Terminal 4**: View HPA Events
```bash
kubectl get events --field-selector involvedObject.name=nginx-test-hpa -w
```

#### Step 4: Observe Scale-Up

Within 1-3 minutes, you should see:

1. CPU utilization increase above 50%
2. HPA target percentage exceed 100%
3. New pods being created
4. Pods transitioning from Pending → ContainerCreating → Running

Example output:
```
NAME              REFERENCE               TARGETS    MINPODS   MAXPODS   REPLICAS
nginx-test-hpa    Deployment/nginx-test   95%/50%    2         10        2

# After ~30 seconds
nginx-test-hpa    Deployment/nginx-test   120%/50%   2         10        4

# After ~1 minute
nginx-test-hpa    Deployment/nginx-test   80%/50%    2         10        6
```

#### Step 5: Stop Load Test

```bash
kubectl delete pod load-generator
```

#### Step 6: Observe Scale-Down

After the stabilization window (5 minutes), pods will scale down:

```bash
# Watch the scale-down
kubectl get hpa -w
```

Scale-down behavior:
- Waits 5 minutes (stabilization window)
- Reduces replicas by 50% at a time
- Takes 15 seconds between scale-down decisions

### HPA Metrics Explained

View detailed HPA status:

```bash
kubectl describe hpa nginx-test-hpa
```

Key sections:

**Current Metrics**:
```
Metrics:                                               ( current / target )
  resource cpu on pods  (as a percentage of request):  45% (45m) / 50%
  resource memory on pods (as a percentage of request): 30% (38Mi) / 70%
```

**Events**:
```
Normal  SuccessfulRescale  HorizontalPodAutoscaler  New size: 4; reason: cpu resource utilization (percentage of request) above target
Normal  SuccessfulRescale  HorizontalPodAutoscaler  New size: 2; reason: All metrics below target
```

### HPA Best Practices

1. **Resource Requests**: Always set resource requests on pods
   ```yaml
   resources:
     requests:
       cpu: 100m
       memory: 128Mi
   ```

2. **Appropriate Targets**: Set realistic CPU/memory targets
   - Too low: Excessive scaling
   - Too high: Poor performance

3. **Min/Max Replicas**: Balance cost and capacity
   - Min: Ensures availability
   - Max: Controls costs

4. **Stabilization Window**: Prevents flapping
   - Scale-up: 0 seconds (fast response)
   - Scale-down: 300 seconds (cautious)

## Cluster Autoscaler

### How It Works

Cluster Autoscaler adjusts the number of nodes when:
- Pods can't be scheduled due to insufficient resources (scale up)
- Nodes are underutilized for extended period (scale down)

### Configuration

Node group is configured with:
- `min_size: 2` - Always maintain 2 nodes
- `max_size: 5` - Scale up to 5 nodes maximum
- `desired_size: 2` - Start with 2 nodes

### Testing Cluster Autoscaler

#### Step 1: Check Current Nodes

```bash
kubectl get nodes
```

You should see 2 nodes.

#### Step 2: Check Node Resources

```bash
kubectl describe nodes | grep -A 5 "Allocated resources"
```

#### Step 3: Create Resource Pressure

Scale nginx deployment to require more nodes:

```bash
kubectl scale deployment nginx-test --replicas=20
```

#### Step 4: Watch for Pending Pods

```bash
kubectl get pods -l app=nginx-test -w
```

Some pods will be in "Pending" state due to insufficient resources.

#### Step 5: Check Cluster Autoscaler Logs

```bash
kubectl logs -f deployment/cluster-autoscaler -n kube-system
```

Look for messages like:
```
Scale-up: setting group size to 3
```

#### Step 6: Watch Nodes Being Added

```bash
kubectl get nodes -w
```

Within 3-5 minutes, new nodes will appear:
```
NAME                             STATUS     ROLES    AGE   VERSION
ip-10-0-10-123.ec2.internal     Ready      <none>   10m   v1.28.3
ip-10-0-11-124.ec2.internal     Ready      <none>   10m   v1.28.3
ip-10-0-12-125.ec2.internal     NotReady   <none>   5s    v1.28.3

# After initialization
ip-10-0-12-125.ec2.internal     Ready      <none>   2m    v1.28.3
```

#### Step 7: Verify Pods Scheduled

```bash
kubectl get pods -l app=nginx-test
```

All 20 pods should now be running.

#### Step 8: Trigger Scale-Down

```bash
kubectl scale deployment nginx-test --replicas=2
```

#### Step 9: Watch Scale-Down (10-15 minutes)

```bash
kubectl get nodes -w
```

After ~10 minutes of underutilization, extra nodes will be removed.

### Cluster Autoscaler Logs Analysis

View detailed logs:

```bash
kubectl logs deployment/cluster-autoscaler -n kube-system --tail=100
```

**Scale-Up Indicators**:
```
Pod triggered scale-up: default/nginx-test-xxx
Estimated 1 nodes needed in node group
Scale-up: setting group size to 3
```

**Scale-Down Indicators**:
```
Node ip-10-0-12-125.ec2.internal is unneeded since 2023-11-01 10:00:00
```

**Useful Commands**:
```bash
# Check autoscaler status
kubectl get configmap cluster-autoscaler-status -n kube-system -o yaml

# View scale events
kubectl get events -n kube-system --sort-by='.lastTimestamp' | grep cluster-autoscaler

# Check node group status
aws eks describe-nodegroup --cluster-name <cluster-name> --nodegroup-name <nodegroup-name>
```

### Cluster Autoscaler Best Practices

1. **Node Affinity**: Use node selectors and affinity rules
2. **Pod Disruption Budgets**: Prevent unwanted pod evictions
3. **Resource Requests**: Always set accurate requests
4. **Monitoring**: Watch autoscaler logs regularly

## Combined Scaling Scenario

### Realistic Load Test

This demonstrates both HPA and Cluster Autoscaler working together:

```bash
# Step 1: Generate high load
kubectl apply -f k8s-manifests/load-generator/load-test.yaml

# Step 2: Watch HPA scale pods
kubectl get hpa -w
# Pods will scale to 10 (max replicas)

# Step 3: Some pods will be pending
kubectl get pods -l app=nginx-test

# Step 4: Cluster Autoscaler adds nodes
kubectl get nodes -w
# New nodes will be added

# Step 5: All pods become Running
kubectl get pods -l app=nginx-test

# Step 6: Stop load test
kubectl delete pod load-generator

# Step 7: Watch scale-down
# - First HPA reduces pods (5 minutes)
# - Then Cluster Autoscaler removes nodes (10 minutes)
```

### Timeline

```
Time    Event
----    -----
0:00    Load test starts
0:30    HPA detects high CPU
1:00    HPA scales to 4 pods
1:30    HPA scales to 6 pods
2:00    HPA scales to 8 pods
2:30    HPA scales to 10 pods (max)
3:00    Some pods pending (no resources)
3:30    Cluster Autoscaler detects pending pods
5:00    New nodes added, pods scheduled
6:00    All systems stable

-- Load test stopped --

11:00   HPA scales down to 8 pods
16:00   HPA scales down to 6 pods
21:00   HPA scales down to 4 pods
26:00   HPA scales down to 2 pods
36:00   Cluster Autoscaler detects underutilized nodes
46:00   Nodes start draining
50:00   Nodes removed, back to 2 nodes
```

## Monitoring and Alerting

### Key Metrics to Monitor

1. **HPA Metrics**:
   ```bash
   kubectl get hpa
   kubectl top pods
   ```

2. **Node Metrics**:
   ```bash
   kubectl top nodes
   kubectl describe nodes
   ```

3. **Cluster Autoscaler**:
   ```bash
   kubectl logs -l app=cluster-autoscaler -n kube-system
   ```

### CloudWatch Integration

View metrics in AWS CloudWatch:

1. Navigate to CloudWatch Console
2. Select "Container Insights"
3. Choose your EKS cluster
4. View metrics and logs

### Creating Alerts

Example alert configurations:

**High Pod CPU**:
- Metric: Container CPU
- Threshold: > 80%
- Duration: 5 minutes

**Node High Utilization**:
- Metric: Node CPU
- Threshold: > 85%
- Duration: 10 minutes

**Failed to Scale**:
- Metric: Cluster Autoscaler errors
- Condition: Any errors in logs

## Screenshots for Documentation

### Capture These Screenshots

1. **Initial State**:
   ```bash
   kubectl get pods -l app=nginx-test
   kubectl get hpa
   kubectl get nodes
   ```

2. **During Load Test**:
   ```bash
   kubectl top pods -l app=nginx-test
   kubectl get hpa
   ```

3. **After Scaling**:
   ```bash
   kubectl get pods -l app=nginx-test
   kubectl get nodes
   ```

4. **HPA Details**:
   ```bash
   kubectl describe hpa nginx-test-hpa
   ```

5. **Cluster Autoscaler Logs**:
   ```bash
   kubectl logs deployment/cluster-autoscaler -n kube-system | tail -50
   ```

## Troubleshooting Auto-Scaling

### HPA Not Scaling

**Check Metrics Server**:
```bash
kubectl get apiservice v1beta1.metrics.k8s.io
kubectl top nodes
```

**Check Resource Requests**:
```bash
kubectl describe deployment nginx-test
```

### Cluster Autoscaler Not Scaling

**Check Logs**:
```bash
kubectl logs -l app=cluster-autoscaler -n kube-system
```

**Check IAM Permissions**:
```bash
aws iam get-role --role-name <cluster-autoscaler-role>
```

**Check Node Group Tags**:
```bash
aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[*].Tags'
```

### Common Issues

1. **Metrics Not Available**: Wait 1-2 minutes after deployment
2. **Slow Scaling**: Normal, can take 2-5 minutes
3. **Won't Scale Down**: Check stabilization window and PDBs
4. **Nodes Not Added**: Check node group max size and IAM permissions

## Summary

- HPA scales pods based on resource utilization (1-3 minutes)
- Cluster Autoscaler scales nodes based on resource needs (3-5 minutes)
- Scale-up is fast, scale-down is cautious (5-15 minutes)
- Both work together to optimize cost and performance
- Always monitor and adjust thresholds based on your workload

