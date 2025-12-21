# 开发者接入指南

> **面向角色**：应用开发者
> **目标**：快速、顺滑地将应用接入基础设施平台

---

## 🚀 开始使用

根据你的需求，选择对应的场景指南：

### 新手入门
- **[5 分钟快速开始](./01.quick-start.md)** - 了解平台能力和核心概念
- **[部署第一个应用](./02.first-app.md)** - 端到端完整流程

### 常见场景
- **[使用数据库](./03.database.md)** - PostgreSQL、Redis、ClickHouse、ArangoDB
- **[管理密钥](./04.secrets.md)** - Vault 接入和凭据管理
- **[接入 SSO 登录](./05.sso.md)** - Casdoor OIDC 集成
- **[监控和分析](./06.observability.md)** - SigNoz 追踪 + PostHog 分析

---

## 📖 文档体系说明

本平台的文档分为三类，各有侧重：

| 分类 | 路径 | 用途 | 适合人群 |
|------|------|------|---------|
| **开发者体验** | `docs/onboarding/` | 场景驱动，注重接入顺滑 | 应用开发者 |
| **SSOT** | `docs/ssot/` | 关键信息集中，避免混乱 | 所有人（参考手册） |
| **README** | 各目录 `README.md` | 模块驱动，设计和维护指南 | 基础设施维护者 |

**建议阅读路径**：
1. 先看 **开发者体验**（本目录）快速上手
2. 遇到问题查 **SSOT** 了解技术细节
3. 需要修改基础设施时看对应模块的 **README**

---

## 🎯 典型用户旅程

### 场景 1: 部署简单 Web 应用
```
[快速开始] → [第一个应用]
   ↓
访问 Kubero UI → 创建 Pipeline → 连接 Git → 部署
   ↓
应用上线：https://my-app.truealpha.club
```

**预计时间**: 15 分钟
**前置条件**: 有 Git 仓库 + Dockerfile

### 场景 2: 部署需要数据库的应用
```
[快速开始] → [第一个应用] → [使用数据库]
   ↓
配置 Vault Role → 在 Kubero 添加 Vault annotations → 部署
   ↓
应用连接 PostgreSQL + Redis
```

**预计时间**: 30 分钟
**前置条件**: 场景 1 + 基本了解 Kubernetes

### 场景 3: 生产级应用（数据库 + SSO + 监控）
```
[第一个应用] → [数据库] → [SSO] → [监控]
   ↓
完整的生产应用，包含：
- 多环境部署 (staging/prod)
- 安全的凭据管理
- 用户身份认证
- 全链路追踪和分析
```

**预计时间**: 2 小时
**前置条件**: 完成场景 1 和 2

---

## 🆘 获取帮助

### 遇到问题？

1. **查看 FAQ**（每个场景文档末尾都有）
2. **搜索 SSOT 文档** - [docs/ssot/README.md](../ssot/README.md)
3. **查看故障排查** - [ops.recovery.md](../ssot/ops.recovery.md)
4. **联系运维团队** - （在此填写联系方式）

### 常见问题快速链接

- 密钥权限错误 → [Vault 故障排查](./04.secrets.md#故障排查)
- 部署失败 → [Kubero Troubleshooting](../../4.apps/README.md#troubleshooting)
- 无法访问应用 → [网络和域名](../ssot/platform.network.md)
- 登录问题 → [认证故障排查](./05.sso.md#常见问题)

---

## 🔗 相关资源

- **平台架构总览** - [docs/README.md](../README.md)
- **SSOT 索引** - [docs/ssot/README.md](../ssot/README.md)
- **Layer 文档** - [L4 Apps](../../4.apps/README.md) · [L2 Platform](../../2.platform/README.md)
- **变更日志** - [docs/change_log/](../change_log/)

---

*Last updated: 2025-12-21*
