# 认证与授权 SSOT

> **核心问题**：用户登录各 Portal 的统一入口

## 目标架构：Casdoor SSO

```
                    ┌─────────────────┐
                    │   GitHub IDP    │
                    │   Google IDP    │
                    └────────┬────────┘
                             │ OIDC
                             ▼
┌─────────────────────────────────────────────────────────────┐
│  Casdoor (L2 Platform)                                      │
│  - 部署在 platform namespace                                 │
│  - 连接 L1 Platform PostgreSQL                               │
│  - 域名: sso.<internal_domain>                               │
└─────────────────────────────────────────────────────────────┘
                             │
          ┌──────────────────┴──────────────────┐
          ▼                                     ▼
    ┌──────────────────────────┐    ┌──────────────────────────┐
    │ L2 服务 (可用 Casdoor)    │    │ L4 应用 (可用 Casdoor)  │
    │ • Dashboard              │    │ • 业务应用              │
    │ • Kubero                 │    │ • SigNoz                │
    │ • Vault UI (OIDC)        │    │ • PostHog               │
    └──────────────────────────┘    └──────────────────────────┘

    ┌──────────────────────────┐    ┌──────────────────────────┐
    │ L1 服务 (不能用 Casdoor)  │    │ L3 数据 (无需 Portal)   │
    │ • Atlantis → Basic Auth  │    │ • PostgreSQL            │
    │ • K3s API → Token        │    │ • Redis                 │
    └──────────────────────────┘    └──────────────────────────┘
```

## 服务认证矩阵

> **规则**：L1 服务无法被 L2 Casdoor 保护（循环依赖），必须使用独立认证。

| 服务 | 层级 | 当前认证 | 目标认证 | 原因 |
|------|------|----------|----------|------|
| **Atlantis** | L1 | Basic Auth | **Basic Auth (保持)** | ⚠️ L1 不能用 L2 SSO |
| **K3s API** | L1 | Token | Token | 系统级，不变 |
| **K8s Dashboard** | L2 | Token + OAuth2-Proxy | Casdoor SSO | 可以用 L2 |
| **Vault UI** | L2 | Root Token | Casdoor OIDC | Vault 原生支持 |
| **Kubero UI** | L2 | 无认证 | Casdoor SSO | 可以用 L2 |
| **L4 Apps** | L4 | 应用自定义 | Casdoor SDK | 可以用 L2 |

## 当前实现：OAuth2-Proxy

当前使用 OAuth2-Proxy + GitHub OAuth 作为过渡方案：

- 配置文件: [`2.platform/1.oauth.tf`](../../2.platform/1.oauth.tf)
- 保护方式: Traefik ForwardAuth middleware

## 相关文件

- OAuth2-Proxy: [`2.platform/1.oauth.tf`](../../2.platform/1.oauth.tf)
- Dashboard: [`2.platform/3.dashboard.tf`](../../2.platform/3.dashboard.tf)
