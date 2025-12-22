# OpenPanel 部署计划

## 📊 Current Status (2025-12-22)

### ✅ Completed (L2 Infrastructure)
- **PostgreSQL User**: `openpanel` user created in L3 PostgreSQL
- **PostgreSQL Database**: Dedicated `openpanel` database (not shared with `app`)
- **ClickHouse User**: `openpanel` user created in L3 ClickHouse
- **ClickHouse Database**: `openpanel_events` for event storage
- **Vault Credentials**: Stored at `secret/data/openpanel`
- **Casdoor SAML App**: SAML application configured for OpenPanel SSO (to be verified)

### 🔄 In Progress (L4 Deployment)
OpenPanel **officially supports Kubernetes/Helm** deployment (unlike PostHog).

**Advantages over PostHog**:
- ✅ Active Helm chart maintenance
- ✅ Smaller resource footprint
- ✅ Cookie-free tracking (privacy-first)
- ✅ Built-in A/B testing
- ✅ Real-time dashboards

**Trade-offs**:
- ⚠️ Smaller community (vs PostHog)
- ⚠️ Fewer enterprise features (no Session Replay in open-source)

---

## 🔧 Deployment Method

### Kubernetes Helm Deployment (Official)
**Status**: Supported and actively maintained.

**Helm Chart**: https://openpanel.dev/docs/self-hosting/deploy-kubernetes

**Pros**:
- ✅ Official support
- ✅ Kubernetes-native
- ✅ Auto-scaling support
- ✅ Integrated with L2/L3 infrastructure

**Cons**:
- ⚠️ Requires configuration (not fully "ready-to-use")
- ⚠️ Need to configure external databases

**Resources**:
- [OpenPanel Self-Host Docs](https://openpanel.dev/docs/self-hosting/self-hosting)
- [Kubernetes Deployment Guide](https://openpanel.dev/docs/self-hosting/deploy-kubernetes)
- [GitHub Repository](https://github.com/Openpanel-dev/openpanel)

---

## 📋 Prepared Infrastructure (Ready to Use)

All database credentials are stored in Vault KV at `secret/data/openpanel`:

```json
{
  "postgres_host": "postgresql.data-staging.svc.cluster.local",
  "postgres_port": "5432",
  "postgres_user": "openpanel",
  "postgres_password": "<generated>",
  "postgres_database": "openpanel",

  "redis_host": "redis-master.data-staging.svc.cluster.local",
  "redis_port": "6379",
  "redis_password": "<from L3>",

  "clickhouse_host": "clickhouse.data-staging.svc.cluster.local",
  "clickhouse_port": "9000",
  "clickhouse_user": "openpanel",
  "clickhouse_password": "<generated>",
  "clickhouse_database": "openpanel_events",

  "saml_idp_entity_id": "https://sso.zitian.party",
  "saml_idp_sso_url": "https://sso.zitian.party/api/saml",
  "saml_idp_metadata": "https://sso.zitian.party/api/saml/metadata?application=built-in/openpanel-saml"
}
```

---

## 🎯 Next Steps

### Phase 1: Verify OpenPanel SAML Support
**Action**: Check if OpenPanel supports SAML natively.

**Investigation**:
- Review OpenPanel documentation for SSO/SAML configuration
- Check Helm chart values for authentication options
- If SAML is not supported, use OAuth2 Proxy as authentication gateway

### Phase 2: Deploy OpenPanel (L4)
**After SAML verification**:
1. Create `4.apps/3.openpanel.tf` with Helm deployment
2. Configure external databases (PostgreSQL, Redis, ClickHouse)
3. Set up Ingress with TLS: `https://openpanel.${internal_domain}`
4. Deploy via Atlantis: `atlantis apply -p apps`

### Phase 3: Configure Authentication
**OpenPanel Side**:
- **If SAML is supported**:
  - Configure SAML IdP metadata: `https://sso.zitian.party/api/saml/metadata?application=built-in/openpanel-saml`
  - Set ACS URL (to be determined - need to verify OpenPanel callback path)
  - Test SAML login flow
- **If SAML is not supported**:
  - Deploy OAuth2 Proxy in front of OpenPanel
  - Configure Traefik ForwardAuth middleware
  - Use local auth (email/password) as fallback

---

## 📝 Technical Notes

### Database Schema Ownership
OpenPanel user has **OWNER** privileges on `openpanel` database:
```sql
-- Verified in L2 configuration
OWNER = openpanel  -- Can run migrations
```

### ClickHouse Event Storage
OpenPanel uses ClickHouse for high-volume event data:
```sql
-- Database: openpanel_events
-- User: openpanel (ALL privileges)
-- Tables: Created by OpenPanel migrations
```

### SAML Integration (To Be Verified)
Casdoor SAML application is pre-configured:
- **Application Name**: `openpanel-saml`
- **ACS URL**: `https://openpanel.${internal_domain}/auth/saml/callback` (to be verified)
- **Attributes**: email, firstName, lastName

**⚠️ WARNING**: OpenPanel SAML callback URL is not verified in official documentation. Common patterns include:
- `/auth/saml/callback`
- `/api/auth/saml/acs`
- `/complete/saml/`

This needs manual verification after reviewing OpenPanel Helm chart or source code.

---

## 🔍 Outstanding Questions

### Question 1: OpenPanel SAML Support
**Status**: Not verified in documentation.

**Next Action**:
- Check Helm chart values for SSO configuration
- Review OpenPanel GitHub issues/discussions
- Test deployment with local auth first, then add SAML

### Question 2: Helm Chart Configuration Complexity
**Finding**: Helm chart requires substantial upfront configuration.

**Required Configuration**:
- External database connection strings
- Domain names and TLS certificates
- Secret generation (API keys, session keys)
- Resource limits and scaling parameters

**Approach**: Create detailed Terraform configuration following SigNoz pattern.

---

## ⏰ Timeline

- **2025-12-22**: L2 infrastructure completed (switched from PostHog to OpenPanel)
- **TBD**: OpenPanel SAML support verification
- **TBD**: L4 Helm deployment
- **TBD**: Authentication integration testing

---

*Last updated: 2025-12-22*
*Status: L2 infrastructure ready, awaiting SAML verification and L4 deployment*
