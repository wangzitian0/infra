# CI/CD 与分支保护策略

## 目标

1. **自动阻塞未通过 CI 的 PR**：必须所有 status checks 通过才能合并
2. **允许评论触发合并**：通过 Atlantis 等工具在评论中执行 `apply`
3. **避免人工操作阻塞**：自动化流程减少错误和延迟

## 当前问题

PR #10 被合并时没有等待所有 CI 检查通过。需要配置：

1. **分支保护规则**（GitHub Settings → Branches）
   - Require status checks to pass before merging
   - Require branches to be up to date before merging
   - Dismiss stale pull request approvals when new commits are pushed
   - Include administrators

2. **评论驱动合并**（Atlantis 或类似）
   - 在 PR 评论中输入 `atlantis apply` 触发合并
   - 自动 plan，需人工审核后合并

## 分支保护规则配置

### 在 GitHub UI 中配置

```
Settings → Branches → Branch protection rules → Add rule

分支模式: main

必需检查:
  ☑ Require a pull request before merging
  ☑ Require status checks to pass before merging
    - Terraform Plan (PR)
    - GitGuardian Security Checks
  ☑ Require branches to be up to date before merging
  ☑ Dismiss stale pull request approvals when new commits are pushed
  ☑ Include administrators

其他:
  ☐ Allow force pushes
  ☐ Allow deletions
```

### 使用 Terraform 配置（未来）

可以在 `terraform/` 中添加 GitHub provider 来自动化这些规则。

## 评论驱动流程 - Atlantis 集成

### 当前流程

```
PR 推送 → terraform-plan.yml 运行 plan
         → 检查通过后手动合并 ❌ 可能忘记或合并失败的 PR

改进:
PR 推送 → terraform-plan.yml 运行 plan
         → PR 评论: "atlantis apply"
         → atlantis: 运行 apply
         → 自动合并 ✓
```

### 需要的步骤

1. **部署 Atlantis 服务**
   - 在 VPS 或 K8s 中运行 Atlantis
   - 配置 GitHub Webhook
   - 设置个人访问令牌（PAT）用于合并

2. **配置 atlantis.yaml**
   ```yaml
   version: 3
   automerge: true
   projects:
   - name: infra
     dir: terraform
     workflow: default
     ```

3. **配置 Webhook**
   - GitHub Settings → Webhooks
   - Payload URL: https://atlantis.yourdomain.com/events
   - Content type: application/json
   - Events: Pull request, Issue comments

## 安全考量

1. **谁可以评论触发 apply？**
   - 仅 repo 成员（default）
   - 或指定的团队

2. **drift 检测**
   - 定期运行 `terraform plan` 检查状态漂移
   - 设置自动告警

3. **审计日志**
   - 记录所有 apply 操作
   - GitHub Actions 日志自动保存

## 当前 Staging 部署状态

- ✅ PR #10 已合并到 main
- ❌ 合并后 deploy workflow 失败（terraform fmt）
- 🔧 Fix branch 创建: `fix/ci-terraform-fmt`
- ⏳ 需要：
  1. 修复 CI 格式问题
  2. 应用分支保护规则
  3. 评估 Atlantis 部署

## 下一步行动

1. Merge `fix/ci-terraform-fmt` PR
2. 在 GitHub 配置分支保护规则
3. （可选）评估 Atlantis 的可行性
4. 文档化团队的合并流程
