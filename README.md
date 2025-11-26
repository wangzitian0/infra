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

1) 生成 SSH key 并添加到 GitHub（若已配置可跳过）：
```bash
ssh-keygen -t ed25519 -C "$(hostname -s)_github" -f ~/.ssh/"$(hostname -s)_github" -N ''
ssh-add ~/.ssh/"$(hostname -s)_github"
cat ~/.ssh/"$(hostname -s)_github".pub   # 复制到 https://github.com/settings/keys
```

2) 克隆私有仓库：
```bash
git clone git@github.com:wangzitian0/infra.git ~/zitian/infra
cd ~/zitian/infra
```

3) 初始化基础环境：
```bash
./tool_dev/init.sh
```
（如果已安装 ansible，可直接执行 `ansible-playbook tool_dev/ansible/setup.yml`）

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
