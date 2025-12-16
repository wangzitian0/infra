# 可观测性（日志/监控）SSOT

> **核心问题**：日志、指标、链路追踪怎么收？用什么工具？落在哪一层？

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│  L4 Apps / observability ns                                 │
├─────────────────────────────────────────────────────────────┤
│  Apps (OTel SDK)                                            │
│     └─ traces/metrics/logs → OTel Collector                 │
│                          → SigNoz                           │
│                          → ClickHouse (PV, retain)          │
└─────────────────────────────────────────────────────────────┘
```

## 组件矩阵

| 组件 | 层级 | 命名空间 | 作用 | 部署方式 | 数据落盘 |
|------|------|----------|------|----------|----------|
| **SigNoz** | L4 | `observability` | APM + Logs + Metrics UI/存储 | Helm (未来 TF) | ClickHouse PVC (`local-path-retain`) |
| **OpenTelemetry Collector** | L4 | `observability` | 统一接入、采样、export | Helm (随 SigNoz) | 无状态 |

## Feature Flag

| Flag | 层级 | 默认值 | 说明 |
|------|------|--------|------|
| `enable_observability` | L1 | `false` | 仅 staging/prod 部署 SigNoz/Collector |

## 域名与访问

| 服务 | 域名 | 备注 |
|------|------|------|
| SigNoz UI | `https://signoz.<internal_domain>` | 通过 Cloudflare proxy + cert-manager |

> 域名 SSOT 见 `docs/ssot/network.md`。
> 告警 SSOT 见 `docs/ssot/alerting.md`。

## 接入规范（Apps → OTel）

1. **统一用 OTel SDK**（语言各自官方发行版）。
2. **Service 名**：`{app}-{env}`（如 `cms-staging`）。
3. **Exporter**：OTLP gRPC → `otel-collector.observability.svc:4317`。
4. **采样**：MVP 默认 `parentbased_traceidratio=0.1`，按服务调。

## 数据保留与容量

- ClickHouse 数据在单 VPS 上，**PV reclaimPolicy=Retain**，避免误删。
- 建议从 7 天留存起步，按实际日志/trace 量调大 PV。
- 超过单机容量时，独立 ClickHouse 或迁移到独立 VPS（见 BRN-004 长期路径）。

## 实施状态

| 项目 | 状态 |
|------|------|
| SigNoz Helm/TF 模块 | ⏳ 未落地 |
| Apps OTel 接入 | ⏳ 未落地 |

## 相关文件

- 选型：`docs/project/BRN-004.md`
- Feature flags：`docs/ssot/vars.md`
- 域名规则：`docs/ssot/network.md`

---

## Used by（反向链接）

- [docs/ssot/README.md](./README.md)
- [docs/ssot/alerting.md](./alerting.md)
