# Terraform Infrastructure

## 📍 你在这里

这个目录包含所有 Terraform 基础设施代码。

## 🎯 用途

**管理 Cloudflare 资源**（DNS/CDN/WAF），VPS 手动管理。

## 📂 目录结构

```
terraform/
├── README.md           → 本文件
├── backend.tf          → State 后端配置
├── main.tf             → 主配置文件
├── variables.tf        → 全局变量定义
├── outputs.tf          → 输出定义
├── modules/            → 可复用模块
│   ├── cloudflare/     → DNS/CDN/WAF 管理
│   ├── vps/            → VPS 模块（模板）
│   ├── database/       → 数据库模块（预留）
│   └── monitoring/     → 监控模块（预留）
└── envs/               → 环境配置
    ├── dev/
    ├── test/
    ├── staging/
    └── prod/
```

## 🚀 快速开始

### 1. 配置环境变量

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

填写：
- Cloudflare API Token
- Cloudflare Zone ID  
- 域名

### 2. 初始化

```bash
terraform init
```

### 3. 查看计划

```bash
terraform plan -var-file=terraform.tfvars
```

### 4. 应用变更

```bash
terraform apply -var-file=terraform.tfvars
```

## 📦 模块说明

### Cloudflare Module
管理：
- DNS 记录（主域名、API、PR 通配符）
- CDN 缓存规则
- WAF 安全规则
- SSL/TLS 配置

### VPS Module
提供多云模板，当前VPS手动管理（HostHatch 无 Terraform Provider）

## ⚠️ 重要提示

- **VPS**: 手动管理，Terraform 仅记录
- **State**: 当前使用 local backend
- **密钥**: 不要提交 `*.tfvars` 文件

## 📚 更多文档

- [架构设计](../docs/architecture.md)
- [用户待办](../docs/0.hi_zitian.md)
- [BRN-004 设计](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
