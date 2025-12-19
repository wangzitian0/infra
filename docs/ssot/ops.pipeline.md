# Pipeline SSOT (运维流水线)

> **核心原则**：所有变更必须可审计。`infra-flash` 评论流是 PR 状态的单一真理来源 (SSOT)。

---

## 1. 核心问题域与解决方案

| 解决的问题 | 实际方案 | 执行位置 | 理由 |
|:---|:---|:---|:---|
| **静态质量** | `fmt`, `lint`, `validate` | GitHub Actions | 快速反馈，不依赖集群环境 |
| **动态预览** | `terraform plan` | Atlantis (Pod) | 必须访问集群内 Vault 和 Backend |
| **AI 护栏** | `@claude review` / 自动 | Claude App (Haiku 4.5) | 文档一致性、IaC 规范、安全审计 |
| **审计合规** | `infra-flash` 评论流 | GHA + Atlantis | 每一笔操作都有 Commit 级别的记录 |
| **环境健康** | `infra dig` | GitHub Actions | 外部视角验证服务连通性 |
| **全量恢复** | `deploy-k3s.yml` | GitHub Actions | 灾备与初始引导 (Bootstrap) |

---

## 2. 运维节点与触发矩阵

我们将流程分为 **自动 (Push)** 和 **指令 (Comment)** 两个平面。

### A. 自动平面 (Push Trigger)
每当代码推送到 PR 分支，系统自动启动以下检查：

1. **Skeleton (骨架)**: `terraform-plan.yml` 立即创建或锁定一个 `infra-flash` 评论。
2. **Static (静态)**: 同上，执行 `validate` 并更新评论中的 CI 表格。
3. **Autoplan**: Atlantis 监听到 push，自动执行 `plan`，由 `infra-flash-update.yml` 将结果追加到评论。
4. **Post-Apply Review**: `claude-code-review.yml` 在 `atlantis apply` 成功后自动触发，Claude 审查已部署的变更。

### B. 指令平面 (Comment Trigger)
通过在 PR 下发表评论手动触发：

| 命令 | 作用 | 触发时机 | 反馈位置 |
|:---|:---|:---|:---|
| `atlantis plan` | 重新生成 Plan | 自动 Plan 失败或需要刷新时 | `infra-flash` 追加 |
| `atlantis apply` | 执行部署 | **必须**在 Plan 成功后 | `infra-flash` 追加 |
| `@claude review this` | 手动触发 AI 审计 | 随时，或针对特定问题时 | 新评论回复 |
| `@claude <任意指令>` | Claude 执行任意任务 | 需要 AI 协助时 | 新评论回复 |
| `infra dig` | 探测环境连通性 | 部署后验证或排查 Ingress 故障时 | `infra-flash` 追加 |
| `infra help` | 获取指令帮助 | 任何时候 | 新评论回复 |

---

## 3. infra-flash: 运维看板 (Dashboard)

每条 `infra-flash` 评论不仅是审计日志，更是该 Commit 的 **SSOT 运维看板**。它必须具备极高的链接准确性和信息完整性。

### 反馈类型定义与区别

| 类型 | 标识 (Title) | 性质 | 核心价值 | 触发方式 |
|:---|:---|:---|:---|:---|
| **CI 静态检查** | `### 🛠️ CI Validate` | 守卫 | 验证语法、Lint 与变量一致性 | 自动 (Push) |
| **AI 代码审计** | `### 🤖 AI Review (Claude)` | 护栏 | 文档一致性检查、层级架构审计、安全审查 | Apply后自动 / @claude手动 |
| **Atlantis 部署** | `### 🚀 Atlantis Action` | 变更 | 真实的 Plan/Apply 状态与输出链接 | 自动/指令 |
| **服务健康检查** | `### 🔍 Health Check` | 验证 | 探测真实环境的连通性与 HTTP 状态 | 指令 |

### 交互规范 (SOP)

1. **Dashboard 理念**：
   - 禁止在 PR 中产生“流式”的新评论。
   - 所有信息必须**追加或原地更新**到对应的 Commit 看板中。
   - 必须包含 `[Run Log]` 或 `[Output]` 的精准跳转链接。
2. **修改与追加**：
   - CI 结果应原地更新（例如从 ⏳ 变为 ✅）。
   - Review 和 Dig 结果采用追加模式，保留历史快照。
   - Atlantis Actions 采用表格形式，记录该 Commit 的所有部署尝试。

---

## 4. 守卫节点与准入标准 (Guards & Admission)

为了确保流水线的健壮性，执行过程中嵌入了多个“守卫”节点。

| 守卫名称 | 职责 | 规范来源 | 强制位置 |
|:---|:---|:---|:---|
| **Variable Guard** | 校验变量是否已在 1P 映射 | [AGENTS.md (Sec 3)](../../AGENTS.md#3-secret--variable-pipeline-the-variable-chain) | `terraform-plan.yml` |
| **Doc Guard** | 强制更新文档与 `check_now` | [AGENTS.md (Principles)](../../AGENTS.md#原则) | `infra review` (AI) |
| **Identity Guard** | 统一 `infra-flash` 发件身份 | [ops.standards.md](./ops.standards.md#3-防御性配置要求-defensive-rules) | 所有 `*.yml` |
| **Admission Guard** | 检查组件是否符合健康检查标准 | [ops.standards.md](./ops.standards.md#1-健康检查分层规范) | `terraform validate` |
| **Propagation Guard**| 强制等待 DNS/网络生效 | [AGENTS.md (SOP Rule 5)](../../AGENTS.md#4-defensive-maintenance-sop-infrastructure-reliability) | `.tf` 代码层 |

---

## 5. 关键工作流清单 (Workflows)

| 文件 | 身份 | 职责 |
|:---|:---|:---|
| `terraform-plan.yml` | `infra-flash` | 静态 CI + 骨架评论创建 |
| `infra-commands.yml` | `infra-flash` | 指令分发器 (`dig`, `help`) |
| `infra-flash-update.yml` | `infra-flash` | 监听并搬运 Atlantis 的输出到主评论 |
| `claude.yml` | `claude[bot]` | 响应 @claude 评论，执行 AI 任务（review/coding/analysis） |
| `claude-code-review.yml` | `claude[bot]` | Apply 成功后自动审查部署变更 |
| `deploy-k3s.yml` | `infra-flash` | **灾备平面**：全量 L1-L4 Flash (仅在 merge 或手动触发) |

---

## 5. 常见异常路径

- **CI 挂了**：查看 `infra-flash` 中的 CI 表格，点击链接看日志，修复后重新 push。
- **Plan 挂了**：
    - 若是权限问题（Vault 过期），手动执行 L1 更新或重启 Atlantis。
    - 若是代码问题，修复后 push。
- **Apply 挂了**：
    - **禁止盲目重试**。必须先 `infra dig` 检查网络或手动进入集群查看 Pod 状态。
    - 确认为状态冲突后，使用 `terraform import` 修复。

---

## 7. 验收准则与测试场景 (UAT)

为了验证流水线的健壮性，任何重大变更后应执行以下场景测试：

| 场景 | 操作 | 预期 Dashboard 行为 | 预期 Identity |
|:---|:---|:---|:---|
| **CI 守卫测试** | 推送包含格式错误的代码 | `Static CI` 显示 ❌，看板底部显示修复命令 | `infra-flash` |
| **手动 AI 审计** | 评论 `@claude review this` | 产生一条新评论，包含 Claude 的审查建议 | `claude[bot]` |
| **Apply 后审计** | `atlantis apply` 成功 | `claude-code-review.yml` 触发，Claude 审查已部署变更 | `claude[bot]` |
| **指令分发测试** | 评论 `infra help` | 产生一条新评论，列出所有可用指令 | `infra-flash` |
| **环境探测测试** | 评论 `infra dig` | `Health Check` 状态更新，追加连通性表格 | `infra-flash` |
| **SSOT 闭环测试** | 多次推送/评论 | 所有信息均有序汇聚在同一条 Commit 评论中 | `infra-flash` |

---

## 8. 维护规范

1. **修改任何 Workflow**：必须同步更新本 SSOT 及其对应的 `README.md`。
2. **新增 infra 命令**：必须在 `infra-commands.yml` 中实现，并在此文档的"指令平面"表格中登记。
3. **AI 审查定制**：通过仓库根目录的 `CLAUDE.md` 文件定义 Claude 的行为准则和审查标准。
4. **Identity 规范**：
   - `infra-flash[bot]`：所有 Atlantis 和 infra 命令相关的评论
   - `claude[bot]`：所有 Claude AI 相关的评论和审查
   - `github-actions`：仅用于 `deploy-k3s.yml` 在 merge 到 main 时的部署