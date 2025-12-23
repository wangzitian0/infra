# 认证与授权 SSOT

> **一句话**：Bootstrap 保持独立根密钥，Platform 原生 OIDC 直连，Portal Gate 仅用于不支持 OIDC 的应用（避免双重认证），根密钥作为故障恢复通道。

## 认证架构

```mermaid
graph TD
    subgraph "认证方式"
        ROOT[根密钥<br/>1Password]
        SSO[Casdoor SSO<br/>GitHub/Password]
        VAULT_AUTH[Vault Auth<br/>Token/OIDC]
        GATE[Portal Gate<br/>OAuth2-Proxy + ForwardAuth]
    end

    subgraph "Bootstrap"
        B_ATLANTIS[Atlantis]
        B_K3S[K3s API]
    end

    subgraph "Platform"
        P_VAULT[Vault UI (OIDC)]
        P_DASH[K8s Dashboard (no OIDC)]
        P_CASDOOR[Casdoor]
        P_KUBERO[Kubero (OIDC)]
        P_SIGNOZ[SigNoz (OIDC)]
    end

    subgraph "Data"
        D_PG[PostgreSQL]
        D_REDIS[Redis]
    end

    ROOT -->|Basic Auth| B_ATLANTIS
    ROOT -->|Token| B_K3S
    
    ROOT -->|Root Token| P_VAULT
    SSO -->|OIDC| P_VAULT
    SSO -->|管理| P_CASDOOR

    SSO --> GATE
    GATE --> P_DASH
    SSO -->|OIDC| P_KUBERO
    SSO -->|OIDC| P_SIGNOZ

    VAULT_AUTH --> D_PG
    VAULT_AUTH --> D_REDIS
    VAULT_AUTH --> P_KUBERO
```

---

## 模块认证策略

| 模块 | 服务 | 认证方式 | 说明 |
|------|------|----------|------|
| **Bootstrap** | Atlantis | 根密钥 (Basic Auth) | 不能依赖 SSO (循环依赖) |
| **Bootstrap** | K3s API | 根密钥 (Token) | 系统级 |
| **Platform** | Vault | 根密钥 (Root Token) + SSO (OIDC 直连) | **不挂 Portal Gate** |
| **Platform** | Dashboard | Portal Gate (ForwardAuth) + Token | Dashboard 无原生 OIDC |
| **Platform** | Casdoor | 根密钥 (admin 密码) | SSO 入口本身 |
| **Platform** | Kubero | Casdoor OIDC 直连 | PaaS 控制面 |
| **Platform** | SigNoz | Casdoor OIDC 直连 | 可观测性控制面 |
| **Data** | PostgreSQL | Vault 动态凭据 | 业务 DB |
| **Data** | Redis | Vault 动态凭据 | 业务缓存 |

---

## 门户级认证分治

Portal Gate 与原生 OIDC 同时启用会导致双重认证。策略是**分治**：原生 OIDC 直连，Portal Gate 仅用于无 OIDC 的应用。

| 分类 | 服务 | 域名 | 认证路径 | 备注 |
|------|------|------|----------|------|
| 原生 OIDC | Vault UI | `https://secrets.<internal_domain>` | Casdoor OIDC 直连 | 禁用 forwardAuth |
| 原生 OIDC | Kubero UI | `https://kcloud.<internal_domain>` | Casdoor OIDC 直连 | |
| 原生 OIDC | SigNoz | `https://signoz.<internal_domain>` | Casdoor OIDC 直连 | |
| Portal Gate | Dashboard | `https://kdashboard.<internal_domain>` | ForwardAuth -> Casdoor | 登录后仍需 token |
| 独立认证 | Atlantis | `https://atlantis.<internal_domain>` | Basic Auth | break-glass |

---

## Vault 权限管理 (RBAC)

Vault 权限基于 Casdoor Roles 自动分配，采用 **Identity Groups** 架构。

### 职责模型
1. **Casdoor (IdP) → 身份 SSOT**: 管理“你是谁”和“你的标签” (Roles)。
   - 位置: `platform/91.casdoor-roles.tf`
2. **Vault (SP) → 授权 SSOT**: 根据标签映射具体 Policies。
   - 位置: `platform/91.vault-auth.tf`

### 角色映射
| Casdoor Role | Vault Identity Group | Vault Policy | 权限说明 |
|--------------|----------------------|--------------|---------|
| `vault-admin` | `admin` | `admin` | 完全管理权限 |
| `vault-developer` | `developer` | `developer` | 应用密钥读写 |
| `vault-viewer` | `viewer` | `viewer` | 只读权限 |

---

## 相关文件

- `platform/5.casdoor.tf` - Casdoor 部署
- `platform/90.casdoor-apps.tf` - OIDC 应用配置
- `platform/91.vault-auth.tf` - Vault OIDC 配置
- `platform/92.portal-auth.tf` - Portal Gate 配置
- `platform/10.kubero.tf` - Kubero 部署 (原生 OIDC)

---
*Last updated: 2025-12-24 (Removed Layer Levels)*
