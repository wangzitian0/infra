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
│       ├── terraform-plan.yml # (!) Terraform validation
│       ├── deploy-k3s.yml   # (!) K3s deployment
│       ├── docs-guard.yml   # (!) Documentation enforcement
│       └── claude.yml       # (!) AI code review (Claude GitHub App)
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
│   ├── 1.nodep/README.md    # L1 bootstrap (k3s/Atlantis/DNS/Cert)
│   ├── 2.platform/README.md # L2 platform (secrets/dashboard/kubero)
│   ├── 3.data/README.md     # L3 data (business databases)
│   └── 4.insight/README.md  # L4 observability/analytics
└── tools/
    └── README.md            # (!) CI/CD & Mgmt SSOT
```

## Key Layers (L1-L4 Simplified Architecture)

| Layer | Name | Definition | Modules (Path :: Function) | k3s Namespace | SSOT |
|---|---|---|---|---|---|
| **L0** | **Tools Chain** | Project Roots | `tools/` :: CI/CD <br> `docs/` :: Architecture <br> `terraform/` :: Orchestration | - | `README.md` |
| **L1** | **Bootstrap** | Zero-Dependency Infra | `1.nodep/` :: Runtime (k3s), CI (Atlantis), DNS/Cert | `kube-system` | `1.nodep/README.md` |
| **L2** | **Platform** | Platform Components | `2.platform/` :: Secrets (Infisical), Dashboard, Kubero, Platform DB | `iac`, `kubernetes-dashboard` | `2.platform/README.md` |
| **L3** | **Data** | Business Data Stores | `3.data/` :: Cache (Redis), Graph (Neo4j), DB (Postgres), OLAP (ClickHouse) | `data` | `3.data/README.md` |
| **L4** | **Insight** | Observability & Analytics | `4.insight/` :: APM (SigNoz), Analytics (PostHog), Alerting | `monitoring` | `4.insight/README.md` |
| **L99** | **Apps** | Business Logic | `apps/` :: Business Services | `apps` | `apps/README.md` |
