# AI Agent 工作指南

## 📦 Repo 关系

**本仓库**: https://github.com/wangzitian0/infra  
**应用仓库**: https://github.com/wangzitian0/PEG-scaner

### 依赖关系

```
infra/ (基础设施)
  ↓ 部署
apps/ (应用代码)
```

- **infra**: 管理所有环境的基础设施（Terraform, Docker Compose, CI/CD）
- **apps**: 应用代码，被 infra 部署到各个环境

### 文档引用规则

**❌ 错误 - 相对路径**:
```markdown
[BRN-004](../apps/PEG-scaner/docs/origin/BRN-004.md)
```

**✅ 正确 - 完整 GitHub URL**:
```markdown
[BRN-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
```

## 🗂️ 目录结构与用途

```
infra/
├── README.md                  → 项目总入口
├── AGENTS.md                  → 本文件，AI 工作指南
├── 0.hi_zitian/               → 需要手动填写的各种配置、密钥，集中放置预于这个文件夹。
├── docs/                      → 所有文档
├── terraform/                 → 基础设施代码
│   ├── README.md              → Terraform 使用指南
│   ├── modules/               → 可复用模块
│   └── envs/                  → 环境配置
├── compose/                   → 服务编排
│   └── README.md              → Compose 使用指南
├── scripts/                   → 自动化脚本
│   └── README.md              → 脚本说明
├── ci/                        → CI/CD 配置
│   └── README.md              → CI/CD 指南
├── observability/             → 可观测性
│   └── README.md              → 监控配置
└── backstage/                 → 开发者门户
    └── README.md              → Backstage 指南
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

## 🚀 快速开始（针对 AI Agent）

### 修改文档时
- 使用完整 GitHub URL 引用 PEG-scaner 文档
- 更新对应的 change_log
- 如果有用户待办，更新 0.hi_zitian.md，每个一级标题是一项要做的事情，每个一级标题下有7个二级标题是5w1H + hint。

### 修改基础设施时
- 先更新 Terraform 模块
- 记录到 change_log
- 更新相关 README

## 🎯 Backstage 优先级

Backstage 是整个系统的核心入口：
1. ✅ 先完善 catalog 定义
2. ✅ 再开发健康检查
3. ✅ 最后添加自动化操作

**目标**: 让用户通过 Backstage 一眼看到所有环境的健康状态！
