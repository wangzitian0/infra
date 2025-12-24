# SSOT Documentation Index

All SSOT (Single Source of Truth) documentation is centralized in `docs/ssot/`.

Test documentation in `e2e_regressions/tests/` focuses on testing and references these SSOT docs.

## 📍 Core Documentation

- [core.dir.md](../docs/ssot/core.dir.md) - Directory structure and project organization
- [core.env.md](../docs/ssot/core.env.md) - Environment variables
- [core.vars.md](../docs/ssot/core.vars.md) - Terraform variables

## 🏗️ Bootstrap Layer

- [Platform PostgreSQL](../docs/ssot/db.platform_pg.md) - Platform database configuration
- [Storage](../docs/ssot/ops.storage.md) - Persistent storage configuration
- [Observability](../docs/ssot/ops.observability.md) - Monitoring and logging

## 🚀 Platform Layer

- [Auth & SSO](../docs/ssot/platform.auth.md) - Authentication and authorization
- [Secrets](../docs/ssot/platform.secrets.md) - Vault secrets management
- [AI Services](../docs/ssot/platform.ai.md) - AI platform services
- [Network](../docs/ssot/platform.network.md) - Network architecture

## 💾 Data Layer

- [Database Overview](../docs/ssot/db.overview.md) - Data layer architecture
- [Business PostgreSQL](../docs/ssot/db.business_pg.md) - Main business database
- [Redis](../docs/ssot/db.redis.md) - Caching layer
- [ClickHouse](../docs/ssot/db.clickhouse.md) - Analytics database
- [ArangoDB](../docs/ssot/db.arangodb.md) - Graph database
- [Vault Integration](../docs/ssot/db.vault-integration.md) - Database secrets via Vault

## 🔧 Operations

- [CI/CD Pipeline](../docs/ssot/ops.pipeline.md) - Continuous integration and deployment
- [Disaster Recovery](../docs/ssot/ops.recovery.md) - Backup and recovery procedures
- [Alerting](../docs/ssot/ops.alerting.md) - Monitoring and alerting
- [Standards](../docs/ssot/ops.standards.md) - Coding and operational standards
- [E2E Testing](../docs/ssot/ops.e2e-regressions.md) - E2E test strategy

## ✅ Design Philosophy

**Separation of Concerns**:
- **SSOT (docs/ssot/)**: Design, definition, architecture - the "what" and "why"
- **Tests (e2e_regressions/tests/)**: Verification, validation - the "how we test"
- **References**: Test READMEs link to relevant SSOT docs

This ensures:
- Single source of truth for design decisions
- Test documentation focuses on testing concerns
- Clear separation between design and verification
