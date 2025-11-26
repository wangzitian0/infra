# tool_env_vars

按 workspace 聚合分散的 `.env.ci`，生成唯一 schema，并在 CI 中检测 key 增删。

当前 workspace：`truealpha`（包含 repo：`PEG-scaner`）。

## 使用

```bash
# 更新聚合 schema
python tool_env_vars/collect_env_ci.py truealpha --update

# CI 检查 drift
python tool_env_vars/collect_env_ci.py truealpha --check
```

workspace 目录位于根目录（例如 `workspace_truealpha/`），其中 `workspace.toml` 列出包含的 repo 及路径；`.env.test/.env.prod` 等配置需遵循 `.env.ci` 的键集合。
