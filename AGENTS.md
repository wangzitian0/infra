# AI Agent 工作指南（k3s reboot）

## 仓库关系
- 本仓库：`infra`（IaC + infra）
- 应用仓库：`apps/` 子模块指向 https://github.com/wangzitian0/PEG-scaner  
- 依赖方向：infra → apps（保持单向，禁止再用软链）
- 设计背景：沿用 BRN-004 三层（IaC → k3s 平台 → Apps），文档引用必须用完整 GitHub URL，例如  
  `https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md`

## 当前目标与范围
- 仅实现一件事：通过 GitHub Actions + Terraform 把 k3s 装到 VPS，并产出 kubeconfig。
- Dokploy 已下线；运行时统一切到 k3s。
- 后续改进按照“能跑 → 能观测 → 能自动化”的顺序推进。

## 目录速览
```
.
├── AGENTS.md                      # 本文件
├── README.md                      # 面向使用者的总览
├── apps/                          # PEG-scaner 子模块
├── docs/                          # 文档
│   ├── README.md
│   ├── 0.hi_zitian.md             # 需要 Zitian 处理的事项
│   └── change_log/2024-12-04.md   # 本次重置的变更记录
├── terraform/                     # k3s IaC
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── scripts/install-k3s.sh.tmpl
│   └── terraform.tfvars.example
└── .github/workflows/deploy-k3s.yml
```

## 工作流（必须可跑）
- CI 部署（推荐）：工作流 `.github/workflows/deploy-k3s.yml`
  - 必填 secrets：`VPS_HOST`、`VPS_SSH_KEY`
  - 可选：`VPS_USER`、`VPS_SSH_PORT`、`K3S_API_ENDPOINT`、`K3S_CHANNEL`、`K3S_VERSION`、`K3S_CLUSTER_NAME`
  - 步骤：生成 tfvars 与 SSH key → terraform fmt/init/plan/apply → 拉 kubeconfig、替换 API Endpoint → `kubectl get nodes` → 上传 artifact
- 本地部署：`cp terraform/terraform.tfvars.example terraform/terraform.tfvars` 填好后运行 `terraform init && terraform plan && terraform apply`，kubeconfig 输出在 `terraform/output/<cluster>-kubeconfig.yaml`

## 文档与记录规则
- 引用 PEG-scaner 文档时使用完整 GitHub URL，禁止相对路径。
- 每次改动：更新 `docs/change_log/2024-12-04.md` 说明做了什么、如何验证。
- 如果有需要用户决策/补充的事项，写入 `docs/0.hi_zitian.md`。

## apps 子模块规则
- 初始化：`git submodule update --init --recursive`
- 同步 upstream：`git submodule update --remote --merge`（或进入 apps 目录拉 main 分支）
- 不要改回软链，保持 infra 对 apps 的只读依赖。

## 渐进式改进路径
1. 稳定 k3s 引导：CI 可 plan/apply，kubeconfig artifact 可下载，冒烟通过。
2. 逐步把应用部署到 k3s（参考 PEG-scaner），并用同一套 CI 触发。
3. 添加观测与 Backstage 健康视图，仍保持 IaC 在本仓库集中管理。

## 安全与习惯
- 私钥、真实 tfvars 不入库，CI 用 GitHub Secrets， 本地用未跟踪的 tfvars。
- 变更 Terraform/CI 时先 fmt/plan，再提交 change_log 与 README/AGENTS。
