# 流程 SSOT

> **核心问题**：如何保证每个组件可用？

**答案**：分层检查 + Audit 追踪

---

## 1. 健康检查分层

```
┌─────────────────────────────────────────────────────────────┐
│  时机        │  能力                │  作用                 │
├─────────────────────────────────────────────────────────────┤
│  Plan       │  variable.validation │  拒绝无效输入          │
│  Apply 前   │  precondition        │  验证依赖就绪          │
│  Pod 启动   │  initContainer       │  等待依赖可用          │
│  运行时     │  readiness/liveness  │  流量控制 / 自动重启   │
│  Apply 后   │  postcondition       │  验证部署成功          │
└─────────────────────────────────────────────────────────────┘
```

### 依赖拓扑

```
PostgreSQL ─┬─→ Vault     (initContainer 等待 PG)
            └─→ Casdoor   (initContainer 等待 PG)
```

### 组件标准模板

```hcl
# 所有依赖 PG 的组件都用这个模式
resource "helm_release" "xxx" {
  lifecycle {
    precondition {
      condition     = data.external.pg_ready.result.ok == "true"
      error_message = "PostgreSQL not ready"
    }
  }
}
```

```yaml
# K8s: 等待依赖 + 健康检查
initContainers:
  - name: wait-for-postgres
    image: busybox:1.36
    command: ['sh', '-c', 'until nc -z postgresql.platform.svc 5432; do sleep 2; done']
readinessProbe:
  exec: { command: ["健康检查命令"] }
livenessProbe:
  exec: { command: ["健康检查命令"] }
```

---

## 2. 部署流程

### L1 Bootstrap（GitHub Actions）

```
push to main → plan (validation + check) → apply (pre/post condition)
```

### L2-L4（Atlantis GitOps）

```
PR → atlantis plan → review → atlantis apply → merge
```

**Lock 策略**：`parallel_plan: true`，plan 失败自动 unlock。

---

## 3. Drift 管理

### 原则

> 允许手动操作，但有 Audit 追踪

### 机制

```
手动 kubectl/helm
       ↓
K8s Audit Log 记录 (who/what/when)
       ↓
下次 atlantis apply 前自动显示:
  "上次 apply 后的手动操作: ..."
       ↓
Reviewer 知晓上下文 → apply
```

### Audit 配置

```yaml
# /etc/rancher/k3s/config.yaml
kube-apiserver-arg:
  - audit-log-path=/var/log/k8s-audit.log
  - audit-policy-file=/etc/rancher/k3s/audit-policy.yaml
```

### Drift 修复

| 场景 | 命令 |
|------|------|
| 资源被删 | `terraform apply` |
| 资源被创建 | `terraform import` |
| State 残留 | `terraform state rm` |

---

## 4. 灾难恢复

| 场景 | 恢复 |
|------|------|
| Pod 挂 | K8s 自动重建 |
| 依赖未就绪 | initContainer 等待 |
| Vault sealed | `vault operator unseal <key>` |
| PG 数据丢失 | 删 PVC → apply → reinit |
| VPS 丢失 | 1Password → 新 VPS → L1 → L2 |

### 1Password 密钥

- `Vault Unseal Keys` - unseal
- `Casdoor Admin` - SSO 管理
- `VPS SSH Key` - 服务器访问
- `R2 Credentials` - TF state

---

## 相关文件

| 文件 | 用途 |
|------|------|
| `1.bootstrap/*.tf` | L1 组件实现 |
| `2.platform/*.tf` | L2 组件实现 |
| `atlantis.yaml` | GitOps 配置 |
