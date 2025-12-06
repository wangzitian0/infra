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
├── .terrateam/              # [+] L0 Orchestration (Config)
│   └── config.yml           # (!) Terrateam Config
├── .github/workflows/       # [+] GitHub Runners
│   └── terrateam.yml        # (!) Workflow Entry
├── apps/                    # [+] Business Code
│   └── tools/               # [+] Dev scripts
├── docs/                    # [+] Architecture & Design
│   ├── dir.md               # (!) This map & Namespace Registry
│   ├── README.md            # (!) Design Concepts
│   ├── project/             # [+] Project Mgmt (BRN-004)
│   └── BRN-004.md           # (!) Full Architecture Spec
├── terraform/               # [!] Infrastructure Code (The Truth)
│   ├── envs/                # [+] Env Configs
│   ├── output/              # [*] Generated files
│   ├── main.tf              # (!) Layer Orchestration
│   ├── variables.tf         # (!) Global Schema
│   ├── 1.nodep/             # [+] L1: Bootstrap (ns: nodep)
│   │   ├── 1.k3s.tf         # (!) Runtime Provisioning
│   │   ├── 2.atlantis.tf    # (!) CI Automation
│   │   └── README.md        # 📖 SSOT
│   ├── 2.env_and_networking/# [+] L2: Foundation (ns: security)
│   │   ├── 1.postgres.tf    # (!) Shared DB
│   │   ├── 2.secret.tf      # (!) Infisical
│   │   └── README.md        # 📖 SSOT
│   ├── 3.computing/         # [+] L3: Runtime (ns: kubero/apps)
│   │   ├── 3.dashboard.tf   # (!) K8s Dashboard
│   │   ├── (kubero.tf)      # (!) PaaS (Planned)
│   │   └── README.md        # 📖 SSOT
│   ├── 4.storage/           # [+] L4: Data (ns: data)
│   │   ├── (redis.tf)       # (!) Cache (Planned)
│   │   ├── (neo4j.tf)       # (!) Graph (Planned)
│   │   └── README.md        # 📖 SSOT
│   └── 5.insight/           # [+] L5: Insight (ns: obs/ingestion)
│       ├── (signoz.tf)      # (!) APM (Planned)
│       ├── (posthog.tf)     # (!) Analytics (Planned)
│       └── README.md        # 📖 SSOT
├── tools/                   # [!] Meta / CI SSOT
│   └── README.md            # (!) CI/CD & Mgmt SSOT
├── .gitignore               # (!) Git Ignore Rules
├── AGENTS.md                # (!) AI Behavior Guidelines
└── README.md                # (!) Project Index
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
