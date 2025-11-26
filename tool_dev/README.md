# tool_dev: 基础环境自动化

负责开发环境的 **Base Layer** (基础层) 建设。目标是实现跨平台（macOS/Linux）的一致性初始化。

## 功能特性

- **自动化安装**: Git, Ansible, Zsh, Tree 等基础工具。
- **Shell 配置**: 统一的 `.zshrc`，支持模块化加载 Workspace 配置。
- **SSH 管理**: 自动生成 SSH 密钥并提示添加到 GitHub。
- **目录结构**: 自动创建 `~/workspace` 和 `~/zitian` 等标准目录。

## 目录结构

```
tool_dev/
├── ansible/           # Ansible Playbooks
│   ├── setup.yml      # 主入口 playbook
│   └── vars/          # 变量配置
├── scripts/           # 辅助脚本
│   └── generate_ssh_key.sh
├── .zshrc             # Zsh 配置文件（将被软链到 ~/.zshrc）
└── init.sh            # 一键安装引导脚本
```

## 使用方法

### 一键安装 (Bootstrap)

在新机器上运行：

```bash
curl -fsSL https://raw.githubusercontent.com/wangzitian0/infra/main/tool_dev/init.sh | bash
```

### 手动运行 Ansible

如果你已经克隆了仓库：

```bash
# 在 infra 根目录
ansible-playbook tool_dev/ansible/setup.yml
```

## 配置说明

### Zsh 配置
`.zshrc` 会自动加载 `infra/workspace_*/workspace.zsh`。
这意味着你可以在各自的 workspace 目录下维护特定的别名和环境变量，而无需修改主 `.zshrc`。

### SSH 密钥
首次运行时，会自动生成 `~/.ssh/<hostname>_github` 密钥对，并提示你添加到 GitHub。
脚本不会覆盖已存在的密钥。
