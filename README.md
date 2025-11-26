# Infra: 基础设施即代码

本项目管理开发环境的基础设施、配置契约和自动化工具。

## 核心模块

- **[tool_dev](./tool_dev/README.md)**: **基础层 (Base Layer)**。基于 Ansible 的跨平台环境初始化工具。负责“所有机器通用”的配置。
- **[tool_env_vars](./tool_env_vars/README.md)**: **契约层 (Contract Layer)**。环境变量聚合与漂移检测工具。负责维护 `.env.ci` 契约。
- **Workspaces**: **工作区层 (Workspace Layer)**。
  - `workspace_truealpha`: PEG-scaner 相关。
  - `workspace_shopee`: Shopee 工作相关。
  - `workspace_my_finance`: 个人财务项目相关。

## 设计理念

本项目遵循 **环境分层** 和 **契约驱动** 的设计哲学。
详见 **[agents.md](./agents.md)** 了解架构设计与 Agent 角色。

## 快速开始（私有仓库）

1) 运行一键私有引导（生成/复用 SSH key、克隆、初始化）：
```bash
bash scripts/bootstrap_private_clone.sh
```
   - 脚本会打印公钥，请手动添加到 GitHub 后按回车继续。

2) 已经克隆/配置完毕时，可直接运行：
```bash
ansible-playbook tool_dev/ansible/setup.yml
```

## 常用操作

### 1. 切换 Workspace
```bash
# 需要先 source ~/.zshrc
chws my_finance
```

### 2. 更新环境变量契约
当你在代码仓库中修改了 `.env.ci` 后：
```bash
# 在 infra 根目录
python tool_env_vars/collect_env_ci.py my_finance --update
```

### 3. CI 检查
```bash
python tool_env_vars/collect_env_ci.py my_finance --check
```
