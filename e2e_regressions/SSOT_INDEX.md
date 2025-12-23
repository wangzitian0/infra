# SSOT Documentation Index

All SSOT (Single Source of Truth) documentation is centralized in `docs/ssot/`.

Test documentation in `e2e_regressions/tests/` focuses on testing and references these SSOT docs.

## 📍 Core Documentation

- [core.dir.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/core.dir.md) - Directory structure and project organization
- [core.env.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/core.env.md) - Environment variables
- [core.vars.md](file:///Users/SP14016/zitian/cc_infra/docs/ssot/core.vars.md) - Terraform variables

## 🏗️ Bootstrap Layer

- [Platform PostgreSQL](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.platform_pg.md) - Platform database configuration
- [Storage](file:///Users/SP14016/zitian/cc_infra/docs/ssot/ops.storage.md) - Persistent storage configuration
- [Observability](file:///Users/SP14016/zitian/cc_infra/docs/ssot/ops.observability.md) - Monitoring and logging

## 🚀 Platform Layer

- [Auth & SSO](file:///Users/SP14016/zitian/cc_infra/docs/ssot/platform.auth.md) - Authentication and authorization
- [Secrets](file:///Users/SP14016/zitian/cc_infra/docs/ssot/platform.secrets.md) - Vault secrets management
- [AI Services](file:///Users/SP14016/zitian/cc_infra/docs/ssot/platform.ai.md) - AI platform services
- [Network](file:///Users/SP14016/zitian/cc_infra/docs/ssot/platform.network.md) - Network architecture

## 💾 Data Layer

- [Database Overview](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.overview.md) - Data layer architecture
- [Business PostgreSQL](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.business_pg.md) - Main business database
- [Redis](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.redis.md) - Caching layer
- [ClickHouse](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.clickhouse.md) - Analytics database
- [ArangoDB](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.arangodb.md) - Graph database
- [Vault Integration](file:///Users/SP14016/zitian/cc_infra/docs/ssot/db.vault-integration.md) - Database secrets via Vault

## 🔧 Operations

- [CI/CD Pipeline](file:///Users/SP14016/zitian/cc_infra/docs/ssot/ops.pipeline.md) - Continuous integration and deployment
- [Disaster Recovery](file:///Users/SP14016/zitian/cc_infra/docs/ssot/ops.recovery.md) - Backup and recovery procedures
- [Alerting](file:///Users/SP14016/zitian/cc_infra/docs/ssot/ops.alerting.md) - Monitoring and alerting
- [Standards](file:///Users/SP14016/zitian/cc_infra/docs/ssot/ops.standards.md) - Coding and operational standards
- [E2E Testing](file:///Users/SP14016/zitian/cc_infra/docs/ssot/ops.e2e-regressions.md) - E2E test strategy

## ✅ Design Philosophy

**Separation of Concerns**:
- **SSOT (docs/ssot/)**: Design, definition, architecture - the "what" and "why"
- **Tests (e2e_regressions/tests/)**: Verification, validation - the "how we test"
- **References**: Test READMEs link to relevant SSOT docs

This ensures:
- Single source of truth for design decisions
- Test documentation focuses on testing concerns
- Clear separation between design and verification
