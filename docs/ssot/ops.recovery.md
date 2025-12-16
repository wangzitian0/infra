# 故障恢复 SSOT

> **核心问题**：出问题了怎么恢复？

---

## Secrets 恢复

### 从 1Password 恢复 GitHub Secret

```bash
# 示例：恢复 VAULT_POSTGRES_PASSWORD
gh secret set VAULT_POSTGRES_PASSWORD \
  --body "$(op item get 'PostgreSQL (Platform)' --vault my_cloud --fields VAULT_POSTGRES_PASSWORD --reveal)"

# 示例：恢复 VPS_SSH_KEY
gh secret set VPS_SSH_KEY \
  --body "$(op item get 'VPS SSH' --vault my_cloud --fields VPS_SSH_KEY --reveal)"
```

### 批量恢复（灾难恢复）

```bash
# Cloudflare
for f in BASE_DOMAIN CLOUDFLARE_ZONE_ID INTERNAL_DOMAIN INTERNAL_ZONE_ID CLOUDFLARE_API_TOKEN; do
  gh secret set $f --body "$(op item get 'Cloudflare API' --vault my_cloud --fields $f --reveal)"
done

# R2/AWS
for f in R2_BUCKET R2_ACCOUNT_ID AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  gh secret set $f --body "$(op item get 'R2 Backend (AWS)' --vault my_cloud --fields $f --reveal)"
done
```

---

## Vault Token 过期

```bash
# 1. 获取新 token
op read 'op://Infrastructure/Vault Root Token/credential'

# 2. 更新 GitHub Secret
gh secret set VAULT_ROOT_TOKEN --body "<token>" --repo wangzitian0/infra

# 3. Apply L1 (更新 Atlantis Pod)
cd 1.bootstrap
terraform apply

# 4. 重试 Atlantis plan
# 在 PR 评论: atlantis plan（或 push 触发 autoplan）
```

---

## State Lock

```bash
# PR 评论
atlantis unlock
atlantis plan
```

---

## Provider 版本不匹配

```bash
terraform init -upgrade
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64
git add .terraform.lock.hcl
git commit -m "chore: update provider lock"
git push
```

---

## PVC 误删恢复

| 场景 | 恢复步骤 |
|------|----------|
| PVC 误删 | PV 仍保留（Retain）→ 重新绑定 PVC |
| VPS /data 丢失 | 从 R2 备份恢复 → 重新 apply Helm |
| 单机容量不足 | 扩容 PVC 或拆分到独立 VPS |

---

## Used by（反向链接）

- [ops.pipeline.md](./ops.pipeline.md)
- [platform.secrets.md](./platform.secrets.md)
