# tool_dev

跨平台研发环境初始化/同步（基于 ansible）。

## 使用

```bash
# 安装 ansible（若未安装）
./tool_dev/init.sh

# 已有 ansible，直接运行 playbook
ansible-playbook tool_dev/ansible/setup.yml
```

## 结构
- `ansible/`：playbooks（setup.yml/basic.yml）与仓库列表 vars。
- `scripts/`：辅助脚本（例如生成 SSH 密钥）。
- `.zshrc`：主 zsh 配置入口（软链接到 `~/.zshrc`），会自动 source 各 `workspace_*/workspace.zsh`，并提供 `chws <name>` 切换工作空间。
- `init.sh`：在新机上一键安装 ansible 并执行 playbook。
