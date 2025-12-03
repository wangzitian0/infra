# AI Agent 工作指南

## 📦 Repo 关系

**本仓库**: https://github.com/wangzitian0/infra  
**应用仓库**: https://github.com/wangzitian0/PEG-scaner

### 依赖关系

```
infra/ (基础设施)
  ↓ 部署
PEG-scaner/ (应用代码)
```

- **infra**: 管理所有环境的基础设施（Terraform, Docker Compose, CI/CD）
- **PEG-scaner**: 应用代码，被 infra 部署到各个环境

### 文档引用规则

**❌ 错误 - 相对路径**:
```markdown
[BRN-004](../PEG-scaner/docs/origin/BRN-004.md)
```

**✅ 正确 - 完整 GitHub URL**:
```markdown
[BRN-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
```

## 🗂️ 目录结构与用途

```
infra/
├── README.md                  → 项目总入口
├── AGENTS.md                ## 📁 目录导航 (给 AI 看的)

```
infra/
├── docs/                      → 所有文档
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
