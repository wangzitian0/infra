# 🤖 AI Code Review 使用指南

## 快速开始

在任何 PR 或 issue 评论中输入以下命令触发 GitHub Copilot Code Review：

```
@copilot please review this PR
```

或使用斜杠命令（更兼容）：

```
/review
```

---

## 功能说明

### 触发方式

| 命令 | 说明 | 兼容性 |
|------|------|--------|
| `@copilot <request>` | GitHub Copilot 原生触发 | 需 Copilot 许可 |
| `/review` | 兼容性别名（推荐） | 同上 |

### 触发时机

- ✅ **手动触发**: 在 PR 评论中主动请求 review
- ❌ **不自动触发**: 不会在 PR 创建时自动运行

### 审查范围

Copilot 会分析：
1. 代码变更 (diff)
2. Terraform/IaC 最佳实践
3. 安全风险
4. 潜在 bug
5. CI 状态（如有权限）

---

## 配置要求

### 仓库级别（管理员）

**不需要** 配置 Rulesets 自动审查，保持 **手动触发** 模式。

如需启用自动审查（可选）：
1. `Settings` → `Rules` → `Rulesets`
2. 创建 Branch Ruleset，目标分支如 `main`
3. 勾选 **"Automatically request Copilot code review"**

### 用户级别

确保你有以下权限之一：
- GitHub Copilot Pro 订阅
- GitHub Copilot Business（组织提供）
- 或组织已启用"无许可用户使用 Copilot review"（消耗组织额度）

---

## Dashboard 集成

Copilot review **不会自动更新** PR Dashboard 的 "AI Review" 行。

如需 Dashboard 集成，可使用其他自定义方案（见历史版本）。

---

## 最佳实践

### 推荐用法

```bash
# 1. 初始 review
@copilot review this infrastructure change

# 2. 针对性问题
@copilot check for security issues in this terraform code

# 3. 跟进修改
@copilot review the latest commits
```

### 与 CI Pipeline 结合

配合标准流水线使用：

```bash
/plan          # 1. 先执行 Terraform Plan
@copilot       # 2. 请求 AI review
/apply         # 3. 确认后 Apply
```

---

## 故障排查

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| Copilot 无响应 | 无许可/无权限 | 联系管理员确认订阅 |
| 回复太慢 | PR 过大 | 拆分 PR 或耐心等待 |
| 无法访问 CI | 权限不足 | 管理员配置 `actions: read` |

---

## SSOT 参考

- **Pipeline 操作**: [ops.pipeline.md](../../ssot/ops.pipeline.md)
- **AI 集成标准**: [platform.ai.md](../../ssot/platform.ai.md)

---

## 示例场景

### 场景 1: Terraform 变更 review

```markdown
@copilot review these terraform changes for:
1. Security best practices
2. State management issues
3. Resource naming conventions
```

### 场景 2: 紧急修复验证

```markdown
/review - please check if this hotfix introduces any regressions
```

### 场景 3: 大型 PR 预审

```markdown
@copilot give me a high-level summary of these changes before I do detailed review
```

---

**提示**: Copilot 的 review 是辅助工具，不能替代人工审查和测试。
