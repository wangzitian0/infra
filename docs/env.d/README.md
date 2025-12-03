# 环境特定 SOP 索引

> 环境差异化操作和配置集中在此；通用三层部署模型与密钥规则见 `../deployment-sop.md`。

- `staging_sop.md` — 包含一次性 Layer 1 安装（Dokploy+Infisical）及环境细节  
- `test_sop.md` — 复用 Layer 1，全量环境变量从 Infisical，PR 预览域名/Project 规则  
- `prod_sop.md` — 复用 Layer 1，生产域名与验证清单
