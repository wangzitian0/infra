# 设计理念与 Agent 架构
!!!AI不可以修改 agent.md，除非我主动和明确的说明修改哪一小部分。

本项目不仅仅是一套脚本，而是一套**基础设施即代码 (IaC)** 的实践，旨在解决多项目、多机器环境下的**一致性**与**隔离性**问题。

## 核心设计哲学

### 1. 环境分层 (Layered Environment)
我们将开发环境分为两层：
- **Base Layer (基础层)**：由 `tool_dev` (Ansible) 管理。负责“所有机器都通用”的配置（Zsh, Git, SSH, 基础目录）。目标是**跨平台一致性**。
- **Workspace Layer (工作区层)**：由 `workspace_*` 目录管理。负责“特定项目集合”的配置（环境变量 schema、特定别名、Go/Python 路径）。目标是**上下文隔离**。

### 2. 契约驱动配置 (Schema-Driven Configuration)
“在我机器上能跑”通常是因为本地有一些未记录的环境变量。
- **设计**：`.env.ci` 是唯一的**契约 (Contract)**。
- **机制**：分散在各仓库的 `.env.ci` 定义了该项目所需的变量 Key。`infra` 仓库负责**聚合**这些 Key 形成 Workspace 级别的总契约。
- **强制性**：任何不在契约中的变量，都不应存在于生产或 CI 环境中。

### 3. 漂移检测 (Drift Detection)
配置漂移是系统腐化的根源。
- **设计**：CI 不仅仅是跑测试，更是**一致性卫士**。
- **机制**：CI Guardian 自动检测代码仓库中的 `.env.ci` 变更。如果代码里新增了 Key 但没有同步到 `infra` 的契约中，CI 必须报错。这强制开发者显式地管理配置变更。

---

## Agent 角色定义

### Sync Tool Agent (基础建设者)
- **设计目标**：Zero-friction Bootstrapping（零摩擦启动）。
- **职责**：
  - 维护 `tool_dev/` 下的 Ansible Playbook。
  - 屏蔽 OS 差异（macOS vs Linux），提供统一的系统级接口。
  - 确保新机器在 5 分钟内达到“Ready to Code”状态。
  - 检查 HostName_github 这个密钥是否已经存在，如果不存在则添加。
  - 围绕 Init 脚本建设，一个脚本生成 github 密钥，剩下的一个 curl|bash 命令一键完成。

### Workspace Env Agent (上下文管理者)
- **设计目标**：Context Isolation（上下文隔离）。
- **职责**：
  - 维护 `workspace_*/` 目录结构。
  - 管理 `workspace.toml` (定义工作区边界) 和 `workspace.zsh` (定义工作区行为)。
  - 确保 `shopee` 的 GOPROXY 不会污染 `my_finance` 的环境，`truealpha` 的 API Key 不会泄露给其他项目。

### CI Guardian (契约执行者)
- **设计目标**：Enforce Consistency（强制一致性）。
- **职责**：
  - 运行 `tool_env_vars/collect_env_ci.py --check`。
  - 监控配置漂移：识别 Key 的新增/删除。
  - 阻止未记录的配置变更进入主分支，确保 `infra` 仓库始终是环境配置的 **Single Source of Truth**。

## 交互工作流

1.  **定义 (Define)**: Workspace Agent 在 `workspace.toml` 中划定项目边界。
2.  **聚合 (Aggregate)**: 运行工具从各项目收集 `.env.ci`，形成 Workspace 契约。
3.  **同步 (Sync)**: Sync Tool Agent 将基础环境推送到物理机；Shell 根据当前目录或配置加载对应的 Workspace 上下文。
4.  **守卫 (Guard)**: CI Guardian 在每次提交时验证契约的一致性。

## 修改checklist
### 目录结构
- `tool_dev/`：基础环境配置，包括 Ansible Playbook、Init 脚本等。
- `workspace_*/`：工作区配置，包括 `workspace.toml`、`workspace.zsh` 等。
- `tool_env_vars/`：环境变量管理工具，包括 `collect_env_ci.py` 等。
### 文档
- 每次改动文档，或者改动代码，都要检查对应文件夹的 readme.md确保强一致。
