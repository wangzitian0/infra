# codex_infra Docs

本仓库所有 Markdown 文档的静态站点（MkDocs）。

---

## 📚 三分类文档体系

根据你的角色和需求，选择对应的文档入口：

### 🚀 开发者体验 - [Onboarding](./repo/docs/onboarding/README.md)

**面向**：应用开发者
**目标**：快速、顺滑地接入平台

**场景驱动的指南**：
- [5 分钟快速开始](./repo/docs/onboarding/01.quick-start.md)
- [部署第一个应用](./repo/docs/onboarding/02.first-app.md)
- [使用数据库](./repo/docs/onboarding/03.database.md)
- [管理密钥](./repo/docs/onboarding/04.secrets.md)
- [接入 SSO 登录](./repo/docs/onboarding/05.sso.md)
- [监控和分析](./repo/docs/onboarding/06.observability.md)

---

### 📖 SSOT - [单一信息源](./repo/docs/ssot/README.md)

**面向**：所有人
**目标**：关键信息集中，避免混乱

**话题式参考手册**：
- **Core**：[目录结构](./repo/docs/ssot/core.dir.md) · [环境模型](./repo/docs/ssot/core.env.md) · [变量清单](./repo/docs/ssot/core.vars.md)
- **Platform**：[认证](./repo/docs/ssot/platform.auth.md) · [密钥](./repo/docs/ssot/platform.secrets.md) · [网络](./repo/docs/ssot/platform.network.md)
- **Data**：[数据库总览](./repo/docs/ssot/db.overview.md) · [Vault 接入](./repo/docs/ssot/db.vault-integration.md)
- **Ops**：[流程](./repo/docs/ssot/ops.pipeline.md) · [恢复](./repo/docs/ssot/ops.recovery.md) · [可观测性](./repo/docs/ssot/ops.observability.md)

---

### 🔧 模块 README - Layer 文档

**面向**：基础设施维护者
**目标**：模块驱动，设计和维护指南

**分层架构文档**：
- [L0 Tools](./repo/tools/README.md) - 工具和脚本
- [L1 Bootstrap](./repo/1.bootstrap/README.md) - 集群引导
- [L2 Platform](./repo/2.platform/README.md) - 平台服务
- [L3 Data](./repo/3.data/README.md) - 数据层
- [L4 Apps](./repo/4.apps/README.md) - 应用层

---

## 🎯 快速导航

### 我是新来的开发者
→ 从 **[开发者体验](./repo/docs/onboarding/README.md)** 开始

### 我要查技术细节
→ 查阅 **[SSOT 文档](./repo/docs/ssot/README.md)**

### 我要修改基础设施
→ 参考对应 **Layer README**

---

## 其他资源

- [Repo README](./repo/README.md) - 仓库总览
- [Current Context](./repo/0.check_now.md) - 当前上下文
- [Docs Center](./repo/docs/README.md) - 文档中心
- [Directory Map](./repo/docs/dir.md) - 目录映射

