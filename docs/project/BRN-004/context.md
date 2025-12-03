# BRN-004 实施上下文

**记录实施过程中的关键决策和背景信息**

---

## 🏗️ 环境信息

### VPS
- **提供商**: HostHatch
- **IP**: 103.214.23.41
- **用途**: Staging + Test (PR Preview) 共享

### 域名策略
- **Production**: truealpha.club, api.truealpha.club
- **Staging**: x-staging.truealpha.club, api-x-staging.truealpha.club
- **Test**: x-test-*.truealpha.club (wildcard for PR previews)
- **SSL**: 单一 `*.truealpha.club` 通配符证书覆盖所有

### Secrets 管理
- **方案**: Infisical Cloud
- **项目**: truealpha
- **环境**: staging, test, prod
- **变量数**: 81（from secrets/.env.example）

---

## 🤔 关键决策

### 决策1: 域名方案变更

**时间**: 2025-12-03  
**问题**: Cloudflare 免费版不支持多级子域名（dev.x.truealpha.club）  
**方案**: 改为扁平结构（x-dev.truealpha.club）  
**结果**: 兼容 SSL 证书和 Cloudflare 免费版

### 决策2: 取消 Dev 环境 DNS

**时间**: 2025-12-03  
**问题**: 开发环境应该本地运行，无需占用 VPS  
**方案**: dev 环境只用 localhost，只为 test/staging/prod 配置 DNS  
**结果**: 节省资源，专注于真正需要部署的环境

### 决策3: VPS Bootstrap 自动化

**时间**: 2025-12-03  
**问题**: 手动 SSH 安装 Docker/Dokploy 不符合 IaC 理念  
**方案**: 创建 terraform/modules/vps-bootstrap，通过 remote-exec 自动化  
**结果**: 一条 `terraform apply` 完成 VPS 准备

### 决策4: 文档重组遵循 BRN/IRD/TRD

**时间**: 2025-12-03  
**问题**: infra 文档混杂选型/设计/实施/操作，不清晰  
**方案**: Link 到 PEG-scaner 的 BRN/IRD/TRD，infra 只保留实施记录+操作手册  
**结果**: 文档职责清晰，避免重复

### 决策5: Dokploy 部署策略

**时间**: 2025-12-03  
**问题**: 单 VPS 如何隔离多个环境（staging, test, ...）  
**方案**: 一个 Dokploy 实例 + 多个 Projects  
**替代方案**: 
- ❌ 多个 Dokploy 实例（技术可行但管理混乱）
- ❌ 单 Dokploy + Docker Compose（绕过 Dokploy 优势）

**结果**: 
- 使用 Dokploy 原生 Project 功能
- 命名规范: `truealpha-{env}` 或 `truealpha-test-{PR#}`
- 扩展路径: 重要环境独立 VPS 后，每个 VPS 一个 Dokploy

---

## 🛠️ 技术约束

### 已知限制
1. **Cloudflare 免费版**: 不支持 Page Rules（CDN缓存配置）
2. **HostHatch**: 无 Terraform Provider，需手动管理 VPS
3. **Dokploy**: 社区生态小，部分功能需自行实现

### 解决方案
1. Cloudflare: 暂时禁用 CDN配置，未来升级 Zone-level API token
2. HostHatch: 通过 null_resource + remote-exec 管理
3. Dokploy: 保持简单配置，复杂需求用 Docker Compose

---

## 📦 依赖版本

| 工具 | 版本 | 备注 |
|------|------|------|
| Terraform | >= 1.6.0 | Provider: cloudflare ~> 4.0 |
| Docker | >= 24.0 | - |
| Docker Compose | >= 2.20 | - |
| Dokploy | latest | 自托管 PaaS |
| Infisical CLI | latest | Secrets 管理 |

---

## 🔄 变更历史

### 2025-12-03
- 创建 Terraform 模块（Cloudflare DNS + VPS Bootstrap）
- 配置 Docker Compose（base + 环境覆盖）
- 重组文档结构（BRN/IRD/TRD 规范）
- 删除 dev/ci 环境 DNS 配置

### 2025-12-02
- 初始 Terraform 配置
- 首次成功部署 DNS 记录（dev 环境）
- 文档迭代（architecture.md, developer-onboarding.md）

---

## 📚 参考资料

- [BRN-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
- [IRD-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/infra/IRD-004.env_eaas_infra.md)
- [TRD-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/tech/TRD-004.env_eaas_implementation.md)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Dokploy Documentation](https://docs.dokploy.com/)
