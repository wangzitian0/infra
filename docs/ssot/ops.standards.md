# 运维标准 SSOT

> **SSOT Key**: `ops.standards`
> **核心定义**: 定义基础设施的命名规范、标签策略及资源配额标准。

---

## 1. 命名规范 (Naming Convention)

| 资源类型 | 格式 | 示例 |
|----------|------|------|
| **Namespace** | `<layer>[-<env>]` | `platform`, `data-staging` |
| **Service** | `<app>[-<role>]` | `redis-master`, `casdoor` |
| **Domain** | `<service>.<scope_domain>` | `sso.zitian.party` |
| **Secret** | `<app>-<type>` | `postgres-creds` |

---

## 2. 标签策略 (Tagging)

所有 Kubernetes 资源应包含以下标准标签：

```yaml
metadata:
  labels:
    app.kubernetes.io/name: "myapp"
    app.kubernetes.io/instance: "myapp-staging"
    app.kubernetes.io/part-of: "cc-infra"
    app.kubernetes.io/managed-by: "terraform"
```

---

## 3. 资源配额 (Quotas)

| 环境 | CPU Request | Memory Request | Limit |
|------|-------------|----------------|-------|
| **Staging** | 10m | 64Mi | 2x Request |
| **Prod** | 100m | 256Mi | 2x Request |

---

## Used by

- [docs/ssot/README.md](./README.md)