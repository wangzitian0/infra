# Bootstrap 网络层 SSOT

> [!NOTE]
> 核心问题：DNS 如何配置？TLS 证书如何颁发？Cloudflare 代理规则？

---

## 网络架构概览

基础设施遵循 [AGENTS.md](../../AGENTS.md) 的 4 层设计 (L1-L4)。本层负责核心 DNS 解析、TLS 证书自动化及 Ingress 路由基础。

### 组件概览

| 组件 | 职责 | 代码位置 |
|------|------|----------|
| **Cloudflare DNS** | 域名解析 | [3.dns_and_cert.tf](../../bootstrap/3.dns_and_cert.tf) |
| **cert-manager** | TLS 证书 (Let's Encrypt) | [3.dns_and_cert.tf](../../bootstrap/3.dns_and_cert.tf) |
| **Traefik Ingress** | K3s 默认 Ingress 控制器 | K3s 内置 |


---

## DNS 配置

### Cloudflare 记录类型

| 模式 | 代理 | 用途 | 示例 |
|------|------|------|------|
| `<service>.<internal_domain>` | ✅ Orange (443) | 内部平台 | `atlantis.zitian.party` |
| `k3s.<internal_domain>` | ❌ Grey (DNS-only) | K3s API | `k3s.zitian.party:6443` |
| `<base_domain>` | ✅ Orange | 生产应用 | `truealpha.club` |
| `x-staging.<base_domain>` | ✅ Orange | Staging 应用 | `x-staging.truealpha.club` |

### 变量

| 变量 | 用途 | 示例 |
|------|------|------|
| `internal_domain` | 内部平台域名 | `zitian.party` |
| `base_domain` | 业务应用域名 | `truealpha.club` |

---

## TLS 证书

### cert-manager 配置

使用 Let's Encrypt 自动签发：

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
```

### Ingress 使用

```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

---

## 服务域名映射

| 服务 | 域名 | 层级 | Ingress |
|------|------|------|---------|
| Atlantis | `atlantis.<internal_domain>` | Bootstrap | ✅ |
| Vault | `secrets.<internal_domain>` | Platform | ✅ |
| Casdoor | `sso.<internal_domain>` | Platform | ✅ |
| Kubero | `kcloud.<internal_domain>` | Platform | ✅ |
| K3s API | `k3s.<internal_domain>` | Bootstrap | ❌ (直接访问) |

---

## 安全加固

### Atlantis IP 白名单

仅允许 GitHub Webhook IP 访问：

```yaml
nginx.ingress.kubernetes.io/whitelist-source-range: "140.82.112.0/20,185.199.108.0/22,192.30.252.0/22"
```

### Cloudflare 安全设置

- **SSL/TLS**: Full (strict)
- **Always Use HTTPS**: On
- **Minimum TLS Version**: 1.2

---

## 相关文件

- DNS 配置: [`bootstrap/3.dns_and_cert.tf`](../../bootstrap/3.dns_and_cert.tf)
- Atlantis Ingress: [`bootstrap/2.atlantis.tf`](../../bootstrap/2.atlantis.tf)

---

## Used by

- [docs/ssot/README.md](./README.md)
- [docs/ssot/core.md](./core.md)
- [bootstrap/README.md](../../bootstrap/README.md)
