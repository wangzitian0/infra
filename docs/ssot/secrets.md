# 密钥管理 SSOT

> **核心问题**：这个密钥在哪配置？谁生成？谁消费？

## 分层模型

| 层级 | 密钥类型 | 生成方式 | 存储位置 | SSOT |
|------|----------|----------|----------|------|
| **根密钥** | SSH/R2/CF/GitHub | 人工创建 | 1Password | ❌ 人工 |
| **Bootstrap** | Platform PG 密码 | 人工设置 | GitHub Secret | ❌ L1 豁免 |
| **Runtime** | 业务 DB/API 密钥 | TF random | Vault | ✅ 自动化 |
| **派生** | Pod 获取的凭证 | Vault Agent | K8s Secret | ✅ 自动化 |

## 根密钥清单 (1Password 恢复一切)

| 密钥名 | 用途 | 丢失影响 | 恢复方式 |
|--------|------|----------|----------|
| `VPS_SSH_KEY` | SSH 登录 VPS | 无法访问节点 | 重新生成 SSH Key |
| `R2_ACCESS_KEY` | TF State 存储 | 无法 plan/apply | Cloudflare 控制台重建 |
| `CLOUDFLARE_API_TOKEN` | DNS/Cert | 无法更新域名 | CF 控制台重建 |
| `GITHUB_APP_KEY` | Atlantis 身份 | CI/CD 失效 | GitHub App 重新签发 |
| `VAULT_ROOT_TOKEN` | Vault 管理 | 无法管理 Vault | init 时备份 |
| `VAULT_UNSEAL_KEYS` | Vault 解封 | Vault 无法启动 | init 时备份 |

## Bootstrap 密钥 (L1 豁免 SSOT)

| 变量名 | 用途 | 来源 → 目标 |
|--------|------|-------------|
| `TF_VAR_platform_pg_password` | Vault/Casdoor DB | GitHub Secret → L1 Helm |
| `TF_VAR_atlantis_web_password` | Atlantis Web UI | GitHub Secret → L1 Helm |
| `TF_VAR_vault_postgres_password` | (同上别名) | GitHub Secret → L1 Helm |

## Runtime 密钥 (L2+ 遵守 SSOT)

| 服务 | 密钥 | 生成 | Vault Path | 消费者 |
|------|------|------|------------|--------|
| Redis | 密码 | TF random | `secret/data/redis` | L4 Apps |
| Neo4j | 密码 | TF random | `secret/data/neo4j` | L4 Apps |
| ClickHouse | 密码 | TF random | `secret/data/clickhouse` | L4 Apps |
| 业务 PG | 密码 | TF random | `secret/data/postgres` | L4 Apps |
| OAuth Client | ID/Secret | **人工创建** → 存 Vault | `secret/platform/oauth` | Casdoor |

## K8s Secret — 人类无感

所有 L2+ 的 K8s Secret 由 Vault Agent Injector 自动注入：
- Pod annotation: `vault.hashicorp.com/agent-inject: "true"`
- 路径: `/vault/secrets/<name>`
- 人类不需要也不应该手动查看/修改这些 Secret

## Vault 路径规范

```
secret/
├── platform/           # L2 平台组件 (仅限 L2 TF 写入)
│   └── oauth           # Casdoor OAuth credentials
├── data/               # L3 数据库凭证 (TF 生成)
│   ├── postgres        # { username, password, host, port, database }
│   ├── redis           # { password, host, port }
│   ├── neo4j           # { password, uri }
│   └── clickhouse      # { password, host, port }
└── apps/               # L4 应用特定密钥 (应用自管)
    └── <app-name>/
```
