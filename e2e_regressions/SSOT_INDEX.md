# SSOT Documentation Index

All SSOT (Single Source of Truth) documentation is now co-located with corresponding tests.

## 📍 Core Documentation

Located in `tests/`:
- [tests/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/README.md) - Directory structure SSOT
- [tests/ENV.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/ENV.md) - Environment variables SSOT
- [tests/VARS.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/VARS.md) - Terraform variables SSOT

## 🏗️ Bootstrap Layer

- [tests/bootstrap/k8s/](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/k8s/) - K8s cluster tests
- [tests/bootstrap/atlantis/](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/atlantis/) - Atlantis CI/CD tests
- [tests/bootstrap/dns_cert/](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/dns_cert/) - DNS & certificates tests
- [tests/bootstrap/storage/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/storage/README.md) - Storage SSOT
- [tests/bootstrap/traefik/](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/traefik/) - Traefik Ingress tests
- [tests/bootstrap/platform_pg/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/platform_pg/README.md) - Platform PostgreSQL SSOT
- [tests/bootstrap/observability/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/observability/README.md) - Observability SSOT
- [tests/bootstrap/network/](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/bootstrap/network/) - Network configuration

## 🚀 Platform Layer

- [tests/platform/auth/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/platform/auth/README.md) - Auth & SSO SSOT
- [tests/platform/secrets/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/platform/secrets/README.md) - Vault secrets SSOT
- [tests/platform/ai/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/platform/ai/README.md) - AI services SSOT
- [tests/platform/network/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/platform/network/README.md) - Platform network SSOT

## 💾 Data Layer

- [tests/data/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/data/README.md) - Database overview SSOT
- [tests/data/postgresql/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/data/postgresql/README.md) - Business PostgreSQL SSOT
- [tests/data/redis/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/data/redis/README.md) - Redis SSOT
- [tests/data/clickhouse/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/data/clickhouse/README.md) - ClickHouse SSOT
- [tests/data/arangodb/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/data/arangodb/README.md) - ArangoDB SSOT
- [tests/data/vault_integration/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/data/vault_integration/README.md) - Vault-DB integration SSOT

## 📱 Apps Layer

- [tests/apps/](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/apps/) - Application tests
- [tests/apps/portal/](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/apps/portal/) - Portal tests

## 🔧 Operations

- [tests/ops/pipeline/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/ops/pipeline/README.md) - CI/CD pipeline SSOT
- [tests/ops/recovery/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/ops/recovery/README.md) - Disaster recovery SSOT
- [tests/ops/alerting/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/ops/alerting/README.md) - Alerting SSOT
- [tests/ops/standards/README.md](file:///Users/SP14016/zitian/cc_infra/e2e_regressions/tests/ops/standards/README.md) - Standards SSOT

## ✅ Benefits of Co-location

- **Strong Coupling**: Tests and docs must be updated together
- **Discoverability**: Developers find docs when writing/reading tests
- **Atomic Changes**: One PR updates both tests and SSOT
- **Verification**: Tests validate what's documented

## 📝 Old Location

Previous SSOT location `docs/ssot/` can be deprecated after migration verification.
