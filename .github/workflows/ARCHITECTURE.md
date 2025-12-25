# CI Pipeline Architecture

> **设计原则**: 自动化优先，灵活控制保底

## 事件与 Token 映射

| Event | Trigger | Job | Token | Purpose | CI Check |
|-------|---------|-----|-------|---------|----------|
| `pull_request` | 自动 | `terraform-plan` | `GITHUB_TOKEN` | PR 自动 plan | ✅ Yes |
| `push` (main) | 自动 | `terraform-apply` | `GITHUB_TOKEN` | Merge 后自动 apply | ✅ Yes |
| `issue_comment` `/plan` | 手动 | `digger` | infra-flash App | 手动 plan (可指定项目) | ❌ No |
| `issue_comment` `/apply` | 手动 | `digger` | infra-flash App | 手动 apply (可指定项目) | ❌ No |
| `issue_comment` `digger plan -p xxx` | 手动 | `digger` | infra-flash App | 项目级操作 | ❌ No |
| `issue_comment` `/bootstrap` | 手动 | `bootstrap` | `GITHUB_TOKEN` | L1 层管理 | ❌ No |
| `issue_comment` `/e2e` | 手动 | `e2e` | `GITHUB_TOKEN` | 触发 E2E 测试 | ❌ No |
| `issue_comment` `/help` | 手动 | `help` | `GITHUB_TOKEN` | 显示帮助 | ❌ No |

## 架构决策

### 1. 为什么分离自动和手动？

**自动 CI Checks (GITHUB_TOKEN)**:
- ✅ 显示在 PR Checks 中
- ✅ 可设置为 Required Status Check
- ✅ 可以 block PR merge
- ✅ 不依赖外部 App，更稳定
- ✅ 不消耗 App rate limit

**手动命令 (infra-flash App)**:
- ✅ Digger 需要 write 权限（PR comments/labels）
- ✅ 支持项目级控制（`digger plan -p platform`）
- ✅ 支持 Digger 高级功能（drift detection）
- ✅ 独立于 CI checks，不会 block merge
- ✅ 更灵活的故障恢复

### 2. 为什么放弃 Digger 自动触发？

**Digger OSS 限制**:
- ❌ 不支持 `push` 事件（需要 Cloud）
- ❌ `on_commit_to_default: apply` 需要 Cloud
- ❌ 错误信息: "unsupported event type"

**解决方案**:
- 自动流程: 原生 terragrunt (无依赖)
- 手动流程: Digger OSS (保留高级功能)

### 3. Token 选择逻辑

```
需要 CI Check？
  ├─ Yes → GITHUB_TOKEN
  │        (terraform-plan, terraform-apply)
  │
  └─ No → 需要 Digger 编排？
           ├─ Yes → infra-flash App token
           │        (digger job)
           │
           └─ No → GITHUB_TOKEN
                    (bootstrap, e2e, help)
```

## 工作流程

### 标准 PR 流程
```
1. 创建 PR
   ↓
2. terraform-plan (自动触发)
   - GITHUB_TOKEN
   - 显示在 CI checks
   - Plan 所有项目
   ↓
3. Review plan output
   ↓
4. (可选) /apply 提前测试
   - infra-flash App
   - Digger 编排
   ↓
5. Approve & Merge
   ↓
6. terraform-apply (自动触发)
   - GITHUB_TOKEN
   - Apply 所有项目
   ✅ 完成
```

### 紧急单项目修复
```
1. PR 已创建，plan 显示多个项目变更
   ↓
2. 只想 apply platform 项目
   ↓
3. 评论: digger apply -p platform
   - infra-flash App
   - 只 apply 指定项目
   ↓
4. 验证成功后再 merge
```

## 防护措施

### Precondition Checks (Level 1)
- **terraform-plan**: GITHUB_REPOSITORY
- **terraform-apply**: GITHUB_REPOSITORY + AWS_ACCESS_KEY_ID
- **digger**: INFRA_FLASH_APP_ID + INFRA_FLASH_APP_KEY
- **bootstrap**: AWS + R2 secrets

### Test Framework (Level 2-4)
- **Level 2**: Unit tests (`tests/ci/`)
- **Level 3**: Postcondition (bootstrap output validation)
- **Level 4**: E2E tests (via `/e2e` command)

## 优势

1. ✅ **完全自动化**: PR → plan → merge → apply
2. ✅ **Required Checks**: 自动 plan/apply 可设为必须通过
3. ✅ **灵活控制**: 手动命令支持项目级操作
4. ✅ **权限隔离**: 自动用 GITHUB_TOKEN，手动用 App
5. ✅ **无云依赖**: Digger OSS，完全自托管
6. ✅ **保留高级功能**: Digger drift detection, 项目管理

## Trade-offs

### 放弃
- ❌ Digger 统一管理所有流程
- ❌ Digger Cloud 功能（UI, webhooks）

### 获得
- ✅ 稳定的自动化 CI
- ✅ Required status checks
- ✅ 无外部依赖
- ✅ 更好的权限控制

## 相关文件

- `.github/workflows/ci.yml` - 主流水线
- `digger.yml` - Digger 配置
- `tests/conftest.py` - 测试防护
- `docs/ssot/ops.pipeline.md` - 运维标准

---

**Last Updated**: 2025-12-25  
**Architecture Version**: v2.0 (Dual-track)
