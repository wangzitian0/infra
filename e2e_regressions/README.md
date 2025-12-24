# E2E Regression Testing Framework

> **Role**: Infrastructure & Application Verification
> **Engine**: Pytest + Playwright + UV

This framework verifies that the actual state of the infrastructure matches the architectural definitions in SSOT.

## 📚 SSOT References

For the authoritative test strategy and pyramid, refer to:
> [**E2E Regression SSOT**](../docs/ssot/ops.e2e-regressions.md)

## 📂 Test Suites

| Suite | Purpose | SSOT Anchor |
|-------|---------|-------------|
| `bootstrap/` | Core cluster, network, and storage. | [Bootstrap SSOTs](../docs/ssot/README.md#bootstrap---引导层) |
| `platform/` | Identity, Secrets, and Control Plane. | [Platform SSOTs](../docs/ssot/README.md#platform---平台层) |
| `data/` | Database connectivity and auth. | [Data SSOTs](../docs/ssot/README.md#data---数据层) |
| `smoke/` | Critical path verification (Fast). | [E2E SSOT / Smoke](../docs/ssot/ops.e2e-regressions.md#测试分级-test-pyramid) |

## 🚦 Usage

### Setup
```bash
cd e2e_regressions
uv sync
```

### Execution
```bash
# Run smoke tests
uv run pytest tests/smoke/ -v

# Run platform tests
uv run pytest tests/platform/ -v
```

---
*Last updated: 2025-12-25*