# Directory Structure (SSOT)

This document serves as the navigation map for the `infra` repository.

## Legend
- `[+]` : Directory
- `[*]` : GitIgnored (Generated file)
- `(!)` : SSOT / Critical File (The Source of Truth)
- `README.md` : Documentation & Entry Point

## Tree

```text
infra/
├── .terrateam/              # [+] L0 Orchestration (Config)
│   └── config.yml           # (!) Terrateam Config
├── .github/workflows/       # [+] GitHub Runners
│   └── terrateam.yml        # (!) Workflow Entry
├── apps/                    # [+] Business Code
│   └── tools/               # [+] Dev scripts
├── docs/                    # [+] Architecture & Design
│   ├── dir.md               # (!) This map
│   ├── README.md            # (!) Design Concepts
│   └── project/             # [+] Project Mgmt
├── terraform/               # [!] Infrastructure Code (The Truth)
│   ├── envs/                # [+] Env Configs
│   ├── output/              # [*] Generated files
│   ├── main.tf              # (!) Layer Orchestration
│   ├── variables.tf         # (!) Global Schema
│   ├── 1.nodep/             # [+] L1: Bootstrap
│   │   ├── 1.k3s.tf         # (!) Provisioning Logic
│   │   └── README.md        # 📖 L1 Docs
│   ├── 2.env_and_networking/# [+] L2: Foundation
│   │   ├── 2.secret.tf      # (!) Secrets Logic
│   │   └── README.md        # 📖 L2 Docs
│   ├── 3.computing/         # [+] L3: Runtime
│   │   ├── 3.dashboard.tf   # (!) App Logic
│   │   └── README.md        # 📖 L3 Docs
│   ├── 4.storage/           # [+] L4: Data
│   │   └── README.md        # 📖 L4 Docs
│   └── 5.insight/           # [+] L5: Insight
│       └── README.md        # 📖 L5 Docs
├── tools/                   # [!] Meta / CI SSOT
│   └── README.md            # (!) CI/CD & Mgmt SSOT
├── .gitignore               # (!) Git Ignore Rules
├── AGENTS.md                # (!) AI Behavior Guidelines
└── README.md                # (!) Project Index
```

## Key Locations

| Purpose | Directory | SSOT File |
|---|---|---|
| **CI/CD Orchestration** | `tools/` | `README.md` |
| **Run Terraform** | `terraform/` | `main.tf` |
| **L1 Bootstrap** | `terraform/1.nodep` | `1.k3s.tf` |
| **L2 Foundation** | `terraform/2.env_and_networking` | `2.secret.tf` |
| **L3 Runtime** | `terraform/3.computing` | `3.dashboard.tf` |
| **L4 Data** | `terraform/4.storage` | `README.md` |
| **L5 Insight** | `terraform/5.insight` | `README.md` |
| **Architecture** | `docs/` | `README.md` |
