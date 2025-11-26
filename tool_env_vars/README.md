# tool_env_vars: 环境变量契约管理

负责开发环境的 **Contract Layer** (契约层) 管理。
通过聚合分散在各代码仓库中的 `.env.ci` 文件，生成 Workspace 级别的统一契约，并防止配置漂移。

## 核心概念

- **`.env.ci`**: 定义了项目运行所需的**所有**环境变量 Key（通常 Value 为空或示例值）。它是环境配置的**契约**。
- **Schema**: 聚合后的 `.env.ci`，存储在 `infra/workspace_<name>/.env.ci`。它是 Single Source of Truth。
- **Drift (漂移)**: 当代码仓库中的 `.env.ci` 新增了 Key，但 `infra` 中的 Schema 未更新时，即发生漂移。

## 功能

1.  **聚合 (Aggregate)**: 扫描 `workspace.toml` 中定义的所有仓库，收集 `.env.ci`。
2.  **校验 (Validate)**: 确保同一 Workspace 内不同仓库没有定义冲突的 Key。
3.  **检测 (Check)**: 在 CI 中运行，确保代码变更符合契约。

## 使用方法

### 1. 更新契约 (Update)
当你向项目中添加了新的环境变量时：

```bash
# 在 infra 根目录
python tool_env_vars/collect_env_ci.py <workspace_name> --update
```
这会更新 `workspace_<name>/.env.ci` 文件。你需要提交这个变更。

### 2. CI 检查 (Check)
在 CI 流水线中运行：

```bash
python tool_env_vars/collect_env_ci.py <workspace_name> --check
```
如果发现漂移（Drift），CI 将失败，提示开发者运行 `--update` 并提交。

## 配置文件

**`workspace.toml` 示例**:

```toml
name = "my_finance"

[[repos]]
name = "my_finance"
path = "~/zitian/my_finance"  # 本地路径
source = "github"
```
