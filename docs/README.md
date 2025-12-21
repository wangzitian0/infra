# Documentation Center

**SSOT Type**: Architecture & Design
**Scope**: High-level designs, architectural decisions, and directory structure maps.

## Key Documents

- **[SSOT 运维看板规范](./ssot/ops.pipeline.md)** - 核心运维体系流程图、状态机与操作手册。
- **[SSOT 话题索引](./ssot/README.md)** - 密钥/数据库/认证/网络/存储等话题。
- **[Directory Map](./ssot/core.dir.md)** - 目录结构 SSOT。
- [Project Status](./project/README.md) - 进行中的任务 (BRNs) 与执行状态。
- [Current Context](../0.check_now.md) and [Change Log](./change_log) - Sprint notes and history roll-ups
- [Env & EaaS Design (BRN-004)](./project/BRN-004.md)
- Design Decisions: [DD-001](./deep_dives/DD-001.secret_and_ci_practices.md) (Secrets & CI) · [DD-002](./deep_dives/DD-002.why_atlantis.md) (Atlantis rationale)

---
*Last updated: 2025-12-16*

---

## TODO: 开发者体验改进

### 1. 缺少开发者导航路径
**问题**: Documentation Center 是一个很好的索引，但它面向的是熟悉系统的人。新来的开发者不知道应该先看什么、后看什么。

**建议**:
- [ ] 在 "Key Documents" 前增加 "## For Developers" 章节
- [ ] 提供角色化的阅读路径：
  - **我是新来的应用开发者** (第一次接入)
    1. 先看：[新应用接入指南](待创建)
    2. 再看：[Kubero 使用指南](../4.apps/README.md)
    3. 然后看：[数据库接入](./ssot/db.overview.md)
    4. 最后看：[SSO 接入](./ssot/platform.auth-for-developers.md)（如需要）
  - **我要部署一个新版本** (日常开发)
    1. 参考：[Kubero Pipeline 操作](待补充)
    2. 故障排查：[常见部署问题](待补充)
  - **我遇到了问题** (故障诊断)
    1. 查看：[Troubleshooting 索引](待创建)
    2. 联系：运维团队（提供联系方式）

**受影响角色**: 应用开发者（文档导航）

### 2. SSOT 索引对开发者不友好
**问题**: SSOT 话题索引按技术组织（Core/Platform/Data/Ops），但开发者关心的是"我要做什么"而不是"系统怎么组织"。

**建议**:
- [ ] 在 README 中增加"开发者任务索引"
- [ ] 按任务组织文档链接：
  - **部署应用**: [Kubero](../4.apps/README.md) → [环境模型](./ssot/core.env.md)
  - **管理密钥**: [Vault 接入](./ssot/db.vault-integration.md) → [密钥管理](./ssot/platform.secrets.md)
  - **连接数据库**: [数据库总览](./ssot/db.overview.md) → [PostgreSQL](./ssot/db.business_pg.md)
  - **接入 SSO**: [认证指南](./ssot/platform.auth-for-developers.md)（待创建）
  - **监控和分析**: [可观测性](./ssot/ops.observability.md) → SigNoz/PostHog（待补充）

**受影响角色**: 应用开发者（任务导向）
