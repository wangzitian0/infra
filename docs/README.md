# Documentation Center

> **定位**：文档体系总入口，连接三类文档
> **受众**：所有角色（开发者 + 运维者）

---

## 📚 文档体系说明

本平台的文档分为三类，各有侧重：

| 分类 | 路径 | 用途 | 适合人群 |
|------|------|------|---------|
| **[开发者体验](./onboarding/)** | `docs/onboarding/` | 场景驱动，注重接入顺滑 | 应用开发者 |
| **[SSOT](./ssot/)** | `docs/ssot/` | 关键信息集中，技术参考手册 | 所有人 |
| **Layer README** | 各目录 `README.md` | 模块驱动，设计和维护指南 | 基础设施维护者 |

---

## 🚀 开发者快速开始

**如果你是应用开发者**，从这里开始：

### [开发者接入指南](./onboarding/README.md)

场景驱动的完整指南：
1. **[5 分钟快速开始](./onboarding/01.quick-start.md)** - 了解平台能力
2. **[部署第一个应用](./onboarding/02.first-app.md)** - 端到端完整流程
3. **[使用数据库](./onboarding/03.database.md)** - PostgreSQL/Redis/ClickHouse
4. **[管理密钥](./onboarding/04.secrets.md)** - Vault 接入
5. **[接入 SSO](./onboarding/05.sso.md)** - Casdoor OIDC
6. **[监控和分析](./onboarding/06.observability.md)** - SigNoz + OpenPanel

**推荐路径**：按顺序阅读 1 → 2 → 根据需求选择 3-6

---

## 📖 SSOT - 技术参考手册

**如果你需要查技术细节**，参考这里：

### [SSOT 话题索引](./ssot/README.md)

话题式组织的单一信息源：

**Core（核心）**：
- [目录结构](./ssot/core.dir.md) - 项目布局和 Namespace 规则
- [环境模型](./ssot/core.env.md) - Workspace/Namespace/域名映射
- [变量清单](./ssot/core.vars.md) - TF_VAR 列表和 Feature Flags

**Platform（平台层）**：
- [认证与授权](./ssot/platform.auth.md) - SSO/OIDC/Portal Gate
- [密钥管理](./ssot/platform.secrets.md) - 1Password/Vault 流程
- [网络与域名](./ssot/platform.network.md) - DNS/Ingress 规则

**Data（数据层）**：
- [数据库总览](./ssot/db.overview.md) - 各数据库连接信息
- [Vault 接入详解](./ssot/db.vault-integration.md) - Per-App Token 机制

**Ops（运维）**：
- [流程汇总](./ssot/ops.pipeline.md) - CI/CD 工作流
- [故障恢复](./ssot/ops.recovery.md) - 紧急恢复手册
- [可观测性](./ssot/ops.observability.md) - SigNoz/OpenPanel 架构

---

## 🔧 架构与设计文档

**如果你要修改基础设施**，参考这里：

### Layer 文档

- [L0 Tools](../0.tools/README.md) - CI 工具和脚本
- [L1 Bootstrap](../1.bootstrap/README.md) - 集群引导层
- [L2 Platform](../2.platform/README.md) - 平台服务层
- [L3 Data](../3.data/README.md) - 数据层
- [L4 Apps](../4.apps/README.md) - 应用层

### 设计文档

- [Project Status](./project/README.md) - 进行中的任务 (BRNs)
- [Current Context](../0.check_now.md) - 当前上下文
- [Change Log](./change_log/) - 变更历史
- [Env & EaaS Design (BRN-004)](./project/BRN-004.md)
- [Deep Dives](./deep_dives/) - 深度技术决策文档
  - [DD-001: Secrets & CI](./deep_dives/DD-001.secret_and_ci_practices.md)
  - [DD-002: Why Atlantis](./deep_dives/DD-002.why_atlantis.md)

---
*Last updated: 2025-12-16*

