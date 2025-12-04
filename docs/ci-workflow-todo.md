# CI/CD 工作流设计 TODO

## 目标设计

```
评论驱动工作流（类 Atlantis）：

PR 创建 → 自动 plan → 评论结果
        ↓
`/plan` → 重新 plan
`/apply staging` → apply 到 staging
`/apply prod` → apply 到 prod（需 approval）
        ↓
合并到 main → 自动同步状态
        ↓
`/revert` → 回滚到上一个状态
```

## 环境设计

| 环境 | 用途 | 触发方式 | State Key |
|------|------|----------|-----------|
| **test** | CI 验证（临时） | PR 自动 | `test/terraform.tfstate` |
| **staging** | 预发布验证 | `/apply staging` | `staging/terraform.tfstate` |
| **prod** | 生产环境 | `/apply prod` + approval | `prod/terraform.tfstate` |

## Phase 1: Staging 完整流程 ✅ 优先

### 1.1 修复当前 CI
- [ ] 检查 PR #6 失败原因
- [ ] 修复 terraform-plan.yml
- [ ] 验证 plan 能在 PR 中评论

### 1.2 单环境 Apply
- [ ] terraform-apply.yml 在 main 合并后自动执行
- [ ] 输出 kubeconfig 到 artifact
- [ ] Smoke test 验证集群可用

### 1.3 State 管理
- [ ] 确认 R2 bucket 中 state 路径正确
- [ ] 验证本地和 CI state 一致

---

## Phase 2: 评论驱动

### 2.1 `/plan` 命令
- [ ] 监听 PR 评论
- [ ] 识别 `/plan` 触发重新 plan
- [ ] 评论 plan 结果

### 2.2 `/apply` 命令
- [ ] `/apply staging` 触发 staging apply
- [ ] `/apply prod` 需要 CODEOWNERS approval
- [ ] apply 结果评论回 PR

### 2.3 `/revert` 命令
- [ ] 记录每次 apply 的 state 版本
- [ ] `/revert` 回滚到上一个版本

---

## Phase 3: 多环境

### 3.1 环境隔离
- [ ] Terraform workspace 或独立 state key
- [ ] 每个环境独立的 Secrets 前缀
- [ ] 环境间不互相影响

### 3.2 环境配置
- [ ] `envs/staging.tfvars`
- [ ] `envs/prod.tfvars`
- [ ] 环境特定的 VPS/集群配置

### 3.3 Promotion 流程
- [ ] staging 验证通过 → 可以 apply prod
- [ ] prod apply 需要额外 approval

---

## 当前阻塞

1. **PR #6 失败原因**：需要查看 Actions 日志
2. **Secrets 配置**：确认 GitHub Secrets 已配置

## 下一步

1. 先检查 PR #6 失败原因
2. 修复后验证 staging 流程
3. 再设计多环境和评论驱动
