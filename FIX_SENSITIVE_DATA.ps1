# Security Fix Script - Replace Hardcoded Sensitive Values
# Run this script to replace sensitive data with placeholders/variables

Write-Host "Security Fix Script - Replacing Hardcoded Sensitive Values" -ForegroundColor Yellow
Write-Host ""

$ErrorActionPreference = "Continue"

# 1. Fix Database Password in database.tf
Write-Host "1. Fixing database.tf..." -ForegroundColor Cyan
$dbFile = "infrastructure/aws/database.tf"
if (Test-Path $dbFile) {
    $content = Get-Content $dbFile -Raw
    if ($content -match 'password\s*=\s*"CHANGE_ME_PASSWORD"') {
        $newContent = $content -replace 'password\s*=\s*"CHANGE_ME_PASSWORD"\s*#.*', 'password = var.db_password  # Use variable from terraform.tfvars'
        Set-Content $dbFile -Value $newContent -NoNewline
        Write-Host "   [OK] Replaced hardcoded password with variable" -ForegroundColor Green
    } else {
        Write-Host "   [INFO] Password already uses variable or not found" -ForegroundColor Gray
    }
} else {
    Write-Host "   [WARN] File not found: $dbFile" -ForegroundColor Yellow
}

# 2. Add db_password variable to variables file
Write-Host "2. Adding db_password variable..." -ForegroundColor Cyan
$varFile = "infrastructure/aws/vairables.tf"
if (Test-Path $varFile) {
    $varContent = Get-Content $varFile -Raw
    if ($varContent -notmatch 'variable\s+"db_password"') {
        $newVar = @"

variable "db_password" {
  description = "RDS database password (set in terraform.tfvars)"
  type        = string
  sensitive   = true
}

"@
        Add-Content $varFile -Value $newVar
        Write-Host "   [OK] Added db_password variable" -ForegroundColor Green
    } else {
        Write-Host "   [INFO] Variable already exists" -ForegroundColor Gray
    }
} else {
    Write-Host "   [WARN] Variables file not found: $varFile" -ForegroundColor Yellow
}

# 3. Fix Kubernetes deployment to use Secrets
Write-Host "3. Fixing Kubernetes deployment (event-catalog.yaml)..." -ForegroundColor Cyan
$k8sFile = "k8s-gitops/apps/event-catalog.yaml"
if (Test-Path $k8sFile) {
    $k8sContent = Get-Content $k8sFile -Raw
    if ($k8sContent -match 'name: DB_PASSWORD\s+value: "CHANGE_ME_PASSWORD"') {
        $secretConfig = @"
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: password
"@
        $newK8sContent = $k8sContent -replace 'name: DB_PASSWORD\s+value: "CHANGE_ME_PASSWORD"', $secretConfig
        Set-Content $k8sFile -Value $newK8sContent -NoNewline
        Write-Host "   [OK] Replaced hardcoded password with Secret reference" -ForegroundColor Green
        Write-Host "   [WARN] Remember to create the secret: kubectl create secret generic db-credentials --from-literal=password='YOUR_PASSWORD'" -ForegroundColor Yellow
    } else {
        Write-Host "   [INFO] Password already uses Secret or not found" -ForegroundColor Gray
    }
} else {
    Write-Host "   [WARN] File not found: $k8sFile" -ForegroundColor Yellow
}

# 4. Replace AWS Account ID in Kubernetes files (with placeholder)
Write-Host "4. Replacing AWS Account ID in Kubernetes files..." -ForegroundColor Cyan
$k8sFiles = Get-ChildItem -Path "k8s-gitops/apps" -Filter "*.yaml" -ErrorAction SilentlyContinue
$accountId = "YOUR_AWS_ACCOUNT_ID"
$replacement = "YOUR_AWS_ACCOUNT_ID"
$count = 0

foreach ($file in $k8sFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match $accountId) {
        $newContent = $content -replace $accountId, $replacement
        Set-Content $file.FullName -Value $newContent -NoNewline
        $count++
        Write-Host "   [OK] Updated: $($file.Name)" -ForegroundColor Green
    }
}

if ($count -eq 0) {
    Write-Host "   [INFO] No AWS Account IDs found in Kubernetes files" -ForegroundColor Gray
} else {
    Write-Host "   [OK] Replaced AWS Account ID in $count file(s)" -ForegroundColor Green
    Write-Host "   [WARN] You'll need to set ECR_REGISTRY environment variable or use ConfigMap" -ForegroundColor Yellow
}

# 5. Replace GCP Project ID in terraform.tfvars (if it exists and is tracked)
Write-Host "5. Checking terraform.tfvars..." -ForegroundColor Cyan
$tfvarsFile = "infrastructure/gcp/terraform.tfvars"
if (Test-Path $tfvarsFile) {
    $isTracked = git ls-files --error-unmatch $tfvarsFile 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   [WARN] WARNING: terraform.tfvars is tracked in Git!" -ForegroundColor Red
        Write-Host "   Run: git rm --cached $tfvarsFile" -ForegroundColor Yellow
    } else {
        Write-Host "   [OK] File is not tracked (good!)" -ForegroundColor Green
    }
} else {
    Write-Host "   [INFO] File not found (may have been deleted)" -ForegroundColor Gray
}

# 6. Replace RDS endpoint in Kubernetes (with placeholder)
Write-Host "6. Replacing hardcoded RDS endpoint..." -ForegroundColor Cyan
if (Test-Path $k8sFile) {
    $k8sContent = Get-Content $k8sFile -Raw
    if ($k8sContent -match 'terraform-\d+\.\w+\.us-east-1\.rds\.amazonaws\.com') {
        $newK8sContent = $k8sContent -replace 'value: "terraform-\d+\.\w+\.us-east-1\.rds\.amazonaws\.com"', 'valueFrom: { configMapKeyRef: { name: db-config, key: host } }'
        Set-Content $k8sFile -Value $newK8sContent -NoNewline
        Write-Host "   [OK] Replaced hardcoded RDS endpoint with ConfigMap reference" -ForegroundColor Green
    } else {
        Write-Host "   [INFO] RDS endpoint already uses variable or not found" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "[OK] Security fixes applied!" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Review the changes: git diff" -ForegroundColor White
Write-Host "2. Create Kubernetes Secret for database:" -ForegroundColor White
Write-Host "   kubectl create secret generic db-credentials --from-literal=password='YOUR_NEW_PASSWORD'" -ForegroundColor Gray
Write-Host "3. Create ConfigMap for database host:" -ForegroundColor White
Write-Host "   kubectl create configmap db-config --from-literal=host='YOUR_RDS_ENDPOINT'" -ForegroundColor Gray
Write-Host "4. Create terraform.tfvars (DO NOT COMMIT):" -ForegroundColor White
Write-Host "   Copy terraform.tfvars.example to terraform.tfvars and fill in values" -ForegroundColor Gray
Write-Host "5. Commit the changes:" -ForegroundColor White
Write-Host "   git add ." -ForegroundColor Gray
Write-Host "   git commit -m 'SECURITY: Replace hardcoded sensitive values'" -ForegroundColor Gray
Write-Host ""
Write-Host "[WARN] IMPORTANT: Rotate all passwords after committing!" -ForegroundColor Red
