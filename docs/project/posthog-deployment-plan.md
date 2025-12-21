# PostHog 部署计划

## 📊 Current Status (2025-12-22)

### ✅ Completed (L2 Infrastructure)
- **PostgreSQL User**: `posthog` user created in L3 PostgreSQL
- **PostgreSQL Database**: Dedicated `posthog` database (not shared with `app`)
- **ClickHouse User**: `posthog` user created in L3 ClickHouse
- **ClickHouse Database**: `posthog_events` for event storage
- **Vault Credentials**: Stored at `secret/data/posthog`
- **Casdoor SAML App**: SAML application configured for PostHog SSO

### ❌ Blocked (L4 Deployment)
PostHog **officially discontinued Kubernetes/Helm support** on **May 31, 2023**.

**Source**: [PostHog Blog - Sunsetting Helm Support](https://posthog.com/blog/sunsetting-helm-support-posthog)

**Impact**:
- Official Helm chart repository: `https://posthog.github.io/charts/` no longer contains main chart
- Only `library` and `plugins` templates remain
- No security updates or feature releases for K8s deployments

---

## 🔧 Deployment Options

### Option 1: Docker Compose (Official Recommendation)
**Official Method**: PostHog only supports Docker Compose for self-hosting.

**Pros**:
- ✅ Official support
- ✅ Security updates
- ✅ Latest features

**Cons**:
- ❌ Not integrated with K8s ecosystem
- ❌ Manual management
- ❌ No auto-scaling

**Resources**:
- [PostHog Self-Host Docs](https://posthog.com/docs/self-host)
- [PostHog Deployment Repo](https://github.com/PostHog/deployment)

---

### Option 2: Kubero Pipeline Deployment
**Strategy**: Convert docker-compose to Kubero app and deploy via Pipeline.

**Pros**:
- ✅ Integrated with infra
- ✅ GitOps workflow
- ✅ Uses prepared L2/L3 infrastructure

**Cons**:
- ⚠️ Manual conversion required
- ⚠️ Custom maintenance

**Implementation**:
1. Download PostHog docker-compose.yml
2. Create Kubero Pipeline `posthog`
3. Configure Phases: staging/prod
4. Use external databases from L3

---

### Option 3: Manual Kubernetes Manifests
**Strategy**: Convert docker-compose to raw K8s Deployment/Service/Ingress.

**Pros**:
- ✅ Full control
- ✅ K8s native

**Cons**:
- ❌ High maintenance cost
- ❌ No official templates
- ❌ Need to track upstream changes manually

---

### Option 4: Legacy Helm Chart (Not Recommended)
**Strategy**: Use last released chart from May 2023.

**Pros**:
- ✅ Quick deployment

**Cons**:
- ❌ No security updates
- ❌ Outdated (1.5 years old)
- ❌ May break anytime
- ❌ Violates security policy

**Recommendation**: ❌ **Do NOT use** - Security risk

---

## 📋 Prepared Infrastructure (Ready to Use)

All database credentials are stored in Vault KV at `secret/data/posthog`:

```json
{
  "postgres_host": "postgresql.data-staging.svc.cluster.local",
  "postgres_port": "5432",
  "postgres_user": "posthog",
  "postgres_password": "<generated>",
  "postgres_database": "posthog",

  "redis_host": "redis-master.data-staging.svc.cluster.local",
  "redis_port": "6379",
  "redis_password": "<from L3>",

  "clickhouse_host": "clickhouse.data-staging.svc.cluster.local",
  "clickhouse_port": "9000",
  "clickhouse_user": "posthog",
  "clickhouse_password": "<generated>",
  "clickhouse_database": "posthog_events",

  "saml_idp_entity_id": "https://sso.zitian.party",
  "saml_idp_sso_url": "https://sso.zitian.party/api/saml",
  "saml_idp_metadata": "https://sso.zitian.party/api/saml/metadata?application=built-in/posthog-saml"
}
```

---

## 🎯 Recommended Next Steps

### Phase 1: Choose Deployment Method
**Decision needed**: Select from Options 1-3 above.

### Phase 2: Deploy PostHog
**After decision**:
- If Docker Compose → Deploy on VPS manually
- If Kubero → Create Pipeline definition
- If Manual K8s → Write Deployment manifests

### Phase 3: Configure SAML
**PostHog Side**:
- Set SAML IdP metadata URL: `https://sso.zitian.party/api/saml/metadata?application=built-in/posthog-saml`
- Configure ACS URL: `https://posthog.zitian.party/complete/saml/`
- Test SAML login flow

---

## 📝 Technical Notes

### Database Schema Ownership
PostHog user has **OWNER** privileges on `posthog` database:
```sql
-- Verified in L2 configuration
OWNER = posthog  -- Can run migrations
```

### ClickHouse Event Storage
PostHog can use ClickHouse for high-volume event data:
```sql
-- Database: posthog_events
-- User: posthog (ALL privileges)
-- Tables: Created by PostHog migrations
```

### SAML Integration
Casdoor SAML application is pre-configured:
- **Application Name**: `posthog-saml`
- **ACS URL**: `https://posthog.zitian.party/complete/saml/`
- **Attributes**: email, firstName, lastName

---

## ⏰ Timeline

- **2025-12-22**: L2 infrastructure completed
- **TBD**: Deployment method selection
- **TBD**: PostHog deployment
- **TBD**: SAML integration testing

---

*Last updated: 2025-12-22*
*Status: Infrastructure ready, awaiting deployment method decision*
