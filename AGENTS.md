# 禁令
- **禁止自动修改本文件**：除非明确指定，否则 AI 不可以自动修改本文件。
- **禁止自动合并 PR**：AI 不可以执行合流操作。

# 原则
- **一致性**：本地/CI 命令与变量一致，plan 输出一致，资源状态一致。
- **完工自检**：完工前必须逐项检查本文件要求。
- **README 优先**：修改任何文件前，必须阅读对应目录的 `README.md`；提交前必须更新相关 `README.md`。
- **SSOT 导向**：所有技术真理应落在 `docs/ssot/`，README 仅作为导航。
- **STAR 框架**：解决问题时使用 Situation, Task, Action, Result 结构分析。
- **渐进式提交**：小步快跑，每一步都有日志校验。

# SSOT Architecture (The Truth)

所有的基础设施定义、架构决策、环境变量契约及 SOP 请查阅：

👉 **[SSOT Documentation Index (docs/ssot/README.md)](docs/ssot/README.md)**

## Module Quick Reference

| Module | Directory | Responsibility | SSOT Reference |
|---|---|---|---|
| **Root** | `.` | Scripts, CI, Docs | [`core.md`](docs/ssot/core.md) |
| **Bootstrap** | [`bootstrap`](bootstrap/README.md) | K3s, DNS, Trust Anchor | [`bootstrap.compute.md`](docs/ssot/bootstrap.compute.md) |
| **Platform** | [`platform`](platform/README.md) | Vault, SSO, PaaS | [`platform.auth.md`](docs/ssot/platform.auth.md) |
| **Data** | [`envs/*/data`](envs/README.md) | Business DBs | [`db.overview.md`](docs/ssot/db.overview.md) |

# AI 协作 SOP

## 1. 开发工作流 (Development Workflow)
1. **读 README**：深入了解当前层的职责。
2. **IaC Cycle**:
    - 修改 `.tf` 代码。
    - `terraform fmt -check`。
    - `terraform plan` (或通过 PR 评论触发)。
3. **更新文档**：更新 `README.md` 和 `change_log/`（如有重大变更）。
4. **验证**：运行 `e2e_regressions/` 下的相关测试。

## 2. 故障与状态处理
- **Drift First**：优先使用 `data` source 或 `import` 块检测存量资源，避免 Apply 冲突。
- **Break-glass**：紧急情况参考 [**Recovery SSOT**](docs/ssot/ops.recovery.md)。
- **State Lock**：遇到状态锁使用 `atlantis unlock` (兼容 Digger 命令)。

## 3. 安全红线
- **严禁提交敏感文件**：`*.tfvars`, `*.pem`, `*.key`, `.env`。
- **SSOT 唯一性**：1Password 是静态密钥的唯一真理；禁止在 GitHub UI 手动修改 Secret。

# 文档职责划分

| 类别 | 存储路径 | 内容性质 |
|------|---------|---------|
| **History** | `docs/change_log/` | 已完成的变更记录。 |
| **Plan** | `docs/project/README.md` | 进行中/计划中的 BRN 项目。 |
| **TRUTH (SSOT)** | `docs/ssot/` | **唯一权威参考**。架构、SOP、约束。 |
| **Navigation** | `**/README.md` | 目录路标，指向 SSOT。 |
| **Tutorials** | `docs/onboarding/` | 场景驱动的接入教程。 |