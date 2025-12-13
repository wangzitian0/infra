# K3s 与 Kubero SSOT

> **核心问题**：集群和 PaaS 平台如何管理？

## K3s 集群架构

```
┌─────────────────────────────────────────────────────────────┐
│  L1 Bootstrap - K3s Cluster                                 │
├─────────────────────────────────────────────────────────────┤
│  组件：                                                      │
│  • K3s Server (单节点)                                       │
│  • Traefik Ingress Controller (内置)                         │
│  • cert-manager (Let's Encrypt)                              │
│  • local-path-provisioner (存储)                             │
├─────────────────────────────────────────────────────────────┤
│  配置来源：                                                   │
│  • VPS_HOST: GitHub Secret                                   │
│  • VPS_SSH_KEY: GitHub Secret                                │
│  • KUBECONFIG: L1 output → Atlantis 环境变量                 │
└─────────────────────────────────────────────────────────────┘
```

## 服务矩阵

| 组件 | 层级 | 职责 | 配置文件 |
|------|------|------|----------|
| **K3s** | L1 | Kubernetes 运行时 | `1.bootstrap/1.k3s.tf` |
| **Traefik** | L1 | Ingress/负载均衡 | K3s 内置 |
| **cert-manager** | L1 | TLS 证书自动化 | `1.bootstrap/3.dns_and_cert.tf` |
| **local-path** | L1 | 持久化存储 | `1.bootstrap/4.storage.tf` |
| **Kubero** | L2 | PaaS 平台 | `2.platform/4.kubero.tf` |

## StorageClass 规范

| StorageClass | 用途 | 保留策略 | 用于 |
|--------------|------|----------|------|
| `local-path` | 临时数据 | Delete | 无状态服务 |
| `local-path-retain` | 持久数据 | Retain | 数据库、Vault |

## Kubero PaaS

Kubero 是 L2 平台的 PaaS 组件，用于部署应用：

```
┌─────────────────────────────────────────────────────────────┐
│  L2 Platform - Kubero                                        │
├─────────────────────────────────────────────────────────────┤
│  命名空间: kubero, kubero-operator-system                    │
│  访问: https://kcloud.<internal_domain>                      │
│  功能:                                                       │
│  • Git-push 部署                                             │
│  • 环境管理 (staging/prod)                                   │
│  • 自动扩缩容                                                 │
└─────────────────────────────────────────────────────────────┘
```

## Namespace 规范

| Namespace | 层级 | 用途 |
|-----------|------|------|
| `kube-system` | L1 | K3s 核心组件 |
| `bootstrap` | L1 | Atlantis |
| `platform` | L2 | Vault, Dashboard, OAuth2-Proxy, Platform PG |
| `kubero` | L2 | Kubero UI |
| `kubero-operator-system` | L2 | Kubero Operator |
| `data-<env>` | L3 | 业务数据库（`data-staging` / `data-prod`） |
| `apps-<env>` | L4 | 业务应用（`apps-staging` / `apps-prod`） |

> 环境模型（workspace/state/namespace/domain 的统一规则）见：[`env.md`](./env.md)

## 相关文件

- K3s: [`1.bootstrap/1.k3s.tf`](../../1.bootstrap/1.k3s.tf)
- 存储: [`1.bootstrap/4.storage.tf`](../../1.bootstrap/4.storage.tf)
- Kubero: [`2.platform/4.kubero.tf`](../../2.platform/4.kubero.tf)
