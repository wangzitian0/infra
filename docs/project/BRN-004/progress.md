# BRN-004 进度追踪

**目标**: 以 BRN/IRD/TRD 为准，记录实施和部署完成度，避免进度分散。

## 里程碑状态

| 里程碑 | 负责人 | 代码完成度 | 部署完成度 | 备注 |
|--------|--------|------------|------------|------|
| Terraform 基础设施（VPS + DNS） | infra | ✅ | ✅ | 已创建模块并应用到 staging/test/prod 规划 |
| Docker Compose 基座 | infra | ✅ | ✅ | base + 环境覆盖 |
| Secrets 管理 (Infisical) | infra | 🟡 | 🟡 | Dokploy API + Terraform 引导已就绪，待填密钥并部署 |
| Staging 首次部署 | infra | 🟡 | 🟡 | 待完成 GitHub Secrets、Terraform apply、服务验证 |
| Test 预览环境 | infra | ⏳ | ⏳ | 待配置域名与流水线 |
| Production 上线 | infra | ⏳ | ⏳ | 待 staging 验证后推进 |
| SigNoz 可观测性 | infra | ⏳ | ⏳ | 待部署与接入 |
| Backstage 集成 | infra | ⏳ | ⏳ | 依赖 catalog/health 检查开发 |

> 交叉参考: 跨环境汇总见 `docs/PROGRESS.md`；环境落地进度见 `terraform/envs/{env}/STATUS.md`。

## 短期行动清单

1. 完成 Staging GitHub Secrets + 自托管 Infisical 环境配置（含部署脚本/模块）  
2. 执行 Staging Terraform apply 并验证服务健康  
3. 补齐 Test 预览环境域名和流水线脚本  
4. 定义 Backstage catalog 实体与健康检查接口雏形

## 参考

- `docs/PROGRESS.md` - 跨环境总体进度  
- `terraform/envs/staging/STATUS.md` - Staging 具体状态  
- `terraform/envs/test/STATUS.md` - Test 具体状态  
- `terraform/envs/prod/STATUS.md` - Prod 具体状态
