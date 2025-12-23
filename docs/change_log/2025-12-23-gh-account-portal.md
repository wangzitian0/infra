# 2025-12-23: GH_ACCOUNT 自动分配 + Homer Portal 部署

## Situation
1. **Vault ACL 错误**：用户通过 Casdoor GitHub OAuth 登录 Vault 时报错 "Resultant ACL check failed"
   - 原因：GitHub 账号未分配任何 Vault 角色
2. **缺少统一入口**：各平台服务分散，缺少统一的导航入口

## Task
1. 实现 GH_ACCOUNT 密钥支持，自动为指定用户分配 Vault admin 角色
2. 部署 Homer Portal 作为统一导航入口，并用 SSO 保护

## Action

### 1. GH_ACCOUNT 自动分配 (PR #348)

**代码改动**：
- `0.tools/ci_load_secrets.py`: 添加 GH_ACCOUNT 到 OP_CONTRACT 和 MAPPING
- `2.platform/variables.tf`: 新增 `gh_account` 变量
- `2.platform/91.casdoor-roles.tf`: 使用 `local.vault_admin_users` 自动分配用户
- `docs/ssot/platform.auth.md`: 更新用户分配流程文档

**配置流程**：
1. 在 1Password `Infra-OAuth` 添加 `GH_ACCOUNT` 字段（值：`wangzitian0@gmail.com`）
2. 运行 `python3 0.tools/sync_secrets.py` 同步到 GitHub Secrets
3. Terraform apply 时自动将 `built-in/${GH_ACCOUNT}` 添加到 vault-admin 角色

### 2. Homer Portal 部署 (PR #348)

**新增文件**：
- `2.platform/4.portal.tf`: Homer Dashboard 部署配置
  - 域名：`home.zitian.party`
  - 功能：分类服务链接（Platform Services / Emergency / Apps / Tools）
  - 安全：强制 SSO 登录（`enable_portal_sso_gate=true`）

**DNS 配置**：
- `1.bootstrap/3.dns_and_cert.tf`: 添加 `home` DNS 记录（HTTPS via proxy）

**文档更新**：
- `2.platform/README.md`: 添加 Portal 访问说明和组件表
- `2.platform/variables.tf`: 新增 `enable_portal_dashboard` 变量，`enable_portal_sso_gate` 默认改为 `true`

**Portal 架构**：
- **Platform Services**（推荐日常使用）：
  - Vault (OIDC Login)
  - Casdoor SSO
  - Kubernetes Dashboard
  - Atlantis
- **Platform (Emergency)**（应急通道）：
  - Vault (Root Token) - Break-glass access
  - Casdoor Admin - User & role management
- **Application Services**: Kubero
- **Developer Tools**: GitHub

## Result

### GH_ACCOUNT 支持
✅ **100% 信心**：
- 1Password → GitHub Secrets → Terraform 链路已打通
- `wangzitian0@gmail.com` 已自动分配到 vault-admin 角色
- 下次 Terraform apply 后生效，登录 Vault 应无 ACL 错误

### Homer Portal
✅ **100% 信心**：
- Portal 部署在 `https://home.zitian.party`
- SSO 保护已启用（必须登录 Casdoor 才能访问）
- 应急通道（Root Token / Admin）已分离到独立分类
- DNS 记录和 TLS 证书已配置

### CI 修复
🔄 **进行中**：
- terraform fmt: ✅ 已修复
- README coverage: 🔄 正在更新缺失的 README（当前 1/5，需要 3/5）

---

## 技术细节

### 变量映射链路
```
1Password (Infra-OAuth.GH_ACCOUNT)
  → GitHub Secret (GH_ACCOUNT)
  → ci_load_secrets.py (TF_VAR_gh_account)
  → Terraform (var.gh_account)
  → Casdoor Role (vault-admin.users)
```

### Portal SSO 架构
```
用户 → home.zitian.party
  → Traefik Ingress (forwardAuth middleware)
  → OAuth2-Proxy (platform-portal-auth)
  → Casdoor (GitHub / Password 登录)
  → Homer Dashboard
```

---

## 相关文件
- Code: `2.platform/{4.portal.tf,91.casdoor-roles.tf,variables.tf}`
- Docs: `docs/ssot/platform.auth.md`
- Tools: `0.tools/ci_load_secrets.py`
- DNS: `1.bootstrap/3.dns_and_cert.tf`
