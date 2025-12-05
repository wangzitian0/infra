# Directory Structure (SSOT)

This document serves as the navigation map for the `infra` repository.

## Legend
- `[+]` : Directory
- `[*]` : GitIgnored (Not in repo, generated locally/CI)
- `(!)` : SSOT / Critical File

## Tree

```text
infra/
├── .github/types/           # GitHub Action Workflows
├── apps/                    # [Submodule] Business Code (See apps/README.md)
│   └── tools/               # [Submodule] Dev scripts (dev.sh, init_db.sh)
├── docs/                    # Architecture & Design Concepts
│   ├── dir.md               # (!) This map
│   └── project/             # Project Management (Status, Plans)
├── terraform/               # [!] Infrastructure Code (The Truth)
│   ├── 0.common/            # [!] Orchestration Entry Point
│   │   ├── envs/            # Environment Specific Configs
│   │   │   ├── staging.tfvars
│   │   │   └── *.tfvars     # [*] Secrets (local only)
│   │   ├── output/          # [*] Generated files (kubeconfig)
│   │   ├── main.tf          # (!) Layer Orchestration
│   │   ├── variables.tf     # (!) Global Schema
│   │   ├── terraform.tfstate# [*] Local state (use R2 backend!)
│   │   └── providers.tf     # Provider Config
│   ├── 1.nodep/             # L1: Bootstrap
│   │   ├── 1.k3s.tf         # k3s Provisioning
│   │   └── scripts/         # Install Scripts
│   ├── 2.env_and_networking/# L2: Foundation
│   │   ├── 1.postgres.tf    # Platform DB (for Infisical)
│   │   ├── 2.secret.tf      # Infisical Deployment
│   │   └── variables.tf     # Foundation Inputs
│   ├── 3.computing/         # L3: Runtime
│   │   └── 3.dashboard.tf   # K8s Dashboard
│   ├── 4.storage/           # L4: Data Services
│   │   └── README.md        # (Placeholder for Business DBs)
│   └── 5.insight/           # L5: Observability
│       └── README.md        # (Placeholder for SigNoz/PostHog)
├── tools/                   # (Empty/Removed - see apps/tools)
├── .gitignore               # (!) Git Ignore Rules
├── AGENTS.md                # (!) AI Behavior Guidelines
└── README.md                # Project Index
```

## Key Locations

| Purpose | Directory | SSOT File |
|---|---|---|
| **Run Terraform** | `terraform/0.common` | `main.tf` |
| **Manage Secrets** | `terraform/2.env_and_networking` | `2.secret.tf` |
| **Add New App** | `terraform/3.computing` | `*.tf` (Future) |
| **Architecture** | `docs/` | `README.md` |
