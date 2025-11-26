# infra

当前只管理一个 workspace：`truealpha`，包含 repo：`PEG-scaner`。

目标：
- `tool_dev/`：基于 ansible 的跨平台研发环境初始化/同步。
- `tool_env_vars/`：以 workspace 为单位，聚合分散的 `.env.ci`，生成唯一 schema，并在 CI 中检测 key 变更（仅增/删）。

## 目录结构

- `tool_dev/`：ansible playbooks + init 脚本 + ssh key 脚本 + `.zshrc`（软链接到 `~/.zshrc`，自动加载各 workspace 的 `workspace.zsh`）。
- `tool_env_vars/`：聚合/校验脚本。
- `workspace_truealpha/`、`workspace_shopee/`：
  - `workspace.toml`：workspace 配置（包含 repo 列表）。
  - `.env.ci`：聚合后的 schema（提交到仓库）。
  - `.env.test` / `.env.prod`：按 schema 填写的环境配置。
  - `workspace.zsh`：workspace 专属 shell 设置（别名/环境变量）。
- `agents.md`：角色与流程。

## 角色

- **Sync Tool Agent**：维护 `tool_dev/`，保证跨平台可用。
- **Workspace Env Agent**：维护 `tool_env_vars/` 与各 workspace，确保变量名唯一、聚合文件最新。
- **CI Guardian**：在本仓库 CI 中执行聚合/对比，提示 `.env.ci` key 的增删。

## 使用流程

### 1) 新机器环境
- 进入仓库，运行 ansible playbook：
```bash
ansible-playbook tool_dev/ansible/setup.yml
```
- 按 workspace 的 `.env.ci` schema 在本机私有位置（例如 `workspace_<name>/.env.local`，不提交）填实际值；shell 配置可在对应的 `workspace.zsh` 编写并在 `.zshrc` 里按需 source。

### 2) truealpha workspace
- 配置：`workspace_truealpha/workspace.toml`（当前包含 `PEG-scaner`）。
- 聚合/校验：
```bash
python tool_env_vars/collect_env_ci.py truealpha --update   # 写入 workspace_truealpha/.env.ci
python tool_env_vars/collect_env_ci.py truealpha --check    # CI 模式，检测 drift
```
- `.env.test` / `.env.prod` 需遵循 `.env.ci` 的键集合。

### 2b) shopee workspace
- 配置：`workspace_shopee/workspace.toml`（示例指向本地 `~/workspace/heheda-main`）。
- workspace 专属 shell 配置：`workspace_shopee/workspace.zsh`（包含目录别名、Go 环境、GOPRIVATE/ENV）。
- 聚合/校验同上：`python tool_env_vars/collect_env_ci.py shopee --update|--check`。

### 3) 变更规则
- `.env.ci` 允许的变更：新增 key 或删除 key。
- 同一 workspace 内变量名不可重复；聚合工具会标出来源。
- CI 通过 `--check` 确保聚合文件与实际 `.env.ci` 一致。

## TODO
- 接入 CI：在 truealpha 的 CI 中运行 `tool_env_vars/collect_env_ci.py truealpha --check`。
- 需要时扩展 `workspace.toml` 字段（repo 源、忽略目录等）。
