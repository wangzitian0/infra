# 4.apps (L4 Applications Layer)

**Scope**: Application deployments for prod/staging environments.

- **Environments**: `prod`, `staging` only
- **Namespace**: `apps-prod`, `apps-staging`

## Architecture

This layer deploys business applications. All non-production environments go to `staging`.

### Deployment Strategy

| Environment | Namespace | Purpose |
|-------------|-----------|---------|
| `staging` | `apps-staging` | All test/dev/preview environments |
| `prod` | `apps-prod` | Production only |

### Components (Planned)

| Component | Purpose |
|-----------|---------|
| Frontend | User-facing web app |
| Backend API | Business logic |
| Workers | Background jobs |

### Usage

```bash
# Staging
atlantis plan -p apps-staging
atlantis apply -p apps-staging

# Production
atlantis plan -p apps-prod
atlantis apply -p apps-prod
```

---
*Last updated: 2025-12-09*
