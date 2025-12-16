# 网络 SSOT

> **核心问题**：服务使用什么域名？Cloudflare 配置？

## 域名规则

| 模式 | Cloudflare 代理 | 用途 | 示例 |
|------|-----------------|------|------|
| `<service>.<internal_domain>` | ✅ Orange (443) | 内部平台 | `atlantis.zitian.party` |
| `k3s.<internal_domain>` | ❌ Grey (DNS-only) | K3s API | `k3s.zitian.party:6443` |
| `x-<env>.<base_domain>` | ✅ Orange | 测试环境 | `x-staging.truealpha.club` |
| `<base_domain>` | ✅ Orange | 生产 | `truealpha.club` |

> 环境模型（workspace/state/namespace/domain 的统一规则）见：[`env.md`](./env.md)

## 服务域名映射

| 服务 | 域名 | 层级 | Ingress |
|------|------|------|---------|
| Atlantis | `atlantis.<internal_domain>` | L1 | ✅ |
| Vault | `secrets.<internal_domain>` | L2 | ✅ |
| Dashboard | `kdashboard.<internal_domain>` | L2 | ✅ |
| Casdoor | `sso.<internal_domain>` | L2 | ✅ |
| Kubero | `kcloud.<internal_domain>` | L4 | ✅ |
| SigNoz | `signoz.<internal_domain>` | L4 | 🔜 待部署 |

### 业务应用域名（L4，多环境）

- **staging**：`x-staging.<base_domain>` / `x-staging-api.<base_domain>`
- **prod**：`<base_domain>` / `api.<base_domain>`

## TLS 证书

使用 cert-manager + Let's Encrypt 自动签发：

```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

## 安全加固

### Atlantis IP 白名单

仅允许 GitHub Webhook IP 访问：

```yaml
# Ingress annotation
nginx.ingress.kubernetes.io/whitelist-source-range: "140.82.112.0/20,185.199.108.0/22,192.30.252.0/22"
```

## 相关文件

- DNS 配置: [`1.bootstrap/3.dns_and_cert.tf`](../../1.bootstrap/3.dns_and_cert.tf)
- Atlantis Ingress: [`1.bootstrap/2.atlantis.tf`](../../1.bootstrap/2.atlantis.tf)
- Network 详情: [`1.bootstrap/network.md`](../../1.bootstrap/network.md)

---

## Used by（反向链接）

- [README.md](./README.md)
- [core.env.md](./core.env.md)
- [ops.alerting.md](./ops.alerting.md)
- [ops.observability.md](./ops.observability.md)
