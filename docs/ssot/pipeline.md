# 流程 SSOT

> **核心问题**：这个操作走什么流程？手动还是自动？

## 流程分类

| 类型 | 触发 | 工具 | 配置位置 | SSOT 状态 |
|------|------|------|----------|-----------| 
| L1 Bootstrap | 手动 | TF + GitHub Actions | `.github/workflows/deploy-k3s.yml` | ❌ 人工触发 |
| L2-L4 部署 | PR 评论 | Atlantis | `atlantis.yaml` | ✅ GitOps |
| 代码审查 | 自动 | Claude Action | `.github/workflows/claude.yml` | ✅ 自动化 |
| 健康检查 | 评论 | GitHub Actions | `.github/workflows/dig.yml` | ✅ 按需 |
| 密钥轮换 | (计划) | Vault + CronJob | TBD | ✅ 自动化 |

## 详细流程

### 1. L1 Bootstrap (打破 SSOT — 鸡生蛋)

触发条件: 手动执行或 push to main (`deploy-k3s.yml`)

```bash
cd 1.bootstrap
terraform init -backend-config="bucket=$R2_BUCKET" ...
terraform apply -auto-approve
```

### 2. L2-L4 GitOps (遵守 SSOT)

```
PR Created → terraform-plan.yml (fmt, lint, plan)
          → github-actions 评论 "atlantis plan"
          → Atlantis 执行 plan
          → infra-flash[bot] 评论结果
          → Claude 自动 review
          → 人工 review
          → 评论 "atlantis apply"
          → 合并到 main
```

### 3. 灾难恢复流程

| 场景 | 恢复步骤 |
|------|----------|
| Vault Pod 挂掉 | Re-apply Helm → PG 数据在 → Unseal |
| Platform PG 丢失 | 从 VPS /data 备份恢复 → Vault re-init |
| VPS 完全丢失 | 1Password 根密钥 → 新 VPS → L1 apply → L2 apply |

## 相关文件

- [deploy-k3s.yml](../../.github/workflows/deploy-k3s.yml) - L1 部署
- [terraform-plan.yml](../../.github/workflows/terraform-plan.yml) - PR 验证
- [atlantis.yaml](../../atlantis.yaml) - Atlantis 配置
