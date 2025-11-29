# Step-by-Step Guide: Removing Sensitive Data from Git Repository

## ⚠️ IMPORTANT WARNINGS

1. **This process will rewrite Git history** - All collaborators must re-clone the repository
2. **Backup your repository** before proceeding
3. **Rotate all exposed credentials** after removal (change passwords, regenerate keys)
4. **Test thoroughly** after making changes

---

## Prerequisites

1. Install `git-filter-repo` (recommended) or use `git filter-branch` (older method)
2. Backup your repository
3. Ensure you have admin access to the remote repository

### Install git-filter-repo (Recommended)

**Windows (PowerShell):**
```powershell
pip install git-filter-repo
```

**Alternative (if pip doesn't work):**
```powershell
# Download from: https://github.com/newren/git-filter-repo/releases
# Or use git filter-branch (see below)
```

---

## Step 1: Backup Your Repository

```powershell
# Create a backup
cd "C:\Users\nishi\Cloud Computing"
Copy-Item -Path "Assignment Attempt 2" -Destination "Assignment Attempt 2 - BACKUP" -Recurse
```

---

## Step 2: Remove Sensitive Files from Git History

### 2.1 Remove Terraform State Files (CRITICAL)

These files should never be in version control:

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"

# Remove from current working directory first
git rm --cached infrastructure/aws/terraform.tfstate.1764264835.backup
git rm --cached infrastructure/aws/terraform.tfstate.1764264836.backup
git rm --cached infrastructure/aws/terraform.tfstate.1764265242.backup
git rm --cached infrastructure/aws/terraform.tfstate.broken

# Remove from Git history using git-filter-repo
git filter-repo --path infrastructure/aws/terraform.tfstate.1764264835.backup --invert-paths
git filter-repo --path infrastructure/aws/terraform.tfstate.1764264836.backup --invert-paths
git filter-repo --path infrastructure/aws/terraform.tfstate.1764265242.backup --invert-paths
git filter-repo --path infrastructure/aws/terraform.tfstate.broken --invert-paths
```

**Alternative using git filter-branch (if git-filter-repo not available):**
```powershell
git filter-branch --force --index-filter `
  "git rm --cached --ignore-unmatch infrastructure/aws/terraform.tfstate.1764264835.backup infrastructure/aws/terraform.tfstate.1764264836.backup infrastructure/aws/terraform.tfstate.1764265242.backup infrastructure/aws/terraform.tfstate.broken" `
  --prune-empty --tag-name-filter cat -- --all
```

### 2.2 Remove terraform.tfvars (CRITICAL)

```powershell
# Remove from Git history
git filter-repo --path infrastructure/gcp/terraform.tfvars --invert-paths
```

**Note:** The `.gitignore` should already exclude `*.tfvars`, but we need to remove it from history.

---

## Step 3: Replace Sensitive Values in Files

### 3.1 Replace Database Password

**Files to update:**
- `infrastructure/aws/database.tf`
- `k8s-gitops/apps/event-catalog.yaml`
- `FINAL_SETUP.md`

**Method 1: Use git-filter-repo to replace in history**

```powershell
# Replace password in all files throughout history
git filter-repo --replace-text <(echo "CHANGE_ME_PASSWORD==>CHANGE_ME_PASSWORD")
```

**Method 2: Manual replacement (then commit)**

1. Edit `infrastructure/aws/database.tf`:
   ```hcl
   password = var.db_password  # Use variable instead
   ```

2. Edit `k8s-gitops/apps/event-catalog.yaml`:
   ```yaml
   - name: DB_PASSWORD
     valueFrom:
       secretKeyRef:
         name: db-credentials
         key: password
   ```

3. Update `FINAL_SETUP.md` to remove hardcoded password references

### 3.2 Replace AWS Account ID

**Option A: Use git-filter-repo (removes from all history)**
```powershell
git filter-repo --replace-text <(echo "YOUR_AWS_ACCOUNT_ID==>YOUR_AWS_ACCOUNT_ID")
```

**Option B: Manual replacement in current files**

Create a script to replace in all files:
```powershell
# PowerShell script to replace AWS Account ID
$files = Get-ChildItem -Recurse -File | Where-Object { $_.Extension -in '.yaml','.yml','.md','.txt','.ps1','.js','.py','.tf' }
foreach ($file in $files) {
    (Get-Content $file.FullName) -replace 'YOUR_AWS_ACCOUNT_ID', 'YOUR_AWS_ACCOUNT_ID' | Set-Content $file.FullName
}
```

**Files to update manually:**
- All files in `k8s-gitops/apps/` - Replace ECR URLs with variables
- `FINAL_SETUP.md` - Replace with placeholder
- `services/README.md` - Replace with placeholder

### 3.3 Replace GCP Project ID

```powershell
# Using git-filter-repo
git filter-repo --replace-text <(echo "YOUR_GCP_PROJECT_ID==>YOUR_GCP_PROJECT_ID")
```

Or manually replace in:
- `infrastructure/gcp/terraform.tfvars` (should be gitignored, but remove from history)
- All documentation files

### 3.4 Replace RDS Endpoints

```powershell
# Replace specific RDS endpoints
git filter-repo --replace-text <(echo "terraform-20251126034838499800000014.cov0iwq0wygo.us-east-1.rds.amazonaws.com==>YOUR_RDS_ENDPOINT")
git filter-repo --replace-text <(echo "terraform-20251120151945012200000013.cov0iwq0wygo.us-east-1.rds.amazonaws.com==>YOUR_RDS_ENDPOINT")
```

Update `k8s-gitops/apps/event-catalog.yaml` to use environment variables or ConfigMaps instead.

### 3.5 Replace Kafka Broker Endpoints

Replace with variables or ConfigMaps. Update:
- `infrastructure/gcp/terraform.tfvars` (use variable)
- `k8s-gitops/apps/booking-service.yaml` (use ConfigMap/Secret)

---

## Step 4: Update .gitignore (Ensure Future Protection)

Verify `.gitignore` includes:

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfstate.*
*.tfvars
!terraform.tfvars.example

# Credentials
*.json
credentials.json
*.pem
*.key
*.env
.env*

# Sensitive configs
**/secrets/
**/credentials/
```

---

## Step 5: Use Environment Variables and Secrets

### 5.1 Create Kubernetes Secrets for Database

```yaml
# k8s-gitops/secrets/db-credentials.yaml (DO NOT COMMIT - use Sealed Secrets or External Secrets)
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: default
type: Opaque
stringData:
  password: "your-actual-password-here"
  host: "your-rds-endpoint-here"
```

### 5.2 Update Terraform to Use Variables

**infrastructure/aws/database.tf:**
```hcl
variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}

resource "aws_db_instance" "default" {
  # ... other config ...
  password = var.db_password
}
```

**infrastructure/aws/terraform.tfvars.example:**
```hcl
db_password = "CHANGE_ME"
```

### 5.3 Update Kubernetes Deployments

**k8s-gitops/apps/event-catalog.yaml:**
```yaml
env:
  - name: DB_HOST
    valueFrom:
      configMapKeyRef:
        name: db-config
        key: host
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-credentials
        key: password
```

---

## Step 6: Force Push to Remote (DANGEROUS - READ CAREFULLY)

⚠️ **WARNING:** This rewrites history. All collaborators must re-clone.

```powershell
# Verify your changes first
git log --oneline

# Force push (this will overwrite remote history)
git push origin --force --all
git push origin --force --tags
```

**Alternative: Create a new branch and migrate**
```powershell
# Safer approach - create cleaned branch
git checkout -b cleaned-history
# ... make all changes ...
git push origin cleaned-history
# Then make it the default branch in GitHub settings
```

---

## Step 7: Rotate All Exposed Credentials

**CRITICAL:** After removing from Git, you MUST:

1. **Change Database Password:**
   ```powershell
   # Update RDS password via AWS Console or:
   aws rds modify-db-instance --db-instance-identifier your-instance --master-user-password "NEW_SECURE_PASSWORD"
   ```

2. **Regenerate AWS Access Keys** (if they were ever committed)
   - Go to AWS IAM Console
   - Delete old access keys
   - Create new ones

3. **Review GCP Service Account Keys**
   - Check if any keys were committed
   - Rotate if necessary

4. **Update Kubernetes Secrets** with new passwords

---

## Step 8: Verify Removal

```powershell
# Search for sensitive data in current files
Select-String -Path . -Pattern "CHANGE_ME_PASSWORD" -Recurse
Select-String -Path . -Pattern "YOUR_AWS_ACCOUNT_ID" -Recurse
Select-String -Path . -Pattern "YOUR_GCP_PROJECT_ID" -Recurse

# Check Git history (if using git-filter-repo, history should be clean)
git log --all --full-history -- "**/terraform.tfstate*"
```

---

## Step 9: Notify Collaborators

Send a message to all collaborators:

```
⚠️ IMPORTANT: Repository History Rewritten

We've removed sensitive information from the repository history.
You MUST re-clone the repository:

1. Backup your local changes
2. Delete your local repository
3. Clone fresh: git clone <repo-url>
4. Re-apply any local changes

Do NOT pull/merge - you must re-clone.
```

---

## Alternative: Less Destructive Approach

If you can't rewrite history (e.g., many collaborators), use this approach:

### Option A: Add to .gitignore and Document

1. Add all sensitive files to `.gitignore`
2. Remove from current working directory
3. Document in README that these should not be committed
4. Accept that old history contains sensitive data (but it's not in current state)

### Option B: Use Git LFS with Encryption

For files that must be tracked but contain sensitive data.

---

## Quick Reference: Files to Update

### High Priority (Do First)
- [ ] `infrastructure/aws/database.tf` - Remove hardcoded password
- [ ] `k8s-gitops/apps/event-catalog.yaml` - Use Secrets for password
- [ ] `infrastructure/gcp/terraform.tfvars` - Remove from Git
- [ ] All `terraform.tfstate*.backup` files - Remove from Git

### Medium Priority
- [ ] All `k8s-gitops/apps/*.yaml` - Replace ECR URLs with variables
- [ ] `FINAL_SETUP.md` - Replace hardcoded values
- [ ] `services/README.md` - Replace hardcoded values

### Low Priority
- [ ] Documentation files - Replace with placeholders
- [ ] Script files - Use environment variables

---

## Testing After Changes

1. **Test Terraform:**
   ```powershell
   cd infrastructure/aws
   terraform init
   terraform plan  # Should work with variables
   ```

2. **Test Kubernetes Deployments:**
   ```powershell
   kubectl apply -f k8s-gitops/apps/event-catalog.yaml
   kubectl get pods
   ```

3. **Verify Secrets:**
   ```powershell
   kubectl get secrets
   kubectl describe secret db-credentials
   ```

---

## Need Help?

If you encounter issues:
1. Restore from backup
2. Use `git reflog` to recover
3. Consider using GitHub's secret scanning (enable in repository settings)
4. Use tools like `truffleHog` or `git-secrets` to scan for secrets

---

## Prevention for Future

1. **Pre-commit Hooks:**
   ```powershell
   # Install git-secrets
   git secrets --install
   git secrets --register-aws
   ```

2. **GitHub Secret Scanning:**
   - Enable in repository settings
   - GitHub will automatically scan for secrets

3. **Code Review:**
   - Always review diffs before merging
   - Look for hardcoded credentials

4. **Use Secret Management:**
   - AWS Secrets Manager
   - Kubernetes Secrets
   - HashiCorp Vault
   - Never commit secrets to Git

