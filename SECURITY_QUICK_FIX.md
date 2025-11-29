# Quick Fix: Remove Sensitive Data (Immediate Actions)

## 🚨 URGENT: Files to Remove Right Now

These files contain sensitive information and should be removed from the repository immediately:

### 1. Remove Terraform State Backup Files (DO THIS FIRST)

```powershell
cd "C:\Users\nishi\Cloud Computing\Assignment Attempt 2"

# Remove from Git tracking
git rm --cached infrastructure/aws/terraform.tfstate.1764264835.backup
git rm --cached infrastructure/aws/terraform.tfstate.1764264836.backup
git rm --cached infrastructure/aws/terraform.tfstate.1764265242.backup
git rm --cached infrastructure/aws/terraform.tfstate.broken

# Delete the files
Remove-Item infrastructure/aws/terraform.tfstate.1764264835.backup -ErrorAction SilentlyContinue
Remove-Item infrastructure/aws/terraform.tfstate.1764264836.backup -ErrorAction SilentlyContinue
Remove-Item infrastructure/aws/terraform.tfstate.1764265242.backup -ErrorAction SilentlyContinue
Remove-Item infrastructure/aws/terraform.tfstate.broken -ErrorAction SilentlyContinue

# Commit the removal
git commit -m "SECURITY: Remove terraform state backup files containing sensitive data"
```

### 2. Remove terraform.tfvars from Git

```powershell
# Check if it's tracked
git ls-files infrastructure/gcp/terraform.tfvars

# If it shows up, remove it
git rm --cached infrastructure/gcp/terraform.tfvars
git commit -m "SECURITY: Remove terraform.tfvars containing sensitive project IDs"
```

### 3. Update .gitignore (Ensure Protection)

Verify these lines exist in `.gitignore`:

```gitignore
*.tfstate
*.tfstate.backup
*.tfstate.*
*.tfvars
!terraform.tfvars.example
```

---

## 🔧 Quick Code Fixes (Before Next Commit)

### Fix 1: Database Password in database.tf

**Current (INSECURE):**
```hcl
password = "CHANGE_ME_PASSWORD"
```

**Fix:**
```hcl
variable "db_password" {
  description = "RDS database password"
  type        = string
  sensitive   = true
}

# In resource:
password = var.db_password
```

### Fix 2: Database Password in Kubernetes

**Current (INSECURE in `k8s-gitops/apps/event-catalog.yaml`):**
```yaml
- name: DB_PASSWORD
  value: "CHANGE_ME_PASSWORD"
```

**Fix:**
```yaml
- name: DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: db-credentials
      key: password
```

Then create the secret separately (DO NOT commit):
```powershell
kubectl create secret generic db-credentials `
  --from-literal=password='YOUR_NEW_PASSWORD' `
  --from-literal=host='YOUR_RDS_ENDPOINT'
```

### Fix 3: Replace Hardcoded AWS Account ID

**In all `k8s-gitops/apps/*.yaml` files:**

Replace:
```yaml
image: YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ticket-booking/frontend:latest
```

With variable or ConfigMap:
```yaml
image: ${ECR_REGISTRY}/ticket-booking/frontend:latest
```

Or use a ConfigMap:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  ecr-registry: "YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com"
```

---

## 📋 Checklist

### Immediate (Do Now)
- [ ] Remove terraform state backup files from Git
- [ ] Remove terraform.tfvars from Git (if tracked)
- [ ] Update .gitignore
- [ ] Commit these changes

### Before Next Push
- [ ] Replace hardcoded database password with variable/secret
- [ ] Replace hardcoded AWS account ID with variable
- [ ] Replace hardcoded GCP project ID with variable
- [ ] Replace hardcoded RDS endpoint with variable/ConfigMap
- [ ] Test that everything still works

### After Removal
- [ ] **ROTATE ALL PASSWORDS** (database, etc.)
- [ ] Update Kubernetes secrets with new passwords
- [ ] Verify no sensitive data in current files
- [ ] Consider rewriting Git history (see REMOVE_SENSITIVE_DATA_GUIDE.md)

---

## ⚠️ Critical: Rotate Credentials

After removing from Git, you MUST change:

1. **Database Password:**
   ```powershell
   # Via AWS Console: RDS > Modify > Change Master Password
   # Or via CLI:
   aws rds modify-db-instance `
     --db-instance-identifier your-instance-name `
     --master-user-password "NEW_SECURE_PASSWORD"
   ```

2. **Any AWS Access Keys** (if they were ever in the repo)

3. **GCP Service Account Keys** (if any were committed)

---

## Quick Test

After making changes, verify:

```powershell
# Check no sensitive data in tracked files
git grep "CHANGE_ME_PASSWORD"
git grep "YOUR_AWS_ACCOUNT_ID"
git grep "YOUR_GCP_PROJECT_ID"

# Should return no results (or only in .gitignore'd files)
```

---

## Next Steps

1. **Immediate:** Remove files listed above
2. **Short-term:** Replace hardcoded values with variables/secrets
3. **Long-term:** Follow `REMOVE_SENSITIVE_DATA_GUIDE.md` to clean Git history

---

## Need Help?

- See `SECURITY_AUDIT_REPORT.md` for full list of issues
- See `REMOVE_SENSITIVE_DATA_GUIDE.md` for detailed removal steps
- Enable GitHub Secret Scanning in repository settings

