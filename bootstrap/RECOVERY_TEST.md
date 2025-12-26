# Bootstrap Recovery Test Plan

## Purpose
Verify that bootstrap layer can deploy from scratch (Day 0) without manual intervention.

## Prerequisites
- Clean K3s cluster
- All secrets in 1Password
- Terraform/Terragrunt installed

## Test Procedure

### 1. Clean Environment (Simulated Disaster)
```bash
# Delete all bootstrap resources
kubectl delete namespace bootstrap platform --ignore-not-found=true

# Remove Terraform state (use with caution!)
# cd bootstrap && rm -rf .terraform terraform.tfstate*
```

### 2. Fresh Bootstrap Deployment
```bash
cd bootstrap

# Set required environment variables
export R2_BUCKET="your-r2-bucket"
export R2_ACCOUNT_ID="your-r2-account-id"
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"

# Run Terragrunt apply
terragrunt apply -auto-approve
```

### 3. Validation Checklist

#### Platform PostgreSQL
```bash
# Check cluster health
kubectl get cluster -n platform platform-pg
# Expected: STATUS = "Cluster in healthy state"

# Verify databases exist
kubectl exec -n platform platform-pg-1 -- psql -U postgres -l
# Expected: vault, casdoor, digger databases present

# Test password authentication
kubectl get secret -n platform platform-pg-superuser -o jsonpath='{.data.password}' | base64 -d
kubectl run -n platform psql-test --rm -it --image=postgres:16 \
  --env="PGPASSWORD=$(kubectl get secret -n platform platform-pg-superuser -o jsonpath='{.data.password}' | base64 -d)" \
  -- psql -h platform-pg-rw.platform.svc.cluster.local -U postgres -d digger -c "SELECT current_database();"
# Expected: Returns "digger", no authentication errors
```

#### Digger Orchestrator
```bash
# Check pod status
kubectl get pods -n bootstrap -l app.kubernetes.io/instance=digger
# Expected: All pods READY 1/1, STATUS Running

# Check logs for errors
kubectl logs -n bootstrap -l app.kubernetes.io/instance=digger --tail=50
# Expected: No authentication errors, "Listening and serving HTTP on :3000"

# Test health endpoint
curl -k https://digger.zitian.party/health
# Expected: {"build_date":"...","deployed_at":"..."}

# Test PostgreSQL connection from Digger
kubectl exec -n bootstrap deployment/digger-digger-backend-web -- \
  sh -c 'psql $DATABASE_URL -c "SELECT current_database();"'
# Expected: Returns "digger", no errors
```

#### Digger Secret Consistency
```bash
# Compare passwords
diff <(kubectl get secret -n platform platform-pg-superuser -o jsonpath='{.data.password}' | base64 -d) \
     <(kubectl get secret -n bootstrap digger-digger-backend-postgres-secret -o jsonpath='{.data.postgres-password}' | base64 -d)
# Expected: No diff, passwords match
```

### 4. Expected Results

✅ **Success Criteria:**
1. Platform PostgreSQL cluster is healthy
2. All databases (vault, casdoor, digger) exist
3. Digger pods are running without CrashLoopBackOff
4. Digger can connect to PostgreSQL without authentication errors
5. Digger health endpoint responds successfully
6. All secrets are consistent

❌ **Failure Indicators:**
- Digger pods in CrashLoopBackOff
- PostgreSQL authentication failures in logs
- Digger health endpoint unreachable
- Password mismatch between secrets

## Recovery from Failure

If password drift is detected after deployment:

```bash
# 1. Get the correct password from secret
NEW_PASS=$(kubectl get secret -n platform platform-pg-superuser -o jsonpath='{.data.password}' | base64 -d)

# 2. Sync PostgreSQL password
kubectl exec -n platform platform-pg-1 -- \
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD '$NEW_PASS';"

# 3. Restart Digger to reconnect with new password
kubectl rollout restart -n bootstrap deployment/digger-digger-backend-web

# 4. Verify recovery
kubectl logs -n bootstrap -l app.kubernetes.io/instance=digger --tail=20
```

## Notes

- CNPG's `superuserSecret` mechanism ensures correct password on fresh bootstrap
- No manual password sync should be needed on Day 0
- Password drift is only an issue on existing deployments where secrets were manually updated
- The `cnpg.io/reload` label on platform-pg-superuser secret tells CNPG to watch for changes,
  but it only updates password files, NOT the PostgreSQL password hash
