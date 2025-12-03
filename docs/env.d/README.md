# 环境特定 SOP 索引

> 通用三层模型与密钥规则见 `../deployment-sop.md`。本目录维护四份环境 SOP：全局 IaC (Layer1+基建) 和 prod/staging/test（高度自动化，复用全局层）。

- `iac_sop.md` — 全局一次性层（Layer 1 + 基础基建声明）：单台 VPS 安装 Dokploy + Infisical + CI 入口；Cloudflare/DNS 预设；适用于后续所有环境的底座。
- `staging_sop.md` — 复用全局层；首个环境，负责验证 Terraform/Dokploy 流程。
- `test_sop.md` — 复用全局层；PR 预览环境，域名/Project 动态生成；追求全自动。
- `prod_sop.md` — 复用全局层；生产域名与验证清单；追求全自动。
