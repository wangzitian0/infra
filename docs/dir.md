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
├── 0.tools/                 # [+] Scripts & Utilities
│   ├── README.md            # Scripts index
│   ├── preflight-check.sh   # Helm URL validation
│   └── migrate-state.sh     # State migration helper
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
│   │   └── ...              # History entries
│   └── deep_dives/
│       ├── README.md        # Deep dive index
│       └── ...              # Decision records
├── 1.bootstrap/             # [+] L1: K3s + Atlantis (GitHub Actions)
│   ├── README.md            # (!) IaC entry & layer map
│   ├── backend.tf           # S3/R2 backend config
│   ├── providers.tf         # Provider definitions
│   └── *.tf                 # Bootstrap resources
├── 2.platform/              # [+] L2: Platform (Atlantis)
│   ├── README.md            # L2 platform docs
│   └── *.tf                 # Infisical, Dashboard, Kubero
├── 3.data/                  # [+] L3: Data (Atlantis)
│   └── README.md            # L3 data layer docs
├── 4.apps/                  # [+] L4: Applications (Atlantis)
│   └── README.md            # L4 apps docs
├── envs/                    # [+] Environment config
│   ├── README.md            # tfvars templates per environment
│   └── *.tfvars.template    # Backend config templates
└── tools/                   # [+] Legacy tools (to be merged)
    └── README.md            # (!) CI/CD & Mgmt SSOT
```

## Key Layers (L1-L4 Simplified Architecture)

| Layer | Name | Definition | Modules (Path :: Function) | k3s Namespace | SSOT |
|---|---|---|---|---|---|
| **L0** | **Tools Chain** | Project Roots | `0.tools/` :: Scripts <br> `docs/` :: Architecture | - | `README.md` |
| **L1** | **Bootstrap** | Zero-Dependency Infra | `1.bootstrap/` :: Runtime (k3s), CI (Atlantis), DNS/Cert | `kube-system`, `nodep` | `1.bootstrap/README.md` |
| **L2** | **Platform** | Platform Components | `2.platform/` :: Secrets (Infisical), Dashboard, Kubero, Platform DB | `iac`, `kubernetes-dashboard` | `2.platform/README.md` |
| **L3** | **Data** | Business Data Stores | `3.data/` :: Cache (Redis), Graph (Neo4j), DB (Postgres), OLAP (ClickHouse) | `data` | `3.data/README.md` |
| **L4** | **Apps** | Applications | `4.apps/` :: Business Services (prod/staging) | `apps` | `4.apps/README.md` |
