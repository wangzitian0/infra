# AI Agent 工作指南

## AGENTS.md - AI 工作指南

**本仓库**: https://github.com/wangzitian0/infra  
**应用仓库**: https://github.com/wangzitian0/PEG-scaner  
**设计文档**: https://github.com/wangzitian0/PEG-scaner/blob/main/docs/

---

## 📚 文档治理准则

### 依赖关系

```
PEG-scaner (app) ←──── infra 了解 app
                 app 不需要了解 infra
```

### 文档体系对应 + 设计变更流程

- ✅ **infra 可以保留自己的文档体系**，但必须和 PEG-scaner 的 BRN/IRD/TRD 对齐  
  - `docs/architecture.md` 对应 → `PEG-scaner/docs/specs/infra/IRD-004.env_eaas_infra.md`
  - `docs/runbooks/deployment.md` 对应 → `PEG-scaner/docs/specs/tech/TRD-004.env_eaas_implementation.md`
  - `docs/project/BRN-004/` 对应 → 实施记录（infra 特有）
- ❌ **不要只改 infra 的 architecture.md 就算设计变更**
- ✅ **设计变更必须修改 PEG-scaner 的 IRD 文档**
  - 例如：改变域名策略 → 更新 `PEG-scaner/docs/specs/infra/IRD-004.env_eaas_infra.md`
  - 例如：三层架构调整 → 更新 IRD
- ✅ **infra 特定的实施细节**可以只在 infra/docs 记录
  - 例如：Terraform 模块具体实现 → 可以只在 infra
  - 例如：某环境的部署状态 → `terraform/envs/*/STATUS.md`

**简单判断**: 如果 app (PEG-scaner) 需要感知的设计 → 改 IRD；如果只是 infra 内部实施 → infra/docs

---

### 主文档形态（集中到 `@docs/project/`）

- **唯一入口**: 每个项目/BRN 在 `docs/project/<BRN-ID>/` 下维护 **3-5 个标准文件 + README.md**，不新增其他文件名  
  - `README.md` → 本项目索引、外部链接、当前阶段与状态  
  - `context.md` → 背景、环境信息、决策依据  
  - `progress.md` → 里程碑/状态追踪（替代零散进度）  
  - `decisions.md` → 关键决策和变更记录（保留时间线）  
  - `ops.md` → 与该项目强相关的 SOP/运行手册入口（可链接到 runbooks）
- **其他 docs/* 文件**: 作为历史/参考存在（如 `architecture.md`、`guides/`、`runbooks/` 等），**不新增同类散文档**，新内容一律纳入上述标准文件或在 PEG-scaner 侧更新 BRN/IRD/TRD。
- **外部规范**: 仍需在 PEG-scaner 仓库同步 BRN/IRD/TRD 的设计变更；本仓库只补充实施/操作细节。

---

### 文档引用规则

**❌ 错误 - 相对路径**:
```markdown
[BRN-004](../PEG-scaner/docs/origin/BRN-004.md)
```

**✅ 正确 - 完整 GitHub URL**:
```markdown
[BRN-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
```

---

## 🗂️ 目录结构与用途

首选路径：`docs/project/<BRN-ID>/`（标准 3-5 文件+README）。其余目录为既有资产，新增内容请遵循上方主文档形态。

```
infra/
├── README.md                  → 项目总入口
├── AGENTS.md                ## 📁 目录导航 (给 AI 看的)
├── docs/                      → 文档（以 project/ 为主，其余为参考/历史）
│   ├── README.md              → 文档导航
│   ├── 0.hi_zitian.md         → 用户待办事项
│   ├── PROGRESS.md            → 整体完成度追踪 (代码 vs 部署)
│   ├── deployment-sop.md      → 🔧 通用部署SOP模板 (所有环境复用)
│   ├── architecture.md        → 技术架构文档
│   ├── env.d/                 → 环境特定SOP
│   │   ├── staging_sop.md     → Staging 环境配置和操作
│   │   ├── test_sop.md        → Test (PR预览) 配置
│   │   └── prod_sop.md        → Production 配置
│   ├── change_log/            → 变更记录
│   ├── guides/                → 操作指南
│   ├── project/               → 📌 主文档落点（标准 3-5 文件+README）
│   │   └── BRN-004/           → 当前项目实施记录
│   └── runbooks/              → 运维手册
├── terraform/                 → 基础设施即代码
│   ├── modules/               → 可复用模块
│   └── envs/                  → 环境配置
│       ├── staging/
│       │   ├── STATUS.md      → 📊 Staging 部署状态
│       │   ├── terraform.tfvars
│       │   └── main.tf
│       ├── test/
│       │   └── STATUS.md      → 📊 Test 部署状态
│       └── prod/
│           └── STATUS.md      → 📊 Prod 部署状态
├── compose/                   → Docker Compose 配置
├── scripts/                   → 自动化脚本
├── observability/             → 可观测性配置
└── ci/                        → CI/CD 配置
```

## 🎯 核心设计：Backstage 健康监测系统

### 监测目标

**环境 × 基建 = 是否真的好了？**

| 环境 | 基建状态 | 应用状态 | 整体健康 |
|------|---------|---------|---------|
| dev | ✅ | ✅ | 🟢 健康 |
| test | ✅ | ⚠️ | 🟡 警告 |
| staging | ✅ | ❌ | 🔴 故障 |
| prod | ✅ | ✅ | 🟢 健康 |

### Backstage 组件设计

#### 1. Service Catalog（服务目录）

**catalog-info.yaml 模板**:
```yaml
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: truealpha
  title: TrueAlpha Platform
spec:
  owner: platform-team

---
# 环境资源
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: environment-dev
  title: Development Environment
  annotations:
    backstage.io/health-check: "https://dev.truealpha.club/health"
spec:
  type: environment
  owner: platform-team
  system: truealpha
```

#### 2. Health Dashboard（健康仪表盘）

监测所有环境和基建组件的健康状态。

#### 3. TechDocs（技术文档）

自动从 `/docs` 生成文档站点。

### 实施路径

**Phase 1**: 定义 catalog entities  
**Phase 2**: 开发健康检查插件  
**Phase 3**: 自动化操作

## 📍 每个目录的快速指南

详见各目录的 README.md：
- `/docs/README.md` - 文档导航
- `/terraform/README.md` - 如何使用 Terraform
- `/compose/README.md` - 如何使用 Docker Compose
- `/backstage/README.md` - Backstage 设置（重点！）

## 🤖 AI 修改文件时的规则

### 文档更新规则

- 使用完整 GitHub URL 引用 PEG-scaner 文档
- 更新对应的 change_log
- 如果有用户待办，更新 0.hi_zitian.md
- **更新 PROGRESS.md**: 反映代码完成度 vs 部署状态
- **更新环境STATUS.md**: 如果影响特定环境部署进度
- **维护文档唯一性**: 介绍和架构文档应该唯一，避免重复
- **新增/修改文档优先落在 `docs/project/<BRN-ID>/` 的标准文件中**（README/context/progress/decisions/ops），避免再新增散落文件

### 修改基础设施时
- 先更新 Terraform 模块
- 更新对应环境的 STATUS.md
- 如果是通用流程，更新 deployment-sop.md
- 如果是环境特定，更新 env.d/{env}_sop.md
- 同步更新文档

### 添加新环境时
1. 创建 `terraform/envs/{env}/STATUS.md`
2. 创建 `docs/env.d/{env}_sop.md` (基于 deployment-sop.md)
3. 更新 PROGRESS.md 添加新环境追踪
4. 更新 README.md 文档导航记录到 change_log
- 更新相关 README

## 🎯 Backstage 优先级

Backstage 是整个系统的核心入口：
1. ✅ 先完善 catalog 定义
2. ✅ 再开发健康检查
3. ✅ 最后添加自动化操作

**目标**: 让用户通过 Backstage 一眼看到所有环境的健康状态！
