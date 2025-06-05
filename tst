You're right, the `gp2` storage class alone won't fix the underlying authentication issues. Let me help you troubleshoot this more systematically.Based on the search results, this is a common authentication issue with the EBS CSI driver. Let me provide you with a comprehensive troubleshooting approach:

## Diagnostic Steps First

Let's diagnose the current state:

**1. Check if EBS CSI driver is installed:**
```bash
kubectl get pods -n kube-system | grep ebs-csi
```

**2. Check the service account:**
```bash
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o yaml
```

**3. Check if OIDC provider exists:**
```bash
aws eks describe-cluster --name <your-cluster-name> --query "cluster.identity.oidc.issuer" --output text
```

**4. List current IAM roles for service accounts:**
```bash
eksctl get iamserviceaccount --cluster <your-cluster-name>
```

## Root Cause and Fix

The error "WebIdentityErr" occurs when the service role associated with your EKS pod can't perform the STS operation on the AssumeRoleWithWebIdentity action. Here's the systematic fix:

### Step 1: Remove Existing Broken Configuration
```bash
# Remove existing addon if present
eksctl delete addon --cluster <your-cluster-name> --name aws-ebs-csi-driver

# Remove existing service account
eksctl delete iamserviceaccount --cluster <your-cluster-name> --name ebs-csi-controller-sa --namespace kube-system
```

### Step 2: Recreate OIDC Provider Association
```bash
eksctl utils associate-iam-oidc-provider --cluster <your-cluster-name> --approve
```

### Step 3: Create IAM Role and Service Account Correctly
```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create the service account with proper IAM role
eksctl create iamserviceaccount \
  --cluster <your-cluster-name> \
  --namespace kube-system \
  --name ebs-csi-controller-sa \
  --role-name AmazonEKS_EBS_CSI_DriverRole \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
  --approve \
  --override-existing-serviceaccounts
```

### Step 4: Install EBS CSI Driver Addon
```bash
eksctl create addon \
  --cluster <your-cluster-name> \
  --name aws-ebs-csi-driver \
  --service-account-role-arn arn:aws:iam::${ACCOUNT_ID}:role/AmazonEKS_EBS_CSI_DriverRole \
  --force
```

### Step 5: Verify the Configuration

**Check the service account annotation:**
```bash
kubectl get serviceaccount ebs-csi-controller-sa -n kube-system -o yaml
```

You should see an annotation like:
```yaml
annotations:
  eks.amazonaws.com/role-arn: arn:aws:iam::ACCOUNT_ID:role/AmazonEKS_EBS_CSI_DriverRole
```

**Check EBS CSI pods are running:**
```bash
kubectl get pods -n kube-system | grep ebs-csi
```

### Step 6: Alternative Manual Installation

If the addon approach fails, install manually:

```bash
# Apply the EBS CSI driver manifests
kubectl apply -k "github.com/kubernetes-sigs/aws-ebs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-1.25"

# Patch the deployment to use the service account
kubectl patch deployment ebs-csi-controller -n kube-system -p '{"spec":{"template":{"spec":{"serviceAccountName":"ebs-csi-controller-sa"}}}}'
```

### Step 7: Test with Simple PVC

Create a test PVC to verify:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ebs-test-claim
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2
  resources:
    requests:
      storage: 4Gi
```

## Common Issues to Check

1. **Trust Relationship**: Ensure the IAM role has correct trust relationship with your cluster's OIDC provider
2. **Service Account Name**: Must be exactly `ebs-csi-controller-sa` in `kube-system` namespace
3. **EKS Version**: Ensure you're using a supported EKS version (1.23+)

After following these steps, try creating your Elasticsearch cluster again. The authentication errors should be resolved.
