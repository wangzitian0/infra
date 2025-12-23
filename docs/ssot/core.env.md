# 环境与隔离模型 SSOT

> **核心问题**：如何管理多个环境？隔离边界在哪里？如何给不同环境传参？

---

## 1. 核心设计原则

- **统一基座 (Single Cluster)**：Staging 和 Prod 共享同一个 K3s 集群以降低维护成本和资源开销。
- **Workspace 隔离**：Data 层使用目录路径（`envs/staging/data` vs `envs/prod/data`）区分 State 状态。
- **Namespace 隔离**：Kubernetes 的 Namespace 作为环境隔离的硬边界。
- **统一控制面 (Platform)**：控制面（Vault, SSO, PaaS Controller, Observability）全局唯一，管理所有环境。

---

## 2. 模块与多环境映射

| 模块 | 份数 | 多环境策略 |
|:---|:---:|:---|
| **Bootstrap** | 1 套 | 全局单例（K3s, Atlantis, DNS）|
| **Platform** | 1 套 | 全局单例（Vault, SSO, PaaS, Observability）|
| **Data** | N 套 | Per-env (staging/prod)，目录级隔离 |

---

## 3. Namespace 隔离规则

| 隔离级别 | Namespace | 适用场景 |
|:---|:---|:---|
| **共享 (Shared)** | `kube-system`, `cert-manager`, `bootstrap`, `platform` | 集群核心、Atlantis、Vault/SSO 基建 |
| **工作负载 (Environment)** | `data-staging`, `apps-staging` | Staging 环境的数据与应用 |
| **工作负载 (Environment)** | `data-prod`, `apps-prod` | Prod 环境的数据与应用 |

> 备注：Platform 层的控制器（如 Kubero）运行在 `kubero` namespace，但它部署的应用运行在 `apps-staging` 或 `apps-prod`。

---

## 4. 变量与参数传递 (The Variable Chain)

### 4.1 Bootstrap / Platform：全局单一配置
Bootstrap 和 Platform 是单例，其变量由 GitHub Secrets 或根目录变量提供。

### 4.2 Data：`envs/*/data/` 环境参数
通过目录结构自动注入 `environment` 变量（见根目录 `terragrunt.hcl`）。

---

## 5. 域名与入口规则

| 环境 | 域名模式 | 示例 | 负责人 |
|:---|:---|:---|:---|
| **基建/Platform** | `internal_domain` | `secrets.zitian.party` | Platform (Vault/Casdoor) |
| **Staging** | `stg.{app}.base_domain` | `stg.myapp.truealpha.club` | Data (App Ingress) |
| **Prod** | `{app}.base_domain` | `myapp.truealpha.club` | Data (App Ingress) |

---

## Used by

- [docs/README.md](../README.md)
- [docs/ssot/core.dir.md](./core.dir.md)
