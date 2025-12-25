# CI Pipeline 概念丢失分析

## 问题概述

在 #369 (feat(ci): Python-driven CI pipeline with slash commands) 和后续的重构中，`docs/ssot/ops.pipeline.md` 从一个**非常详细的运维手册**简化成了**简洁的 SSOT 文档**，丢失了大量重要的设计概念和操作细节。

---

## 丢失的核心概念

### 1. **infra-flash Dashboard 设计哲学**

#### 原版 (6f7947c - 2025-12-XX)

```markdown
## 3. infra-flash: 运维看板 (Dashboard)

每条 `infra-flash` 评论不仅是审计日志，更是该 Commit 的 **SSOT 运维看板**。
它必须具备极高的链接准确性和信息完整性。

### 反馈类型定义与区别

| 类型 | 标识 (Title) | 性质 | 核心价值 | 触发方式 |
|:---|:---|:---|:---|:---|
| **CI 静态检查** | `### 🛠️ CI Validate` | 守卫 | 验证语法、Lint 与变量一致性 | 自动 (Push) |
| **AI 代码审计** | `### 🤖 Copilot Review` | 护栏 | 文档一致性检查、层级架构审计 | 自动/指令 |
| **Atlantis 部署** | `### 🚀 Atlantis Action` | 变更 | 真实的 Plan/Apply 状态与输出链接 | 自动/指令 |
| **服务健康检查** | `### 🔍 Health Check` | 验证 | 探测真实环境的连通性与 HTTP 状态 | 指令 |

### 交互规范 (SOP)

1. **Dashboard 理念**：
   - 禁止在 PR 中产生"流式"的新评论。
   - 所有信息必须**追加或原地更新**到对应的 Commit 看板中。
   - 必须包含 `[Run Log]` 或 `[Output]` 的精准跳转链接。
2. **修改与追加**：
   - CI 结果应原地更新（例如从 ⏳ 变为 ✅）。
   - Review 和 Dig 结果采用追加模式，保留历史快照。
   - Atlantis Actions 采用表格形式，记录该 Commit 的所有部署尝试。
```

#### 当前版本

**完全丢失**。仅在架构图中提到 "Dashboard" 但无任何设计细节。

---

### 2. **触发矩阵 (Push vs Comment)**

#### 原版

```markdown
## 2. 运维节点与触发矩阵

我们将流程分为 **自动 (Push)** 和 **指令 (Comment)** 两个平面。

### A. 自动平面 (Push Trigger)
每当代码推送到 PR 分支，系统自动启动"三位一体"检查：

1. **Skeleton (骨架)**: `terraform-plan.yml` 立即创建或锁定一个 `infra-flash` 评论。
2. **Static (静态)**: 同上，执行 `validate` 并更新评论中的 CI 表格。
3. **AI Review**: `infra-commands.yml` 自动运行 `review` 逻辑，并将建议追加到评论中。
4. **Autoplan**: Atlantis 监听到 push，自动执行 `plan`，由 `infra-flash-update.yml` 将结果追加到评论。

### B. 指令平面 (Comment Trigger)
通过在 PR 下发表评论手动触发：

| 命令 | 作用 | 触发时机 | 反馈位置 |
...
```

#### 当前版本

仅有 SOP-001/002/003 的步骤说明，**没有触发机制的系统性解释**。

---

### 3. **守卫节点 (Guards)**

#### 原版

```markdown
## 4. 守卫节点与准入标准 (Guards & Admission)

为了确保流水线的健壮性，执行过程中嵌入了多个"守卫"节点。

| 守卫名称 | 职责 | 规范来源 | 强制位置 |
|:---|:---|:---|:---|
| **Variable Guard** | 校验变量是否已在 1P 映射 | [AGENTS.md (Sec 3)] | `terraform-plan.yml` |
| **Doc Guard** | 强制更新文档与 `check_now` | [AGENTS.md (Principles)] | `infra review` (AI) |
| **Identity Guard** | 统一 `infra-flash` 发件身份 | [ops.standards.md] | 所有 `*.yml` |
| **Admission Guard** | 检查组件是否符合健康检查标准 | [ops.standards.md] | `terraform validate` |
| **Propagation Guard**| 强制等待 DNS/网络生效 | [AGENTS.md (SOP Rule 5)] | `.tf` 代码层 |
```

#### 当前版本

**完全丢失**。

---

### 4. **工作流清单与职责**

#### 原版

```markdown
## 5. 关键工作流清单 (Workflows)

| 文件 | 身份 | 职责 |
|:---|:---|:---|
| `terraform-plan.yml` | `infra-flash` | 静态 CI + 骨架评论创建 |
| `infra-commands.yml` | `infra-flash` | 指令分发器 (`review`, `dig`, `help`) |
| `infra-flash-update.yml` | `infra-flash` | 监听并搬运 Atlantis 的输出到主评论 |
| `deploy-k3s.yml` | `infra-flash` | **灾备平面**：全量 L1-L4 Flash (仅在 merge 或手动触发) |
```

#### 当前版本

仅有一个简单的表格指向文件路径，**没有职责说明**。

---

### 5. **异常路径处理**

#### 原版

```markdown
## 5. 常见异常路径

- **CI 挂了**：查看 `infra-flash` 中的 CI 表格，点击链接看日志，修复后重新 push。
- **Plan 挂了**：
    - 若是权限问题（Vault 过期），手动执行 L1 更新或重启 Atlantis。
    - 若是代码问题，修复后 push。
- **Apply 挂了**：
    - **禁止盲目重试**。必须先 `infra dig` 检查网络或手动进入集群查看 Pod 状态。
    - 确认为状态冲突后，使用 `terraform import` 修复。
```

#### 当前版本

**完全丢失**。

---

## 当前状态

### 保留的内容

✅ 架构图 (Mermaid)  
✅ 关键决策 (分层执行、Feedback Loop)  
✅ 基本 SOP (SOP-001/002/003/004)  
✅ SSOT 索引 (文件路径)  

### 丢失的内容

❌ Dashboard 设计哲学和交互规范  
❌ 触发矩阵详细说明  
❌ 守卫节点体系  
❌ 工作流职责清单  
❌ 异常路径处理指南  
❌ 核心问题域与解决方案映射  

---

## 问题根源

### 时间线

1. **6f7947c** (2025-12-XX): 引入 `infra-flash` Dashboard + 详细运维手册
2. **472f660** (feat(ci): Python-driven CI): 将 Atlantis 逻辑迁移到 Python + 斜杠命令
3. **9e65fca** (docs: refactor Data, Ops, and Core SSOTs to new template): **应用新 SSOT 模板，大量内容被精简**
4. **当前**: SSOT 文档非常简洁，但运维知识断层

### 核心矛盾

- **SSOT 模板哲学**: 简洁、引用、避免重复
- **Pipeline 复杂度**: 需要详细的设计文档和操作手册
- **结果**: SSOT 化后，**操作性知识** 被移除但没有安置到其他位置

---

## 实际问题

### 1. Dashboard 实现存在但文档缺失

代码中存在完整的 Dashboard 实现：
- `tools/ci/core/dashboard.py` (268 lines)
- `tools/ci/commands/init.py`
- `tools/ci/commands/update.py`

但 `ops.pipeline.md` 完全没有说明：
- Dashboard 的设计理念（per-commit SSOT）
- 状态更新机制（原地更新 vs 追加）
- Marker 机制 (`<!-- infra-dashboard:`)
- 与 CI jobs/PR 的交互逻辑

### 2. 概念散落无归属

- **Job**: 出现在 CI workflow 但未在 SSOT 中定义其与 Stage 的关系
- **Comment**: 作为交互入口但缺少系统性说明
- **Commit Dashboard**: 核心设计但在 SSOT 中只字未提

### 3. 新人学习曲线陡峭

当前 SSOT 对新加入者不友好：
- 看 SSOT 只知道"有 Dashboard"但不知道如何工作
- 需要读代码才能理解 `infra-dashboard` marker
- 异常处理完全靠经验

---

## 建议方案

### 短期修复

1. **恢复关键章节到 `ops.pipeline.md`**:
   - Dashboard 设计哲学（per-commit SSOT 理念）
   - 触发矩阵（自动 vs 手动，Push vs Comment）
   - 异常路径处理指南

2. **创建独立的操作手册**:
   - 位置：`docs/project/active/pipeline_operations.md`
   - 内容：详细的操作步骤、故障排查、守卫节点说明

### 长期优化

1. **分层文档结构**:
   ```
   docs/ssot/ops.pipeline.md          # SSOT: 架构、约束、索引
   docs/project/active/
     ├── pipeline_operations.md        # 操作手册
     ├── pipeline_troubleshooting.md   # 故障排查
     └── dashboard_design.md           # Dashboard 设计文档
   ```

2. **代码即文档**:
   - 在 `dashboard.py` 中补充详细 docstring
   - 在 CI workflow 中添加注释说明 Dashboard 更新时机

---

## 立即行动项

1. ✅ **分析完成** (本文档)
2. ⏳ **决策**: 选择修复方案（恢复 vs 重构 vs 混合）
3. ⏳ **执行**: 补充文档 / 重构结构
4. ⏳ **验证**: 新人 onboarding 测试

---

## 参考 Commits

- **Dashboard 引入**: 6f7947c (feat(ci): implement Infra Operations Dashboard)
- **SSOT 重构**: 9e65fca (docs: refactor Data, Ops, and Core SSOTs)
- **Python CI**: 472f660 (feat(ci): Python-driven CI pipeline)
- **当前 HEAD**: d087d0f

---

**结论**: CI 系统本身的实现（代码）是完整的，但**设计文档和操作知识**在 SSOT 化过程中严重缺失。需要补充或重新组织文档层次。
