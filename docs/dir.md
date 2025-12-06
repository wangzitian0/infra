# Directory Structure (SSOT)

This document serves as the navigation map for the `infra` repository.

## Legend
- `[+]` : Directory
- `[*]` : GitIgnored (Generated file)
- `(!)` : SSOT / Critical File (The Source of Truth)
- `README.md` : Documentation & Entry Point

## Tree

```text
root/
├── 0.check_now.md          # (!) Current sprint context
├── .github/                 # [+] CI/Bots
│   ├── README.md            # CI/CD folder index
│   └── workflows/           # [+] GitHub Runners
│       ├── README.md        # Workflows index
│       └── terrateam.yml    # (!) Workflow Entry
├── AGENTS.md                # (!) AI Behavior Guidelines
├── README.md                # (!) Project Index
├── docs/
│   ├── dir.md               # (!) This map & Namespace Registry
│   ├── README.md            # (!) Design Concepts
│   ├── BRN-004.env_eaas_design.md # (!) Env & EaaS architecture
│   ├── project/
│   │   ├── README.md        # BRN status/index
│   │   └── BRN-004.md       # BRN-004 integrated architecture
│   ├── change_log/
│   │   ├── README.md        # Change log index
│   │   ├── 2025-12-04.k3s_bootstrap_reset.md    # History: k3s reset
│   │   ├── 2025-12-05.staging_deployment_design.md # History: staging design
│   │   └── 2025-12-06.checklist_merge.md        # History: checklist merge
│   └── deep_dives/
│       ├── README.md        # Deep dive index
│       ├── DD-001.secret_and_ci_practices.md    # Decisions: secrets & CI
│       └── DD-002.why_atlantis.md               # Decisions: Atlantis rationale
├── terraform/
│   ├── README.md            # (!) IaC entry & layer map
│   ├── envs/README.md       # tfvars templates per environment
│   ├── 1.nodep/README.md    # L1 bootstrap (k3s/Atlantis)
│   ├── 2.env_and_networking/README.md # L2 foundation (secrets/ingress/db)
│   ├── 3.computing/README.md # L3 runtime (PaaS/dashboard)
│   ├── 4.storage/README.md  # L4 data stores
│   └── 5.insight/README.md  # L5 observability/analytics
└── tools/
    └── README.md            # (!) CI/CD & Mgmt SSOT
```

## Key Layers (Defined in BRN-004)

| Layer | Name | Definition | Modules (Path :: Function) | k3s Namespace | SSOT |
|---|---|---|---|---|---|
| **L0** | **Tools Chain** | Project Roots | `tools/` :: CI/CD <br> `docs/` :: Architecture <br> `terraform/` :: Orchestration | - | `README.md` |
| **L1** | **Bootstrap** | Infrastructure Logic | `1.nodep/` :: Runtime (k3s), CI (Atlantis) | `nodep` | `1.nodep/README.md` |
| **L2** | **Foundation** | Security & Networking | `2.env_and_networking/` :: Secrets (Infisical, Postgres_env) | `security` | `2.env.../README.md` |
| **L3** | **Runtime** | App Runtime & PaaS | `3.computing/` :: PaaS (Kubero), Dashboard, Apps | `kubero`, `apps` | `3.comp.../README.md` |
| **L4** | **Data** | Data Stores | `4.storage/` :: Cache (Redis), Graph (Neo4j), DB (Postgres_app) | `data` | `4.storage/README.md` |
| **L5** | **Insight** | Observability | `5.insight/` :: Obs. (SigNoz), Analytics (PostHog) | `observability`, `ingestion` | `5.insight/README.md` |
| **L99** | **Apps** | Business Logic | `apps/` :: Business Services | `apps` | `apps/README.md` |
