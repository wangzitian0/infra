# Directory Structure (SSOT)

This document serves as the navigation map for the `infra` repository.

## How to walk the docs (start from `AGENTS.md`)
- Begin with [AGENTS.md](../AGENTS.md) → [README.md](../README.md) → [0.check_now.md](../0.check_now.md) for guardrails, current focus, and sprint context.
- When a concept appears, jump to its SSOT: architecture in [docs/README.md](./README.md) and [BRN-004.env_eaas_design.md](./BRN-004.env_eaas_design.md); decisions in deep dives ([DD-001](./deep_dives/DD-001.secret_and_ci_practices.md), [DD-002](./deep_dives/DD-002.why_atlantis.md)).
- For execution/state, read [docs/project/README.md](./project/README.md) (per-BRN status) and the latest entries under `docs/change_log/`.
- Infrastructure truth lives in [terraform/README.md](../terraform/README.md) and each layer README (`1.nodep`…`5.insight`). Tooling lives in [tools/README.md](../tools/README.md).
- Application work starts at [apps/README.md](../apps/README.md) and [apps/docs/index.md](../apps/docs/index.md); each subfolder (apps/, libs/, tools/, x-*) has its own README as SSOT.

## Legend
- `[+]` : Directory
- `[*]` : GitIgnored (Generated file)
- `(!)` : SSOT / Critical File (The Source of Truth)
- `README.md` : Documentation & Entry Point

## Tree

```text
root/
├── 0.check_now.md          # (!) Current context (active sprint)
├── .terrateam/              # [+] L0 Orchestration (Config)
│   └── config.yml           # (!) Terrateam Config
├── .github/workflows/       # [+] GitHub Runners
│   └── terrateam.yml        # (!) Workflow Entry
├── AGENTS.md                # (!) AI Behavior Guidelines (entrypoint)
├── README.md                # (!) Project Index
├── apps/                    # [+] Business Code
│   ├── AGENTS.md            # (!) App-specific guardrails
│   ├── README.md            # (!) Nx workspace index
│   ├── apps/                # [+] Runtime apps (backend, mobile, CMS, regression)
│   ├── docs/                # [+] Product/tech docs (see index.md)
│   ├── libs/                # [+] Shared libraries (schema, Neo4j repo)
│   ├── tools/               # [+] Workspace tooling
│   ├── x-data/              # [*] Generated data
│   └── x-log/               # [*] Logs
├── docs/                    # [+] Architecture & Design
│   ├── dir.md               # (!) This map & Namespace Registry
│   ├── README.md            # (!) Design Concepts
│   ├── BRN-004.env_eaas_design.md # (!) Env & EaaS architecture
│   ├── project/             # [+] Project Mgmt (BRN-004)
│   ├── change_log/          # [+] History (YYYY-MM-DD.*)
│   ├── deep_dives/          # [+] Design decision write-ups
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
└── .gitignore               # (!) Git Ignore Rules
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
