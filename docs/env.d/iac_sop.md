# IaC / 全局层 (Layer 1 + 基础基建) SOP

**目的**: 在单台 VPS 上一次性完成全局平台与基础基建声明，供 staging/test/prod 复用。完成后，其他环境只需运行 Terraform (Layer 2) + Dokploy/Compose (Layer 3)。

## 角色与组件
- 运行时/入口: Dokploy（单实例，内含 Traefik）
- 密钥管理: Infisical（Cloud 版或自托管，Machine Identity）
- 网络/边界: Cloudflare（DNS/CDN/WAF）
- 观测（预留）: SigNoz（可后续部署）
- CI/CD: GitHub Actions（使用 MI 拉取密钥）

## 一次性安装步骤（仅此处执行）
1) **安装 Docker**（VPS）  
```bash
curl -fsSL https://get.docker.com | sh
```
2) **安装 Dokploy**（VPS）  
```bash
curl -sSL https://dokploy.com/install.sh | sh
```
3) **Infisical 准备**（Cloud 或自托管）  
   - 创建 Project: `truealpha`  
   - 环境: staging / test / prod  
   - 导入 `secrets/.env.example` 全部变量，填入真实值（含 SSH/Cloudflare/DB/应用等）  
   - 为每个环境创建 Machine Identity (MI) → 记下 Client ID/Secret/Project ID
4) **GitHub Secrets（仅 MI 三元组）**  
   在仓库 Settings → Secrets and variables → Actions：`INFISICAL_CLIENT_ID` / `INFISICAL_CLIENT_SECRET` / `INFISICAL_PROJECT_ID`

> 完成上述步骤后，不再在 GitHub Secrets 放置 SSH/Cloudflare/DB 等任何凭据，这些均在 Infisical。

## Terraform 预设（基础基建声明）
- Cloudflare DNS/WAF、VPS 引导、公共配置放在 `terraform/envs/{env}`（从 staging 开始）。  
- 推荐顺序：先完成本文件，再执行 `staging_sop.md` 的 Layer 2/3。

## 完成标志
- Dokploy UI 可访问，管理员已创建  
- Infisical 项目与三个环境存在，变量齐全，MI 可用  
- GitHub Secrets 仅包含 MI 三元组  
- Cloudflare 域名可管理（未必已创建记录，记录在 Layer 2 中声明）
