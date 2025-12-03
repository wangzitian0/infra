# BRN-004 关键决策记录

记录影响设计与实施的关键决策，补充 `context.md` 的详细背景，保持时间顺序。

## 决策列表

- **域名方案扁平化**（2025-12-03）  
  - 原因: Cloudflare 免费版不支持多级子域  
  - 方案: 改为 `x-<env>.truealpha.club` 结构，兼容通配符证书  
  - 影响: 需同步 PEG-scaner IRD 文档

- **取消 Dev 环境 DNS**（2025-12-03）  
  - 原因: Dev 本地运行即可，无需 VPS 资源  
  - 方案: 仅为 test/staging/prod 配置 DNS  
  - 影响: 节省资源，聚焦可部署环境

- **VPS Bootstrap 自动化**（2025-12-03）  
  - 原因: 手动 SSH 配置不符合 IaC 原则  
  - 方案: `terraform/modules/vps-bootstrap` + remote-exec 自动化  
  - 影响: 一条 `terraform apply` 完成基础准备

- **文档责任分离**（2025-12-03）  
  - 原因: 设计/实施/操作混杂，重复度高  
  - 方案: 设计变更在 PEG-scaner BRN/IRD/TRD；实施/操作在 infra `docs/project/` + runbooks  
  - 影响: 设计变更需先改 PEG-scaner IRD，再同步实施

## 待决策/风险

- Test 预览环境域名及销毁策略  
- Backstage 健康检查接口设计与数据源选择  
- SigNoz 部署形态（单实例 vs 分层）

## 参考

- 详细背景: `context.md`  
- 设计文档: [IRD-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/infra/IRD-004.env_eaas_infra.md), [TRD-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/tech/TRD-004.env_eaas_implementation.md)
