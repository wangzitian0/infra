# Directory Structure (SSOT)

This map lists every Markdown file in the infra repo with a one-line purpose so each concept can jump to its SSOT (architecture/decisions in `docs/`, state in `docs/project` + `docs/change_log`, infra truth in `terraform/`, tooling in `tools/`, current focus in `0.check_now.md`).

## Legend
- `[+]` : Directory
- `[*]` : GitIgnored (Generated file)
- `(!)` : SSOT / Critical File (The Source of Truth)
- `README.md` : Documentation & Entry Point

## Tree

```text
root/
├── 0.check_now.md - Current sprint context & checklist
├── AGENTS.md - Agent guardrails
├── README.md - Repo entry overview
├── docs/
│   ├── README.md - Architecture/doc center
│   ├── dir.md - Repo map (this file)
│   ├── BRN-004.env_eaas_design.md - Env & EaaS architecture spec
│   ├── project/
│   │   ├── README.md - BRN status/index
│   │   └── BRN-004.md - BRN-004 full architecture/selection
│   ├── change_log/
│   │   ├── 2025-12-04.k3s_bootstrap_reset.md - History: k3s reset
│   │   ├── 2025-12-05.staging_deployment_design.md - History: staging design
│   │   └── 2025-12-06.checklist_merge.md - History: checklist merge
│   └── deep_dives/
│       ├── DD-001.secret_and_ci_practices.md - Decisions: secrets & CI
│       └── DD-002.why_atlantis.md - Decisions: Atlantis rationale
├── terraform/
│   ├── README.md - IaC entry & layer map
│   ├── 1.nodep/README.md - L1 bootstrap (k3s/Atlantis)
│   ├── 2.env_and_networking/README.md - L2 foundation (secrets/ingress/db)
│   ├── 3.computing/README.md - L3 runtime (PaaS/dashboard)
│   ├── 4.storage/README.md - L4 data stores
│   └── 5.insight/README.md - L5 observability/analytics
└── tools/
    └── README.md - CI/CD tooling & mgmt
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
