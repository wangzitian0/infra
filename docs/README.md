# 📚 Documentation Index

## 主文档入口（标准 3-5 文件 + README）

`docs/project/BRN-004/`（新增内容优先落这里）
- `README.md` - 项目索引、外部 BRN/IRD/TRD 链接、阶段与状态
- `context.md` - 背景、环境信息、决策依据
- `progress.md` - 里程碑与完成度（补充/细化 `docs/PROGRESS.md`）
- `decisions.md` - 关键决策与变更记录（时间线）
- `ops.md` - 与本项目强相关的 SOP/运行手册入口（可链接 runbooks）

## 配套/参考文档（保留历史，不新增同类散件）
- **[0.hi_zitian.md](0.hi_zitian.md)** - 用户待办
- **[PROGRESS.md](PROGRESS.md)** - 跨环境整体完成度
- **[architecture.md](architecture.md)** - 系统架构与技术选型
- **[deployment-sop.md](deployment-sop.md)** - 通用部署 SOP 模板
- **[env.d/](env.d/)** - 环境特定 SOP（staging/test/prod）
- **[change_log/](change_log/)** - 变更记录（按 BRN）
- **[guides/](guides/)** - 开发/接入指南
- **[runbooks/](runbooks/)** - 运维操作手册
- **外部设计文档（PEG-scaner）**  
  - [BRN-004: EaaS 基础设施设计](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)  
  - [BRN-007: 应用环境机制](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-007.app_env_design.md)  
  - [IRD-004: 基础设施设计](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/infra/IRD-004.env_eaas_infra.md)  
  - [TRD-004: 实施方案](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/tech/TRD-004.env_eaas_implementation.md)

## 快速导航

- 👉 开始配置/部署: [0.hi_zitian.md](0.hi_zitian.md)
- 👉 查看当前项目实施: `project/BRN-004/`（优先）
- 👉 了解架构/选型: [architecture.md](architecture.md)
- 👉 参考通用 SOP: [deployment-sop.md](deployment-sop.md)
- 👉 环境特定操作: [env.d/](env.d/)
- 👉 运维操作: [runbooks/operations.md](runbooks/operations.md)
- 👉 变更记录: [change_log/BRN-004.md](change_log/BRN-004.md)

## 文档引用规则

### 引用 PEG-scaner 文档
使用完整 GitHub URL：
```markdown
[BRN-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
```

### 引用本仓库文档
使用相对路径：
```markdown
[架构设计](architecture.md)
```
