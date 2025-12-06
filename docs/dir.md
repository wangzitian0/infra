# Directory Structure (SSOT)

This document serves as the navigation map for the `infra` repository. Concepts should point to their SSOT: architecture and decisions in `docs/`, state and history in `docs/project/` + `docs/change_log/`, infrastructure truth in `terraform/`, tooling in `tools/`, and current focus in `0.check_now.md`.

## Legend
- `[+]` : Directory
- `[*]` : GitIgnored (Generated file)
- `(!)` : SSOT / Critical File (The Source of Truth)
- `README.md` : Documentation & Entry Point

## Tree

```text
root/
├── 0.check_now.md
├── AGENTS.md
├── README.md
├── docs/
│   ├── README.md
│   ├── dir.md
│   ├── BRN-004.env_eaas_design.md
│   ├── project/
│   │   ├── README.md
│   │   └── BRN-004.md
│   ├── change_log/
│   │   ├── 2025-12-04.k3s_bootstrap_reset.md
│   │   ├── 2025-12-05.staging_deployment_design.md
│   │   └── 2025-12-06.checklist_merge.md
│   └── deep_dives/
│       ├── DD-001.secret_and_ci_practices.md
│       └── DD-002.why_atlantis.md
├── terraform/
│   ├── README.md
│   ├── 1.nodep/README.md
│   ├── 2.env_and_networking/README.md
│   ├── 3.computing/README.md
│   ├── 4.storage/README.md
│   └── 5.insight/README.md
└── tools/
    └── README.md
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
