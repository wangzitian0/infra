# Pipeline SSOT (运维流水线)

> **核心原则**：所有变更必须可审计。`infra-flash` 评论流是 PR 状态的单一真理来源 (SSOT)。

---

## 1. 核心问题域与解决方案

| 解决的问题 | 实际方案 | 执行位置 | 理由 |
|:---|:---|:---|:---|
| **静态质量** | `fmt`, `lint`, `validate` | GitHub Actions | 快速反馈，不依赖集群环境 |
| **动态预览** | `terraform plan` | Atlantis (Pod) | 必须访问集群内 Vault 和 Backend |
| **AI 护栏** | `infra review` | Copilot Action | 自动化文档检查与 IaC 规范审计 |
| **审计合规** | `infra-flash` 评论流 | GHA + Atlantis | 每一笔操作都有 Commit 级别的记录 |
| **环境健康** | `infra dig` | GitHub Actions | 外部视角验证服务连通性 |
| **全量恢复** | `deploy-k3s.yml` | GitHub Actions | 灾备与初始引导 (Bootstrap) |

---

## 2. 运维节点与触发矩阵

我们将流程分为 **自动 (Push)** 和 **指令 (Comment)** 两个平面。

### A. 自动平面 (Push Trigger)
每当代码推送到 PR 分支，系统自动启动“三位一体”检查：

1. **Skeleton (骨架)**: `terraform-plan.yml` 立即创建或锁定一个 `infra-flash` 评论。
2. **Static (静态)**: 同上，执行 `validate` 并更新评论中的 CI 表格。
3. **AI Review**: `infra-commands.yml` 自动运行 `review` 逻辑，并将建议追加到评论中。
4. **Autoplan**: Atlantis 监听到 push，自动执行 `plan`，由 `infra-flash-update.yml` 将结果追加到评论。

### B. 指令平面 (Comment Trigger)
通过在 PR 下发表评论手动触发：

| 命令 | 作用 | 触发时机 | 反馈位置 |
|:---|:---|:---|:---|
| `atlantis plan` | 重新生成 Plan | 自动 Plan 失败或需要刷新时 | `infra-flash` 追加 |
| `atlantis apply` | 执行部署 | **必须**在 Plan 成功且 Review 通过后 | `infra-flash` 追加 |
| `infra review` | 手动触发 AI 审计 | 随时，或针对特定问题追问时 | `infra-flash` 追加 |
| `infra dig` | 探测环境连通性 | 部署后验证或排查 Ingress 故障时 | `infra-flash` 追加 |
| `infra help` | 获取指令帮助 | 任何时候 | 新评论回复 |

---

## 3. 审计流 (infra-flash) 状态机

每条 `infra-flash` 评论代表一个 Commit 的生命周期：

1. **Initialized**: 锚点 `<!-- infra-flash-commit:sha -->` 建立。
2. **Validated**: CI 表格更新（✅/❌）。
3. **Reviewed**: AI 审查意见注入。
4. **Planned**: Atlantis Plan 结果追加，展示 `Plan: X to add, 0 to destroy`。
5. **Applied**: Atlantis Apply 结果追加。
6. **Closed**: `👉 Next: Merge PR`。

**重复性规避**：
- 禁止 `copilot.yml` 或 `dig.yml` 单独发新评论。
- 所有的 `Update Comment` 逻辑必须通过 SHA 锚点定位到所属 Commit。

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
| `infra-commands.yml` | `infra-flash` | 指令分发器 (`review`, `dig`, `help`) |
| `infra-flash-update.yml` | `infra-flash` | 监听并搬运 Atlantis 的输出到主评论 |
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

## 6. 维护规范

1. **修改任何 Workflow**：必须同步更新本 SSOT 及其对应的 `README.md`。
2. **新增命令**：必须在 `infra-commands.yml` 中实现，并在此文档的“指令平面”表格中登记。
3. ** identity**：除了 `deploy-k3s.yml` 在 push main 时可能以 `github-actions` 身份运行，PR 期间的所有动作必须模拟 `infra-flash[bot]` 身份。