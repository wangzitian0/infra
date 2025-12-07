# 4.insight (Insight Layer / Layer 4)

**Scope**:
- **Observability**: SigNoz (Traces, Logs, Metrics)
- **Analytics**: PostHog (Product Analytics)
- **Alerting**: AlertManager / PagerDuty integration
- **Namespace**: `monitoring`

## Architecture

This layer provides observability and analytics for the entire stack.

### Components (Planned)

| Component | Purpose | Notes |
|-----------|---------|-------|
| SigNoz | OpenTelemetry APM | Replaces Prometheus/Grafana for app teams |
| PostHog | Product analytics | Self-hosted for privacy/cost control |
| AlertManager | Alert routing | Integrated with SigNoz |

### SigNoz

- OpenTelemetry native
- Unified traces, logs, metrics
- Lower operational complexity than Prometheus + Grafana + Loki stack

### PostHog

- Product analytics (funnels, cohorts, feature flags)
- Self-hosted instance for data sovereignty

### Alerting Strategy

- **Infrastructure**: SigNoz built-in alerts
- **Business**: PostHog anomaly detection
- **Escalation**: PagerDuty / Slack integration

### Usage

```bash
terraform apply -target="module.insight"
```

---
*Last updated: 2025-12-08*
