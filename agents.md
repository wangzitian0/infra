# agents

围绕三个目标：1) 用 ansible 同步基础开发环境（tool_dev）；2) 以 workspace 管理分散的 `.env.ci` 并聚合 schema（tool_env_vars）；3) 在 CI 中检测 key 变化（只增删）。当前 workspace：`truealpha`（repo：`PEG-scaner`）、`shopee`（repo：`heheda-main`）。

## 角色

- **Sync Tool Agent**：维护 `tool_dev/`（基于 ansible 的跨平台环境同步），确保新机器可一键初始化。
- **Workspace Env Agent**：维护 workspace 及 `tool_env_vars/`（当前有 `workspace_truealpha`、`workspace_shopee`），保持 `workspace.toml`、聚合 `.env.ci`、`.env.test/.env.prod` 等最新；确保 workspace 内变量名唯一。
- **CI Guardian**：在本仓库 CI 中运行聚合/对比，识别 `.env.ci` key 的新增或删除，保证各 workspace 配置强一致。

## 工作流

1) **新增/维护 workspace**
   - 在根目录创建 `workspace_<name>/workspace.toml`（例：`workspace_truealpha` 列出 PEG-scaner，`workspace_shopee` 列出 heheda-main）。
   - 运行 `tool_env_vars/collect_env_ci.py <workspace> --update` 生成聚合 schema（`.env.ci`）和可选 `.env.test/.env.prod`。
   - 确保 key 在 workspace 内不重复；如有重复或值不一致，脚本会给出警告。

2) **项目仓库 `.env.ci` 变更**
   - 允许的变更：仅新增或删除 key。
   - CI Guardian 在本仓库 CI 中聚合相关 repo 的 `.env.ci`，与 `workspace_<name>/.env.ci` 对比；有差异则提示更新。

3) **环境同步**
   - 新机器：运行 `ansible-playbook tool_dev/ansible/setup.yml` 完成基础依赖与 shell 配置（`.zshrc` 软链到 `tool_dev/.zshrc`）。
   - Workspace 特定的环境变量：按 workspace 的 `.env.ci` schema 填写到本机私有文件（例如 `workspace_<name>/.env.local`，不提交）；workspace 专属 shell 配置放在 `workspace_<name>/workspace.zsh` 并由 `.zshrc` 自动加载。

## 约束与检查

- `.env.ci` 可散落在各项目的任意目录，但在同一 workspace 中变量名必须全局唯一。
- 聚合文件（`workspace_<name>/.env.ci`）是 CI 使用的唯一 schema。
- CI 必须检测到 `.env.ci` key 的增删 drift，阻止不一致的配置进入主分支。
