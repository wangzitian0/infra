# 基础设施 AI Agent 行为准则

> **禁令**：除非明确指定，否则 AI 不可以自动修改本文件。AI 不可以执行合流 (Merge PR) 操作。

# 🚨 核心强制原则 (SSOT First)

1.  **SSOT 为最高真理**：基础设施的架构、规则、SOP **唯一权威来源**是 `docs/ssot/`。
2.  **强制前置检查 (Step 0)**：在执行任何代码修改或运维操作前，**必须**首先在 `docs/ssot/` 中搜索并阅读相关话题。
    - *示例：若涉及数据库，必读 `db.overview.md`；若涉及密钥，必读 `platform.secrets.md`。*
3.  **无 SSOT 不开工**：如果要引入一个新概念/组件，**必须**先在 `docs/ssot/` 创建对应的真理文件，严禁在 README 或代码中散落孤立的设计决策。
4.  **禁止隐性漂移**：如果发现现实（代码/资源）与 SSOT 不符，**必须**立即修正 SSOT（若现实是正确的）或修正代码（若 SSOT 是正确的）。

---

# 🛠️ 执行流程 (Execution Loop)

## 第一步：情境分析 (Situation Assessment)
使用 **STAR Framework** 分析问题。在 Action 阶段，必须明确标注：“我将参考哪个 SSOT 文件”。

## 第二步：真理对齐 (SSOT Alignment)
- **搜索**：`grep -r <keyword> docs/ssot/`
- **校验**：检查当前任务是否违反了 [**Ops Standards / Defensive Maintenance**](./docs/ssot/ops.standards.md#3-防御性运维守则-defensive-maintenance) 中的任何一条 Rule。

## 第三步：IaC 循环 (Implementation)
1. 修改 `.tf` 代码。
2. `terraform fmt` 并执行 `terraform plan`。
3. **关键同步**：更新受影响的 SSOT Playbooks 或 Constraints。

## 第四步：完工自检 (Self-Check)
在宣布完工前，对照 [**0.check_now.md**](./0.check_now.md) 和相关 SSOT 的 **"The Proof"** 章节，确认测试已通过。

---

# 知识库导航 (The Truth)

👉 **[SSOT Documentation Index (docs/ssot/README.md)](./docs/ssot/README.md)**

| 查阅内容 | 对应 SSOT 文件 / 章节 |
|----------|----------------------|
| **防御性运维/守则** | [**Ops Standards / Defensive Maintenance**](./docs/ssot/ops.standards.md#3-防御性运维守则-defensive-maintenance) |
| **Provider 优先级** | [**Ops Standards / Provider Priority**](./docs/ssot/ops.standards.md#2-托管资源评估-sop-provider-priority) |
| **密钥流转/契约** | [**Platform Secrets SSOT**](./docs/ssot/platform.secrets.md) |
| **故障恢复 SOP** | [**Recovery SSOT**](./docs/ssot/ops.recovery.md) |
| **流水线操作** | [**Pipeline SSOT**](./docs/ssot/ops.pipeline.md) |

---

# 安全与红线
- **严禁**提交 `*.pem`, `*.key`, `.env`, `*.tfvars`。
- **状态不一致处理**：Apply 冲突时必须执行 [**State Discrepancy Protocol**](./docs/ssot/ops.standards.md#rule-4-状态不一致协议-state-discrepancy-protocol)。
- **密钥源头**：1Password 是静态密钥的唯一真源。